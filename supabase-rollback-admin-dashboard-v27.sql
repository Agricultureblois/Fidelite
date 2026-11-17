-- Retour arrière de la v28 : remet admin_dashboard exactement comme en v27.
-- Les tables monthly_till_revenue / reward_values et les fonctions de saisie peuvent rester
-- (elles ne gênent pas). Pour tout retirer :
--   drop function if exists public.admin_kpi_stats();
--   drop function if exists public.admin_set_monthly_revenue(text, text, numeric);
--   drop function if exists public.admin_set_reward_values(text, jsonb);
--   drop table if exists public.monthly_till_revenue;
--   drop table if exists public.reward_values;

CREATE OR REPLACE FUNCTION public.admin_dashboard(p_pin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not is_admin_pin(p_pin) then
    raise exception 'Code admin incorrect';
  end if;

  return jsonb_build_object(
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
end;
$function$;
