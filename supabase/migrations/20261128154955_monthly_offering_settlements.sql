-- Saturday amounts accumulate without any deductions. Existing gross amounts
-- are preserved; no monthly settlement is confirmed by this migration.
alter table public.ofrendas rename to ofrendas_sabatinas;

create table public.ofrendas_mensuales (
  id uuid primary key default gen_random_uuid(),
  mes date not null unique check (mes between date '2026-11-01' and date '2027-10-01' and extract(day from mes)=1),
  fecha_caja date not null check (fecha_caja between date '2026-11-01' and date '2027-10-31'),
  monto_bruto numeric(12,2) not null check (monto_bruto>0 and monto_bruto<>'NaN'::numeric),
  aporte_distrito numeric(12,2) generated always as (round(monto_bruto*.10,2)) stored,
  colaboracion_fija numeric(12,2) generated always as (10.00::numeric) stored,
  monto_neto numeric(12,2) generated always as (monto_bruto-round(monto_bruto*.10,2)-10.00) stored,
  fuente_bruto numeric(14,2) not null,
  fuente_revision text not null,
  ajuste_razon text not null default '' check(length(ajuste_razon)<=300),
  version bigint not null default 1,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  updated_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(date_trunc('month',fecha_caja)::date=mes)
);
alter table public.ofrendas_mensuales enable row level security;
create policy ofrendas_mensuales_lectura on public.ofrendas_mensuales for select to authenticated using (private.es_miembro());
create policy ofrendas_mensuales_escritura on public.ofrendas_mensuales for all to authenticated
using (private.tiene_rol(array['admin','tesoreria'])) with check (private.tiene_rol(array['admin','tesoreria']));
revoke all on public.ofrendas_mensuales from public,anon,authenticated;
grant select on public.ofrendas_mensuales to authenticated;
-- DML is guarded by a trigger, with the same RLS as other treasury data.
grant insert(mes,fecha_caja,monto_bruto,fuente_bruto,fuente_revision,ajuste_razon),
 update(monto_bruto,fuente_bruto,fuente_revision,ajuste_razon,version)
 on public.ofrendas_mensuales to authenticated;
create trigger mensual_autor before update on public.ofrendas_mensuales for each row execute function private.actualizar_autor();

create view public.resumen_ofrendas_mensuales with (security_invoker=true) as
with meses as (
 select generate_series(date '2026-11-01',date '2027-10-01',interval '1 month')::date as mes
), fuentes as (
 select date_trunc('month',fecha)::date as mes,sum(monto_bruto)::numeric(14,2) as total_sabatino,
 count(*)::integer as sabados_registrados,
 md5(string_agg(fecha::text||':'||monto_bruto::text,',' order by fecha)) as fuente_revision
 from public.ofrendas_sabatinas group by 1
)
select m.mes,coalesce(f.total_sabatino,0)::numeric(14,2) as total_sabatino,
 coalesce(f.sabados_registrados,0) as sabados_registrados,coalesce(f.fuente_revision,md5('')) as fuente_revision,
 c.id as cierre_id,c.fecha_caja,c.monto_bruto,c.aporte_distrito,c.colaboracion_fija,c.monto_neto,
 c.ajuste_razon,coalesce(c.version,0) as version,
 (c.id is not null and c.fuente_revision is distinct from coalesce(f.fuente_revision,md5(''))) as requiere_revision
from meses m left join fuentes f using(mes) left join public.ofrendas_mensuales c using(mes);
revoke all on public.resumen_ofrendas_mensuales from public,anon;
grant select on public.resumen_ofrendas_mensuales to authenticated;

-- Serialize Saturday changes and confirmations of the same month.
create function private.bloquear_mes_ofrenda() returns trigger language plpgsql security invoker set search_path='' as $$
declare v_mes date;
begin
 if tg_op='UPDATE' and new.fecha<>old.fecha then raise exception 'La fecha del sábado no se modifica; corrige su monto.'; end if;
 v_mes:=date_trunc('month',case when tg_op='DELETE' then old.fecha else new.fecha end)::date;
 perform pg_advisory_xact_lock(hashtextextended('ofrendas:'||v_mes::text,0));
 if tg_op='DELETE' then return old; end if;
 return new;
end $$;
create trigger sabatina_bloqueo before insert or update or delete on public.ofrendas_sabatinas
for each row execute function private.bloquear_mes_ofrenda();

-- Validate even direct REST writes; clients cannot forge the source snapshot.
create function private.validar_cierre_ofrenda() returns trigger language plpgsql security invoker set search_path='' as $$
declare v_revision text; v_total numeric; v_cantidad integer;
begin
 perform pg_advisory_xact_lock(hashtextextended('ofrendas:'||new.mes::text,0));
 if new.mes>date_trunc('month',now() at time zone 'America/Lima')::date then raise exception 'No se puede confirmar un mes futuro.'; end if;
 select coalesce(sum(monto_bruto),0),count(*),coalesce(md5(string_agg(fecha::text||':'||monto_bruto::text,',' order by fecha)),md5(''))
 into v_total,v_cantidad,v_revision from public.ofrendas_sabatinas where fecha>=new.mes and fecha<(new.mes+interval '1 month')::date;
 if new.fuente_revision is distinct from v_revision or new.fuente_bruto<>v_total then raise exception 'Los sábados cambiaron. Actualiza los datos y revisa el mes.'; end if;
 if v_cantidad>0 and new.monto_bruto<>v_total and length(btrim(new.ajuste_razon))<3 then raise exception 'Explica el ajuste del total mensual.'; end if;
 if tg_op='UPDATE' then new.version:=old.version+1; end if;
 return new;
end $$;
create trigger mensual_validacion before insert or update on public.ofrendas_mensuales
for each row execute function private.validar_cierre_ofrenda();

create function public.confirmar_ofrenda_mensual(p_mes date,p_monto_bruto numeric,p_fuente_revision text,p_version bigint,p_ajuste_razon text default '')
returns uuid language plpgsql security invoker set search_path='' as $$
declare v_actual public.ofrendas_mensuales%rowtype; v_total numeric; v_id uuid; v_fecha date;
begin
 perform pg_advisory_xact_lock(hashtextextended('ofrendas:'||p_mes::text,0));
 select * into v_actual from public.ofrendas_mensuales where mes=p_mes for update;
 if found and v_actual.monto_bruto=p_monto_bruto and v_actual.fuente_revision=p_fuente_revision and v_actual.ajuste_razon=btrim(p_ajuste_razon) then return v_actual.id; end if;
 if coalesce(v_actual.version,0) is distinct from p_version then raise exception 'Otro usuario modificó el cierre. Actualiza y revisa el mes.'; end if;
 select coalesce(sum(monto_bruto),0) into v_total from public.ofrendas_sabatinas where fecha>=p_mes and fecha<(p_mes+interval '1 month')::date;
 if v_actual.id is null then
   v_fecha:=least((p_mes+interval '1 month'-interval '1 day')::date,(now() at time zone 'America/Lima')::date);
   insert into public.ofrendas_mensuales(mes,fecha_caja,monto_bruto,fuente_bruto,fuente_revision,ajuste_razon)
   values(p_mes,v_fecha,p_monto_bruto,v_total,p_fuente_revision,btrim(p_ajuste_razon)) returning id into v_id;
 else
   update public.ofrendas_mensuales set monto_bruto=p_monto_bruto,fuente_bruto=v_total,fuente_revision=p_fuente_revision,ajuste_razon=btrim(p_ajuste_razon)
   where id=v_actual.id returning id into v_id;
 end if;
 return v_id;
end $$;
revoke all on function public.confirmar_ofrenda_mensual(date,numeric,text,bigint,text) from public,anon;
grant execute on function public.confirmar_ofrenda_mensual(date,numeric,text,bigint,text) to authenticated;
revoke all on function private.bloquear_mes_ofrenda(),private.validar_cierre_ofrenda() from public,anon,authenticated;

create or replace view public.resumen_caja with (security_invoker=true) as
with ingresos as (select coalesce(sum(monto_bruto),0) as bruto,coalesce(sum(aporte_distrito),0) as distrito,
 coalesce(sum(colaboracion_fija),0) as colaboracion,coalesce(sum(monto_neto),0) as neto from public.ofrendas_mensuales),
gastos as (select coalesce(sum(monto),0) as monto from public.egresos)
select c.saldo_inicial,i.bruto::numeric(14,2) as ingresos_brutos,i.distrito::numeric(14,2) as aportes_distrito,
 i.colaboracion::numeric(14,2) as colaboraciones,i.neto::numeric(14,2) as ingresos_netos,g.monto::numeric(14,2) as egresos,
 (c.saldo_inicial+i.neto-g.monto)::numeric(14,2) as saldo_actual from public.configuracion_caja c cross join ingresos i cross join gastos g;
create or replace view public.evolucion_caja with (security_invoker=true) as
with dias as (select date '2026-11-01'+n as fecha from generate_series(0,364) as g(n)),
movimientos as (
 select fecha_caja as fecha,monto_neto as ingreso,0::numeric as egreso from public.ofrendas_mensuales
 union all select fecha,0::numeric,monto from public.egresos
), diario as (
 select d.fecha,coalesce(sum(m.ingreso),0) as ingresos_netos,coalesce(sum(m.egreso),0) as egresos
 from dias d left join movimientos m using(fecha) group by d.fecha
)
select d.fecha,d.ingresos_netos::numeric(14,2),d.egresos::numeric(14,2),
(c.saldo_inicial+sum(d.ingresos_netos-d.egresos) over(order by d.fecha))::numeric(14,2) as saldo_caja
from diario d cross join public.configuracion_caja c;
-- These obsolete generated deductions have no remaining accounting consumers.
alter table public.ofrendas_sabatinas drop column aporte_distrito,drop column colaboracion_fija,drop column monto_neto;
