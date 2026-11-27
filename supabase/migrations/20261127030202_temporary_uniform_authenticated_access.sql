-- Acceso temporal uniforme para cuentas autenticadas, sin perfil obligatorio.
create or replace function private.tiene_rol(p_roles text[]) returns boolean
language sql stable security invoker set search_path = '' as $$
  select auth.uid() is not null and not coalesce((auth.jwt()->>'is_anonymous')::boolean,false);
$$;
create or replace function private.es_miembro() returns boolean
language sql stable security invoker set search_path = '' as $$
  select auth.uid() is not null and not coalesce((auth.jwt()->>'is_anonymous')::boolean,false);
$$;
-- Los nombres se conservan por compatibilidad con las políticas y RPC existentes.
-- No se consulta ni exige perfiles.rol. Se conserva el historial para revertir este modo.
revoke insert,update,delete on public.perfiles from authenticated;
drop policy perfiles_admin on public.perfiles;
alter policy perfiles_lectura on public.perfiles
using (user_id = (select auth.uid()));
