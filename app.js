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
  btn.hidden = false;
  if (isStandalone) {
    help.textContent = "Carte installée : ouvrez-la depuis votre écran d'accueil à chaque visite.";
    btn.hidden = true;
    return;
  }
  if (isIos) {
    help.textContent = "Touchez le bouton pour voir les étapes d'installation sur iPhone ou Android.";
    btn.textContent = "Voir l'aide";
  } else {
    help.textContent = "Touchez le bouton pour voir les étapes d'installation sur iPhone ou Android.";
    btn.textContent = deferredInstallPrompt ? 'Installer' : "Voir l'aide";
  }
}
window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  deferredInstallPrompt = event;
  const btn = $('installApp');
  if (btn) { btn.hidden = false; btn.textContent = 'Installer'; }
});
let state = { member: null, ranks: [], menu: null, adminPin: '' };

function toast(text) { $('toast').textContent = text; $('toast').hidden = false; setTimeout(() => $('toast').hidden = true, 2200); }
function normalizePhone(v) { return String(v || '').replace(/[^\d+]/g, '').replace(/^0033/, '+33'); }
function normalizePin(v) { return String(v || '').replace(/[^\d]/g, ''); }
function memberCode(phone) { return 'AGRI-' + String(phone || '').replace(/[^\d]/g, ''); }
function qrUrl(data) { return 'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=' + encodeURIComponent(data); }
function fullName(member) { return [member?.first_name, member?.last_name].filter(Boolean).join(' ').trim(); }
function escapeHtml(value) { return String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
function ensureConfig() {
  if (!window.AGRI_SUPABASE_URL || window.AGRI_SUPABASE_URL.includes('REMPLACE_MOI')) {
    toast('Configuration Supabase manquante');
    return false;
  }
  db = window.supabase.createClient(window.AGRI_SUPABASE_URL, window.AGRI_SUPABASE_ANON_KEY);
  return true;
}
async function checkAdmin() {
  const pin = normalizePin(state.adminPin);
  if (!pin) return false;
  const { data, error } = await db.rpc('admin_ok', { p_pin: pin });
  if (error) throw error;
  return data === true;
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
  $('qrImage').src = qrUrl(JSON.stringify({ code: member.code, firstName: member.first_name || '', lastName: member.last_name || '', phone: member.phone || '' }));
  renderHistory(member.visits || []);
  renderRewards(points);
  $('signinPanel').hidden = true;
  $('clientApp').hidden = false;
  localStorage.setItem('agriMemberCode', member.code);
  if (member.phone) localStorage.setItem('agriMemberPhone', member.phone);
}
function renderHistory(visits) {
  const list = $('historyList'); list.innerHTML = '';
  if (!visits.length) { list.innerHTML = '<article class="history-item"><strong>Aucune visite enregistrée</strong><span>0 pt</span></article>'; return; }
  visits.slice().reverse().forEach(v => { const item = document.createElement('article'); item.className = 'history-item'; item.innerHTML = '<strong>' + new Date(v.created_at).toLocaleDateString('fr-FR') + '</strong><span>+' + v.points + ' pts · ' + money.format(v.amount) + '</span>'; list.appendChild(item); });
}
function renderRewards(points) {
  const list = $('rewardList'); list.innerHTML = '';
  const used = state.member?.reward_redemptions || [];
  state.ranks.forEach(rank => {
    const unlocked = points >= Number(rank.points_required);
    const redeemed = used.find(r => r.rank_name === rank.name && Number(r.points_required) === Number(rank.points_required));
    const item = document.createElement('article');
    item.className = 'reward-item' + (unlocked ? '' : ' locked') + (redeemed ? ' redeemed' : '');
    item.innerHTML = '<strong>' + escapeHtml(rank.name) + '<small> · ' + Number(rank.points_required) + ' pts</small></strong><span>' + (redeemed ? 'Déjà utilisé' : unlocked ? 'Débloqué' : 'À venir') + '</span><p>' + escapeHtml(rank.reward) + '</p>';
    list.appendChild(item);
  });
}
async function getMemberWithVisits(code) {
  const { data, error } = await db.rpc('get_member_card', { p_code: code });
  if (error) throw error;
  return data;
}
async function refreshMember() {
  let code = localStorage.getItem('agriMemberCode');
  if (!code && localStorage.getItem('agriMemberPhone')) code = memberCode(localStorage.getItem('agriMemberPhone'));
  if (!code) return;
  try {
    const member = await getMemberWithVisits(code);
    if (member) renderClient(member);
  } catch (error) {
    toast(error.message || 'Connexion client à actualiser');
  }
}
async function signup(e) {
  e.preventDefault();
  const firstName = $('firstNameInput').value.trim();
  const lastName = $('lastNameInput').value.trim();
  const phone = normalizePhone($('phoneInput').value);
  if (!firstName || phone.length < 8) return toast('Prénom et téléphone requis');
  const code = memberCode(phone);
  const { data, error } = await db.rpc('signup_member', { p_first_name: firstName, p_last_name: lastName, p_phone: phone, p_code: code });
  if (error) return toast(error.message);
  const member = data || await getMemberWithVisits(code);
  localStorage.setItem('agriMemberPhone', phone);
  renderClient(member);
}
async function unlockAdmin() {
  state.adminPin = normalizePin($('adminPinInput').value);
  $('adminPinInput').value = state.adminPin;
  try {
    if (!(await checkAdmin())) { state.adminPin = ''; return toast('Code admin incorrect'); }
  } catch (error) {
    state.adminPin = '';
    return toast(error.message || 'Connexion admin impossible');
  }
  localStorage.removeItem('agriAdminPin');
  $('pinPanel').hidden = true;
  await openAdmin();
}
async function openAdmin() {
  try {
    if (!(await checkAdmin())) { localStorage.removeItem('agriAdminPin'); state.adminPin = ''; $('pinPanel').hidden = false; return; }
    $('adminPanel').hidden = false;
    await loadAdmin();
  } catch (error) {
    localStorage.removeItem('agriAdminPin');
    state.adminPin = '';
    $('pinPanel').hidden = false;
    toast(error.message || 'Accès admin impossible');
  }
}
async function loadAdmin() {
  const { data, error } = await db.rpc('admin_dashboard', { p_pin: state.adminPin });
  if (error) throw error;
  const members = data?.members || [];
  const admins = data?.admins || [];
  $('statClients').textContent = members.length;
  $('statPoints').textContent = members.reduce((s, m) => s + Number(m.points || 0), 0);
  $('statVisits').textContent = data?.visits_count || 0;
  const list = $('clientList'); list.innerHTML = '';
  members.forEach(m => {
    const item = document.createElement('article');
    item.className = 'client-item client-item-admin';
    item.innerHTML = '<div><strong>' + escapeHtml(fullName(m) || 'Client') + '</strong><span>' + Number(m.points || 0) + ' pts · ' + escapeHtml(rankFor(m.points).name) + '</span><small>' + escapeHtml(m.code) + ' · ' + escapeHtml(m.phone) + '</small></div><div class="client-actions"><button class="mini-action correct-client" type="button" data-client-code="' + escapeHtml(m.code) + '" data-client-points="' + Number(m.points || 0) + '" data-client-name="' + escapeHtml(fullName(m) || m.code) + '">Corriger</button><button class="danger-action delete-client" type="button" data-client-id="' + escapeHtml(m.id) + '" data-client-name="' + escapeHtml(fullName(m) || m.code) + '">Supprimer</button></div>';
    const rewards = adminRewardHtml(m);
    if (rewards) item.insertAdjacentHTML('beforeend', rewards);
    list.appendChild(item);
  });
  const adminList = $('adminUsersList'); adminList.innerHTML = '';
  admins.forEach(a => { const item = document.createElement('article'); item.className = 'client-item'; item.innerHTML = '<strong>' + escapeHtml(a.name) + '</strong><small>Admin actif</small>'; adminList.appendChild(item); });
  renderRankEditor();
}
function adminRewardHtml(member) {
  const points = Number(member.points || 0);
  const redemptions = member.reward_redemptions || [];
  const eligible = state.ranks.filter(rank => Number(rank.points_required) > 0 && points >= Number(rank.points_required));
  if (!eligible.length) return '<div class="admin-rewards empty">Aucun cadeau débloqué pour le moment.</div>';
  const rows = eligible.map(rank => {
    const used = redemptions.find(r => r.rank_name === rank.name && Number(r.points_required) === Number(rank.points_required));
    if (used) {
      const date = used.created_at ? new Date(used.created_at).toLocaleDateString('fr-FR') : '';
      return '<article class="admin-reward used"><div><strong>' + escapeHtml(rank.name) + '</strong><span>Utilisé' + (date ? ' le ' + date : '') + '</span><small>' + escapeHtml(rank.reward) + '</small></div></article>';
    }
    return '<article class="admin-reward available"><div><strong>' + escapeHtml(rank.name) + '</strong><span>Cadeau disponible</span><small>' + escapeHtml(rank.reward) + '</small></div><button class="mini-action redeem-reward" type="button" data-client-id="' + escapeHtml(member.id) + '" data-client-name="' + escapeHtml(fullName(member) || member.code) + '" data-rank-name="' + escapeHtml(rank.name) + '" data-rank-points="' + Number(rank.points_required) + '" data-rank-reward="' + escapeHtml(rank.reward) + '">Marquer utilisé</button></article>';
  }).join('');
  return '<div class="admin-rewards"><p>Cadeaux paliers</p>' + rows + '</div>';
}
function renderRankEditor() {
  const wrap = $('gradeEditor'); wrap.innerHTML = '';
  state.ranks.forEach((r, i) => { const row = document.createElement('article'); row.className = 'grade-row'; row.innerHTML = '<input data-rank-name="' + i + '" value="' + r.name.replace(/"/g,'&quot;') + '"><input data-rank-points="' + i + '" type="number" value="' + r.points_required + '"><textarea data-rank-reward="' + i + '" rows="2">' + r.reward + '</textarea>'; wrap.appendChild(row); });
}
async function addPoints() {
  const code = $('scanCode').value.trim().toUpperCase();
  const amount = Math.round(Number($('amountSpent').value || 0));
  if (!code || !amount) return toast('Code et montant requis');
  const pts = Math.max(0, amount);
  const { data: updated, error } = await db.rpc('admin_add_points', { p_pin: state.adminPin, p_code: code, p_amount: pts });
  if (error) return toast(error.message);
  $('amountSpent').value = '';
  toast('Points ajoutés à ' + (fullName(updated) || updated.code));
  if (state.member && state.member.code === updated.code) renderClient(updated);
  await loadAdmin();
}
async function lookupScanCode() {
  const code = $('scanCode').value.trim().toUpperCase();
  if (code.length < 8) return;
  const m = await getMemberWithVisits(code);
  if (m) $('adminClientName').value = fullName(m) || m.code;
}
async function deleteClient(memberId, memberName) {
  if (!memberId) return;
  if (!confirm('Supprimer ' + memberName + ' ? Ses points et visites seront supprimés.')) return;
  const { error } = await db.rpc('admin_delete_member', { p_pin: state.adminPin, p_member_id: memberId });
  if (error) return toast(error.message);
  if (state.member && state.member.id === memberId) {
    localStorage.removeItem('agriMemberCode');
    localStorage.removeItem('agriMemberPhone');
    state.member = null;
  }
  toast('Client supprimé');
  await loadAdmin();
}
async function correctClientPoints(code, currentPoints, memberName) {
  const value = prompt('Nouveau total de points pour ' + memberName, String(currentPoints || 0));
  if (value === null) return;
  const points = Math.max(0, Math.round(Number(value)));
  if (!Number.isFinite(points)) return toast('Nombre de points invalide');
  const { data: updated, error } = await db.rpc('admin_set_points', { p_pin: state.adminPin, p_code: code, p_points: points });
  if (error) return toast(error.message);
  if (state.member && state.member.code === updated.code) renderClient(updated);
  toast('Points corrigés');
  await loadAdmin();
}
async function redeemReward(memberId, memberName, rankName, pointsRequired, reward) {
  if (!confirm('Marquer le cadeau "' + rankName + '" comme utilisé pour ' + memberName + ' ?')) return;
  const { error } = await db.rpc('admin_redeem_reward', {
    p_pin: state.adminPin,
    p_member_id: memberId,
    p_rank_name: rankName,
    p_points_required: Number(pointsRequired || 0),
    p_reward: reward
  });
  if (error) return toast(error.message);
  toast('Cadeau marqué utilisé');
  await loadAdmin();
  if (state.member) await refreshMember();
}
async function updateMenu(e) {
  e.preventDefault();
  const { data, error } = await db.rpc('admin_update_menu', { p_pin: state.adminPin, p_starter: $('adminStarter').value, p_main: $('adminMain').value, p_dessert: $('adminDessert').value, p_price: $('adminPrice').value });
  if (error) return toast(error.message);
  state.menu = data; renderMenu(); toast('Menu mis à jour');
}
async function addAdmin(e) {
  e.preventDefault();
  const name = $('newAdminName').value.trim() || 'Admin';
  const pin = $('newAdminPin').value.trim();
  if (pin.length < 4) return toast('PIN trop court');
  const { error } = await db.rpc('admin_add_user', { p_pin: state.adminPin, p_name: name, p_new_pin: pin });
  if (error) return toast(error.message);
  $('newAdminName').value = ''; $('newAdminPin').value = ''; toast('Admin ajouté'); await loadAdmin();
}
async function saveRanks() {
  const rows = Array.from(document.querySelectorAll('[data-rank-name]')).map((input, idx) => { const i = input.dataset.rankName; return { name: input.value, points_required: Number(document.querySelector('[data-rank-points="' + i + '"]').value || 0), reward: document.querySelector('[data-rank-reward="' + i + '"]').value, sort_order: idx + 1 }; });
  const { error } = await db.rpc('admin_save_ranks', { p_pin: state.adminPin, p_ranks: rows });
  if (error) return toast(error.message);
  await loadPublicData(); await loadAdmin(); toast('Grades enregistrés');
}
let scanStream = null, scanTimer = null;
async function stopScanner() { if (scanTimer) clearInterval(scanTimer); scanTimer = null; if (scanStream) scanStream.getTracks().forEach(t => t.stop()); scanStream = null; $('scanPanel').hidden = true; }
async function startScanner() {
  if (!navigator.mediaDevices?.getUserMedia) return toast('Caméra non disponible');
  if (!('BarcodeDetector' in window)) return toast('Scanner non supporté, saisissez le code');
  $('scanPanel').hidden = false; $('scanStatus').textContent = 'Ouverture caméra...';
  try { scanStream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } }); $('scanVideo').srcObject = scanStream; await $('scanVideo').play(); const detector = new BarcodeDetector({ formats: ['qr_code'] }); $('scanStatus').textContent = 'Placez le QR code dans le cadre.'; scanTimer = setInterval(async () => { const codes = await detector.detect($('scanVideo')); if (!codes.length) return; let value = codes[0].rawValue || ''; try { const payload = JSON.parse(value); if (payload.code) { $('scanCode').value = payload.code; $('adminClientName').value = [payload.firstName, payload.lastName].filter(Boolean).join(' ') || ''; await lookupScanCode(); } } catch { const match = value.match(/AGRI-[0-9]+/); $('scanCode').value = match ? match[0] : value; await lookupScanCode(); } await stopScanner(); toast('QR scanné'); }, 700); } catch { await stopScanner(); toast('Autorisez la caméra'); }
}
function bindUi() {
  document.querySelectorAll('.tab').forEach(tab => tab.addEventListener('click', () => { document.querySelectorAll('.tab').forEach(t => t.classList.remove('active')); document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active')); tab.classList.add('active'); $(tab.dataset.tab).classList.add('active'); }));
  $('signupForm').addEventListener('submit', signup);
  $('installApp').addEventListener('click', () => {
    $('installPanel').hidden = false;
    setupInstallHelp();
  });
  $('tryInstallApp').addEventListener('click', () => {
    $('installPanel').hidden = false;
    setupInstallHelp();
    toast("Utilisez le menu Chrome puis Ajouter à l'écran d'accueil.");
  });
  $('closeInstallHelp').addEventListener('click', () => $('installPanel').hidden = true);
  $('refreshClient').addEventListener('click', refreshMember);
  $('adminToggle').addEventListener('click', () => {
    localStorage.removeItem('agriAdminPin');
    state.adminPin = '';
    $('adminPinInput').value = '';
    $('pinPanel').hidden = false;
  });
  $('unlockAdmin').addEventListener('click', unlockAdmin);
  $('cancelPin').addEventListener('click', () => $('pinPanel').hidden = true);
  $('closeAdmin').addEventListener('click', () => $('adminPanel').hidden = true);
  $('logoutAdmin').addEventListener('click', () => { localStorage.removeItem('agriAdminPin'); state.adminPin = ''; $('adminPanel').hidden = true; toast('Admin déconnecté'); });
  $('addPoints').addEventListener('click', addPoints);
  $('scanCode').addEventListener('input', lookupScanCode);
  $('menuForm').addEventListener('submit', updateMenu);
  $('adminUserForm').addEventListener('submit', addAdmin);
  $('clientList').addEventListener('click', (event) => {
    const button = event.target.closest('.delete-client');
    if (button) deleteClient(button.dataset.clientId, button.dataset.clientName || 'ce client');
    const correctButton = event.target.closest('.correct-client');
    if (correctButton) correctClientPoints(correctButton.dataset.clientCode, correctButton.dataset.clientPoints, correctButton.dataset.clientName || 'ce client');
    const rewardButton = event.target.closest('.redeem-reward');
    if (rewardButton) redeemReward(rewardButton.dataset.clientId, rewardButton.dataset.clientName || 'ce client', rewardButton.dataset.rankName, rewardButton.dataset.rankPoints, rewardButton.dataset.rankReward);
  });
  $('saveRanks').addEventListener('click', saveRanks);
  $('openScanner').addEventListener('click', startScanner);
  $('closeScanner').addEventListener('click', stopScanner);
  $('copyCode').addEventListener('click', () => navigator.clipboard?.writeText($('memberCode').textContent));
  $('switchClient').addEventListener('click', () => { localStorage.removeItem('agriMemberCode'); localStorage.removeItem('agriMemberPhone'); state.member = null; $('clientApp').hidden = true; $('signinPanel').hidden = false; });
  window.addEventListener('focus', refreshMember);
}
async function init() {
  bindUi();
  if (!ensureConfig()) return;
  try {
    if ('serviceWorker' in navigator) {
      const registrations = await navigator.serviceWorker.getRegistrations();
      await Promise.all(registrations.map(registration => registration.unregister()));
    }
    if ('caches' in window) {
      const keys = await caches.keys();
      await Promise.all(keys.map(key => caches.delete(key)));
    }
  } catch {}
  try { await loadPublicData(); await refreshMember(); } catch (e) { toast(e.message || 'Erreur de connexion'); }
}
init();


