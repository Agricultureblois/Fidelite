-- v31 (23/11/2026) : correctif enregistrement des grades.
-- Supabase (extension safeupdate, active pour les appels de l'appli) refuse
-- "delete from ranks;" sans WHERE -> erreur 400 "DELETE requires a WHERE clause"
-- à chaque clic sur « Enregistrer les grades ».
-- Seul changement : "delete from ranks where true;" (même effet).
-- Retour arrière : remettre "delete from ranks;" (inutile, ça ne marchait pas).

create or replace function public.admin_save_ranks(p_pin text, p_ranks jsonb)
 returns boolean
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if not is_admin_pin(p_pin) then
    raise exception 'Code admin incorrect';
  end if;

  delete from ranks where true;

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
$function$;
