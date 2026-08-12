-- Test rapide apres la mise a jour securite.
-- Remplace 4937 si tu as choisi un autre code admin.

select admin_ok('4937') as code_admin_ok;

select
  proname as fonction_presente
from pg_proc
where proname in (
  'admin_ok',
  'get_member_card',
  'signup_member',
  'admin_dashboard',
  'admin_add_points',
  'admin_set_points',
  'admin_delete_member',
  'admin_update_menu',
  'admin_add_user',
  'admin_save_ranks'
)
order by proname;

select admin_dashboard('4937') as tableau_admin_ok;
