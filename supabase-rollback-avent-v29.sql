-- Retour arrière de la v29 (Avent). Les points déjà distribués restent acquis aux clients.
drop function if exists public.admin_use_advent_gift(text, uuid);
drop function if exists public.admin_advent_overview(text);
drop function if exists public.advent_spin(text);
drop function if exists public.advent_open_case(text);
drop function if exists public.advent_state(text);
drop function if exists public.advent_draw(text, date);
drop table if exists public.advent_plays;
drop table if exists public.advent_config;
-- Pour simplement désactiver sans rien supprimer :
--   update public.advent_config set enabled = false;
