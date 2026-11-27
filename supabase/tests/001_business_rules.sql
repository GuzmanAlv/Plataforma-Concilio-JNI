-- Ejecutar como postgres sobre una base de PRUEBAS con la migración instalada.
-- psql -v ON_ERROR_STOP=1 -f supabase/tests/001_business_rules.sql
-- Los cambios se revierten al terminar. No requiere pgTAP.
begin;

insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000000001','concilio-admin-test@example.invalid'),
 ('00000000-0000-4000-8000-000000000002','concilio-consulta-test@example.invalid'),
 ('00000000-0000-4000-8000-000000000003','concilio-sin-perfil-test@example.invalid'),
 ('00000000-0000-4000-8000-000000000004','concilio-secretaria-test@example.invalid'),
 ('00000000-0000-4000-8000-000000000005','concilio-tesoreria-test@example.invalid');
insert into public.perfiles(user_id,nombre,rol) values
 ('00000000-0000-4000-8000-000000000001','Prueba admin','admin'),
 ('00000000-0000-4000-8000-000000000002','Prueba consulta','consulta'),
 ('00000000-0000-4000-8000-000000000004','Prueba secretaria','secretaria'),
 ('00000000-0000-4000-8000-000000000005','Prueba tesoreria','tesoreria');

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
set local role authenticated;

do $$
declare
  v_joven uuid; v_otro uuid; v_lider1 uuid; v_lider2 uuid; v_sesion uuid; v_sesion2 uuid;
  v_rechazado boolean; v_saldo numeric;
begin
  if (select count(*) from public.grupos) <> 4 then raise exception 'Deben existir exactamente cuatro grupos.'; end if;
  v_joven := public.crear_integrante('Joven de prueba',date '2005-06-12','amarillo');
  v_otro := public.crear_integrante('Otro joven de prueba',date '2006-02-14','verde');
  v_sesion := public.guardar_asistencia('amarillo',date '2026-11-07',array[v_joven]);
  v_sesion2 := public.guardar_asistencia('amarillo',date '2026-11-07',array[]::uuid[]);
  if v_sesion<>v_sesion2 then raise exception 'Corregir asistencia debe conservar la sesión.'; end if;
  if (select count(*) from public.asistencia_registros where sesion_id=v_sesion)<>1 then
    raise exception 'Asistencia duplicada o snapshot incorrecto.';
  end if;
  if (select presente from public.asistencia_registros where sesion_id=v_sesion and integrante_id=v_joven) then
    raise exception 'La corrección de presencia no se guardó.';
  end if;
  if (select count(*) from public.asistencia_por_sabado where grupo_id='amarillo')<>1 then
    raise exception 'Los sábados sin registro no se deben convertir en ceros.';
  end if;

  v_rechazado := false;
  begin perform public.guardar_asistencia('amarillo',date '2026-11-07',array[v_otro]);
  exception when others then v_rechazado:=true; end;
  if not v_rechazado then raise exception 'Se aceptó integrante ajeno al grupo.'; end if;

  v_rechazado := false;
  begin perform public.guardar_asistencia('amarillo',date '2026-11-08',array[v_joven]);
  exception when check_violation then v_rechazado:=true; end;
  if not v_rechazado then raise exception 'Se aceptó una asistencia de domingo.'; end if;

  v_rechazado := false;
  begin perform public.guardar_asistencia('amarillo',date '2026-10-31',array[v_joven]);
  exception when check_violation then v_rechazado:=true; end;
  if not v_rechazado then raise exception 'Se aceptó fecha anterior al ciclo.'; end if;

  v_rechazado := false;
  begin perform public.cambiar_grupo(v_joven,'verde','integrante',date '2026-11-06');
  exception when others then v_rechazado:=true; end;
  if not v_rechazado then raise exception 'Se permitió invalidar una asistencia histórica.'; end if;

  perform public.cambiar_grupo(v_joven,'verde','integrante',date '2026-11-08');
  perform public.cambiar_grupo(v_joven,'verde','integrante',date '2026-11-09');
  if (select count(*) from public.membresias_grupo where integrante_id=v_joven)<>2 then
    raise exception 'Mantener el grupo actual no debe crear otra membresía.';
  end if;
  perform public.guardar_asistencia('verde',date '2026-11-14',array[v_joven]);
  if (select total_convocados from public.asistencia_por_sabado where grupo_id='verde' and fecha=date '2026-11-14')<>2 then
    raise exception 'La lista histórica de convocados es incorrecta.';
  end if;
  perform public.archivar_integrante(v_joven,date '2026-11-15');
  if (select activo from public.integrantes where id=v_joven) then raise exception 'La baja no se guardó.'; end if;
  if (select count(*) from public.asistencia_registros where integrante_id=v_joven)<>2 then
    raise exception 'La baja perdió la asistencia histórica.';
  end if;

  v_rechazado := false;
  begin
    update public.grupos set activo=true where id='amarillo';
    set constraints all immediate;
  exception when others then v_rechazado:=true; end;
  if not v_rechazado then raise exception 'Se activó un grupo sin dos líderes.'; end if;
  set constraints all deferred;
  v_lider1:=public.crear_integrante('Líder uno de prueba',date '2000-01-01','amarillo','lider');
  v_lider2:=public.crear_integrante('Líder dos de prueba',date '2001-01-01','amarillo','lider');
  update public.grupos set activo=true where id='amarillo';
  set constraints all immediate;
  set constraints all deferred;
  v_rechazado:=false;
  begin
    perform public.cambiar_grupo(v_lider1,'verde','lider',date '2026-11-20');
    set constraints all immediate;
  exception when others then v_rechazado:=true; end;
  if not v_rechazado then raise exception 'Se dejó un grupo activo con un solo líder.'; end if;
  set constraints all deferred;

  insert into public.ofrendas(fecha,monto_bruto) values (date '2026-11-07',100);
  if not exists (select 1 from public.ofrendas where fecha=date '2026-11-07'
    and aporte_distrito=10 and colaboracion_fija=10 and monto_neto=80) then
    raise exception 'Desglose de ofrenda incorrecto.';
  end if;
  insert into public.ofrendas(fecha,monto_bruto) values (date '2026-11-14',5);
  if (select monto_neto from public.ofrendas where fecha=date '2026-11-14')<>-5.50 then
    raise exception 'El neto negativo no debe truncarse.';
  end if;
  delete from public.ofrendas where fecha=date '2026-11-14';
  v_rechazado:=false;
  begin insert into public.ofrendas(fecha,monto_bruto) values (date '2026-11-07',120);
  exception when unique_violation then v_rechazado:=true; end;
  if not v_rechazado then raise exception 'Se duplicó una ofrenda del mismo sábado.'; end if;
  v_rechazado:=false;
  begin insert into public.ofrendas(fecha,monto_bruto) values(date '2026-11-28','NaN'::numeric);
  exception when check_violation then v_rechazado:=true; end;
  if not v_rechazado then raise exception 'La caja admite importes NaN.'; end if;
  insert into public.egresos(fecha,monto,concepto) values (date '2026-11-08',25,'Gasto de prueba');
  update public.configuracion_caja set saldo_inicial=100 where id=1;
  select saldo_actual into v_saldo from public.resumen_caja;
  if v_saldo<>155 then raise exception 'Saldo incorrecto: %',v_saldo; end if;
  if (select saldo_caja from public.evolucion_caja where fecha=date '2026-11-30')<>155 then
    raise exception 'La evolución perdió el saldo de arrastre.';
  end if;
  if (select count(*) from public.evolucion_caja)<>365 then raise exception 'Evolución fuera del ciclo.'; end if;
  if not exists (select 1 from public.auditoria_caja where saldo_nuevo=100) then
    raise exception 'El saldo inicial no generó auditoría.';
  end if;

  v_rechazado:=false;
  begin insert into public.membresias_grupo(integrante_id,grupo_id,rol,fecha_inicio)
    values(v_otro,'rojo','integrante',date '2026-11-02');
  exception when insufficient_privilege then v_rechazado:=true; end;
  if not v_rechazado then raise exception 'El cliente puede eludir la RPC de membresías.'; end if;
  raise notice 'PASS: ciclo, snapshots, correcciones, historial, líderes, desglose, saldo, auditoría y grants.';
end;
$$;


-- Acceso uniforme: una cuenta sin perfil puede operar en todos los módulos.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',true);
do $$
declare joven uuid; rechazado boolean:=false;
begin
  if (select count(*) from public.grupos)<>4 then raise exception 'La cuenta sin perfil no puede leer grupos.'; end if;
  joven := public.crear_integrante('Prueba sin perfil',date '2005-01-01','rojo');
  if not exists(select 1 from public.integrantes where id=joven) then raise exception 'No se guardó el joven.'; end if;
  insert into public.ofrendas(fecha,monto_bruto) values(date '2026-11-21',10.05);
  if (select aporte_distrito from public.ofrendas where fecha=date '2026-11-21')<>1.01 then raise exception 'Redondeo incorrecto.'; end if;
  insert into public.egresos(fecha,monto,concepto) values(date '2026-11-21',1,'Prueba transaccional');
  update public.configuracion_caja set saldo_inicial=110 where id=1;
  if not exists(select 1 from public.auditoria_caja where saldo_nuevo=110) then raise exception 'Auditoría inaccesible.'; end if;
  begin update public.perfiles set rol='admin' where user_id=auth.uid();
  exception when insufficient_privilege then rechazado:=true; end;
  if not rechazado then raise exception 'Los perfiles históricos siguen siendo editables.'; end if;
end;
$$;
-- Un antiguo perfil de consulta también tiene permisos uniformes.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
select public.crear_integrante('Prueba perfil antiguo',date '2005-01-01','rojo');

-- Las sesiones anónimas de Auth no obtienen acceso aunque tengan UID.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000003","is_anonymous":true}',true);
do $$ begin
  if (select count(*) from public.grupos)<>0 then raise exception 'Se admitió una sesión anónima.'; end if;
end; $$;
reset role;
set local role anon;
do $$
declare rechazado boolean:=false;
begin
  if (select count(*) from public.configuracion_app)<>1 then raise exception 'Versión APK inaccesible.'; end if;
  begin perform count(*) from public.integrantes;
  exception when insufficient_privilege then rechazado:=true; end;
  if not rechazado then raise exception 'Acceso público al directorio.'; end if;
end;
$$;
reset role;
rollback;
