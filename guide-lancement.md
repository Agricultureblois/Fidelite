# Guide de lancement - L'Agriculture Fidélité

## Ce qui est prêt dans cette version

- Inscription client avec prénom et numéro de téléphone.
- Carte fidélité avec points, grade, progression et QR code personnel.
- Menu du jour modifiable.
- Espace administrateur protégé par code PIN.
- Ajout de points : 1 euro dépensé = 1 point.
- Modification des grades, paliers et cadeaux.
- Liste clients avec prénom, points, grade, visites et code client.
- Export clients en CSV.
- Web app installable sur téléphone une fois publiée en ligne.

Code admin par défaut : 1900

## Parcours client recommandé

1. Le client scanne le QR code de la carte fidélité du restaurant.
2. Il entre son prénom et son numéro de téléphone.
3. Il ajoute la page à son écran d'accueil.
4. À chaque visite, il montre son QR code personnel.
5. L'équipe ajoute les points selon le montant payé.

Texte simple à mettre sur une affiche :

Votre fidélité récompensée à L'Agriculture
1 euro dépensé = 1 point
Scannez, inscrivez-vous, présentez votre QR code à chaque visite.
Cafés, verres, desserts, menus et avantages maison à débloquer.

## Procédure équipe

1. Demander : "Vous avez notre carte fidélité ?"
2. Si non : faire scanner le QR code d'inscription.
3. Si oui : demander au client d'ouvrir son QR code personnel.
4. Ouvrir l'espace admin.
5. Entrer le code client ou scanner le QR code dans la future version connectée.
6. Vérifier ou ajouter le prénom.
7. Entrer le montant payé.
8. Valider l'ajout de points.

Conseil : arrondir le montant à l'euro le plus proche.
Exemple : menu à 19,90 EUR = 20 points.

## Pour la vraie mise en ligne

Il faudra ajouter :

- un hébergement web,
- une base de données en ligne,
- un vrai compte administrateur sécurisé,
- un domaine ou sous-domaine,
- une politique simple de confidentialité,
- éventuellement un service SMS ou notifications.

Exemple d'adresse :
https://fidelite.lagriculture-blois.fr

## Phrase RGPD simple

Votre prénom et votre numéro de téléphone sont utilisés uniquement pour gérer votre compte fidélité L'Agriculture et les communications liées au restaurant. Vous pouvez demander la suppression de vos données à tout moment auprès de l'équipe.

## Prochaine étape technique

Transformer cette maquette en application connectée avec une vraie base clients commune à tous les appareils. La version actuelle garde les données dans le navigateur, ce qui est parfait pour la démonstration, mais pas suffisant pour un lancement officiel avec plusieurs clients et plusieurs appareils admin.
