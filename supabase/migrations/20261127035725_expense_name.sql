alter table public.egresos add column nombre text not null default 'Gasto'
  check (length(btrim(nombre)) between 2 and 160);
grant insert(nombre), update(nombre) on public.egresos to authenticated;
