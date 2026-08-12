# Important pour Supabase SQL Editor

Si tu vois cette erreur :

syntax error at or near "$$"
LINE 1: $$;

Cela veut dire que Supabase lance un morceau du script qui commence au milieu d'une fonction.

Pour corriger :

1. Dans SQL Editor, clique dans la zone de texte.
2. Fais Ctrl + A.
3. Appuie sur Supprimer.
4. Recopie le fichier supabase-schema.sql depuis la toute première ligne.
5. La toute première ligne visible doit être exactement :

create schema if not exists extensions;

6. Il ne doit pas y avoir $$; au tout début.
7. Ne sélectionne aucun morceau du texte avant de cliquer Run.
8. Clique Run.

Si un morceau de texte est sélectionné, Supabase peut lancer uniquement la sélection au lieu du script complet.
