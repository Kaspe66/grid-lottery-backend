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
    if (activeTab === 'leaders') loadLeaders();
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
        
        const statBotReal = document.getElementById('stat-bot-real');
        const statBotBonus = document.getElementById('stat-bot-bonus');
        if (statBotReal) statBotReal.innerHTML = `${data.botProfitReal || 0} <span style="font-size:1rem;color:rgba(255,255,255,0.5)">(${((data.botProfitReal || 0)/1000).toFixed(2)} GRAM)</span>`;
        if (statBotBonus) statBotBonus.textContent = data.botProfitBonus || 0;
        
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

// --- LEADERS ---
async function loadLeaders() {
    try {
        const data = await apiFetch('/admin/users');
        allUsersData = data.users;
        renderLeadersTable();
    } catch(e) {}
}

document.getElementById('leader-sort')?.addEventListener('change', renderLeadersTable);

function renderLeadersTable() {
    const tbody = document.getElementById('leaders-tbody');
    const sortBy = document.getElementById('leader-sort').value;
    tbody.innerHTML = '';
    
    let usersList = Object.keys(allUsersData)
        .filter(id => id !== '_SYSTEM_')
        .map(id => ({ id, ...allUsersData[id] }));
        
    usersList.sort((a, b) => {
        if (sortBy === 'wonReal') {
            return ((b.stats && b.stats.totalWonReal) || 0) - ((a.stats && a.stats.totalWonReal) || 0);
        } else if (sortBy === 'balanceReal') {
            return (b.balance_real || 0) - (a.balance_real || 0);
        } else if (sortBy === 'games') {
            return ((b.stats && b.stats.gamesPlayed) || 0) - ((a.stats && a.stats.gamesPlayed) || 0);
        }
        return 0;
    });
    
    // Top 50
    usersList.slice(0, 50).forEach((u, index) => {
        const tr = document.createElement('tr');
        const wonReal = u.stats && u.stats.totalWonReal ? u.stats.totalWonReal : 0;
        const games = u.stats && u.stats.gamesPlayed ? u.stats.gamesPlayed : 0;
        
        let placeIcon = index + 1;
        if (index === 0) placeIcon = '🥇';
        if (index === 1) placeIcon = '🥈';
        if (index === 2) placeIcon = '🥉';
        
        tr.innerHTML = `
            <td><strong style="font-size:1.2rem">${placeIcon}</strong></td>
            <td>${u.id}</td>
            <td>${u.name || 'User'}</td>
            <td>${u.balance_real || 0}</td>
            <td>${wonReal}</td>
            <td>${games}</td>
        `;
        tbody.appendChild(tr);
    });
}

window.editUser = async function(id) {
    currentEditingUserId = id;
    const u = allUsersData[id];
    document.getElementById('modal-real').value = u.balance_real || 0;
    document.getElementById('modal-bonus').value = u.balance_bonus || 0;
    document.getElementById('modal-banned').checked = !!u.banned;
    
    document.getElementById('user-details-section').classList.add('hidden');
    document.getElementById('user-finance-tbody').innerHTML = '<tr><td colspan="3" style="text-align:center;">Загрузка...</td></tr>';
    document.getElementById('user-modal').classList.remove('hidden');
    
    try {
        const res = await apiFetch('/admin/users/' + id + '/details');
        if (res.success && res.details) {
            const { stats, deposits, withdrawals } = res.details;
            
            document.getElementById('stat-games').innerText = stats.gamesPlayed || 0;
            document.getElementById('stat-wins').innerText = stats.wins || 0;
            document.getElementById('stat-spent').innerText = Math.floor(stats.totalSpent || 0);
            document.getElementById('stat-won').innerText = Math.floor(stats.totalWon || 0);
            
            let totalDep = 0;
            let totalWd = 0;
            const financeRecords = [];
            
            deposits.forEach(d => {
                totalDep += (d.amount || 0);
                financeRecords.push({ type: 'Пополнение', amount: d.amount, time: d.time, color: '#10b981' });
            });
            
            withdrawals.forEach(w => {
                if (w.status === 'approved') {
                    totalWd += (w.amount || 0);
                }
                financeRecords.push({ type: `Вывод (${w.status})`, amount: w.amount, time: w.timestamp, color: w.status === 'approved' ? '#f59e0b' : (w.status === 'rejected' ? '#ef4444' : '#6b7280') });
            });
            
            document.getElementById('stat-deposits-total').innerText = Math.floor(totalDep);
            document.getElementById('stat-withdrawals-total').innerText = Math.floor(totalWd);
            
            financeRecords.sort((a, b) => b.time - a.time);
            
            const tbody = document.getElementById('user-finance-tbody');
            tbody.innerHTML = '';
            if (financeRecords.length === 0) {
                tbody.innerHTML = '<tr><td colspan="3" style="text-align:center;">Нет транзакций</td></tr>';
            } else {
                financeRecords.forEach(r => {
                    const tr = document.createElement('tr');
                    tr.innerHTML = `
                        <td style="color:${r.color}">${r.type}</td>
                        <td><b>${r.amount}</b></td>
                        <td>${new Date(r.time).toLocaleString()}</td>
                    `;
                    tbody.appendChild(tr);
                });
            }
            document.getElementById('user-details-section').classList.remove('hidden');
        }
    } catch(e) {
        console.error("Failed to load user details", e);
    }
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
                const finalGram = Math.max(0, (w.amount / 1000) - 0.05);
                const amountNano = Math.floor(finalGram * 1000000000);
                const tonLinkWeb = `https://app.tonkeeper.com/transfer/${w.wallet}?amount=${amountNano}`;
                const tonLinkRaw = `ton://transfer/${w.wallet}?amount=${amountNano}`;

                statusHtml = '<span class="status-badge status-pending">Ожидает</span>';
                btns = `
                    <div style="display:flex; gap:5px; margin-bottom:5px;">
                        <a href="${tonLinkWeb}" class="btn-primary" style="text-decoration: none; padding: 5px 10px; font-size: 12px; border-radius: 6px; background-color: #3b82f6; color: white;" target="_blank">🌐 Web (Tonkeeper)</a>
                        <a href="${tonLinkRaw}" class="btn-primary" style="text-decoration: none; padding: 5px 10px; font-size: 12px; border-radius: 6px; background-color: #2481cc; color: white;">⚡ Desktop (Telegram/Wallet)</a>
                    </div>
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
        
        const tReal = document.getElementById('bots-treasury-real');
        const tBonus = document.getElementById('bots-treasury-bonus');
        if (tReal) tReal.textContent = `Real: ${data.systemReal}`;
        if (tBonus) tBonus.textContent = `Bonus: ${data.systemBonus}`;
        
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
