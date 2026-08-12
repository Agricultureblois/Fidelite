# Démo en ligne rapide

Objectif : obtenir un lien public pour tester l'application sur téléphone.

## Option la plus simple : Netlify

1. Va sur https://app.netlify.com/drop
2. Crée un compte gratuit si demandé.
3. Dépose le dossier agriculture-fidelite complet, ou le fichier agriculture-fidelite-demo.zip.
4. Netlify donne une adresse du type : https://nom-aleatoire.netlify.app
5. Ouvre cette adresse sur ton téléphone.
6. Sur iPhone : Safari > Partager > Sur l'écran d'accueil.
7. Sur Android : Chrome > menu > Ajouter à l'écran d'accueil / Installer.

## Fichiers à publier

- index.html
- logo-agriculture.jpg
- manifest.json
- service-worker.js

## Important

Cette démo en ligne permet de tester l'installation et le rendu client.
Elle ne remplace pas encore la vraie version avec base de données.

Dans cette démo :
- les points sont gardés dans le navigateur,
- si tu changes de téléphone, les données ne suivent pas,
- l'admin est protégé par un PIN local,
- le code admin par défaut est 1900.

## Pour montrer aux clients/testeurs

Tu peux envoyer le lien Netlify par SMS ou WhatsApp avec ce message :

Bonjour, voici la démo de la carte fidélité de L'Agriculture : [LIEN]
Ouvrez le lien, inscrivez votre prénom et votre téléphone, puis ajoutez l'application à votre écran d'accueil.
