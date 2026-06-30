const { Telegraf } = require('telegraf');
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const token = '7675654779:AAGiBuHXrNzX_VFnd6n1MGig1o1N2w8O3tg'; 
const webAppUrl = 'https://grid-lottery-game.web.app/?v=2'; 

const bot = new Telegraf(token);
const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

// Прокси для аватарок (чтобы обойти блокировку CORS в браузере)
app.get('/avatar', async (req, res) => {
    const url = req.query.url;
    if (!url) return res.status(400).send('No url');
    try {
        const response = await fetch(url);
        const buffer = await response.arrayBuffer();
        res.set('Content-Type', response.headers.get('content-type'));
        res.set('Access-Control-Allow-Origin', '*');
        res.set('Cache-Control', 'public, max-age=86400'); // кэшируем на сутки
        res.send(Buffer.from(buffer));
    } catch (e) {
        res.status(500).send('Error fetching avatar');
    }
});

bot.start((ctx) => {
    const userId = ctx.from.id;
    ctx.setChatMenuButton({ type: 'web_app', text: 'Играть 🎲', web_app: { url: webAppUrl } }).catch(e => console.log(e));
    ctx.reply('Добро пожаловать в Grid Lottery! 🎲\n\nПриглашай друзей и получай 500 монет за каждого!\nТвоя ссылка:\nhttps://t.me/GridLotteryBot/app?startapp=ref_' + userId + '\n\nНажми кнопку ниже, чтобы зайти в комнату:', {
        reply_markup: {
            inline_keyboard: [
                [{ text: '🕹 Открыть игру', web_app: { url: webAppUrl } }]
            ]
        }
    });
});
bot.launch();

const BETTING_TIME = 60; 
const ROULETTE_TIME = 8; 
const REWARD_TIME = 5;   

let users = {}; 
const DB_URL_USERS = 'https://grid-lottery-game-default-rtdb.firebaseio.com/users.json';
const DB_URL_BALANCES = 'https://grid-lottery-game-default-rtdb.firebaseio.com/balances.json';
const DB_URL_WITHDRAWALS = 'https://grid-lottery-game-default-rtdb.firebaseio.com/withdrawals.json';

function createUserObject(balance = 50) {
    return {
        balance_real: 0,
        balance_bonus: balance,
        stats: { gamesPlayed: 0, wins: 0, totalWon: 0, totalSpent: 0 },
        lastBonusClaim: 0,
        referredBy: null,
        referralsCount: 0,
        hasDeposited: false,
        name: 'User',
        photo_url: ''
    };
}

fetch(DB_URL_USERS)
    .then(res => res.json())
    .then(data => {
        if (data) {
            users = data;
            
            let migrated = false;
            for (let id in users) {
                if (users[id].balance !== undefined) {
                    users[id].balance_bonus = (users[id].balance_bonus || 0) + users[id].balance;
                    users[id].balance_real = users[id].balance_real || 0;
                    delete users[id].balance;
                    migrated = true;
                }
                if (users[id].hasDeposited === undefined) {
                    users[id].hasDeposited = false;
                    migrated = true;
                }
            }
            if (migrated) saveUsers();
            
            console.log('Пользователи загружены.');
        } else {
            fetch(DB_URL_BALANCES).then(r => r.json()).then(oldBalances => {
                if (oldBalances) {
                    for (let id in oldBalances) {
                        users[id] = createUserObject(oldBalances[id]);
                    }
                    saveUsers();
                    console.log('Миграция старых балансов завершена.');
                }
            });
        }
    })
    .catch(err => console.error('Ошибка загрузки базы данных:', err));

function saveUsers() {
    fetch(DB_URL_USERS, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(users)
    }).catch(err => console.error('Ошибка сохранения БД:', err));
}

function getColorForId(id) {
    const colors = ['0xFFF43F5E', '0xFF8B5CF6', '0xFFD946EF', '0xFF0EA5E9', '0xFF10B981', '0xFFF59E0B', '0xFFEC4899', '0xFF6366F1'];
    let hash = 0;
    let str = String(id);
    for (let i = 0; i < str.length; i++) hash = str.charCodeAt(i) + ((hash << 5) - hash);
    return colors[Math.abs(hash) % colors.length];
}

function validateInitData(initData, token) {
    if (!initData) return false;
    const urlParams = new URLSearchParams(initData);
    const hash = urlParams.get('hash');
    if (!hash) return false;
    
    urlParams.delete('hash');
    const params = Array.from(urlParams.entries());
    params.sort((a, b) => a[0].localeCompare(b[0]));
    const dataCheckString = params.map(([k, v]) => `${k}=${v}`).join('\n');
    
    const secretKey = crypto.createHmac('sha256', 'WebAppData').update(token).digest();
    const calculatedHash = crypto.createHmac('sha256', secretKey).update(dataCheckString).digest('hex');
    
    return calculatedHash === hash;
}

// --- Игровые комнаты ---
const rooms = [
    { id: 'room_5', name: 'Песочница', cellPrice: 5, maxPlayers: 7, players: new Set(), playersData: new Map(), gameState: Array(100).fill(null), gamePhase: 'WAITING', timeLeft: BETTING_TIME, bank: 0, winnerHistory: [], rouletteInterval: null },
    { id: 'room_10', name: 'Любитель', cellPrice: 10, maxPlayers: 7, players: new Set(), playersData: new Map(), gameState: Array(100).fill(null), gamePhase: 'WAITING', timeLeft: BETTING_TIME, bank: 0, winnerHistory: [], rouletteInterval: null },
    { id: 'room_25', name: 'Профи', cellPrice: 25, maxPlayers: 7, players: new Set(), playersData: new Map(), gameState: Array(100).fill(null), gamePhase: 'WAITING', timeLeft: BETTING_TIME, bank: 0, winnerHistory: [], rouletteInterval: null },
    { id: 'room_50', name: 'Элита', cellPrice: 50, maxPlayers: 7, players: new Set(), playersData: new Map(), gameState: Array(100).fill(null), gamePhase: 'WAITING', timeLeft: BETTING_TIME, bank: 0, winnerHistory: [], rouletteInterval: null },
];

function getRoom(id) {
    return rooms.find(r => r.id === id);
}

function resetRoom(room) {
    room.gameState = Array(100).fill(null);
    room.gamePhase = 'WAITING';
    room.timeLeft = BETTING_TIME;
    room.bank = 0;
    io.to(room.id).emit('init_state', room.gameState);
    
    if (room.players.size >= 2) {
        room.gamePhase = 'BETTING';
    }
    
    io.to(room.id).emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank, cellPrice: room.cellPrice });
}

function startRoulette(room) {
    const purchasedCells = [];
    room.gameState.forEach((cell, index) => {
        if (cell !== null) purchasedCells.push(index);
    });

    if (purchasedCells.length === 0) {
        resetRoom(room);
        return;
    }

    room.gamePhase = 'ROULETTE';
    room.timeLeft = ROULETTE_TIME;
    io.to(room.id).emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank });
    
    let jumps = 0;
    const maxJumps = (ROULETTE_TIME * 1000) / 150; 
    let currentCell = crypto.randomInt(0, 100);
    
    // Выбираем финального победителя заранее
    const winningIndex = purchasedCells[crypto.randomInt(0, purchasedCells.length)];

    room.rouletteInterval = setInterval(() => {
        currentCell = purchasedCells[crypto.randomInt(0, purchasedCells.length)]; // Прыгаем только по купленным
        io.to(room.id).emit('roulette_tick', currentCell);
        
        jumps++;
        if (jumps >= maxJumps) {
            clearInterval(room.rouletteInterval);
            finishRoulette(room, winningIndex);
        }
    }, 150);
}

function finishRoulette(room, winningIndex) {
    room.gamePhase = 'REWARD';
    room.timeLeft = REWARD_TIME;
    io.to(room.id).emit('roulette_finish', winningIndex);
    
    let rewardData = {
        hasWinner: false,
        cell: winningIndex + 1
    };
    
    const winnerData = room.gameState[winningIndex];
    
    if (winnerData) {
        let commission = Math.floor(room.bank * 0.1);
        let winAmount = room.bank - commission;

        if (!users['_SYSTEM_']) users['_SYSTEM_'] = { balance_real: 0, balance_bonus: 0, stats: { totalWon: 0 } };
        users['_SYSTEM_'].balance_real += commission;
        users['_SYSTEM_'].stats.totalWon += commission;

        rewardData = {
            hasWinner: true,
            username: winnerData.username,
            bank: winAmount,
            cell: winningIndex + 1
        };
        if (users[winnerData.telegram_id]) {
            users[winnerData.telegram_id].balance_real += winAmount;
            users[winnerData.telegram_id].stats.wins++;
            users[winnerData.telegram_id].stats.totalWon += winAmount;
        } else {
            users[winnerData.telegram_id] = createUserObject(50);
            users[winnerData.telegram_id].balance_real += winAmount;
            users[winnerData.telegram_id].stats.wins++;
            users[winnerData.telegram_id].stats.totalWon += winAmount;
        }
        saveUsers();
        io.emit('users_update', users);

        room.winnerHistory.unshift({
            username: winnerData.username,
            first_name: winnerData.first_name,
            photo_url: winnerData.photo_url,
            bank: winAmount,
            cell: winningIndex + 1,
            color: winnerData.color
        });
        if (room.winnerHistory.length > 10) room.winnerHistory.pop();
        io.to(room.id).emit('history_update', room.winnerHistory);
    } else {
        // Никто не выиграл - деньги уходят проекту
        if (room.bank > 0) {
            if (!users['_SYSTEM_']) users['_SYSTEM_'] = { balance_real: 0, balance_bonus: 0, stats: { totalWon: 0 } };
            users['_SYSTEM_'].balance_real += room.bank;
            users['_SYSTEM_'].stats.totalWon += room.bank;
            saveUsers();
        }
    }
    
    io.to(room.id).emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank, rewardData: rewardData });

    setTimeout(() => {
        resetRoom(room);
    }, REWARD_TIME * 1000);
}

// Глобальный цикл обновления комнат
setInterval(() => {
    rooms.forEach(room => {
        if (room.gamePhase === 'BETTING') {
            room.timeLeft--;
            io.to(room.id).emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank });
            if (room.timeLeft <= 0) {
                startRoulette(room);
            }
        } else if (room.gamePhase === 'ROULETTE') {
            room.timeLeft--;
            if (room.timeLeft < 0) room.timeLeft = 0;
            io.to(room.id).emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank });
        }
    });
}, 1000);

function broadcastRoomsUpdate() {
    const roomsInfo = rooms.map(r => ({
        id: r.id,
        name: r.name,
        cellPrice: r.cellPrice,
        maxPlayers: r.maxPlayers,
        playersCount: r.players.size
    }));
    io.emit('rooms_list', roomsInfo);
}

io.on('connection', (socket) => {
    console.log(`Игрок подключился. Socket ID: ${socket.id}`);

    // Отправляем список комнат при подключении
    socket.emit('rooms_list', rooms.map(r => ({
        id: r.id,
        name: r.name,
        cellPrice: r.cellPrice,
        maxPlayers: r.maxPlayers,
        playersCount: r.players.size
    })));

    socket.on('auth', (userData, callback) => {
        if (!userData || !userData.initData) {
            if (callback) callback({ success: false, message: 'Доступ только через Telegram' });
            return;
        }
        
        const isValid = validateInitData(userData.initData, token);
        if (!isValid) {
            if (callback) callback({ success: false, message: 'Ошибка подписи Telegram' });
            return;
        }

        let authUser = null;
        let tgId = userData.telegram_id;
        try {
            const parsedData = new URLSearchParams(userData.initData);
            authUser = JSON.parse(parsedData.get('user'));
            tgId = authUser.id.toString();
        } catch (e) {
            // fallback
        }

        socket.userData = {
            telegram_id: tgId,
            username: userData.username || 'User',
            first_name: authUser ? authUser.first_name : '',
            photo_url: authUser ? authUser.photo_url : '',
            color: userData.color || '#FFFFFF',
            initData: userData.initData
        };

        if (!users[tgId]) {
            users[tgId] = createUserObject(50);
            saveUsers();
        }

        socket.emit('users_update', users);
        if (callback) callback({ success: true });
    });

    socket.on('join_room', (data, callback) => {
        const { roomId, userData } = data;
        const room = getRoom(roomId);
        
        if (!room) {
            if (callback) callback({ success: false, message: 'Комната не найдена' });
            return;
        }
        
        if (room.players.size >= room.maxPlayers) {
            if (callback) callback({ success: false, message: 'Комната заполнена' });
            return;
        }

        // ВАЛИДАЦИЯ ТЕЛЕГРАМ
        if (!userData || !userData.initData) {
            if (callback) callback({ success: false, message: 'Доступ только через Telegram' });
            return;
        }
        
        const isValid = validateInitData(userData.initData, token);
        if (!isValid) {
            if (callback) callback({ success: false, message: 'Ошибка подписи Telegram (Взлом)' });
            return;
        }

        let authUser = null;
        let tgId = socket.id;

        try {
            const urlParams = new URLSearchParams(userData.initData);
            const userStr = urlParams.get('user');
            if (userStr) {
                authUser = JSON.parse(userStr);
                tgId = authUser.id.toString();
            }
        } catch (e) {
            console.error('Ошибка парсинга юзера', e);
        }

        // Если подпись валидна, берем реальные данные, игнорируя то, что прислал клиент напрямую
        socket.userData = {
            telegram_id: tgId,
            username: authUser ? (authUser.username || authUser.first_name) : (userData.username || 'User'),
            first_name: authUser ? authUser.first_name : (userData.first_name || 'User'),
            photo_url: authUser ? authUser.photo_url : (userData.photo_url || ''),
            color: getColorForId(tgId)
        };
        
        socket.roomId = roomId;

        if (users[tgId] === undefined) {
            users[tgId] = createUserObject(50);
            
            // Проверка рефералов
            if (userData.initData) {
                const urlParams = new URLSearchParams(userData.initData);
                const startParam = urlParams.get('start_param');
                if (startParam && startParam.startsWith('ref_')) {
                    const referrerId = startParam.split('_')[1];
                    if (users[referrerId] && referrerId !== tgId) {
                        users[tgId].referredBy = referrerId;
                        users[referrerId].balance_bonus += 50;
                        users[referrerId].referralsCount++;
                    }
                }
            }
        }
        
        // Обновляем публичные данные
        users[tgId].name = socket.userData.username;
        users[tgId].photo_url = socket.userData.photo_url;
        saveUsers();

        room.players.add(socket.id);
        room.playersData.set(socket.id, socket.userData);
        socket.join(roomId);

        // Если было ОЖИДАНИЕ и стало >= 2 игроков, запускаем таймер
        if (room.gamePhase === 'WAITING' && room.players.size >= 2) {
            room.gamePhase = 'BETTING';
            room.timeLeft = BETTING_TIME;
        }

        socket.emit('init_state', room.gameState);
        socket.emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank, cellPrice: room.cellPrice });
        socket.emit('history_update', room.winnerHistory);
        io.emit('users_update', users);
        
        broadcastRoomsUpdate();
        
        // Оповещаем остальных в комнате об обновлении фазы (если она сменилась)
        io.to(roomId).emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank });
        io.to(roomId).emit('room_players', Array.from(room.playersData.values()));
        
        if (callback) callback({ success: true });
    });

    socket.on('leave_room', () => {
        handleLeaveRoom(socket);
    });

    socket.on('click_cell', (index) => {
        const room = getRoom(socket.roomId);
        if (!room) return;
        if (room.gamePhase !== 'BETTING') return;
        if (typeof index !== 'number' || index < 0 || index >= 100) return;
        if (room.gameState[index] !== null) {
            socket.emit('error', 'Ячейка уже занята');
            return; 
        }

        const tgId = socket.userData.telegram_id;
        let userRecord = users[tgId];
        if (!userRecord) return;
        
        let price = room.cellPrice;
        let bonus = userRecord.balance_bonus || 0;
        let real = userRecord.balance_real || 0;

        if (bonus + real >= price) {
            if (bonus >= price) {
                userRecord.balance_bonus -= price;
            } else {
                let remainder = price - bonus;
                userRecord.balance_bonus = 0;
                userRecord.balance_real -= remainder;
            }
            
            userRecord.stats.totalSpent += price;
            userRecord.stats.gamesPlayed++;
            room.bank += price;           
            saveUsers();
            
            room.gameState[index] = {
                username: socket.userData.username,
                telegram_id: tgId,
                color: socket.userData.color,
                first_name: socket.userData.first_name,
                photo_url: socket.userData.photo_url
            };
            
            io.to(room.id).emit('update_state', room.gameState);
            io.emit('users_update', users);
            io.to(room.id).emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank, cellPrice: room.cellPrice }); 
        } else {
            socket.emit('error', 'Недостаточно средств');
        }
    });

    socket.on('request_withdrawal', (data) => {
        const tgId = socket.userData.telegram_id;
        let userRecord = users[tgId];
        if (!userRecord) return;
        
        const amount = data.amount || 0;
        const wallet = data.wallet || '';
        
        if (amount < 500) {
            socket.emit('withdrawal_error', 'Минимальная сумма вывода - 500 монет');
            return;
        }
        
        if (!userRecord.hasDeposited) {
            socket.emit('withdrawal_error', 'Для вывода средств необходим хотя бы один депозит (пополнение)');
            return;
        }
        
        if ((userRecord.balance_real || 0) < amount) {
            socket.emit('withdrawal_error', 'Недостаточно реальных монет для вывода');
            return;
        }
        
        userRecord.balance_real -= amount;
        saveUsers();
        io.emit('users_update', users);
        
        const withdrawId = `wd_${Date.now()}_${tgId}`;
        const withdrawData = {
            userId: tgId,
            username: userRecord.name,
            amount: amount,
            wallet: wallet,
            status: 'pending',
            timestamp: Date.now()
        };
        
        fetch(`${DB_URL_WITHDRAWALS.replace('.json', '')}/${withdrawId}.json`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(withdrawData)
        }).then(() => {
            socket.emit('withdrawal_success', 'Заявка на вывод успешно создана');
        }).catch(err => {
            console.error('Ошибка создания вывода', err);
            socket.emit('withdrawal_error', 'Ошибка сервера при создании заявки');
        });
    });

    socket.on('disconnect', () => {
        handleLeaveRoom(socket);
        console.log(`Игрок отключился: ${socket.id}`);
    });

    socket.on('send_emoji', (emoji) => {
        if (!socket.roomId || !emoji) return;
        io.to(socket.roomId).emit('emoji_message', {
            telegram_id: socket.userData.telegram_id,
            username: socket.userData.username,
            photo_url: socket.userData.photo_url,
            color: socket.userData.color,
            emoji: emoji
        });
    });

    function handleLeaveRoom(socket) {
        if (socket.roomId) {
            const room = getRoom(socket.roomId);
            if (room) {
                room.players.delete(socket.id);
                room.playersData.delete(socket.id);
                socket.leave(socket.roomId);
                
                // Если игроков стало меньше 2 и ставок еще нет, отменяем обратный отсчет
                if (room.gamePhase === 'BETTING' && room.players.size < 2 && room.bank === 0) {
                    room.gamePhase = 'WAITING';
                    room.timeLeft = BETTING_TIME;
                    io.to(room.id).emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank });
                }
                
                io.to(room.id).emit('room_players', Array.from(room.playersData.values()));
                broadcastRoomsUpdate();
            }
            socket.roomId = null;
        }
    }
});


// ==========================================
// ИНТЕГРАЦИЯ TON (ПОПОЛНЕНИЯ)
// ==========================================
const PROJECT_WALLET = 'UQBxu51QZAAzUfi1WJLSS6SOYuEDu9W18Bsjw4ZfCMtF_TUh'; // ЗАМЕНИТЕ НА СВОЙ КОШЕЛЕК
const TRANSACTIONS_FILE = path.join(__dirname, 'transactions.json');
let processedTransactions = new Set();

if (fs.existsSync(TRANSACTIONS_FILE)) {
    try {
        const data = fs.readFileSync(TRANSACTIONS_FILE, 'utf8');
        processedTransactions = new Set(JSON.parse(data));
    } catch (err) {
        console.error('Ошибка чтения transactions.json', err);
    }
}

function saveTransactions() {
    fs.writeFileSync(TRANSACTIONS_FILE, JSON.stringify(Array.from(processedTransactions)), 'utf8');
}

async function checkTonTransactions() {
    if (PROJECT_WALLET.includes('XXXXX')) return; // Отключено, пока нет реального кошелька
    
    try {
        const response = await fetch(`https://toncenter.com/api/v2/getTransactions?address=${PROJECT_WALLET}&limit=10`);
        const data = await response.json();
        
        if (data.ok && data.result) {
            let updated = false;
            for (const tx of data.result) {
                const hash = tx.transaction_id.hash;
                if (processedTransactions.has(hash)) continue;
                
                processedTransactions.add(hash);
                updated = true;
                
                const inMsg = tx.in_msg;
                if (inMsg && inMsg.value && inMsg.message) {
                    const value = Number(inMsg.value);
                    const msg = inMsg.message.trim();
                    
                    if (msg.startsWith('deposit_')) {
                        const tgId = msg.split('_')[1];
                        
                        // Курс: 1 Gram (1 000 000 000 nano) = 1000 игровых монет
                        // Следовательно: 1000 монет / 1 000 000 000 = 0.000001
                        // amountInCoins = value (в нано-граммах) / 1,000,000
                        const amountInCoins = Math.floor(value / 1000000); 
                        
                        if (amountInCoins > 0) {
                            if (!users[tgId]) {
                                users[tgId] = createUserObject(50);
                            }
                            users[tgId].balance_real += amountInCoins;
                            users[tgId].hasDeposited = true;
                            console.log(`Успешное пополнение: Игрок ${tgId} получил ${amountInCoins} монет за ${value} nanoGram.`);
                            saveUsers();
                            io.emit('users_update', users); // Обновляем балансы у всех (включая самого игрока)
                        }
                    }
                }
            }
            if (updated) {
                saveTransactions();
            }
        }
    } catch (e) {
        console.error('Ошибка проверки транзакций TON:', e.message);
    }
}

setInterval(checkTonTransactions, 15000); // Проверяем каждые 15 секунд
// ==========================================

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Сервер запущен на порту ${PORT}.`);
});

process.once('SIGINT', () => bot.stop('SIGINT'));
process.once('SIGTERM', () => bot.stop('SIGTERM'));