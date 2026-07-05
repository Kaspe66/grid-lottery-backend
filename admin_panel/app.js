const loginContainer = document.getElementById('login-container');
const dashboardContainer = document.getElementById('dashboard-container');
const passwordInput = document.getElementById('admin-password');
const loginBtn = document.getElementById('login-btn');
const logoutBtn = document.getElementById('logout-btn');
const loginError = document.getElementById('login-error');

const statOnline = document.getElementById('stat-online');
const statTotal = document.getElementById('stat-total');
const statReal = document.getElementById('stat-real');
const statBonus = document.getElementById('stat-bonus');

const broadcastMsg = document.getElementById('broadcast-msg');
const broadcastBtn = document.getElementById('broadcast-btn');
const broadcastStatus = document.getElementById('broadcast-status');

const maintenanceToggle = document.getElementById('maintenance-toggle');
const maintenanceText = document.getElementById('maintenance-status-text');

let adminToken = localStorage.getItem('adminToken');
let refreshInterval = null;

// Initialization
if (adminToken) {
    showDashboard();
}

loginBtn.addEventListener('click', async () => {
    const pwd = passwordInput.value;
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
            showDashboard();
        } else {
            loginError.textContent = data.message || 'Ошибка входа';
        }
    } catch (e) {
        loginError.textContent = 'Ошибка сети';
    }
});

logoutBtn.addEventListener('click', () => {
    localStorage.removeItem('adminToken');
    adminToken = null;
    if (refreshInterval) clearInterval(refreshInterval);
    loginContainer.classList.remove('hidden');
    dashboardContainer.classList.add('hidden');
    passwordInput.value = '';
    loginError.textContent = '';
});

function showDashboard() {
    loginContainer.classList.add('hidden');
    dashboardContainer.classList.remove('hidden');
    fetchStats();
    if (refreshInterval) clearInterval(refreshInterval);
    refreshInterval = setInterval(fetchStats, 5000);
}

async function fetchStats() {
    try {
        const res = await fetch('/admin/stats', {
            headers: { 'Authorization': 'Bearer ' + adminToken }
        });
        
        if (res.status === 401) {
            logoutBtn.click();
            return;
        }
        
        const data = await res.json();
        if (data.success) {
            statOnline.textContent = data.online;
            statTotal.textContent = data.totalUsers;
            statReal.textContent = data.systemReal;
            statBonus.textContent = data.systemBonus;
            
            maintenanceToggle.checked = data.maintenance;
            updateMaintenanceText(data.maintenance);
        }
    } catch (e) {
        console.error('Ошибка загрузки статистики:', e);
    }
}

function updateMaintenanceText(isOn) {
    if (isOn) {
        maintenanceText.textContent = 'Режим включен';
        maintenanceText.style.color = '#ef4444';
    } else {
        maintenanceText.textContent = 'Режим выключен';
        maintenanceText.style.color = '#fff';
    }
}

maintenanceToggle.addEventListener('change', async (e) => {
    const isActive = e.target.checked;
    updateMaintenanceText(isActive);
    
    try {
        await fetch('/admin/maintenance', {
            method: 'POST',
            headers: { 
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + adminToken
            },
            body: JSON.stringify({ active: isActive })
        });
    } catch (e) {
        console.error('Ошибка переключения режима', e);
    }
});

broadcastBtn.addEventListener('click', async () => {
    const msg = broadcastMsg.value.trim();
    if (!msg) {
        broadcastStatus.textContent = 'Сообщение не может быть пустым';
        broadcastStatus.style.color = '#ef4444';
        return;
    }
    
    broadcastBtn.disabled = true;
    broadcastBtn.textContent = 'Отправка...';
    
    try {
        const res = await fetch('/admin/broadcast', {
            method: 'POST',
            headers: { 
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + adminToken
            },
            body: JSON.stringify({ message: msg })
        });
        const data = await res.json();
        
        if (data.success) {
            broadcastStatus.textContent = 'Рассылка успешно запущена!';
            broadcastStatus.style.color = '#10b981';
            broadcastMsg.value = '';
            setTimeout(() => { broadcastStatus.textContent = ''; }, 3000);
        } else {
            broadcastStatus.textContent = data.message || 'Ошибка рассылки';
            broadcastStatus.style.color = '#ef4444';
        }
    } catch (e) {
        broadcastStatus.textContent = 'Ошибка сети при рассылке';
        broadcastStatus.style.color = '#ef4444';
    } finally {
        broadcastBtn.disabled = false;
        broadcastBtn.textContent = 'Отправить рассылку';
    }
});
