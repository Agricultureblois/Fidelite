-- v29 : Calendrier de l'Avent + roue de Noël (décembre 2026)
-- Migration Supabase "add_advent_calendar_and_wheel".
-- 100 % additive : nouvelles tables et fonctions uniquement, rien d'existant n'est modifié.
--
-- Règles :
--  * Case du jour (1er au 24 décembre) : ne s'ouvre que si un crédit a été fait au client CE jour-là
--    (heure de Paris). Une case par client et par jour, pas de rattrapage.
--  * Roue : 1 tour gagné tous les 3 jours de présence distincts en décembre (3, 6, 9...).
--  * Cadeaux réels (boisson chaude / apéro) : budget plafonné (advent_config.budget, 20 € par défaut),
--    réparti sur la période (pas tout le premier jour) et tiré côté serveur.
--  * Le reste des gains = points bonus.
-- Retour arrière : supabase-rollback-avent-v29.sql

create table if not exists public.advent_config (
  id int primary key default 1 check (id = 1),
  enabled boolean not null default true,
  start_date date not null,
  cases_until date not null,
  end_date date not null,
  budget numeric(8,2) not null check (budget >= 0)
);
alter table public.advent_config enable row level security;
insert into public.advent_config (id, enabled, start_date, cases_until, end_date, budget)
values (1, true, date '2026-12-01', date '2026-12-24', date '2026-12-31', 20)
on conflict (id) do nothing;

create table if not exists public.advent_plays (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete cascade,
  kind text not null check (kind in ('case', 'wheel')),
  case_day int,
  play_date date not null,
  prize_key text not null,
  prize_type text not null check (prize_type in ('points', 'gift')),
  label text not null,
  points int not null default 0,
  value numeric(8,2) not null default 0,
  used_at timestamptz,
  used_by text,
  created_at timestamptz not null default now()
);
alter table public.advent_plays enable row level security;
create unique index if not exists advent_one_case_per_day on public.advent_plays (member_id, case_day) where kind = 'case';
create index if not exists advent_plays_member on public.advent_plays (member_id);

-- Tirage (interne). L'appelant doit déjà tenir le verrou advisory.
create or replace function public.advent_draw(p_kind text, p_today date)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  c advent_config%rowtype;
  v_coffee numeric;
  v_apero numeric;
  spent numeric;
  elapsed int;
  total int;
  can_coffee boolean;
  can_apero boolean;
  r numeric := random();
  r2 numeric := random();
  pts int;
begin
  select * into c from advent_config where id = 1;
  v_coffee := coalesce((select value from reward_values where rank_name = 'Apprenti'), 3.5);
  v_apero := coalesce((select value from reward_values where rank_name = 'Plongeur'), 5);
  select coalesce(sum(value), 0) into spent from advent_plays where prize_type = 'gift';
  elapsed := greatest(1, (p_today - c.start_date) + 1);
  total := greatest(1, (c.end_date - c.start_date) + 1);
  can_coffee := spent + v_coffee <= c.budget and spent + v_coffee <= c.budget * elapsed / total + 5;
  can_apero := spent + v_apero <= c.budget and spent + v_apero <= c.budget * elapsed / total + 5;

  if p_kind = 'case' then
    if can_coffee and r < 0.10 then
      return jsonb_build_object('key', 'coffee', 'type', 'gift', 'label', 'Une boisson chaude offerte', 'points', 0, 'value', v_coffee);
    end if;
    pts := case when r2 < 0.50 then 5 when r2 < 0.80 then 10 when r2 < 0.95 then 15 else 25 end;
  else
    if (can_coffee or can_apero) and r < 0.15 then
      if can_coffee and can_apero then
        if r2 < 0.5 then
          return jsonb_build_object('key', 'coffee', 'type', 'gift', 'label', 'Une boisson chaude offerte', 'points', 0, 'value', v_coffee);
        else
          return jsonb_build_object('key', 'apero', 'type', 'gift', 'label', 'Un apéro offert', 'points', 0, 'value', v_apero);
        end if;
      elsif can_coffee then
        return jsonb_build_object('key', 'coffee', 'type', 'gift', 'label', 'Une boisson chaude offerte', 'points', 0, 'value', v_coffee);
      else
        return jsonb_build_object('key', 'apero', 'type', 'gift', 'label', 'Un apéro offert', 'points', 0, 'value', v_apero);
      end if;
    end if;
    pts := case when r2 < 0.30 then 10 when r2 < 0.55 then 20 when r2 < 0.70 then 15 when r2 < 0.80 then 25
                when r2 < 0.95 then 30 else 50 end;
  end if;
  return jsonb_build_object('key', 'p' || pts, 'type', 'points', 'label', '+' || pts || ' points', 'points', pts, 'value', 0);
end;
$function$;
revoke all on function public.advent_draw(text, date) from public, anon, authenticated;

-- État du calendrier et de la roue pour un client
create or replace function public.advent_state(p_code text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  m members%rowtype;
  c advent_config%rowtype;
  today date := (now() at time zone 'Europe/Paris')::date;
  active boolean;
  v_days int;
  visited_today boolean;
  v_case_day int;
  opened_today boolean;
  spins_used int;
begin
  select * into m from members where code = upper(trim(p_code));
  if m.id is null then raise exception 'Client introuvable'; end if;
  select * into c from advent_config where id = 1;
  if c.id is null or not c.enabled or (c.only_codes is not null and not (m.code = any(c.only_codes))) then
    return jsonb_build_object('active', false, 'soon', false);
  end if;
  active := today between c.start_date and c.end_date;
  if not active then
    return jsonb_build_object('active', false, 'soon', false);
  end if;

  select count(distinct (created_at at time zone 'Europe/Paris')::date) into v_days
  from visits
  where member_id = m.id
    and (created_at at time zone 'Europe/Paris')::date between c.start_date and c.end_date;
  select exists (
    select 1 from visits where member_id = m.id and (created_at at time zone 'Europe/Paris')::date = today
  ) into visited_today;
  v_case_day := (today - c.start_date) + 1;
  select exists (select 1 from advent_plays p where p.member_id = m.id and p.kind = 'case' and p.case_day = v_case_day) into opened_today;
  select count(*) into spins_used from advent_plays where member_id = m.id and kind = 'wheel';

  return jsonb_build_object(
    'active', true,
    'soon', false,
    'today', today,
    'start_date', c.start_date,
    'cases_until', c.cases_until,
    'end_date', c.end_date,
    'case_day', case when today <= c.cases_until then v_case_day else null end,
    'visited_today', visited_today,
    'closed_dow', to_jsonb(c.closed_dow),
    'closed_today', (extract(dow from today)::int = any(c.closed_dow)),
    'can_open', (today <= c.cases_until and visited_today and not opened_today and not (extract(dow from today)::int = any(c.closed_dow))),
    'visit_days', v_days,
    'spins_used', spins_used,
    'spins_available', greatest(0, (v_days / 3) - spins_used),
    'next_spin_in', 3 - (v_days % 3),
    'plays', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'kind', p.kind, 'case_day', p.case_day, 'key', p.prize_key, 'type', p.prize_type,
        'label', p.label, 'points', p.points, 'used', p.used_at is not null, 'created_at', p.created_at
      ) order by p.created_at)
      from advent_plays p where p.member_id = m.id
    ), '[]'::jsonb)
  );
end;
$function$;

-- Ouvrir la case du jour
create or replace function public.advent_open_case(p_code text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  m members%rowtype;
  c advent_config%rowtype;
  today date := (now() at time zone 'Europe/Paris')::date;
  cd int;
  prize jsonb;
begin
  perform pg_advisory_xact_lock(290001);
  select * into m from members where code = upper(trim(p_code)) for update;
  if m.id is null then raise exception 'Client introuvable'; end if;
  select * into c from advent_config where id = 1;
  if c.id is null or not c.enabled or today not between c.start_date and c.cases_until
     or (c.only_codes is not null and not (m.code = any(c.only_codes))) then
    raise exception 'Le calendrier n''est pas ouvert aujourd''hui';
  end if;
  if extract(dow from today)::int = any(c.closed_dow) then
    raise exception 'Le restaurant est fermé aujourd''hui : pas de case le week-end';
  end if;
  cd := (today - c.start_date) + 1;
  if not exists (
    select 1 from visits where member_id = m.id and (created_at at time zone 'Europe/Paris')::date = today
  ) then
    raise exception 'Passe nous voir aujourd''hui pour ouvrir la case !';
  end if;
  if exists (select 1 from advent_plays p where p.member_id = m.id and p.kind = 'case' and p.case_day = cd) then
    raise exception 'Case du jour déjà ouverte';
  end if;

  prize := advent_draw('case', today);
  insert into advent_plays (member_id, kind, case_day, play_date, prize_key, prize_type, label, points, value)
  values (m.id, 'case', cd, today, prize->>'key', prize->>'type', prize->>'label', (prize->>'points')::int, (prize->>'value')::numeric);
  if (prize->>'points')::int > 0 then
    update members set points = points + (prize->>'points')::int, updated_at = now() where id = m.id;
  end if;
  return jsonb_build_object('prize', prize, 'case_day', cd, 'state', advent_state(m.code), 'member', get_member_card(m.code));
end;
$function$;

-- Tourner la roue
create or replace function public.advent_spin(p_code text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  m members%rowtype;
  c advent_config%rowtype;
  today date := (now() at time zone 'Europe/Paris')::date;
  v_days int;
  used int;
  prize jsonb;
begin
  perform pg_advisory_xact_lock(290001);
  select * into m from members where code = upper(trim(p_code)) for update;
  if m.id is null then raise exception 'Client introuvable'; end if;
  select * into c from advent_config where id = 1;
  if c.id is null or not c.enabled or today not between c.start_date and c.end_date
     or (c.only_codes is not null and not (m.code = any(c.only_codes))) then
    raise exception 'La roue n''est pas ouverte aujourd''hui';
  end if;
  select count(distinct (created_at at time zone 'Europe/Paris')::date) into v_days
  from visits
  where member_id = m.id
    and (created_at at time zone 'Europe/Paris')::date between c.start_date and c.end_date;
  select count(*) into used from advent_plays where member_id = m.id and kind = 'wheel';
  if (v_days / 3) - used <= 0 then
    raise exception 'Pas de tour disponible : un tour tous les 3 jours de présence';
  end if;

  prize := advent_draw('wheel', today);
  insert into advent_plays (member_id, kind, play_date, prize_key, prize_type, label, points, value)
  values (m.id, 'wheel', today, prize->>'key', prize->>'type', prize->>'label', (prize->>'points')::int, (prize->>'value')::numeric);
  if (prize->>'points')::int > 0 then
    update members set points = points + (prize->>'points')::int, updated_at = now() where id = m.id;
  end if;
  return jsonb_build_object('prize', prize, 'state', advent_state(m.code), 'member', get_member_card(m.code));
end;
$function$;

-- Vue équipe : budget et cadeaux à remettre
create or replace function public.admin_advent_overview(p_pin text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  c advent_config%rowtype;
  spent numeric;
begin
  if not is_admin_pin(p_pin) then
    raise exception 'Code admin incorrect';
  end if;
  select * into c from advent_config where id = 1;
  select coalesce(sum(value), 0) into spent from advent_plays where prize_type = 'gift';
  return jsonb_build_object(
    'enabled', c.enabled,
    'start_date', c.start_date,
    'end_date', c.end_date,
    'budget', c.budget,
    'spent', spent,
    'plays', (select count(*) from advent_plays),
    'points_given', (select coalesce(sum(points), 0) from advent_plays),
    'gifts_pending', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'label', p.label, 'value', p.value, 'created_at', p.created_at,
        'member_name', trim(coalesce(m.first_name, '') || ' ' || coalesce(m.last_name, '')), 'member_code', m.code
      ) order by p.created_at)
      from advent_plays p join members m on m.id = p.member_id
      where p.prize_type = 'gift' and p.used_at is null
    ), '[]'::jsonb),
    'gifts_used', (select count(*) from advent_plays where prize_type = 'gift' and used_at is not null)
  );
end;
$function$;

create or replace function public.admin_use_advent_gift(p_pin text, p_play_id uuid)
 returns boolean
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  admin_name text;
begin
  select name into admin_name
  from admin_users
  where active = true
    and pin = regexp_replace(coalesce(p_pin, ''), '[^0-9]', '', 'g')
  limit 1;
  if admin_name is null then
    raise exception 'Code admin incorrect';
  end if;
  update advent_plays set used_at = now(), used_by = admin_name
  where id = p_play_id and prize_type = 'gift' and used_at is null;
  return found;
end;
$function$;

grant execute on function public.advent_state(text) to anon, authenticated;
grant execute on function public.advent_open_case(text) to anon, authenticated;
grant execute on function public.advent_spin(text) to anon, authenticated;
grant execute on function public.admin_advent_overview(text) to anon, authenticated;
grant execute on function public.admin_use_advent_gift(text, uuid) to anon, authenticated;

-- v30 (appliquée ensuite) : colonnes de configuration ajoutées et fonctions ci-dessus mises à jour
-- (les définitions ci-dessus sont déjà la version finale) :
--   only_codes : si renseigné, seuls ces codes clients voient l'Avent (mode test). null = tout le monde.
--   closed_dow : jours de fermeture (0 = dimanche, 6 = samedi) : pas de case ces jours-là.
alter table public.advent_config add column if not exists only_codes text[];
alter table public.advent_config add column if not exists closed_dow int[] not null default '{0,6}';
