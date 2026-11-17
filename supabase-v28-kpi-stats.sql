-- v28 : stats de pilotage (CA caisse / taux de capture, rétention, panier médian,
-- passages en jours distincts) + valeur estimée des cadeaux.
--
-- Migration Supabase "add_kpi_stats_and_reward_values", appliquée le 17/11/2026.
-- 100 % additive : aucune table existante n'est modifiée, admin_dashboard renvoie
-- exactement les mêmes clés qu'avant, plus de nouvelles. Si le calcul des nouvelles
-- stats échouait, les anciennes continuent de s'afficher (bloc exception).
-- Retour arrière : supabase-rollback-admin-dashboard-v27.sql
--
-- Si vous collez ce fichier dans l'éditeur SQL de Supabase : ne sélectionnez aucun
-- morceau du texte avant de cliquer Run (voir A-LIRE-ERREUR-SQL.md).

-- 1) CA caisse mensuel saisi par l'équipe (sert au taux de capture)
create table if not exists public.monthly_till_revenue (
  period text primary key check (period ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  amount numeric(12,2) not null check (amount >= 0),
  updated_at timestamptz not null default now()
);
alter table public.monthly_till_revenue enable row level security;

-- 2) Valeur estimée (au prix de vente) de chaque cadeau, par grade
create table if not exists public.reward_values (
  rank_name text primary key,
  value numeric(8,2) check (value is null or value >= 0),
  updated_at timestamptz not null default now()
);
alter table public.reward_values enable row level security;

-- Valeurs de départ tirées de la carte (modifiables dans Réglages > Grades et cadeaux).
-- Apprenti (boisson chaude), Plongeur (apéro) et Directeur : volontairement non renseignés.
insert into public.reward_values (rank_name, value) values
  ('Commis de cuisine', 6.50),
  ('Serveur', 15.00),
  ('Chef de rang', 15.00),
  ('Sous-chef', 19.00),
  ('Chef de cuisine', 19.00)
on conflict (rank_name) do nothing;

-- 3) Saisie du CA caisse d'un mois (valeur vide = effacer)
create or replace function public.admin_set_monthly_revenue(p_pin text, p_period text, p_amount numeric)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  saved monthly_till_revenue%rowtype;
begin
  if not is_admin_pin(p_pin) then
    raise exception 'Code admin incorrect';
  end if;
  if p_period is null or p_period !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
    raise exception 'Mois invalide';
  end if;
  if p_amount is null then
    delete from monthly_till_revenue where period = p_period;
    return jsonb_build_object('period', p_period, 'amount', null);
  end if;
  if p_amount < 0 then
    raise exception 'Montant invalide';
  end if;
  insert into monthly_till_revenue (period, amount)
  values (p_period, p_amount)
  on conflict (period) do update set amount = excluded.amount, updated_at = now()
  returning * into saved;
  return to_jsonb(saved);
end;
$function$;

-- 4) Saisie des valeurs de cadeaux : p_values = [{"rank_name": "...", "value": 6.5}, ...]
create or replace function public.admin_set_reward_values(p_pin text, p_values jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  item jsonb;
  v numeric;
begin
  if not is_admin_pin(p_pin) then
    raise exception 'Code admin incorrect';
  end if;
  if p_values is null or jsonb_typeof(p_values) <> 'array' then
    raise exception 'Format invalide';
  end if;
  for item in select * from jsonb_array_elements(p_values) loop
    if coalesce(btrim(item->>'rank_name'), '') = '' then
      continue;
    end if;
    v := nullif(btrim(item->>'value'), '')::numeric;
    if v is not null and v < 0 then
      raise exception 'Valeur invalide';
    end if;
    insert into reward_values (rank_name, value)
    values (item->>'rank_name', v)
    on conflict (rank_name) do update set value = excluded.value, updated_at = now();
  end loop;
  return coalesce((
    select jsonb_agg(jsonb_build_object('rank_name', rank_name, 'value', value) order by rank_name)
    from reward_values
  ), '[]'::jsonb);
end;
$function$;

-- 5) Calcul des nouvelles stats (agrégats uniquement, aucune donnée personnelle).
--    Interne : appelée seulement par admin_dashboard, jamais exposée à l'API publique.
create or replace function public.admin_kpi_stats()
 returns jsonb
 language sql
 stable
 security definer
 set search_path to 'public'
as $function$
  with v as (
    select member_id, amount,
           to_char(created_at at time zone 'Europe/Paris', 'YYYY-MM') as period,
           (created_at at time zone 'Europe/Paris')::date as d
    from visits
  ),
  months as (
    select to_char(g, 'YYYY-MM') as period
    from generate_series(
      date_trunc('month', now() at time zone 'Europe/Paris') - interval '5 months',
      date_trunc('month', now() at time zone 'Europe/Paris'),
      interval '1 month'
    ) g
  ),
  act as (
    select distinct period, member_id from v
  ),
  agg as (
    select period,
           sum(amount) as revenue,
           count(*) as credits,
           count(distinct (member_id, d)) as visit_days,
           count(distinct member_id) as active_members,
           percentile_cont(0.5) within group (order by amount) as median_basket
    from v
    group by period
  ),
  monthly as (
    select jsonb_agg(jsonb_build_object(
      'period', m.period,
      'revenue', coalesce(a.revenue, 0),
      'credits', coalesce(a.credits, 0),
      'visit_days', coalesce(a.visit_days, 0),
      'active_members', coalesce(a.active_members, 0),
      'median_basket', coalesce(round(a.median_basket::numeric, 1), 0),
      'prev_active', (
        select count(*) from act p
        where p.period = to_char(to_date(m.period || '-01', 'YYYY-MM-DD') - interval '1 month', 'YYYY-MM')
      ),
      'returning', (
        select count(*) from act c
        join act p on p.member_id = c.member_id
          and p.period = to_char(to_date(m.period || '-01', 'YYYY-MM-DD') - interval '1 month', 'YYYY-MM')
        where c.period = m.period
      ),
      'till_revenue', (select t.amount from monthly_till_revenue t where t.period = m.period)
    ) order by m.period) as j
    from months m
    left join agg a on a.period = m.period
  )
  select jsonb_build_object(
    'monthly', coalesce((select j from monthly), '[]'::jsonb),
    'visit_days_total', (select count(distinct (member_id, d)) from v),
    'median_basket', (select coalesce(round((percentile_cont(0.5) within group (order by amount))::numeric, 1), 0) from visits),
    'reward_values', coalesce((
      select jsonb_agg(jsonb_build_object('rank_name', rank_name, 'value', value) order by rank_name)
      from reward_values
    ), '[]'::jsonb),
    'rewards_value_total', (
      select coalesce(sum(rv.value), 0)
      from reward_redemptions rr
      join reward_values rv on rv.rank_name = rr.rank_name
    ),
    'rewards_value_month', (
      select coalesce(sum(rv.value), 0)
      from reward_redemptions rr
      join reward_values rv on rv.rank_name = rr.rank_name
      where to_char(rr.created_at at time zone 'Europe/Paris', 'YYYY-MM') = to_char(now() at time zone 'Europe/Paris', 'YYYY-MM')
    ),
    'rewards_without_value', (
      select count(*)
      from reward_redemptions rr
      left join reward_values rv on rv.rank_name = rr.rank_name
      where rv.value is null
    ),
    'rewards_missing_ranks', coalesce((
      select jsonb_agg(q.rank_name order by q.rank_name)
      from (
        select distinct rr.rank_name
        from reward_redemptions rr
        left join reward_values rv on rv.rank_name = rr.rank_name
        where rv.value is null
      ) q
    ), '[]'::jsonb),
    'challenge_points_total', (select coalesce(sum(points), 0) from challenge_claims)
  );
$function$;

revoke all on function public.admin_kpi_stats() from public, anon, authenticated;

-- 6) admin_dashboard : même contenu qu'en v27 + les nouvelles clés.
create or replace function public.admin_dashboard(p_pin text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  base jsonb;
  kpi jsonb;
begin
  if not is_admin_pin(p_pin) then
    raise exception 'Code admin incorrect';
  end if;

  base := jsonb_build_object(
    'members',
    coalesce((
      select jsonb_agg(
        to_jsonb(m) || jsonb_build_object(
          'reward_redemptions',
          coalesce((
            select jsonb_agg(to_jsonb(rr) order by rr.created_at)
            from reward_redemptions rr
            where rr.member_id = m.id
          ), '[]'::jsonb)
        )
        order by m.points desc, m.created_at desc
      )
      from members m
    ), '[]'::jsonb),
    'visits_count',
    (select count(*) from visits),
    'admins',
    coalesce((
      select jsonb_agg(jsonb_build_object('name', name) order by created_at)
      from admin_users
      where active = true
    ), '[]'::jsonb),
    'revenue_total',
    (select coalesce(sum(amount), 0) from visits),
    'revenue_month',
    (select coalesce(sum(amount), 0) from visits where to_char(created_at, 'YYYY-MM') = to_char(now(), 'YYYY-MM')),
    'avg_basket',
    (select coalesce(round(avg(amount)), 0) from visits),
    'visits_by_weekday',
    (
      select jsonb_agg(jsonb_build_object('label', d.label, 'count', coalesce(c.cnt, 0)) order by d.sort_idx)
      from (values (1,1,'Lun'),(2,2,'Mar'),(3,3,'Mer'),(4,4,'Jeu'),(5,5,'Ven'),(6,6,'Sam'),(7,0,'Dim')) as d(sort_idx, dow, label)
      left join (
        select extract(dow from created_at at time zone 'Europe/Paris')::int as dow, count(*) as cnt
        from visits
        group by 1
      ) c on c.dow = d.dow
    ),
    'visits_by_hour',
    (
      select jsonb_agg(jsonb_build_object('label', lpad(h::text, 2, '0') || 'h', 'count', coalesce(c.cnt, 0)) order by h)
      from generate_series(0, 23) as h
      left join (
        select extract(hour from created_at at time zone 'Europe/Paris')::int as hr, count(*) as cnt
        from visits
        group by 1
      ) c on c.hr = h
    ),
    'rewards_redeemed_total',
    (select count(*) from reward_redemptions),
    'rewards_redeemed_month',
    (select count(*) from reward_redemptions where to_char(created_at, 'YYYY-MM') = to_char(now(), 'YYYY-MM')),
    'rewards_by_rank',
    coalesce((
      select jsonb_agg(jsonb_build_object('label', rank_name, 'count', cnt) order by cnt desc)
      from (
        select rank_name, count(*) as cnt
        from reward_redemptions
        group by rank_name
      ) g
    ), '[]'::jsonb)
  );

  -- Les nouvelles stats ne doivent jamais empêcher l'affichage des anciennes.
  begin
    kpi := public.admin_kpi_stats();
  exception when others then
    kpi := '{}'::jsonb;
  end;

  return base || kpi;
end;
$function$;

grant execute on function public.admin_set_monthly_revenue(text, text, numeric) to anon, authenticated;
grant execute on function public.admin_set_reward_values(text, jsonb) to anon, authenticated;
