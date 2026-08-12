# L'Agriculture Fidélité — contexte projet

Application de fidélité pour "L'Agriculture", brasserie à Blois tenue par Thibault (associé-gérant). PWA connectée en production, développée par itérations successives.

## Stack technique

- **Frontend** : HTML/CSS/JS vanilla, pas de framework, pas de build. Fichiers : `index.html`, `styles.css`, `app.js`.
- **Backend** : Supabase (Postgres + fonctions RPC `security definer`, RLS activée). Config dans `supabase-config.js` (URL + clé anon publique — jamais la service_role key).
- **Hébergement** : GitHub Pages. Déploiement = remplacer les fichiers modifiés directement sur le dépôt (drag & drop sur github.com, pas de CI/CD).
- **PWA** : `manifest.json` + `service-worker.js`. Important : `app.js` **désenregistre volontairement le service worker et vide les caches à chaque chargement** (voir fonction `init()`) — c'était un choix délibéré pour éviter les soucis de cache pendant le développement. À garder en tête si on retravaille un jour le offline/cache.
- **Cache-busting** : `index.html` référence `styles.css?v=N` et `app.js?v=N`. **Toujours incrémenter N à chaque modification de ces fichiers**, sinon les téléphones gardent l'ancienne version en cache.

## Historique des scripts SQL

Plusieurs fichiers `supabase-*.sql` à la racine documentent l'historique des réparations/évolutions (schéma initial, correctifs sécurité, ajout du suivi des cadeaux utilisés en v11, etc.). Le fichier `A-LIRE-ERREUR-SQL.md` documente une erreur `$$` déjà rencontrée et résolue dans l'éditeur SQL Supabase — pas un problème actif.

Code admin initial par défaut : `1900` (documenté dans les README, à changer si pas déjà fait).

## Identité visuelle (à respecter pour toute évolution UI)

- **Palette** : noir (`--black:#090807`), or (`--gold:#d6aa54`, `--gold-soft:#f0d89a`), crème (`--cream:#fff8ea`), fond dégradé sombre.
- **Typo** : Georgia/Times New Roman serif pour les titres, sans-serif système pour le reste.
- **Ton** : chaleureux, personnel, tutoiement côté client (ex. "L'apéro, c'est cadeau pour toi !", "Prends ce que tu veux !"). Thibault a rédigé ces textes lui-même, à conserver tels quels sauf demande contraire.
- Logo : épis de blé dorés encadrant le nom, arc doré au-dessus. Fichier `logo-agriculture.jpg`.

## Système de fidélité

1 € dépensé = 1 point. 9 grades (table `ranks` en base, éditables depuis l'admin) :

| Grade | Points | Récompense |
|---|---|---|
| Stagiaire | 0 | Bienvenue sur l'app |
| Apprenti | 100 | Une boisson chaude offerte ! |
| Plongeur | 250 | L'apéro, c'est cadeau pour toi ! |
| Commis de cuisine | 450 | On t'offre le dessert, fais-toi plaisir ;) |
| Serveur | 700 | Le plat que tu prends, tu ne le paies pas aujourd'hui ! |
| Chef de rang | 1000 | 15 € de remise sur l'addition, juste pour toi <3 |
| Sous-chef | 1400 | Un menu du jour offert par ton restaurant favori |
| Chef de cuisine | 1900 | Deux menus du jour à -50% |
| Directeur du restaurant | 2500 | Prends ce que tu veux ! |

## Ce qui a été fait (chronologie)

1. **Maquette React initiale** (artefact, non utilisée en prod) — a servi à valider le concept et les seuils de points avant de découvrir que Thibault avait déjà une vraie version en prod.
2. **v11 → v12 (ergonomie client)** :
   - Points affichés en gros ("hero") sur la carte de fidélité, grade en pastille discrète.
   - Barre de progression avec message clair "Plus que X points avant [grade]" + aperçu de la prochaine récompense directement sur l'accueil.
   - Navigation par onglets déplacée en barre fixe en bas d'écran (plus naturelle au pouce).
   - Bouton flottant QR pour accès en un tap depuis n'importe quel onglet.
   - Inscription simplifiée à Prénom + Téléphone (nom retiré du formulaire, colonne toujours en base, éditable via admin).
   - Formatage automatique du téléphone pendant la saisie.
   - Solde de points cumulé affiché après chaque visite dans l'historique.
3. **v13 (organisation admin)** :
   - Barre de recherche client (nom / téléphone / code) dans l'espace admin.
   - Menu de tri : Points décroissants (défaut) / Regrouper par grade / Activité récente / Nom A→Z.
4. **v14 (accès admin caché)** :
   - Icône ⚙️ admin retirée de l'écran client public — plus aucune trace visible.
   - Lien secret `index.html#equipe-lagriculture` : saute directement sur la saisie du PIN puis l'admin (scanner en premier). Prévu pour être installé en icône dédiée sur les téléphones de Thibault + employés (à renommer "Équipe" lors de l'ajout à l'écran d'accueil).
   - Bonus : correction de l'encodage cassé de `manifest.json` (accents mal affichés) + ajout d'un raccourci PWA "Espace équipe" (Android uniquement, iOS ne supporte pas les shortcuts manifest).
5. **v15 (notifications in-app)** :
   - Bannière "🎉 Nouveau grade débloqué !" affichée à l'ouverture de l'app si le grade a progressé depuis la dernière visite sur cet appareil (comparaison via `localStorage`, indexée par grade pas juste par nom pour éviter un faux positif si un admin baisse les points).
   - Bannière "🍽️ Le menu du jour a changé" si le menu a été mis à jour depuis la dernière ouverture (comparaison sur `daily_menu.updated_at`).
   - **Important** : ce sont des notifications *in-app* uniquement (visibles à l'ouverture), pas de vraies push notifications qui alertent téléphone fermé. Une vraie push nécessiterait VAPID + réécriture du service worker + une fonction serveur (Supabase Edge Function) — pas fait, explicitement mis de côté comme chantier futur si besoin.

## Roadmap / idées non développées

Proposées à Thibault, pas encore construites, à prioriser selon ses retours :

- **Notifications push réelles** (phase 2 du sujet notifications, voir ci-dessus).
- **Parrainage** entre clients (points pour les deux si un client en invite un autre).
- **Statistiques admin plus poussées** : CA généré par la fidélité, jours/heures les plus actifs, panier moyen.
- **Points bonus anniversaire** / **défi du mois** ("viens 3 fois ce mois-ci, +50 points").
- Autres idées évoquées mais pas priorisées : photos sur le menu du jour, export CSV clients, mur des records anonymisé, vue "clients à risque" (pas venus depuis longtemps), historique cumulé des cadeaux offerts.

## Contraintes et préférences de Thibault

- Communique en français, informel, direct. Préfère qu'on lui pose 1-2 questions ciblées plutôt que de deviner.
- Pas très technique (suit des instructions pas-à-pas pour Supabase/GitHub), donc privilégier des changements qui ne touchent QUE le frontend (`index.html`/`app.js`/`styles.css`) sans migration Supabase quand c'est possible — évite de lui faire manipuler l'éditeur SQL à chaque fois.
- Déploiement manuel (pas de Git configuré en ligne de commande a priori) : livrer les fichiers modifiés clairement identifiés, pas juste "tout le zip", pour qu'il puisse glisser-déposer rapidement sur GitHub.
- Toujours donner un résumé clair de ce qui a changé et pourquoi en fin de tâche, en français.
