-- A lancer apres le fichier "supabase-urgence-securite.sql".
-- Remplace 4937 par le nouveau code admin que tu veux utiliser.
-- Evite 1900 maintenant, il faut repartir sur un nouveau code.

update admin_users
set pin = '4937'
where active = true;
