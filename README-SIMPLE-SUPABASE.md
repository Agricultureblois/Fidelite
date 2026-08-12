# Version connectée simple - Supabase

Utilise cette version si Supabase bloque avec les erreurs `$$`.

## 1. Lancer le SQL simple

Dans Supabase SQL Editor :

1. Clique dans la zone SQL.
2. Fais Ctrl + A.
3. Supprime tout.
4. Ouvre le fichier `supabase-schema-simple.sql`.
5. Copie tout.
6. Colle dans Supabase.
7. Clique Run.

Ce fichier ne contient pas de fonctions `$$`, donc il évite les erreurs de dollar-quoted string.

## 2. Configurer l'application

Dans `supabase-config.js`, remplace :

```js
window.AGRI_SUPABASE_URL = "REMPLACE_MOI_URL_SUPABASE";
window.AGRI_SUPABASE_ANON_KEY = "REMPLACE_MOI_CLE_ANON";
```

par les valeurs de Supabase > Project Settings > API.

Prends :
- Project URL
- anon public key

Ne prends jamais la service_role key.

## 3. Publier sur GitHub Pages

Envoie ces fichiers :

- index.html
- styles.css
- app.js
- supabase-config.js
- logo-agriculture.jpg
- manifest.json
- service-worker.js
- .nojekyll

## Code admin initial

1900

## Important sécurité

Cette version connectée simple fonctionne vraiment entre appareils, mais elle est moins sécurisée qu'une version backend complète : le PIN admin est stocké dans une table lisible par l'application.

Pour une phase test restaurant, c'est acceptable. Pour une exploitation long terme avec beaucoup de clients, il faudra ensuite renforcer la sécurité avec des fonctions serveur ou une authentification admin Supabase.
