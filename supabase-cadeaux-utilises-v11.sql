-- CADEAUX UTILISES V11 - L'Agriculture Fidelite
-- A lancer dans Supabase > SQL Editor.
-- Ne supprime aucun client et ne touche pas aux points.

create table if not exists reward_redemptions (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references members(id) on delete cascade,
  rank_name text not null,
  points_required integer not null,
  reward text not null,
  redeemed_by text,
  created_at timestamptz not null default now(),
  unique (member_id, rank_name, points_required)
);

alter table reward_redemptions enable row level security;

drop policy if exists "reward_redemptions_no_public_access" on reward_redemptions;

create policy "reward_redemptions_no_public_access"
on reward_redemptions for all
using (false)
with check (false);

create or replace function get_member_card(p_code text)
returns jsonb
language sql
security definer
set search_path = public
as E'
  select case
    when m.id is null then null
    else to_jsonb(m) || jsonb_build_object(
      ''visits'',
      coalesce((
        select jsonb_agg(to_jsonb(v) order by v.created_at)
        from visits v
        where v.member_id = m.id
      ), ''[]''::jsonb),
      ''reward_redemptions'',
      coalesce((
        select jsonb_agg(to_jsonb(rr) order by rr.created_at)
        from reward_redemptions rr
        where rr.member_id = m.id
      ), ''[]''::jsonb)
    )
  end
  from (
    select *
    from members
    where code = upper(trim(p_code))
    limit 1
  ) m;
';

create or replace function admin_dashboard(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public
as E'
begin
  if not is_admin_pin(p_pin) then
    raise exception ''Code admin incorrect'';
  end if;

  return jsonb_build_object(
    ''members'',
    coalesce((
      select jsonb_agg(
        to_jsonb(m) || jsonb_build_object(
          ''reward_redemptions'',
          coalesce((
            select jsonb_agg(to_jsonb(rr) order by rr.created_at)
            from reward_redemptions rr
            where rr.member_id = m.id
          ), ''[]''::jsonb)
        )
        order by m.points desc, m.created_at desc
      )
      from members m
    ), ''[]''::jsonb),
    ''visits_count'',
    (select count(*) from visits),
    ''admins'',
    coalesce((
      select jsonb_agg(jsonb_build_object(''name'', name) order by created_at)
      from admin_users
      where active = true
    ), ''[]''::jsonb)
  );
end;
';

create or replace function admin_redeem_reward(
  p_pin text,
  p_member_id uuid,
  p_rank_name text,
  p_points_required integer,
  p_reward text
)
returns boolean
language plpgsql
security definer
set search_path = public
as E'
declare
  admin_name text;
  member_points integer;
begin
  select name into admin_name
  from admin_users
  where active = true
    and pin = regexp_replace(coalesce(p_pin, ''''), ''[^0-9]'', '''', ''g'')
  limit 1;

  if admin_name is null then
    raise exception ''Code admin incorrect'';
  end if;

  select points into member_points
  from members
  where id = p_member_id;

  if member_points is null then
    raise exception ''Client introuvable'';
  end if;

  if member_points < p_points_required then
    raise exception ''Palier pas encore atteint'';
  end if;

  insert into reward_redemptions (member_id, rank_name, points_required, reward, redeemed_by)
  values (p_member_id, p_rank_name, p_points_required, p_reward, admin_name)
  on conflict (member_id, rank_name, points_required) do nothing;

  return true;
end;
';

grant usage on schema public to anon, authenticated;
grant execute on function get_member_card(text) to anon, authenticated;
grant execute on function admin_dashboard(text) to anon, authenticated;
grant execute on function admin_redeem_reward(text, uuid, text, integer, text) to anon, authenticated;

notify pgrst, 'reload schema';

select 'OK cadeaux utilises actifs' as resultat;
