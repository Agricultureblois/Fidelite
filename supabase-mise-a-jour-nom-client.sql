-- Mise à jour à lancer une seule fois dans Supabase SQL Editor.
-- Elle ajoute le champ "nom" aux clients déjà existants.

alter table members add column if not exists last_name text;
