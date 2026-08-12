-- URGENCE SECURITE - L'Agriculture Fidelite
-- A lancer dans Supabase > SQL Editor, en une seule fois.
-- Important : ne pas laisser le navigateur traduire la page Supabase.

alter table members add column if not exists last_name text;

create or replace function is_admin_pin(p_pin text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from admin_users
    where active = true
      and pin = p_pin
  );
$$;

create or replace function admin_ok(p_pin text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select is_admin_pin(p_pin);
$$;

create or replace function get_member_card(p_code text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select case
    when m.id is null then null
    else to_jsonb(m) || jsonb_build_object(
      'visits',
      coalesce((
        select jsonb_agg(to_jsonb(v) order by v.created_at)
        from visits v
        where v.member_id = m.id
      ), '[]'::jsonb)
    )
  end
  from (
    select *
    from members
    where code = upper(trim(p_code))
    limit 1
  ) m;
$$;

create or replace function signup_member(p_first_name text, p_last_name text, p_phone text, p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_first text := nullif(trim(p_first_name), '');
  clean_last text := nullif(trim(p_last_name), '');
  clean_phone text := nullif(trim(p_phone), '');
  clean_code text := upper(trim(p_code));
begin
  if clean_first is null or clean_phone is null or length(clean_phone) < 8 then
    raise exception 'Prenom et telephone requis';
  end if;

  insert into members (first_name, last_name, phone, code, updated_at)
  values (clean_first, clean_last, clean_phone, clean_code, now())
  on conflict (phone) do update set
    first_name = excluded.first_name,
    last_name = excluded.last_name,
    code = excluded.code,
    updated_at = now();

  return get_member_card(clean_code);
end;
$$;

create or replace function admin_dashboard(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_admin_pin(p_pin) then
    raise exception 'Code admin incorrect';
  end if;

  return jsonb_build_object(
    'members',
    coalesce((
      select jsonb_agg(to_jsonb(m) order by m.points desc, m.created_at desc)
      from members m
    ), '[]'::jsonb),
    'visits_count',
    (select count(*) from visits),
    'admins',
    coalesce((
      select jsonb_agg(jsonb_build_object('name', name) order by created_at)
      from admin_users
      where active = true
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function admin_add_points(p_pin text, p_code text, p_amount integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_member members%rowtype;
  clean_code text := upper(trim(p_code));
  pts integer := greatest(0, p_amount);
begin
  if not is_admin_pin(p_pin) then
    raise exception 'Code admin incorrect';
  end if;
  if pts < 1 or pts > 1000 then
    raise exception 'Montant invalide : maximum 1000 points par ajout';
  end if;

  select * into target_member
  from members
  where code = clean_code
  for update;

  if target_member.id is null then
    raise exception 'Client introuvable';
  end if;

  insert into visits (member_id, amount, points)
  values (target_member.id, pts, pts);

  update members
  set points = points + pts,
      updated_at = now()
  where id = target_member.id;

  return get_member_card(clean_code);
end;
$$;

create or replace function admin_set_points(p_pin text, p_code text, p_points integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_code text := upper(trim(p_code));
  pts integer := greatest(0, p_points);
begin
  if not is_admin_pin(p_pin) then
    raise exception 'Code admin incorrect';
  end if;
  if pts > 100000 then
    raise exception 'Nombre de points trop eleve';
  end if;

  update members
  set points = pts,
      updated_at = now()
  where code = clean_code;

  if not found then
    raise exception 'Client introuvable';
  end if;

  return get_member_card(clean_code);
end;
$$;

create or replace function admin_delete_member(p_pin text, p_member_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_admin_pin(p_pin) then
    raise exception 'Code admin incorrect';
  end if;

  delete from visits where member_id = p_member_id;
  delete from members where id = p_member_id;
  return true;
end;
$$;

create or replace function admin_update_menu(p_pin text, p_starter text, p_main text, p_dessert text, p_price text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_menu daily_menu%rowtype;
begin
  if not is_admin_pin(p_pin) then
    raise exception 'Code admin incorrect';
  end if;

  update daily_menu
  set starter = p_starter,
      main = p_main,
      dessert = p_dessert,
      price = p_price,
      updated_at = now()
  where id = 1
  returning * into updated_menu;

  return to_jsonb(updated_menu);
end;
$$;

create or replace function admin_add_user(p_pin text, p_name text, p_new_pin text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_admin_pin(p_pin) then
    raise exception 'Code admin incorrect';
  end if;
  if length(trim(p_new_pin)) < 4 then
    raise exception 'PIN trop court';
  end if;

  insert into admin_users (name, pin, active)
  values (coalesce(nullif(trim(p_name), ''), 'Admin'), trim(p_new_pin), true);

  return true;
end;
$$;

create or replace function admin_save_ranks(p_pin text, p_ranks jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_admin_pin(p_pin) then
    raise exception 'Code admin incorrect';
  end if;

  delete from ranks;

  insert into ranks (name, points_required, reward, sort_order)
  select
    name,
    points_required,
    reward,
    sort_order
  from jsonb_to_recordset(p_ranks) as x(
    name text,
    points_required integer,
    reward text,
    sort_order integer
  );

  return true;
end;
$$;

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
