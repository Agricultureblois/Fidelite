insert into admin_users (name, pin, active)
select 'Admin principal', '4937', true
where not exists (select 1 from admin_users);

update admin_users
set pin = '4937',
    active = true;

create or replace function admin_ok(p_pin text)
returns boolean
language sql
security definer
set search_path = public
as E'
  select exists (
    select 1
    from admin_users
    where active = true
      and pin = regexp_replace(coalesce(p_pin, ''''), ''[^0-9]'', '''', ''g'')
  );
';

grant usage on schema public to anon, authenticated;
grant execute on function admin_ok(text) to anon, authenticated;
grant execute on function admin_dashboard(text) to anon, authenticated;
grant execute on function admin_add_points(text, text, integer) to anon, authenticated;
grant execute on function admin_set_points(text, text, integer) to anon, authenticated;
grant execute on function admin_delete_member(text, uuid) to anon, authenticated;
grant execute on function admin_update_menu(text, text, text, text, text) to anon, authenticated;
grant execute on function admin_add_user(text, text, text) to anon, authenticated;
grant execute on function admin_save_ranks(text, jsonb) to anon, authenticated;

notify pgrst, 'reload schema';

select admin_ok('4937') as code_admin_ok;
