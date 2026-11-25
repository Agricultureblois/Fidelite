# Publication automatique du menu du jour

Chaque matin du lundi au vendredi, une tâche programmée de Claude :

1. lit le menu partagé de l'**Ardoise de l'Agri** (document `ardoise/menu` de l'artefact) ;
2. ne fait rien si la date de ce menu n'est pas celle du jour (menu pas mis à jour) ;
3. génère les deux images avec `node menu-auto/render.js menu.json` :
   `images/AAAA-MM-JJ-post.jpg` (1080×1350) et `images/AAAA-MM-JJ-story.jpg` (1080×1920) ;
4. les pousse sur ce dépôt (seuls les 7 derniers jours sont gardés). Metricool les récupère par le lien direct
   `https://raw.githubusercontent.com/agricultureblois/fidelite/main/menu-auto/images/…` (le lien du site GitHub Pages est refusé par Metricool) ;
5. programme dans Metricool, pour 6h00 : le post Facebook + Instagram (légende `node menu-auto/caption.js menu.json`) et la story Facebook + Instagram.

`ardoise.html` est une copie de l'Ardoise : si le design de l'Ardoise change, recopier la nouvelle version ici.
Polices Lora et Inter (SIL Open Font License) incluses dans `fonts/`, car Google Fonts n'est pas joignable depuis la tâche.
