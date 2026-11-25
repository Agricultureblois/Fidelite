// Génère les images du menu du jour (post Facebook/Instagram 1080x1350 et story 1080x1920)
// à partir de la page Ardoise de l'Agri. Usage : node menu-auto/render.js menu.json
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const dir = __dirname;
const menu = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const FIELDS = ["date","showdate","entree","plat","plat2","dessert","showprix","p1","p2","p3"];
const FONTS = [["Lora",400,"italic"],["Lora",400,"normal"],["Lora",600,"italic"],["Lora",600,"normal"],["Lora",700,"normal"],["Inter",400,"normal"],["Inter",500,"normal"],["Inter",600,"normal"]];
const fontCss = FONTS.map(([fam,w,st]) => {
  const b64 = fs.readFileSync(path.join(dir,'fonts',`${fam.toLowerCase()}-latin-${w}-${st}.woff2`)).toString('base64');
  return `@font-face{font-family:'${fam}';font-style:${st};font-weight:${w};src:url(data:font/woff2;base64,${b64}) format('woff2');}`;
}).join('\n');
function season(iso){ const m = Number(iso.slice(5,7)) - 1;
  return m>=2&&m<=4 ? "printemps_bois" : m>=5&&m<=7 ? "ete_bois" : m>=8&&m<=10 ? "automne" : "hiver_bois"; }
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.route('**/*', r => r.request().url().startsWith('file:') || r.request().url().startsWith('data:') ? r.continue() : r.abort());
  await page.addInitScript(css => { document.addEventListener('DOMContentLoaded', () => { const s=document.createElement('style'); s.textContent=css; document.head.appendChild(s); }); }, fontCss);
  await page.goto('file://' + path.join(dir, 'ardoise.html'));
  await page.waitForFunction(() => typeof logoImg !== 'undefined' && !!logoImg && typeof bgImg !== 'undefined' && !!bgImg, null, { timeout: 60000 });
  await page.evaluate(async ({ menu, FIELDS, preset }) => {
    await Promise.all(["600 112px Lora","italic 600 112px Lora","italic 400 50px Lora","700 54px Lora","500 32px Inter","600 26px Inter","italic 400 36px Lora","500 25px Inter"].map(f => document.fonts.load(f, "Menu du jour é")));
    FIELDS.forEach(k => { if (!(k in menu)) return; const el = document.getElementById(k);
      if (el.type === 'checkbox') el.checked = !!menu[k]; else el.value = typeof menu[k] === 'string' ? menu[k] : ''; });
    document.getElementById('moment').value = 'Ce midi';
    await applyPreset(preset);
  }, { menu, FIELDS, preset: season(menu.date) });
  const out = {};
  for (const [f, name] of [['fb','post'],['screen','story']]) {
    const data = await page.evaluate(f => { setFormat(f); return document.getElementById('c').toDataURL('image/jpeg', 0.9); }, f);
    const file = path.join(dir, 'images', `${menu.date}-${name}.jpg`);
    fs.writeFileSync(file, Buffer.from(data.split(',')[1], 'base64'));
    out[name] = file;
  }
  await browser.close();
  // garde seulement les 7 derniers jours d'images
  const imgs = fs.readdirSync(path.join(dir,'images')).filter(n => /^\d{4}-\d{2}-\d{2}-(post|story)\.jpg$/.test(n)).sort();
  const dates = [...new Set(imgs.map(n => n.slice(0,10)))].sort();
  const keep = new Set(dates.slice(-7));
  imgs.forEach(n => { if (!keep.has(n.slice(0,10))) fs.unlinkSync(path.join(dir,'images',n)); });
  console.log(JSON.stringify(out));
})().catch(e => { console.error(e); process.exit(1); });
