const $ = (id) => document.getElementById(id);
const money = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
let db = null;
let deferredInstallPrompt = null;
function setupInstallHelp() {
  const help = $('installHelp');
  const btn = $('installApp');
  if (!help || !btn) return;
  const ua = navigator.userAgent || '';
  const isIos = /iphone|ipad|ipod/i.test(ua);
  const isStandalone = window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone;
  if (isStandalone) {
    help.textContent = "Carte installée : ouvrez-la depuis votre écran d'accueil à chaque visite.";
    btn.hidden = true;
    return;
  }
  if (isIos) {
    help.textContent = "Sur iPhone : ouvrez dans Safari, touchez Partager, puis Sur l'écran d'accueil.";
    btn.hidden = true;
  } else {
    help.textContent = "Sur Android : touchez Installer si le bouton apparaît, sinon menu puis Ajouter à l'écran d'accueil.";
  }
}
window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  deferredInstallPrompt = event;
  const btn = $('installApp');
  if (btn) btn.hidden = false;
});
let state = { member: null, ranks: [], menu: null, adminPin: localStorage.getItem('agriAdminPin') || '' };

function toast(text) { $('toast').textContent = text; $('toast').hidden = false; setTimeout(() => $('toast').hidden = true, 2200); }
function normalizePhone(v) { return String(v || '').replace(/[^\d+]/g, '').replace(/^0033/, '+33'); }
function memberCode(phone) { return 'AGRI-' + String(phone || '').replace(/[^\d]/g, ''); }
function qrUrl(data) { return 'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=' + encodeURIComponent(data); }
function ensureConfig() {
  if (!window.AGRI_SUPABASE_URL || window.AGRI_SUPABASE_URL.includes('REMPLACE_MOI')) {
    toast('Configuration Supabase manquante');
    return false;
  }
  db = window.supabase.createClient(window.AGRI_SUPABASE_URL, window.AGRI_SUPABASE_ANON_KEY);
  return true;
}
async function checkAdmin() {
  if (!state.adminPin) return false;
  const { data, error } = await db.from('admin_users').select('id').eq('pin', state.adminPin).eq('active', true).limit(1);
  if (error) throw error;
  return data && data.length > 0;
}
async function loadPublicData() {
  const ranksRes = await db.from('ranks').select('name,points_required,reward,sort_order').order('sort_order');
  if (ranksRes.error) throw ranksRes.error;
  state.ranks = ranksRes.data || [];
  const menuRes = await db.from('daily_menu').select('*').eq('id', 1).single();
  if (menuRes.error) throw menuRes.error;
  state.menu = menuRes.data;
  renderMenu();
}
function rankFor(points) { return state.ranks.reduce((cur, rank) => points >= Number(rank.points_required) ? rank : cur, state.ranks[0] || { name: 'Stagiaire', points_required: 0, reward: '' }); }
function nextRankFor(points) { return state.ranks.find(rank => Number(rank.points_required) > points) || rankFor(points); }
function renderMenu() {
  const m = state.menu || { starter: '', main: '', dessert: '', price: '' };
  $('menuStarter').textContent = m.starter || '';
  $('menuMain').textContent = m.main || '';
  $('menuDessert').textContent = m.dessert || '';
  $('menuPrice').textContent = m.price || '';
  $('adminStarter').value = m.starter || '';
  $('adminMain').value = m.main || '';
  $('adminDessert').value = m.dessert || '';
  $('adminPrice').value = m.price || '';
}
function renderClient(member) {
  state.member = member;
  const points = Number(member.points || 0);
  const rank = rankFor(points);
  const next = nextRankFor(points);
  const base = Number(rank.points_required || 0);
  const target = Number(next.points_required || base);
  const ratio = target === base ? 100 : Math.min(100, Math.round(((points - base) / (target - base)) * 100));
  $('welcomeName').textContent = member.first_name ? 'Bonjour ' + member.first_name : 'Bienvenue';
  $('currentRank').textContent = rank.name;
  $('pointsValue').textContent = points;
  $('rankProgressLabel').textContent = target === base ? 'Grade maximum atteint' : (points - base) + ' / ' + (target - base) + ' points';
  $('nextRankLabel').textContent = target === base ? rank.name : next.name;
  $('progressBar').style.width = ratio + '%';
  $('memberCode').textContent = member.code;
  $('qrImage').src = qrUrl(JSON.stringify({ code: member.code, firstName: member.first_name || '', phone: member.phone || '' }));
  renderHistory(member.visits || []);
  renderRewards(points);
  $('signinPanel').hidden = true;
  $('clientApp').hidden = false;
  localStorage.setItem('agriMemberCode', member.code);
}
function renderHistory(visits) {
  const list = $('historyList'); list.innerHTML = '';
  if (!visits.length) { list.innerHTML = '<article class="history-item"><strong>Aucune visite enregistrée</strong><span>0 pt</span></article>'; return; }
  visits.slice().reverse().forEach(v => { const item = document.createElement('article'); item.className = 'history-item'; item.innerHTML = '<strong>' + new Date(v.created_at).toLocaleDateString('fr-FR') + '</strong><span>+' + v.points + ' pts · ' + money.format(v.amount) + '</span>'; list.appendChild(item); });
}
function renderRewards(points) {
  const list = $('rewardList'); list.innerHTML = '';
  state.ranks.forEach(rank => { const unlocked = points >= Number(rank.points_required); const item = document.createElement('article'); item.className = 'reward-item' + (unlocked ? '' : ' locked'); item.innerHTML = '<strong>' + rank.name + '<small> · ' + rank.points_required + ' pts</small></strong><span>' + (unlocked ? 'Débloqué' : 'À venir') + '</span><p>' + rank.reward + '</p>'; list.appendChild(item); });
}
async function getMemberWithVisits(code) {
  const memberRes = await db.from('members').select('*').eq('code', code).single();
  if (memberRes.error) return null;
  const visitsRes = await db.from('visits').select('*').eq('member_id', memberRes.data.id).order('created_at');
  if (visitsRes.error) throw visitsRes.error;
  return { ...memberRes.data, visits: visitsRes.data || [] };
}
async function refreshMember() {
  const code = localStorage.getItem('agriMemberCode');
  if (!code) return;
  const member = await getMemberWithVisits(code);
  if (member) renderClient(member);
}
async function signup(e) {
  e.preventDefault();
  const firstName = $('firstNameInput').value.trim();
  const phone = normalizePhone($('phoneInput').value);
  if (!firstName || phone.length < 8) return toast('Prénom et téléphone requis');
  const code = memberCode(phone);
  const res = await db.from('members').upsert({ first_name: firstName, phone, code }, { onConflict: 'phone' }).select('*').single();
  if (res.error) return toast(res.error.message);
  const member = await getMemberWithVisits(res.data.code);
  renderClient(member);
}
async function unlockAdmin() {
  state.adminPin = $('adminPinInput').value.trim();
  if (!(await checkAdmin())) { state.adminPin = ''; return toast('Code admin incorrect'); }
  localStorage.setItem('agriAdminPin', state.adminPin);
  $('pinPanel').hidden = true;
  await openAdmin();
}
async function openAdmin() {
  if (!(await checkAdmin())) { localStorage.removeItem('agriAdminPin'); state.adminPin = ''; $('pinPanel').hidden = false; return; }
  $('adminPanel').hidden = false;
  await loadAdmin();
}
async function loadAdmin() {
  const membersRes = await db.from('members').select('*').order('points', { ascending: false });
  const visitsRes = await db.from('visits').select('id');
  const adminsRes = await db.from('admin_users').select('name').eq('active', true);
  if (membersRes.error) throw membersRes.error;
  $('statClients').textContent = membersRes.data.length;
  $('statPoints').textContent = membersRes.data.reduce((s, m) => s + Number(m.points || 0), 0);
  $('statVisits').textContent = visitsRes.data ? visitsRes.data.length : 0;
  const list = $('clientList'); list.innerHTML = '';
  membersRes.data.forEach(m => { const item = document.createElement('article'); item.className = 'client-item'; item.innerHTML = '<strong>' + (m.first_name || 'Client') + '</strong><span>' + m.points + ' pts · ' + rankFor(m.points).name + '</span><small>' + m.code + ' · ' + m.phone + '</small>'; list.appendChild(item); });
  const adminList = $('adminUsersList'); adminList.innerHTML = '';
  (adminsRes.data || []).forEach(a => { const item = document.createElement('article'); item.className = 'client-item'; item.innerHTML = '<strong>' + a.name + '</strong><small>Admin actif</small>'; adminList.appendChild(item); });
  renderRankEditor();
}
function renderRankEditor() {
  const wrap = $('gradeEditor'); wrap.innerHTML = '';
  state.ranks.forEach((r, i) => { const row = document.createElement('article'); row.className = 'grade-row'; row.innerHTML = '<input data-rank-name="' + i + '" value="' + r.name.replace(/"/g,'&quot;') + '"><input data-rank-points="' + i + '" type="number" value="' + r.points_required + '"><textarea data-rank-reward="' + i + '" rows="2">' + r.reward + '</textarea>'; wrap.appendChild(row); });
}
async function addPoints() {
  const code = $('scanCode').value.trim().toUpperCase();
  const amount = Math.round(Number($('amountSpent').value || 0));
  if (!code || !amount) return toast('Code et montant requis');
  const member = await getMemberWithVisits(code);
  if (!member) return toast('Client introuvable');
  const pts = Math.max(0, amount);
  const visitRes = await db.from('visits').insert({ member_id: member.id, amount: pts, points: pts });
  if (visitRes.error) return toast(visitRes.error.message);
  const updateRes = await db.from('members').update({ points: Number(member.points || 0) + pts, updated_at: new Date().toISOString() }).eq('id', member.id).select('*').single();
  if (updateRes.error) return toast(updateRes.error.message);
  $('amountSpent').value = '';
  const updated = await getMemberWithVisits(code);
  toast('Points ajoutés à ' + (updated.first_name || updated.code));
  if (state.member && state.member.code === updated.code) renderClient(updated);
  await loadAdmin();
}
async function lookupScanCode() {
  const code = $('scanCode').value.trim().toUpperCase();
  if (code.length < 8) return;
  const m = await getMemberWithVisits(code);
  if (m) $('adminClientName').value = m.first_name || '';
}
async function updateMenu(e) {
  e.preventDefault();
  const res = await db.from('daily_menu').update({ starter: $('adminStarter').value, main: $('adminMain').value, dessert: $('adminDessert').value, price: $('adminPrice').value, updated_at: new Date().toISOString() }).eq('id', 1).select('*').single();
  if (res.error) return toast(res.error.message);
  state.menu = res.data; renderMenu(); toast('Menu mis à jour');
}
async function addAdmin(e) {
  e.preventDefault();
  const name = $('newAdminName').value.trim() || 'Admin';
  const pin = $('newAdminPin').value.trim();
  if (pin.length < 4) return toast('PIN trop court');
  const res = await db.from('admin_users').insert({ name, pin, active: true });
  if (res.error) return toast(res.error.message);
  $('newAdminName').value = ''; $('newAdminPin').value = ''; toast('Admin ajouté'); await loadAdmin();
}
async function saveRanks() {
  const rows = Array.from(document.querySelectorAll('[data-rank-name]')).map((input, idx) => { const i = input.dataset.rankName; return { name: input.value, points_required: Number(document.querySelector('[data-rank-points="' + i + '"]').value || 0), reward: document.querySelector('[data-rank-reward="' + i + '"]').value, sort_order: idx + 1 }; });
  await db.from('ranks').delete().gte('id', 0);
  const res = await db.from('ranks').insert(rows);
  if (res.error) return toast(res.error.message);
  await loadPublicData(); await loadAdmin(); toast('Grades enregistrés');
}
let scanStream = null, scanTimer = null;
async function stopScanner() { if (scanTimer) clearInterval(scanTimer); scanTimer = null; if (scanStream) scanStream.getTracks().forEach(t => t.stop()); scanStream = null; $('scanPanel').hidden = true; }
async function startScanner() {
  if (!navigator.mediaDevices?.getUserMedia) return toast('Caméra non disponible');
  if (!('BarcodeDetector' in window)) return toast('Scanner non supporté, saisissez le code');
  $('scanPanel').hidden = false; $('scanStatus').textContent = 'Ouverture caméra...';
  try { scanStream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } }); $('scanVideo').srcObject = scanStream; await $('scanVideo').play(); const detector = new BarcodeDetector({ formats: ['qr_code'] }); $('scanStatus').textContent = 'Placez le QR code dans le cadre.'; scanTimer = setInterval(async () => { const codes = await detector.detect($('scanVideo')); if (!codes.length) return; let value = codes[0].rawValue || ''; try { const payload = JSON.parse(value); if (payload.code) { $('scanCode').value = payload.code; $('adminClientName').value = payload.firstName || ''; } } catch { const match = value.match(/AGRI-[0-9]+/); $('scanCode').value = match ? match[0] : value; await lookupScanCode(); } await stopScanner(); toast('QR scanné'); }, 700); } catch { await stopScanner(); toast('Autorisez la caméra'); }
}
function bindUi() {
  document.querySelectorAll('.tab').forEach(tab => tab.addEventListener('click', () => { document.querySelectorAll('.tab').forEach(t => t.classList.remove('active')); document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active')); tab.classList.add('active'); $(tab.dataset.tab).classList.add('active'); }));
  $('signupForm').addEventListener('submit', signup);
  $('installApp').addEventListener('click', async () => { if (!deferredInstallPrompt) { setupInstallHelp(); return; } deferredInstallPrompt.prompt(); await deferredInstallPrompt.userChoice; deferredInstallPrompt = null; $('installApp').hidden = true; setupInstallHelp(); });
  $('refreshClient').addEventListener('click', refreshMember);
  $('adminToggle').addEventListener('click', () => state.adminPin ? openAdmin() : $('pinPanel').hidden = false);
  $('unlockAdmin').addEventListener('click', unlockAdmin);
  $('cancelPin').addEventListener('click', () => $('pinPanel').hidden = true);
  $('closeAdmin').addEventListener('click', () => $('adminPanel').hidden = true);
  $('logoutAdmin').addEventListener('click', () => { localStorage.removeItem('agriAdminPin'); state.adminPin = ''; $('adminPanel').hidden = true; toast('Admin déconnecté'); });
  $('addPoints').addEventListener('click', addPoints);
  $('scanCode').addEventListener('input', lookupScanCode);
  $('menuForm').addEventListener('submit', updateMenu);
  $('adminUserForm').addEventListener('submit', addAdmin);
  $('saveRanks').addEventListener('click', saveRanks);
  $('openScanner').addEventListener('click', startScanner);
  $('closeScanner').addEventListener('click', stopScanner);
  $('copyCode').addEventListener('click', () => navigator.clipboard?.writeText($('memberCode').textContent));
  $('switchClient').addEventListener('click', () => { localStorage.removeItem('agriMemberCode'); state.member = null; $('clientApp').hidden = true; $('signinPanel').hidden = false; });
  window.addEventListener('focus', refreshMember);
}
async function init() {
  bindUi();
  if (!ensureConfig()) return;
  try { await loadPublicData(); await refreshMember(); if ('serviceWorker' in navigator) navigator.serviceWorker.register('service-worker.js').catch(() => {}); } catch (e) { toast(e.message || 'Erreur de connexion'); }
}
init();

