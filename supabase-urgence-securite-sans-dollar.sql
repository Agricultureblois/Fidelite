-- URGENCE SECURITE - L'Agriculture Fidelite
-- A lancer dans Supabase > SQL Editor, en une seule fois.
-- Important : ne pas laisser le navigateur traduire la page Supabase.

alter table members add column if not exists last_name text;

create or replace function is_admin_pin(p_pin text)
returns boolean
language sql
security definer
set search_path = public
as E'\n  select exists (\n    select 1\n    from admin_users\n    where active = true\n      and pin = p_pin\n  );\n';

create or replace function admin_ok(p_pin text)
returns boolean
language sql
security definer
set search_path = public
as E'\n  select is_admin_pin(p_pin);\n';

create or replace function get_member_card(p_code text)
returns jsonb
language sql
security definer
set search_path = public
as E'\n  select case\n    when m.id is null then null\n    else to_jsonb(m) || jsonb_build_object(\n      ''visits'',\n      coalesce((\n        select jsonb_agg(to_jsonb(v) order by v.created_at)\n        from visits v\n        where v.member_id = m.id\n      ), ''[]''::jsonb)\n    )\n  end\n  from (\n    select *\n    from members\n    where code = upper(trim(p_code))\n    limit 1\n  ) m;\n';

create or replace function signup_member(p_first_name text, p_last_name text, p_phone text, p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as E'\ndeclare\n  clean_first text := nullif(trim(p_first_name), '''');\n  clean_last text := nullif(trim(p_last_name), '''');\n  clean_phone text := nullif(trim(p_phone), '''');\n  clean_code text := upper(trim(p_code));\nbegin\n  if clean_first is null or clean_phone is null or length(clean_phone) < 8 then\n    raise exception ''Prenom et telephone requis'';\n  end if;\n\n  insert into members (first_name, last_name, phone, code, updated_at)\n  values (clean_first, clean_last, clean_phone, clean_code, now())\n  on conflict (phone) do update set\n    first_name = excluded.first_name,\n    last_name = excluded.last_name,\n    code = excluded.code,\n    updated_at = now();\n\n  return get_member_card(clean_code);\nend;\n';

create or replace function admin_dashboard(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public
as E'\nbegin\n  if not is_admin_pin(p_pin) then\n    raise exception ''Code admin incorrect'';\n  end if;\n\n  return jsonb_build_object(\n    ''members'',\n    coalesce((\n      select jsonb_agg(to_jsonb(m) order by m.points desc, m.created_at desc)\n      from members m\n    ), ''[]''::jsonb),\n    ''visits_count'',\n    (select count(*) from visits),\n    ''admins'',\n    coalesce((\n      select jsonb_agg(jsonb_build_object(''name'', name) order by created_at)\n      from admin_users\n      where active = true\n    ), ''[]''::jsonb)\n  );\nend;\n';

create or replace function admin_add_points(p_pin text, p_code text, p_amount integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as E'\ndeclare\n  target_member members%rowtype;\n  clean_code text := upper(trim(p_code));\n  pts integer := greatest(0, p_amount);\nbegin\n  if not is_admin_pin(p_pin) then\n    raise exception ''Code admin incorrect'';\n  end if;\n  if pts < 1 or pts > 1000 then\n    raise exception ''Montant invalide : maximum 1000 points par ajout'';\n  end if;\n\n  select * into target_member\n  from members\n  where code = clean_code\n  for update;\n\n  if target_member.id is null then\n    raise exception ''Client introuvable'';\n  end if;\n\n  insert into visits (member_id, amount, points)\n  values (target_member.id, pts, pts);\n\n  update members\n  set points = points + pts,\n      updated_at = now()\n  where id = target_member.id;\n\n  return get_member_card(clean_code);\nend;\n';

create or replace function admin_set_points(p_pin text, p_code text, p_points integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as E'\ndeclare\n  clean_code text := upper(trim(p_code));\n  pts integer := greatest(0, p_points);\nbegin\n  if not is_admin_pin(p_pin) then\n    raise exception ''Code admin incorrect'';\n  end if;\n  if pts > 100000 then\n    raise exception ''Nombre de points trop eleve'';\n  end if;\n\n  update members\n  set points = pts,\n      updated_at = now()\n  where code = clean_code;\n\n  if not found then\n    raise exception ''Client introuvable'';\n  end if;\n\n  return get_member_card(clean_code);\nend;\n';

create or replace function admin_delete_member(p_pin text, p_member_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as E'\nbegin\n  if not is_admin_pin(p_pin) then\n    raise exception ''Code admin incorrect'';\n  end if;\n\n  delete from visits where member_id = p_member_id;\n  delete from members where id = p_member_id;\n  return true;\nend;\n';

create or replace function admin_update_menu(p_pin text, p_starter text, p_main text, p_dessert text, p_price text)
returns jsonb
language plpgsql
security definer
set search_path = public
as E'\ndeclare\n  updated_menu daily_menu%rowtype;\nbegin\n  if not is_admin_pin(p_pin) then\n    raise exception ''Code admin incorrect'';\n  end if;\n\n  update daily_menu\n  set starter = p_starter,\n      main = p_main,\n      dessert = p_dessert,\n      price = p_price,\n      updated_at = now()\n  where id = 1\n  returning * into updated_menu;\n\n  return to_jsonb(updated_menu);\nend;\n';

create or replace function admin_add_user(p_pin text, p_name text, p_new_pin text)
returns boolean
language plpgsql
security definer
set search_path = public
as E'\nbegin\n  if not is_admin_pin(p_pin) then\n    raise exception ''Code admin incorrect'';\n  end if;\n  if length(trim(p_new_pin)) < 4 then\n    raise exception ''PIN trop court'';\n  end if;\n\n  insert into admin_users (name, pin, active)\n  values (coalesce(nullif(trim(p_name), ''''), ''Admin''), trim(p_new_pin), true);\n\n  return true;\nend;\n';

create or replace function admin_save_ranks(p_pin text, p_ranks jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as E'\nbegin\n  if not is_admin_pin(p_pin) then\n    raise exception ''Code admin incorrect'';\n  end if;\n\n  delete from ranks;\n\n  insert into ranks (name, points_required, reward, sort_order)\n  select\n    name,\n    points_required,\n    reward,\n    sort_order\n  from jsonb_to_recordset(p_ranks) as x(\n    name text,\n    points_required integer,\n    reward text,\n    sort_order integer\n  );\n\n  return true;\nend;\n';

drop policy if exists "members_all" on members;
drop policy if exists "visits_all" on visits;
drop policy if exists "ranks_read" on ranks;
drop policy if exists "menu_read" on daily_menu;
drop policy if exists "admins_read" on admin_users;

drop policy if exists "ranks_public_select" on ranks;
drop policy if exists "menu_public_select" on daily_menu;

create policy "ranks_public_select" on ranks for select using (true);
create policy "menu_public_select" on daily_menu for select using (true);

grant execute on function is_admin_pin(text) to anon, authenticated;
grant execute on function admin_ok(text) to anon, authenticated;
grant execute on function get_member_card(text) to anon, authenticated;
grant execute on function signup_member(text, text, text, text) to anon, authenticated;
grant execute on function admin_dashboard(text) to anon, authenticated;
grant execute on function admin_add_points(text, text, integer) to anon, authenticated;
grant execute on function admin_set_points(text, text, integer) to anon, authenticated;
grant execute on function admin_delete_member(text, uuid) to anon, authenticated;
grant execute on function admin_update_menu(text, text, text, text, text) to anon, authenticated;
grant execute on function admin_add_user(text, text, text) to anon, authenticated;
grant execute on function admin_save_ranks(text, jsonb) to anon, authenticated;
