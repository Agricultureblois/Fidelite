-- =====================================================================
-- v30 — Correctif : message d'attente du calendrier de l'Avent
-- Appliqué en base le 17/11/2026
-- =====================================================================
--
-- PROBLÈME
-- Le frontend (app.js, fonction renderAdvent) prévoit un message
-- d'attente avant l'ouverture du calendrier :
--   "Bientôt : le calendrier de l'Avent et sa roue de Noël arrivent
--    le <date> !"
-- Il s'affiche quand advent_state renvoie soon = true, et lit la date
-- dans le champ start_date.
--
-- Or la version v29 de advent_state codait 'soon' à false dans ses
-- TROIS sorties, et ne renvoyait pas start_date hors période active.
-- Ce message était donc du code mort : avant l'ouverture, la carte
-- restait simplement masquée, sans effet d'annonce.
--
-- CORRECTIF
-- Ajout d'une branche "avant l'ouverture" qui renvoie soon = true
-- accompagné de start_date. Comportements volontairement inchangés :
--   - client non éligible (only_codes) ou calendrier désactivé
--     -> soon = false : on n'annonce rien à quelqu'un qui n'y aura
--        pas droit ;
--   - après end_date -> soon = false : rien à annoncer.
--
-- 100 % additive : aucune table modifiée, aucune autre fonction touchée.
-- Le message ne devient visible que si start_date est dans le futur.
-- =====================================================================

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
  -- Calendrier absent, désactivé, ou client non éligible : rien à afficher (pas même l'annonce).
  if c.id is null or not c.enabled or (c.only_codes is not null and not (m.code = any(c.only_codes))) then
    return jsonb_build_object('active', false, 'soon', false);
  end if;
  -- Avant l'ouverture : on annonce la date pour faire monter l'attente côté client.
  if today < c.start_date then
    return jsonb_build_object('active', false, 'soon', true, 'start_date', c.start_date);
  end if;
  active := today between c.start_date and c.end_date;
  -- Après la fin du calendrier : rien à afficher.
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
