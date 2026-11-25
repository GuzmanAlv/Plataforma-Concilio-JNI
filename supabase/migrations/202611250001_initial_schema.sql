-- Concilio JNI Dreamrs · ciclo oficial 01/11/2026–31/10/2027 · PEN.
-- Ejecutar una sola vez mediante Supabase CLI o SQL Editor (rol postgres).
begin;

create schema if not exists extensions;
create extension if not exists btree_gist with schema extensions;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table public.perfiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null default '',
  rol text not null check (rol in ('admin','secretaria','tesoreria','consulta')),
  created_at timestamptz not null default now()
);

create function private.tiene_rol(p_roles text[]) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.perfiles
    where user_id = (select auth.uid()) and rol = any(p_roles));
$$;
revoke all on function private.tiene_rol(text[]) from public, anon;
grant execute on function private.tiene_rol(text[]) to authenticated;

create function private.es_miembro() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.perfiles where user_id = (select auth.uid()));
$$;
revoke all on function private.es_miembro() from public, anon;
grant execute on function private.es_miembro() to authenticated;

create table public.grupos (
  id text primary key check (id in ('amarillo','verde','rojo','celeste')),
  nombre text generated always as ('Grupo ' || case id
    when 'amarillo' then 'Amarillo' when 'verde' then 'Verde'
    when 'rojo' then 'Rojo' when 'celeste' then 'Celeste' end) stored,
  activo boolean not null default false
);
insert into public.grupos(id) values ('amarillo'),('verde'),('rojo'),('celeste');

create table public.integrantes (
  id uuid primary key default gen_random_uuid(),
  nombre_completo text not null check (length(btrim(nombre_completo)) between 2 and 160),
  fecha_nacimiento date not null check (fecha_nacimiento >= date '1900-01-01'),
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.membresias_grupo (
  id uuid primary key default gen_random_uuid(),
  integrante_id uuid not null references public.integrantes(id) on delete restrict,
  grupo_id text not null references public.grupos(id) on delete restrict,
  rol text not null check (rol in ('lider','integrante')),
  fecha_inicio date not null,
  fecha_fin date,
  created_at timestamptz not null default now(),
  check (fecha_fin is null or fecha_fin > fecha_inicio),
  -- [inicio,fin): el día del cambio pertenece al nuevo grupo.
  exclude using gist (integrante_id with =,
    daterange(fecha_inicio,fecha_fin,'[)') with &&)
);
create index membresias_grupo_grupo_fecha_idx on public.membresias_grupo(grupo_id,fecha_inicio);

create table public.asistencia_sesiones (
  id uuid primary key default gen_random_uuid(),
  grupo_id text not null references public.grupos(id) on delete restrict,
  fecha date not null check (fecha between date '2026-11-01' and date '2027-10-31'
    and extract(isodow from fecha) = 6),
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  updated_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(grupo_id,fecha)
);

create table public.asistencia_registros (
  id uuid primary key default gen_random_uuid(),
  sesion_id uuid not null references public.asistencia_sesiones(id) on delete restrict,
  integrante_id uuid not null references public.integrantes(id) on delete restrict,
  presente boolean not null,
  unique(sesion_id,integrante_id)
);
create index asistencia_registros_integrante_idx on public.asistencia_registros(integrante_id);

create table public.ofrendas (
  id uuid primary key default gen_random_uuid(),
  fecha date not null unique check (fecha between date '2026-11-01' and date '2027-10-31'
    and extract(isodow from fecha) = 6),
  monto_bruto numeric(12,2) not null check (monto_bruto > 0 and monto_bruto <> 'NaN'::numeric),
  aporte_distrito numeric(12,2) generated always as (round(monto_bruto * 0.10,2)) stored,
  colaboracion_fija numeric(12,2) generated always as (10.00::numeric) stored,
  -- No se trunca a cero: una ofrenda pequeña puede dejar un neto negativo.
  monto_neto numeric(12,2) generated always as
    (monto_bruto - round(monto_bruto * 0.10,2) - 10.00) stored,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  updated_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.egresos (
  id uuid primary key default gen_random_uuid(),
  fecha date not null check (fecha between date '2026-11-01' and date '2027-10-31'),
  monto numeric(12,2) not null check (monto > 0 and monto <> 'NaN'::numeric),
  concepto text not null check (length(btrim(concepto)) between 2 and 300),
  comprobante_path text check (comprobante_path is null or
    (length(comprobante_path) between 3 and 500 and comprobante_path !~ '(^/|\.\.|://)')),
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  updated_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index egresos_fecha_idx on public.egresos(fecha);

create table public.configuracion_caja (
  id smallint primary key default 1 check (id = 1),
  saldo_inicial numeric(12,2) not null default 0 check (saldo_inicial <> 'NaN'::numeric),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null default auth.uid()
);
insert into public.configuracion_caja(id) values (1);

create table public.configuracion_app (
  id smallint primary key default 1 check (id = 1),
  version_actual text not null default '0.1.0' check (version_actual ~ '^\d+\.\d+\.\d+$'),
  build_actual integer not null default 1 check (build_actual > 0),
  url_apk text check (url_apk is null or url_apk ~ '^https://[^[:space:]]+$'),
  updated_at timestamptz not null default now()
);
insert into public.configuracion_app(id) values (1);

create table public.inventario_items (
  id uuid primary key default gen_random_uuid(),
  nombre text not null check (length(btrim(nombre)) between 2 and 160),
  cantidad integer not null default 0 check (cantidad >= 0),
  estado text not null default 'bueno' check (estado in ('bueno','regular','malo','baja')),
  observaciones text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.auditoria_caja (
  id bigint generated always as identity primary key,
  saldo_anterior numeric(12,2) not null,
  saldo_nuevo numeric(12,2) not null,
  modificado_por uuid references auth.users(id) on delete set null,
  modificado_en timestamptz not null default now()
);

create function private.actualizar_timestamp() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
create trigger integrantes_timestamp before update on public.integrantes
for each row execute function private.actualizar_timestamp();
create trigger inventario_timestamp before update on public.inventario_items
for each row execute function private.actualizar_timestamp();
create trigger app_timestamp before update on public.configuracion_app
for each row execute function private.actualizar_timestamp();

create function private.actualizar_autor() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end;
$$;
create trigger sesiones_autor before update on public.asistencia_sesiones
for each row execute function private.actualizar_autor();
create trigger ofrendas_autor before update on public.ofrendas
for each row execute function private.actualizar_autor();
create trigger egresos_autor before update on public.egresos
for each row execute function private.actualizar_autor();
create trigger caja_autor before update on public.configuracion_caja
for each row execute function private.actualizar_autor();

create function private.auditar_caja() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.saldo_inicial is distinct from new.saldo_inicial then
    insert into public.auditoria_caja(saldo_anterior,saldo_nuevo,modificado_por)
    values (old.saldo_inicial,new.saldo_inicial,auth.uid());
  end if;
  return new;
end;
$$;
create trigger caja_auditoria after update on public.configuracion_caja
for each row execute function private.auditar_caja();

create function private.validar_integrante() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.fecha_nacimiento > (now() at time zone 'America/Lima')::date then
    raise exception 'La fecha de nacimiento no puede estar en el futuro.';
  end if;
  if tg_op = 'UPDATE' and new.activo is distinct from old.activo
    and not new.activo and exists (select 1 from public.membresias_grupo
      where integrante_id = new.id and fecha_fin is null) then
    raise exception 'Utiliza archivar_integrante para cerrar su membresía y conservar el historial.';
  end if;
  return new;
end;
$$;
create trigger integrantes_validacion before insert or update on public.integrantes
for each row execute function private.validar_integrante();

create function private.validar_membresia() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op <> 'DELETE' then
    if not exists (select 1 from public.integrantes where id = new.integrante_id and activo) then
      raise exception 'Solo se puede asignar un integrante activo.';
    end if;
    if new.fecha_inicio < (select fecha_nacimiento from public.integrantes where id = new.integrante_id) then
      raise exception 'La membresía no puede empezar antes del nacimiento.';
    end if;
  end if;
  if tg_op <> 'INSERT' then
    if exists (
      select 1 from public.asistencia_registros r
      join public.asistencia_sesiones s on s.id = r.sesion_id
      where r.integrante_id = old.integrante_id and s.grupo_id = old.grupo_id
        and s.fecha >= old.fecha_inicio and (old.fecha_fin is null or s.fecha < old.fecha_fin)
        and (tg_op = 'DELETE' or new.integrante_id <> old.integrante_id
          or new.grupo_id <> s.grupo_id or s.fecha < new.fecha_inicio
          or (new.fecha_fin is not null and s.fecha >= new.fecha_fin))
    ) then
      raise exception 'El cambio invalidaría asistencia histórica. Elige una fecha posterior a los registros existentes.';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
create trigger membresias_validacion before insert or update or delete on public.membresias_grupo
for each row execute function private.validar_membresia();

-- Los grupos se pueden preparar en borrador. Al activarlos se exige >=2 líderes.
-- La restricción diferida permite reemplazar líderes en una sola transacción.
create function private.validar_lideres() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_grupo record;
begin
  -- Bloqueo consistente para que dos cambios concurrentes no evadan el mínimo.
  perform 1 from public.grupos order by id for update;
  for v_grupo in select id from public.grupos where activo loop
    if (select count(*) from public.membresias_grupo m
      join public.integrantes i on i.id=m.integrante_id
      where m.grupo_id=v_grupo.id and m.rol='lider' and i.activo
        and m.fecha_inicio <= (now() at time zone 'America/Lima')::date
        and (m.fecha_fin is null or m.fecha_fin > (now() at time zone 'America/Lima')::date)) < 2 then
      raise exception 'El grupo % activo requiere por lo menos dos líderes actuales.',v_grupo.id;
    end if;
  end loop;
  return null;
end;
$$;
create constraint trigger grupos_lideres after insert or update on public.grupos
deferrable initially deferred for each row execute function private.validar_lideres();
create constraint trigger membresias_lideres after insert or update or delete on public.membresias_grupo
deferrable initially deferred for each row execute function private.validar_lideres();
create constraint trigger integrantes_lideres after update on public.integrantes
deferrable initially deferred for each row execute function private.validar_lideres();

create function private.validar_asistencia() returns trigger
language plpgsql set search_path = '' as $$
declare v_fecha date; v_grupo text;
begin
  select fecha,grupo_id into strict v_fecha,v_grupo from public.asistencia_sesiones where id=new.sesion_id;
  if not exists (select 1 from public.membresias_grupo where integrante_id=new.integrante_id
    and grupo_id=v_grupo and fecha_inicio<=v_fecha and (fecha_fin is null or fecha_fin>v_fecha)) then
    raise exception 'El integrante no pertenecía a ese grupo en la fecha seleccionada.';
  end if;
  if exists (select 1 from public.asistencia_registros r join public.asistencia_sesiones s on s.id=r.sesion_id
    where r.integrante_id=new.integrante_id and s.fecha=v_fecha and s.id<>new.sesion_id) then
    raise exception 'El integrante ya tiene asistencia en otro grupo ese sábado.';
  end if;
  return new;
end;
$$;
create trigger registros_validacion before insert or update on public.asistencia_registros
for each row execute function private.validar_asistencia();

-- RPC: escritura atómica de integrante y asignación inicial.
create function public.crear_integrante(
  p_nombre_completo text,p_fecha_nacimiento date,p_grupo_id text,
  p_rol text default 'integrante',p_fecha_inicio date default date '2026-11-01'
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if not private.tiene_rol(array['admin','secretaria']) then raise exception 'Acceso denegado.' using errcode='42501'; end if;
  perform 1 from public.grupos order by id for update;
  insert into public.integrantes(nombre_completo,fecha_nacimiento)
    values (btrim(p_nombre_completo),p_fecha_nacimiento) returning id into v_id;
  insert into public.membresias_grupo(integrante_id,grupo_id,rol,fecha_inicio)
    values (v_id,p_grupo_id,p_rol,p_fecha_inicio);
  return v_id;
end;
$$;

create function public.cambiar_grupo(p_integrante_id uuid,p_grupo_id text,p_rol text,p_fecha date)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_actual public.membresias_grupo%rowtype; v_id uuid;
begin
  if not private.tiene_rol(array['admin','secretaria']) then raise exception 'Acceso denegado.' using errcode='42501'; end if;
  if p_fecha is null or p_fecha > (now() at time zone 'America/Lima')::date then
    raise exception 'Indica una fecha efectiva de cambio que no sea futura.';
  end if;
  perform 1 from public.grupos order by id for update;
  perform 1 from public.integrantes where id=p_integrante_id and activo for update;
  if not found then raise exception 'Integrante activo no encontrado.'; end if;
  select * into v_actual from public.membresias_grupo
    where integrante_id=p_integrante_id and fecha_fin is null for update;
  if found then
    if v_actual.grupo_id=p_grupo_id and v_actual.rol=p_rol then return v_actual.id; end if;
    if p_fecha <= v_actual.fecha_inicio then
      raise exception 'La nueva asignación debe empezar después de la asignación vigente.';
    end if;
    update public.membresias_grupo set fecha_fin=p_fecha where id=v_actual.id;
  end if;
  insert into public.membresias_grupo(integrante_id,grupo_id,rol,fecha_inicio)
    values (p_integrante_id,p_grupo_id,p_rol,p_fecha) returning id into v_id;
  return v_id;
end;
$$;

create function public.archivar_integrante(p_integrante_id uuid,p_fecha date)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.tiene_rol(array['admin','secretaria']) then raise exception 'Acceso denegado.' using errcode='42501'; end if;
  if p_fecha is null or p_fecha > (now() at time zone 'America/Lima')::date then
    raise exception 'Indica una fecha de baja que no sea futura.';
  end if;
  perform 1 from public.grupos order by id for update;
  perform 1 from public.integrantes where id=p_integrante_id for update;
  if not found then raise exception 'Integrante no encontrado.'; end if;
  update public.membresias_grupo set fecha_fin=p_fecha
    where integrante_id=p_integrante_id and fecha_fin is null;
  update public.integrantes set activo=false where id=p_integrante_id;
end;
$$;

create function public.guardar_asistencia(p_grupo_id text,p_fecha date,p_presentes uuid[])
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_sesion uuid;
begin
  if not private.tiene_rol(array['admin','secretaria']) then raise exception 'Acceso denegado.' using errcode='42501'; end if;
  if p_fecha is null or p_fecha < date '2026-11-01' or p_fecha > date '2027-10-31'
    or extract(isodow from p_fecha) <> 6 then
    raise exception 'Selecciona un sábado del ciclo noviembre 2026–octubre 2027.' using errcode='23514';
  end if;
  if p_presentes is null or array_position(p_presentes,null) is not null then
    raise exception 'Envía una lista de UUID presentes (puede estar vacía).';
  end if;
  -- Serializa correcciones con movimientos de grupo y otros guardados.
  perform 1 from public.grupos order by id for update;
  if exists (select 1 from unnest(p_presentes) as p(id) where not exists (
    select 1 from public.membresias_grupo m where m.integrante_id=p.id and m.grupo_id=p_grupo_id
      and m.fecha_inicio<=p_fecha and (m.fecha_fin is null or m.fecha_fin>p_fecha)
  )) then raise exception 'La lista contiene un integrante ajeno al grupo en esa fecha.'; end if;
  insert into public.asistencia_sesiones(grupo_id,fecha) values (p_grupo_id,p_fecha)
    on conflict(grupo_id,fecha) do update set updated_at=now(),updated_by=auth.uid()
    returning id into v_sesion;
  -- Snapshot completo: los convocados no marcados quedan como ausentes.
  insert into public.asistencia_registros(sesion_id,integrante_id,presente)
    select v_sesion,m.integrante_id,m.integrante_id=any(p_presentes)
    from public.membresias_grupo m where m.grupo_id=p_grupo_id and m.fecha_inicio<=p_fecha
      and (m.fecha_fin is null or m.fecha_fin>p_fecha)
    on conflict(sesion_id,integrante_id) do update set presente=excluded.presente;
  return v_sesion;
end;
$$;

-- Vistas con permisos del usuario: nunca eluden RLS.
create view public.asistencia_por_sabado with (security_invoker=true) as
select s.fecha,s.grupo_id,count(r.id)::integer as total_convocados,
  count(r.id) filter (where r.presente)::integer as total_presentes
from public.asistencia_sesiones s left join public.asistencia_registros r on r.sesion_id=s.id
group by s.id,s.fecha,s.grupo_id;

create view public.resumen_caja with (security_invoker=true) as
select c.saldo_inicial,
  coalesce((select sum(monto_bruto) from public.ofrendas),0)::numeric(14,2) as ingresos_brutos,
  coalesce((select sum(aporte_distrito) from public.ofrendas),0)::numeric(14,2) as aportes_distrito,
  coalesce((select sum(colaboracion_fija) from public.ofrendas),0)::numeric(14,2) as colaboraciones,
  coalesce((select sum(monto_neto) from public.ofrendas),0)::numeric(14,2) as ingresos_netos,
  coalesce((select sum(monto) from public.egresos),0)::numeric(14,2) as egresos,
  (c.saldo_inicial+coalesce((select sum(monto_neto) from public.ofrendas),0)
    -coalesce((select sum(monto) from public.egresos),0))::numeric(14,2) as saldo_actual
from public.configuracion_caja c;

create view public.evolucion_caja with (security_invoker=true) as
with dias as (
  select date '2026-11-01'+n as fecha from generate_series(0,364) as g(n)
), movimientos as (
  select fecha,sum(monto_neto)::numeric(14,2) as ingreso,0::numeric(14,2) as egreso
    from public.ofrendas group by fecha
  union all
  select fecha,0::numeric(14,2),sum(monto)::numeric(14,2) from public.egresos group by fecha
), diario as (
  select d.fecha,coalesce(sum(m.ingreso),0) as ingresos_netos,coalesce(sum(m.egreso),0) as egresos
    from dias d left join movimientos m on m.fecha=d.fecha group by d.fecha
)
select d.fecha,d.ingresos_netos::numeric(14,2),d.egresos::numeric(14,2),
  (c.saldo_inicial+sum(d.ingresos_netos-d.egresos) over(order by d.fecha))::numeric(14,2) as saldo_caja
from diario d cross join public.configuracion_caja c;

-- RLS: el registro en Auth por sí solo no permite leer datos del concilio.
alter table public.perfiles enable row level security;
create policy perfiles_lectura on public.perfiles for select to authenticated
using (user_id=(select auth.uid()) or private.tiene_rol(array['admin']));
create policy perfiles_admin on public.perfiles for all to authenticated
using (private.tiene_rol(array['admin'])) with check (private.tiene_rol(array['admin']));

alter table public.grupos enable row level security;
create policy grupos_lectura on public.grupos for select to authenticated using (private.es_miembro());
create policy grupos_escritura on public.grupos for update to authenticated
using (private.tiene_rol(array['admin','secretaria'])) with check (private.tiene_rol(array['admin','secretaria']));

alter table public.integrantes enable row level security;
create policy integrantes_lectura on public.integrantes for select to authenticated using (private.es_miembro());
create policy integrantes_edicion on public.integrantes for update to authenticated
using (private.tiene_rol(array['admin','secretaria'])) with check (private.tiene_rol(array['admin','secretaria']));

alter table public.membresias_grupo enable row level security;
create policy membresias_lectura on public.membresias_grupo for select to authenticated using (private.es_miembro());
alter table public.asistencia_sesiones enable row level security;
create policy sesiones_lectura on public.asistencia_sesiones for select to authenticated using (private.es_miembro());
alter table public.asistencia_registros enable row level security;
create policy registros_lectura on public.asistencia_registros for select to authenticated using (private.es_miembro());

alter table public.ofrendas enable row level security;
create policy ofrendas_lectura on public.ofrendas for select to authenticated using (private.es_miembro());
create policy ofrendas_escritura on public.ofrendas for all to authenticated
using (private.tiene_rol(array['admin','tesoreria'])) with check (private.tiene_rol(array['admin','tesoreria']));
alter table public.egresos enable row level security;
create policy egresos_lectura on public.egresos for select to authenticated using (private.es_miembro());
create policy egresos_escritura on public.egresos for all to authenticated
using (private.tiene_rol(array['admin','tesoreria'])) with check (private.tiene_rol(array['admin','tesoreria']));
alter table public.configuracion_caja enable row level security;
create policy caja_lectura on public.configuracion_caja for select to authenticated using (private.es_miembro());
create policy caja_escritura on public.configuracion_caja for update to authenticated
using (private.tiene_rol(array['admin','tesoreria'])) with check (private.tiene_rol(array['admin','tesoreria']));
alter table public.configuracion_app enable row level security;
create policy app_lectura on public.configuracion_app for select to anon,authenticated using (true);
create policy app_escritura on public.configuracion_app for update to authenticated
using (private.tiene_rol(array['admin'])) with check (private.tiene_rol(array['admin']));
alter table public.inventario_items enable row level security;
create policy inventario_lectura on public.inventario_items for select to authenticated using (private.es_miembro());
create policy inventario_escritura on public.inventario_items for all to authenticated
using (private.tiene_rol(array['admin','secretaria'])) with check (private.tiene_rol(array['admin','secretaria']));
alter table public.auditoria_caja enable row level security;
create policy auditoria_lectura on public.auditoria_caja for select to authenticated
using (private.tiene_rol(array['admin','tesoreria']));

-- Grants explícitos: las tablas que se escriben por RPC no tienen DML de cliente.
revoke all on public.perfiles,public.grupos,public.integrantes,public.membresias_grupo,
  public.asistencia_sesiones,public.asistencia_registros,public.ofrendas,public.egresos,
  public.configuracion_caja,public.configuracion_app,public.inventario_items,public.auditoria_caja
from anon,authenticated;
grant select on public.perfiles,public.grupos,public.integrantes,public.membresias_grupo,
  public.asistencia_sesiones,public.asistencia_registros,public.ofrendas,public.egresos,
  public.configuracion_caja,public.configuracion_app,public.inventario_items,public.auditoria_caja
to authenticated;
grant select on public.configuracion_app to anon;
grant insert,update,delete on public.perfiles to authenticated;
grant insert(id,fecha,monto_bruto),update(fecha,monto_bruto) on public.ofrendas to authenticated;
grant insert(id,fecha,monto,concepto,comprobante_path),update(fecha,monto,concepto,comprobante_path)
  on public.egresos to authenticated;
grant insert(id,nombre,cantidad,estado,observaciones),update(nombre,cantidad,estado,observaciones)
  on public.inventario_items to authenticated;
grant delete on public.ofrendas,public.egresos,public.inventario_items to authenticated;
grant update(activo) on public.grupos to authenticated;
grant update(nombre_completo,fecha_nacimiento) on public.integrantes to authenticated;
grant update(saldo_inicial) on public.configuracion_caja to authenticated;
grant update(version_actual,build_actual,url_apk) on public.configuracion_app to authenticated;
grant select on public.asistencia_por_sabado,public.resumen_caja,public.evolucion_caja to authenticated;
revoke all on public.asistencia_por_sabado,public.resumen_caja,public.evolucion_caja from anon;

revoke all on function public.crear_integrante(text,date,text,text,date) from public,anon;
revoke all on function public.cambiar_grupo(uuid,text,text,date) from public,anon;
revoke all on function public.archivar_integrante(uuid,date) from public,anon;
revoke all on function public.guardar_asistencia(text,date,uuid[]) from public,anon;
grant execute on function public.crear_integrante(text,date,text,text,date),
  public.cambiar_grupo(uuid,text,text,date),public.archivar_integrante(uuid,date),
  public.guardar_asistencia(text,date,uuid[]) to authenticated;

-- Storage: archivos privados; guardar solo la ruta, generar URLs firmadas temporales.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('comprobantes','comprobantes',false,10485760,
  array['image/jpeg','image/png','image/webp','image/heic','image/heif']);
create policy comprobantes_lectura on storage.objects for select to authenticated
using (bucket_id='comprobantes' and private.es_miembro());
create policy comprobantes_insert on storage.objects for insert to authenticated
with check (bucket_id='comprobantes' and private.tiene_rol(array['admin','tesoreria']));
create policy comprobantes_update on storage.objects for update to authenticated
using (bucket_id='comprobantes' and private.tiene_rol(array['admin','tesoreria']))
with check (bucket_id='comprobantes' and private.tiene_rol(array['admin','tesoreria']));
create policy comprobantes_delete on storage.objects for delete to authenticated
using (bucket_id='comprobantes' and private.tiene_rol(array['admin','tesoreria']));

-- Las funciones internas no son RPC y no deben poder invocarse directamente.
revoke all on function private.actualizar_timestamp(),private.actualizar_autor(),
  private.auditar_caja(),private.validar_integrante(),private.validar_membresia(),
  private.validar_lideres(),private.validar_asistencia() from public,anon,authenticated;

commit;
