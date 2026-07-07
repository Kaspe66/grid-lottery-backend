let adminToken = localStorage.getItem('adminToken');
let refreshInterval = null;
let currentEditingUserId = null;
let allUsersData = {};

// DOM Elements
const loginContainer = document.getElementById('login-container');
const appContainer = document.getElementById('app-container');
const loginBtn = document.getElementById('login-btn');
const logoutBtn = document.getElementById('logout-btn');
const navBtns = document.querySelectorAll('.nav-btn');
const tabs = document.querySelectorAll('.tab-content');

if (adminToken) showApp();

// --- AUTH ---
loginBtn.addEventListener('click', async () => {
    const pwd = document.getElementById('admin-password').value;
    if (!pwd) return;
    try {
        const res = await fetch('/admin/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ password: pwd })
        });
        const data = await res.json();
        if (data.success) {
            adminToken = data.token;
            localStorage.setItem('adminToken', adminToken);
            showApp();
        } else {
            document.getElementById('login-error').textContent = data.message;
        }
    } catch (e) {
        document.getElementById('login-error').textContent = 'Ошибка сети';
    }
});

logoutBtn.addEventListener('click', () => {
    localStorage.removeItem('adminToken');
    adminToken = null;
    if (refreshInterval) clearInterval(refreshInterval);
    loginContainer.classList.remove('hidden');
    appContainer.classList.add('hidden');
});

function showApp() {
    loginContainer.classList.add('hidden');
    appContainer.classList.remove('hidden');
    loadActiveTab();
    if (refreshInterval) clearInterval(refreshInterval);
    refreshInterval = setInterval(loadActiveTab, 5000);
}

// --- TABS ---
navBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        navBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        tabs.forEach(t => t.classList.remove('active'));
        document.getElementById('tab-' + btn.dataset.tab).classList.add('active');
        loadActiveTab();
    });
});

function loadActiveTab() {
    const activeTab = document.querySelector('.nav-btn.active').dataset.tab;
    if (activeTab === 'dashboard') loadDashboard();
    if (activeTab === 'users') loadUsers();
    if (activeTab === 'withdrawals') loadWithdrawals();
    if (activeTab === 'settings') loadSettings();
    if (activeTab === 'logs') loadLogs();
    if (activeTab === 'deposits') loadDeposits();
    if (activeTab === 'bots') loadBots();
}

async function apiFetch(url, options = {}) {
    options.headers = { ...options.headers, 'Authorization': 'Bearer ' + adminToken };
    const res = await fetch(url, options);
    if (res.status === 401) { logoutBtn.click(); throw new Error('Unauthorized'); }
    return res.json();
}

// --- DASHBOARD ---
async function loadDashboard() {
    try {
        const data = await apiFetch('/admin/stats');
        document.getElementById('stat-online').textContent = data.online;
        document.getElementById('stat-total').textContent = data.totalUsers;
        document.getElementById('stat-real').innerHTML = `${data.systemReal} <span style="font-size:1rem;color:rgba(255,255,255,0.5)">(${(data.systemReal/1000).toFixed(2)} GRAM)</span>`;
        document.getElementById('stat-bonus').textContent = data.systemBonus;
        
        const mToggle = document.getElementById('maintenance-toggle');
        const mText = document.getElementById('maintenance-status-text');
        if (mToggle.checked !== data.maintenance) mToggle.checked = data.maintenance;
        mText.textContent = data.maintenance ? 'Режим включен' : 'Режим выключен';
        mText.style.color = data.maintenance ? '#ef4444' : '#fff';
    } catch (e) {}
}

document.getElementById('maintenance-toggle').addEventListener('change', async (e) => {
    await apiFetch('/admin/maintenance', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ active: e.target.checked })
    });
    loadDashboard();
});

document.getElementById('broadcast-btn').addEventListener('click', async (e) => {
    const msg = document.getElementById('broadcast-msg').value;
    if (!msg) return;
    e.target.disabled = true;
    e.target.textContent = 'Отправка...';
    const data = await apiFetch('/admin/broadcast', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: msg })
    });
    document.getElementById('broadcast-status').textContent = data.success ? 'Успешно!' : 'Ошибка';
    setTimeout(() => { document.getElementById('broadcast-status').textContent = ''; e.target.disabled = false; e.target.textContent = 'Отправить рассылку'; }, 2000);
});

// --- USERS ---
async function loadUsers() {
    try {
        const data = await apiFetch('/admin/users');
        allUsersData = data.users;
        renderUsersTable();
    } catch(e) {}
}

document.getElementById('user-search').addEventListener('input', renderUsersTable);

function renderUsersTable() {
    const tbody = document.getElementById('users-tbody');
    const query = document.getElementById('user-search').value.toLowerCase();
    tbody.innerHTML = '';
    
    Object.keys(allUsersData).forEach(id => {
        if (id === '_SYSTEM_') return;
        const u = allUsersData[id];
        if (query && !id.includes(query) && !(u.name && u.name.toLowerCase().includes(query))) return;
        
        const tr = document.createElement('tr');
        const statusHtml = u.banned ? '<span class="status-badge status-banned">Забанен</span>' : '<span class="status-badge status-active">Активен</span>';
        
        const lockedHtml = u.balance_locked ? `<br><small style="color:#fbbf24">(+${u.balance_locked} в холде)</small>` : '';
        
        tr.innerHTML = `
            <td>${id}</td>
            <td>${u.name || 'User'}</td>
            <td>${u.balance_real || 0} <small style="color:rgba(255,255,255,0.5)">(${((u.balance_real || 0)/1000).toFixed(2)} GRAM)</small>${lockedHtml}</td>
            <td>${u.balance_bonus || 0}</td>
            <td>${u.stats?.gamesPlayed || 0}</td>
            <td>${statusHtml}</td>
            <td class="action-btns">
                <button class="btn-success" onclick="editUser('${id}')">Изменить</button>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

function editUser(id) {
    currentEditingUserId = id;
    const u = allUsersData[id];
    document.getElementById('modal-real').value = u.balance_real || 0;
    document.getElementById('modal-bonus').value = u.balance_bonus || 0;
    document.getElementById('modal-banned').checked = !!u.banned;
    document.getElementById('user-modal').classList.remove('hidden');
}

document.getElementById('modal-close').addEventListener('click', () => {
    document.getElementById('user-modal').classList.add('hidden');
});

document.getElementById('modal-save').addEventListener('click', async () => {
    if (!currentEditingUserId) return;
    const body = {
        balance_real: document.getElementById('modal-real').value,
        balance_bonus: document.getElementById('modal-bonus').value,
        banned: document.getElementById('modal-banned').checked
    };
    await apiFetch('/admin/users/' + currentEditingUserId, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
    });
    document.getElementById('user-modal').classList.add('hidden');
    loadUsers();
});

// --- WITHDRAWALS ---
async function loadWithdrawals() {
    try {
        const data = await apiFetch('/admin/withdrawals');
        const tbody = document.getElementById('withdrawals-tbody');
        tbody.innerHTML = '';
        const items = Object.keys(data.withdrawals || {}).map(k => ({id:k, ...data.withdrawals[k]})).sort((a,b)=>b.timestamp-a.timestamp);
        
        items.forEach(w => {
            let statusHtml = '';
            let btns = '';
            if (w.status === 'pending') {
                statusHtml = '<span class="status-badge status-pending">Ожидает</span>';
                btns = `
                    <button class="btn-success" onclick="processWithdrawal('${w.id}', 'approved')">Одобрить</button>
                    <button class="btn-danger" onclick="processWithdrawal('${w.id}', 'rejected')">Отклонить</button>
                `;
            } else if (w.status === 'approved') {
                statusHtml = '<span class="status-badge status-active">Выплачено</span>';
            } else {
                statusHtml = '<span class="status-badge status-banned">Отклонено</span>';
            }
            
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td>${new Date(w.timestamp).toLocaleString()}</td>
                <td>${w.username} (${w.userId})</td>
                <td><b>${w.amount}</b> <small style="color:rgba(255,255,255,0.5)">(${ (w.amount/1000).toFixed(2) } GRAM)</small></td>
                <td><small>${w.wallet}</small></td>
                <td>${statusHtml}</td>
                <td class="action-btns">${btns}</td>
            `;
            tbody.appendChild(tr);
        });
    } catch(e) {}
}

window.processWithdrawal = async function(id, status) {
    if (!confirm(status === 'approved' ? 'Пометить как выплаченную?' : 'Отклонить заявку и вернуть монеты игроку?')) return;
    await apiFetch('/admin/withdrawals/' + id, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status })
    });
    loadWithdrawals();
}

// --- DEPOSITS ---
async function loadDeposits() {
    try {
        const data = await apiFetch('/admin/deposits');
        const tbody = document.getElementById('deposits-tbody');
        tbody.innerHTML = '';
        data.deposits.forEach(d => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td>${new Date(d.time).toLocaleString()}</td>
                <td>${d.username} (${d.tgId})</td>
                <td><b style="color:#10b981">+${d.amount}</b> <small style="color:rgba(255,255,255,0.5)">(${ (d.amount/1000).toFixed(2) } GRAM)</small></td>
                <td>${d.valueNano}</td>
            `;
            tbody.appendChild(tr);
        });
    } catch(e) {}
}

// --- SETTINGS ---
async function loadSettings() {
    try {
        const data = await apiFetch('/admin/settings');
        document.getElementById('set-daily').value = data.settings.dailyBonus;
        document.getElementById('set-ref').value = data.settings.referralBonus;
        document.getElementById('set-com').value = data.settings.commissionPercent;
    } catch(e) {}
}

document.getElementById('save-settings-btn').addEventListener('click', async () => {
    const body = {
        dailyBonus: Number(document.getElementById('set-daily').value),
        referralBonus: Number(document.getElementById('set-ref').value),
        commissionPercent: Number(document.getElementById('set-com').value)
    };
    await apiFetch('/admin/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
    });
    const st = document.getElementById('settings-status');
    st.textContent = 'Настройки сохранены!';
    st.style.color = '#10b981';
    setTimeout(() => st.textContent='', 2000);
});

// --- LOGS ---
async function loadLogs() {
    try {
        const data = await apiFetch('/admin/events');
        const list = document.getElementById('logs-list');
        list.innerHTML = '';
        data.events.forEach(e => {
            const li = document.createElement('li');
            li.innerHTML = `
                <div class="log-time">${new Date(e.time).toLocaleString()}</div>
                <div class="log-type ${e.type}">${e.type}</div>
                <div class="log-msg">${e.message}</div>
            `;
            list.appendChild(li);
        });
    } catch(e) {}
}

// --- BOTS ---
async function loadBots() {
    try {
        const data = await apiFetch('/admin/bots');
        
        const bToggle = document.getElementById('bots-toggle');
        const bText = document.getElementById('bots-status-text');
        if (bToggle.checked !== data.botsEnabled) bToggle.checked = data.botsEnabled;
        bText.textContent = data.botsEnabled ? 'Боты включены' : 'Боты выключены';
        bText.style.color = data.botsEnabled ? '#10b981' : '#fff';
        
        const tbody = document.getElementById('bots-tbody');
        tbody.innerHTML = '';
        data.bots.forEach(b => {
            const tr = document.createElement('tr');
            
            let statusHtml = '';
            if (b.state === 'WAITING' || b.state === 'SEARCHING') statusHtml = '<span style="color:#fbbf24">Ожидает/Ищет</span>';
            else if (b.state === 'IN_ROOM' || b.state === 'BETTING') statusHtml = '<span style="color:#10b981">В Игре (Ставит)</span>';
            else if (b.state === 'WATCHING_ROULETTE' || b.state === 'WAITING_FOR_ROULETTE') statusHtml = '<span style="color:#3b82f6">Смотрит рулетку</span>';
            else if (b.state === 'WAITING_FOR_PLAYER') statusHtml = '<span style="color:#a855f7">Ждет Игрока</span>';
            else statusHtml = `<span style="color:#ef4444">${b.state}</span>`;
            
            tr.innerHTML = `
                <td>${b.id}</td>
                <td><b>${b.name}</b></td>
                <td>
                    <label class="switch" style="transform: scale(0.7); margin: 0;">
                        <input type="checkbox" class="bot-indiv-toggle" data-id="${b.id}" ${b.enabled ? 'checked' : ''}>
                        <span class="slider"></span>
                    </label>
                </td>
                <td>${b.currentRoom ? b.currentRoom : '-'}</td>
                <td>${statusHtml}</td>
                <td>${b.boughtCells} / ${b.targetCells}</td>
                <td style="color:#10b981">+${b.totalWonReal || 0}</td>
                <td style="color:#f59e0b">+${b.totalWonBonus || 0}</td>
            `;
            tbody.appendChild(tr);
        });

        document.querySelectorAll('.bot-indiv-toggle').forEach(el => {
            el.addEventListener('change', async (e) => {
                const botId = e.target.dataset.id;
                await apiFetch(`/admin/bots/${botId}/toggle`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ enabled: e.target.checked })
                });
                loadBots();
            });
        });
    } catch(e) {}
}

document.getElementById('bots-toggle').addEventListener('change', async (e) => {
    await apiFetch('/admin/bots/toggle', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ enabled: e.target.checked })
    });
    loadBots();
});
