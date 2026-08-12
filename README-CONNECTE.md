# Version connectée - L'Agriculture Fidélité

Cette version règle le problème de la démo : les points sont stockés dans une vraie base Supabase.

## Ce qu'il faut faire

1. Créer un compte gratuit sur https://supabase.com
2. Créer un nouveau projet.
3. Aller dans SQL Editor.
4. Coller tout le contenu de supabase-schema.sql.
5. Cliquer Run.
6. Aller dans Project Settings > API.
7. Copier :
   - Project URL
   - anon public key
8. Ouvrir supabase-config.js.
9. Remplacer :
   - REMPLACE_MOI_URL_SUPABASE
   - REMPLACE_MOI_CLE_ANON
10. Envoyer les fichiers sur GitHub Pages.

## Code admin initial

1900

Change-le ensuite en ajoutant un autre admin, puis on pourra désactiver l'ancien dans Supabase si besoin.

## Fonctionnement

- Le client s'inscrit avec prénom + téléphone.
- Son QR code contient son code client.
- L'admin scanne le QR.
- L'admin ajoute le montant.
- Les points sont enregistrés en base.
- Le client appuie sur Actualiser, ou rouvre l'app, et voit ses points.

## À publier sur GitHub Pages

- index.html
- styles.css
- app.js
- supabase-config.js
- logo-agriculture.jpg
- manifest.json
- service-worker.js
- .nojekyll

## Important

Ne partage jamais la service_role key Supabase. L'app utilise seulement la anon public key.
