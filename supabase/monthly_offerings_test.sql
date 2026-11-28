-- Run as database owner in SQL Editor. All fixture writes are rolled back.
begin;
select set_config('request.jwt.claim.sub',(select id::text from auth.users order by created_at limit 1),true);
set local role authenticated;
do $$
declare v_base numeric; v_revision text; v_old_revision text; v_id uuid; v_retry uuid; v_version bigint;
begin
 select saldo_actual into v_base from public.resumen_caja;
 insert into public.ofrendas_sabatinas(fecha,monto_bruto) values
 ('2026-11-07',100),('2026-11-14',100),('2026-11-21',100),('2026-11-28',100);
 if (select saldo_actual from public.resumen_caja)<>v_base then raise exception 'Pending Saturdays entered cash'; end if;
 select fuente_revision into v_revision from public.resumen_ofrendas_mensuales where mes='2026-11-01';
 v_old_revision:=v_revision;
 v_id:=public.confirmar_ofrenda_mensual('2026-11-01',400,v_revision,0,'');
 if not exists(select 1 from public.ofrendas_mensuales where id=v_id and aporte_distrito=40 and colaboracion_fija=10 and monto_neto=350) then raise exception 'Monthly deductions incorrect'; end if;
 if (select saldo_actual from public.resumen_caja)<>v_base+350 then raise exception 'Cash wrong'; end if;
 v_retry:=public.confirmar_ofrenda_mensual('2026-11-01',400,v_revision,0,'');
 if v_retry<>v_id or (select version from public.ofrendas_mensuales where id=v_id)<>1 then raise exception 'Retry not idempotent'; end if;
 update public.ofrendas_sabatinas set monto_bruto=150 where fecha='2026-11-28';
 if not exists(select 1 from public.resumen_ofrendas_mensuales where mes='2026-11-01' and total_sabatino=450 and requiere_revision) then raise exception 'Source change not flagged'; end if;
 if (select saldo_actual from public.resumen_caja)<>v_base+350 then raise exception 'Unconfirmed correction changed cash'; end if;
 begin
   perform public.confirmar_ofrenda_mensual('2026-11-01',450,v_old_revision,1,'');
   raise exception 'Stale source accepted' using errcode='P0002';
 exception when sqlstate 'P0001' then null; end;
 select fuente_revision into v_revision from public.resumen_ofrendas_mensuales where mes='2026-11-01';
 perform public.confirmar_ofrenda_mensual('2026-11-01',450,v_revision,1,'');
 if (select monto_neto from public.ofrendas_mensuales where id=v_id)<>395 then raise exception 'Correction wrong'; end if;
 begin
   perform public.confirmar_ofrenda_mensual('2026-11-01',460,v_revision,2,'');
   raise exception 'Unexplained adjustment accepted' using errcode='P0002';
 exception when sqlstate 'P0001' then null; end;
 perform public.confirmar_ofrenda_mensual('2026-11-01',460,v_revision,2,'Ajuste por conteo');
 begin
   perform public.confirmar_ofrenda_mensual('2026-11-01',470,v_revision,2,'Otro cierre');
   raise exception 'Stale version accepted' using errcode='P0002';
 exception when sqlstate 'P0001' then null; end;
 if (select count(*) from public.ofrendas_mensuales where mes='2026-11-01')<>1 then raise exception 'Duplicate month'; end if;
 if (select saldo_actual from public.resumen_caja)<>v_base+404 then raise exception 'Double counted cash'; end if;
 if (select saldo_caja from public.evolucion_caja order by fecha desc limit 1)<>(select saldo_actual from public.resumen_caja) then raise exception 'Chart and balance differ'; end if;
 update public.ofrendas_sabatinas set monto_bruto=.05 where fecha between '2026-11-01' and '2026-11-30';
 select fuente_revision into v_revision from public.resumen_ofrendas_mensuales where mes='2026-11-01';
 perform public.confirmar_ofrenda_mensual('2026-11-01',.20,v_revision,3,'');
 if not exists(select 1 from public.ofrendas_mensuales where id=v_id and aporte_distrito=.02 and monto_neto=-9.82) then raise exception 'Rounding must use month gross'; end if;
end $$;
rollback;
