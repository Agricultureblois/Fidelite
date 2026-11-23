# L'Agriculture Fidélité — contexte projet

Application de fidélité pour "L'Agriculture", brasserie à Blois tenue par Thibault (associé-gérant). PWA connectée, **en production** sur https://fidelite.lagriculture-blois.fr, développée par itérations successives. État actuel : **v31** (cache-busting `?v=31`).

## Stack technique

- **Frontend** : HTML/CSS/JS vanilla, pas de framework, pas de build. Fichiers : `index.html` (app client + espace admin intégré), `equipe.html` (page équipe dédiée), `styles.css`, `app.js`, `qrcode.js`.
- **Backend** : Supabase, projet `agriculture-fidelite` (ref `csvipekjeddgvbtnravj`, région eu-west-1). Postgres + fonctions RPC `security definer`. Config dans `supabase-config.js` (URL + clé anon publique : normal qu'elle soit dans un dépôt public, mais **jamais la service_role key**).
- **Hébergement** : GitHub Pages, dépôt `agricultureblois/Fidelite` (public). **Déploiement = `git add/commit/push` depuis le dossier local** (git configuré depuis le 12/08/2026). Un push met l'app en ligne pour les clients en environ une minute : vérifier avant de pousser.
- **PWA** : `manifest.json` + `service-worker.js`. Le service worker est enregistré par `init()` en version **minimale sans aucun cache** (simple passe-plat réseau). C'est la condition de Chrome pour proposer "Installer" en 1 tap sur Android. **Ne jamais y ajouter de cache** : les téléphones garderaient des versions périmées.
- **QR code** : généré **localement** par `qrcode.js` (bibliothèque MIT intégrée au dépôt, chargée avant `app.js`). Le QR ne contient que le code client. Ne pas réintroduire de service externe : ça faisait fuiter des données clients.
- **Cache-busting** : `index.html` et `equipe.html` référencent `styles.css?v=N`, `qrcode.js?v=N` et `app.js?v=N` : incrémenter N dans **les deux pages**. **Toujours incrémenter N à chaque modification de ces fichiers**, sinon les téléphones gardent l'ancienne version.
- `.claude/` est dans `.gitignore` (réglages locaux de Claude Code, jamais dans le dépôt).

## Base de données (état réel Supabase)

- **9 tables, RLS activée sur toutes** : `admin_users`, `challenge_claims`, `daily_menu`, `members`, `ranks`, `reward_redemptions`, `visits`, `monthly_till_revenue` (CA caisse saisi par mois), `reward_values` (valeur € estimée de chaque cadeau, par nom de grade).
- **Fonctions RPC** : `signup_member`, `get_member_card`, `claim_challenge`, `admin_ok`, `is_admin_pin`, `admin_dashboard`, `admin_add_points`, `admin_set_points`, `admin_add_user`, `admin_delete_member`, `admin_redeem_reward`, `admin_save_ranks`, `admin_update_menu`, `admin_set_monthly_revenue`, `admin_set_reward_values`, `admin_kpi_stats` (interne, non appelable en API), plus le trigger `protect_member_points`.
- **Source de vérité = la base Supabase, pas les fichiers `.sql` du dépôt.** Les `supabase-*.sql` à la racine s'arrêtent à la v11 (cadeaux utilisés) et documentent l'historique. Trois migrations ont été appliquées directement sur Supabase sans être versionnées en fichiers : `add_monthly_challenge` (12/08), `add_business_stats_to_admin_dashboard` et `add_rewards_stats_to_admin_dashboard` (13/08). Avant toute évolution de la base, inspecter l'existant (liste des migrations, tables, fonctions). **À faire** : exporter ces migrations dans le dépôt (`supabase-*.sql`) pour pouvoir reconstruire la base, et versionner chaque future migration.
- `A-LIRE-ERREUR-SQL.md` documente une erreur `$$` déjà résolue dans l'éditeur SQL Supabase : pas un problème actif.
- **Sécurité** : le dépôt est public et les README mentionnent le code admin par défaut `1900`. Vérifier qu'il a été changé (`supabase-changer-pin-admin.sql`). Les PIN sont gérés dans `admin_users`.

## Identité visuelle (à respecter pour toute évolution UI)

- **Palette** : noir (`--black:#090807`), or (`--gold:#d6aa54`, `--gold-soft:#f0d89a`), crème (`--cream:#fff8ea`), fond dégradé sombre.
- **Typo** : Georgia/Times New Roman serif pour les titres, sans-serif système pour le reste.
- **Ton** : chaleureux, personnel, tutoiement côté client (ex. "L'apéro, c'est cadeau pour toi !"). Thibault a rédigé les textes des récompenses lui-même : à conserver tels quels sauf demande contraire.
- Logo : épis de blé dorés, arc doré au-dessus. Fichier `logo-agriculture.jpg`.

## Système de fidélité

1 € dépensé = 1 point. 9 grades (table `ranks`, éditables depuis l'admin) :

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

**Défi du mois** (côté client, validé par `claim_challenge`, table `challenge_claims`) : 5 visites dans le mois = +30 points, 10 visites = +70 points. Les compteurs repartent chaque mois (période `AAAA-MM`).

## Fonctionnalités en place

**Côté client (`index.html`)**
- Inscription Prénom + Téléphone (formatage automatique du numéro), carte fidélité avec points en grand, barre "Plus que X points avant [grade]", aperçu de la prochaine récompense, historique avec solde cumulé après chaque visite.
- Navigation en barre fixe en bas d'écran + bouton flottant QR accessible partout.
- Onglets Accueil / Récompenses / Menu du jour / QR. Cadeaux regroupés côté client.
- Bannières in-app à l'ouverture : "🎉 Nouveau grade débloqué" et "🍽️ Le menu du jour a changé" (comparaison via `localStorage` : `agriLastSeenRankIdx_<code>`, `agriLastSeenMenuUpdatedAt`).
- Défi du mois avec bouton de réclamation. Installation PWA en 1 tap sur Android.
- Aucun bouton admin visible côté client.

**Côté équipe (`equipe.html#equipe-lagriculture`, ou le même hash sur `index.html`)**
- Page dédiée pour l'icône "Équipe" sur les téléphones de Thibault et des employés. Le code PIN reste la vraie protection (le lien secret évite seulement que des clients tombent dessus). Le code admin est mémorisé sur l'appareil (`agriAdminPin`).
- Admin en 3 onglets : **Créditer** (recherche client par nom/téléphone/code ou scan caméra, montants rapides 2 / 3 / 15 / 20 € + autre montant), **Clients** (recherche, tri points/grade/activité/nom, aperçu client, correction des points, suppression, cadeaux à marquer comme utilisés, export CSV, vue "clients à risque"), **Réglages** (menu du jour, grades et récompenses, gestion des admins).
- **Stats business** : CA du mois et total, panier moyen, visites, clients, points distribués, cadeaux offerts (mois/total) et récompense la plus utilisée, graphiques par jour de semaine et par heure.

## v28 — Pilotage (17/11/2026)
Carte « Pilotage » dans l'onglet Clients : taux de capture (CA appli / CA caisse saisi par mois), rétention mois sur mois, panier médian, passages en jours distincts, valeur € des cadeaux offerts. Migration `supabase-v28-kpi-stats.sql` (déjà appliquée sur Supabase ; retour arrière : `supabase-rollback-admin-dashboard-v27.sql`). Valeurs des cadeaux initiales = prix de la carte, à confirmer ; Apprenti et Plongeur non renseignés. `admin_dashboard` renvoie les mêmes clés qu'avant + les nouvelles.

## v29 — Calendrier de l'Avent + roue de Noël (décembre 2026)
Migrations `supabase-v29-avent.sql` (déjà appliquée ; retour arrière `supabase-rollback-avent-v29.sql`). Tables `advent_config` (dates 1–24/12 cases, 31/12 fin de roue, budget 20 €, `enabled` = interrupteur), `advent_plays`. RPC : `advent_state`, `advent_open_case`, `advent_spin` (client, par code), `admin_advent_overview`, `admin_use_advent_gift` (équipe), `advent_draw` (interne). Règles : case du jour ouverte seulement si un crédit a été fait ce jour-là (heure de Paris), pas de rattrapage ; 1 tour de roue tous les 3 jours de présence ; gains = points (cases +5/10/15/25, roue +10 à +50) ou cadeaux réels (boisson chaude, apéro, valeurs de `reward_values`) tirés côté serveur, plafonnés par le budget et étalés sur la période. Désactiver : `update advent_config set enabled=false;`. Équipe : carte « Calendrier de l'Avent » dans l'onglet Clients (budget dépensé, cadeaux à remettre → bouton « Remis »). Restaurant fermé samedi et dimanche : pas de case ces jours-là (`advent_config.closed_dow`, défaut {0,6}), cases perdues, affichées « fermé ». Pas de message « Bientôt » avant le 1er décembre. **Mode test** : `advent_config.only_codes` (tableau de codes clients) réserve l'Avent à ces comptes ; pour tester avant décembre : `update advent_config set start_date=current_date, cases_until=current_date+23, end_date=current_date+30, only_codes=array['AGRI-...'] where id=1;` puis REMETTRE `start_date='2026-12-01', cases_until='2026-12-24', end_date='2026-12-31', only_codes=null` et supprimer les parties de test (`delete from advent_plays;`) et re-créditer/retirer les points de test. Testé en base avec rollback ; non testé en conditions réelles avant le 1er décembre.

## v31 — correctif enregistrement des grades (23/11/2026)
Bug (présent depuis longtemps) : `saveRanks` sélectionnait `[data-rank-name]`, qui attrape aussi les boutons « Marquer utilisé » de l'aperçu client (même attribut) → erreur JS silencieuse, rien n'était envoyé au serveur dès qu'un aperçu client avec cadeau disponible était affiché. Corrigé en limitant les sélecteurs à `#gradeEditor input[...]`. Grades 10 à 12 ajoutés en base le 23/11/2026 (Associé de la maison 3500, Patron d'un soir 5000, Légende de l'Agriculture 7500).

## Historique (d'après git)

- **v11 → v15** (juillet/août 2026) : refonte ergonomique client, tri/recherche admin, accès équipe caché, notifications in-app (grade, menu).
- **12/08/2026** : git configuré, page équipe dédiée, mémorisation du code admin, crédit simplifié, défi du mois.
- **13/08/2026** : clients à risque, stats business, admin en 3 onglets, aperçu client, montants rapides, stats cadeaux, export CSV.
- **03/11/2026** : QR généré localement, service worker minimal enregistré, installation en 1 tap.

## Roadmap / idées non développées

À prioriser selon les retours de Thibault :

- **Notifications push réelles** (alertent téléphone fermé). Demande VAPID, un service worker plus complexe (sans jamais y mettre de cache de pages) et une Supabase Edge Function. Les bannières in-app existent déjà.
- **Parrainage** (points pour les deux si un client en invite un autre).
- **Points bonus anniversaire**.
- Idées non priorisées : photos sur le menu du jour, mur des records anonymisé, menu de la semaine.

## Contraintes et préférences de Thibault

- Français, informel, direct. Phrases courtes. Préfère 1 à 2 questions ciblées plutôt qu'une supposition, des résultats directement utilisables, et valide par petits messages : intégrer les corrections tout de suite sans réexpliquer.
- Pas développeur : privilégier les changements qui ne touchent que le frontend (`index.html`/`equipe.html`/`app.js`/`styles.css`) sans migration SQL quand c'est possible. Si une migration est nécessaire, l'appliquer et la versionner dans le dépôt, sans lui demander de manipuler l'éditeur SQL.
- Toujours terminer par un résumé clair en français de ce qui a changé et pourquoi.
