-- Update personal details and effective assignment in one transaction.
-- Invoker preserves the existing SELECT/UPDATE policies; membership changes
-- use the existing guarded RPC and its historical interval checks.
create function public.editar_integrante(
  p_integrante_id uuid, p_nombre_completo text, p_fecha_nacimiento date,
  p_grupo_id text, p_rol text, p_fecha date
) returns void language plpgsql security invoker set search_path = '' as $$
begin
  -- Keep lock order consistent with cambiar_grupo.
  perform public.cambiar_grupo(p_integrante_id,p_grupo_id,p_rol,p_fecha);
  update public.integrantes
    set nombre_completo=btrim(p_nombre_completo), fecha_nacimiento=p_fecha_nacimiento
    where id=p_integrante_id and activo;
  if not found then raise exception 'Integrante activo no encontrado.'; end if;
end;
$$;
revoke all on function public.editar_integrante(uuid,text,date,text,text,date) from public,anon;
grant execute on function public.editar_integrante(uuid,text,date,text,text,date) to authenticated;
