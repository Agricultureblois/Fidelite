// Légende du post menu du jour. Usage : node menu-auto/caption.js menu.json
const fs = require('fs');
const m = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const [y, mo, d] = m.date.split('-').map(Number);
let jour = new Date(Date.UTC(y, mo - 1, d)).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', timeZone: 'UTC' });
jour = jour.charAt(0).toUpperCase() + jour.slice(1);
const plats = [m.plat, m.plat2].filter(Boolean);
const lines = [`🍽️ Ce midi au Café de l'Agriculture — ${jour}`, ''];
if (m.entree) lines.push(`Entrée : ${m.entree}`);
if (plats.length) lines.push(`${plats.length > 1 ? 'Plats' : 'Plat'} : ${plats.join(' ou ')}`);
if (m.dessert) lines.push(`Dessert : ${m.dessert}`);
if (m.showprix) lines.push('', `Plat seul ${m.p1} · 2 plats ${m.p2} · Menu complet ${m.p3}`);
lines.push('', 'Tous nos plats sont faits maison 👨‍🍳', '📍 16 place de la République, Blois · 02 54 74 01 28', '', '#Blois #MenuDuJour #FaitMaison #Brasserie');
console.log(lines.join('\n'));
