-- REPARATION DROITS APPLICATION PUBLIQUE
-- A lancer dans Supabase > SQL Editor.
-- Si admin_ok('4937') marche dans Supabase mais pas dans l'application,
-- ce fichier redonne les droits d'appel aux fonctions depuis le site public.

grant usage on schema public to anon, authenticated;

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

notify pgrst, 'reload schema';

select admin_ok('4937') as code_admin_ok;
