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
app.use(express.json());
app.use('/admin', express.static(path.join(__dirname, 'admin_panel')));
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
    ctx.reply('Добро пожаловать в Grid Lottery! 🎲\n\nУникальная игра, где ты можешь испытать удачу на сетке из 100 ячеек!\nВыбирай ячейки, делай ставки бонусными или реальными монетами, и забирай банк, если рулетка остановится на твоей ячейке.\n\nПриглашай друзей и получай 500 монет за каждого!\nТвоя ссылка:\nhttps://t.me/GridLotteryBot/app?startapp=ref_' + userId + '\n\nНажми кнопку ниже, чтобы зайти в комнату:', {
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

let maintenanceMode = false;
let onlineSockets = new Set();

let users = {}; 
const DB_URL_USERS = 'https://grid-lottery-game-default-rtdb.firebaseio.com/users.json';
const DB_URL_BALANCES = 'https://grid-lottery-game-default-rtdb.firebaseio.com/balances.json';
const DB_URL_WITHDRAWALS = 'https://grid-lottery-game-default-rtdb.firebaseio.com/withdrawals.json';
const DB_URL_SETTINGS = 'https://grid-lottery-game-default-rtdb.firebaseio.com/settings.json';
const DB_URL_DEPOSITS = 'https://grid-lottery-game-default-rtdb.firebaseio.com/deposits.json';

let gameSettings = {
    dailyBonus: 50,
    referralBonus: 500,
    commissionPercent: 10,
    botsEnabled: false
};

fetch(DB_URL_SETTINGS).then(r => r.json()).then(data => {
    if (data) {
        gameSettings = { ...gameSettings, ...data };
    }
}).catch(err => console.error('Ошибка загрузки настроек:', err));

function saveSettings() {
    fetch(DB_URL_SETTINGS, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(gameSettings)
    }).catch(e => {});
}

let liveEvents = [];
function addEvent(type, message) {
    liveEvents.unshift({ type, message, time: Date.now() });
    if (liveEvents.length > 100) liveEvents.pop();
}

let allDeposits = {};
fetch(DB_URL_DEPOSITS).then(r => r.json()).then(data => {
    if (data) allDeposits = data;
}).catch(err => console.error('Ошибка загрузки депозитов:', err));

function saveDeposits() {
    fetch(DB_URL_DEPOSITS, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(allDeposits)
    }).catch(e => {});
}

function createUserObject(balance = 50) {
    return {
        balance_real: 0,
        balance_bonus: balance,
        stats: { gamesPlayed: 0, wins: 0, totalWon: 0, totalWonReal: 0, totalWonBonus: 0, totalSpent: 0 },
        lastBonusClaim: 0,
        referredBy: null,
        referralsCount: 0,
        hasDeposited: false,
        name: 'User',
        photo_url: '',
        banned: false,
        balance_locked: 0
    };
}

fetch(DB_URL_USERS)
    .then(res => res.json())
    .then(data => {
        if (data) {
            users = data;
            
            let migrated = false;
            for (let id in users) {
                if (id === '_SYSTEM_') {
                    users[id] = { commission_balance: (users[id].commission_balance || 0) + (users[id].balance_real || 0) + (users[id].balance_bonus || 0) };
                    migrated = true;
                    continue;
                }
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
const rooms = [];
const prices = [5, 10, 20, 30, 50];
const currencies = ['BONUS', 'REAL'];

currencies.forEach(currency => {
    prices.forEach(price => {
        for (let i = 1; i <= 20; i++) {
            let roomName = currency === 'BONUS' ? `Бонусы ${price} (Комната ${i})` : `Реал ${price} (Комната ${i})`;
            rooms.push({
                id: `room_${currency}_${price}_${i}`,
                name: roomName,
                cellPrice: price,
                currency: currency,
                maxPlayers: 7,
                players: new Set(),
                playersData: new Map(),
                gameState: Array(100).fill(null),
                gamePhase: 'WAITING',
                timeLeft: BETTING_TIME,
                bank: 0,
                bank_real: 0,
                bank_bonus: 0,
                winnerHistory: [],
                rouletteInterval: null
            });
        }
    });
});

function getRoom(id) {
    return rooms.find(r => r.id === id);
}

function resetRoom(room) {
    room.gameState = Array(100).fill(null);
    room.gamePhase = 'WAITING';
    room.timeLeft = BETTING_TIME;
    room.bank = 0;
    room.bank_real = 0;
    room.bank_bonus = 0;
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
    
    // Обновляем статистику сыгранных игр (1 раз за раунд на уникального игрока)
    let playersInRound = new Set();
    room.gameState.forEach(cell => {
        if (cell !== null && !String(cell.telegram_id).startsWith('bot_')) {
            playersInRound.add(cell.telegram_id);
        }
    });
    playersInRound.forEach(tgId => {
        if (users[tgId]) {
            users[tgId].stats.gamesPlayed = (users[tgId].stats.gamesPlayed || 0) + 1;
        }
    });
    
    let rewardData = {
        hasWinner: false,
        cell: winningIndex + 1
    };
    
    const winnerData = room.gameState[winningIndex];
    
    if (winnerData) {
        let realPlayerBetReal = 0;
        let realPlayerBetBonus = 0;
        
        room.gameState.forEach(cell => {
            if (cell !== null && !String(cell.telegram_id).startsWith('bot_')) {
                if (room.currency === 'REAL') realPlayerBetReal += room.cellPrice;
                if (room.currency === 'BONUS') realPlayerBetBonus += room.cellPrice;
            }
        });

        let commissionReal = Math.floor(realPlayerBetReal * (gameSettings.commissionPercent / 100));
        let winAmountReal = (room.bank_real || 0) - commissionReal;

        let commissionBonus = Math.floor(realPlayerBetBonus * (gameSettings.commissionPercent / 100));
        let winAmountBonus = (room.bank_bonus || 0) - commissionBonus;

        let winAmountTotal = winAmountReal + winAmountBonus;

        if (!users['_SYSTEM_']) users['_SYSTEM_'] = { commission_balance: 0, commission_bonus: 0 };
        users['_SYSTEM_'].commission_balance = (users['_SYSTEM_'].commission_balance || 0) + commissionReal;
        users['_SYSTEM_'].commission_bonus = (users['_SYSTEM_'].commission_bonus || 0) + commissionBonus;

        rewardData = {
            hasWinner: true,
            username: winnerData.username,
            bank: winAmountTotal,
            cell: winningIndex + 1
        };
        
        if (winnerData.telegram_id && String(winnerData.telegram_id).startsWith('bot_')) {
            let botRealProfit = realPlayerBetReal - commissionReal;
            let botBonusProfit = realPlayerBetBonus - commissionBonus;
            
            users['_SYSTEM_'].bot_profit_real = (users['_SYSTEM_'].bot_profit_real || 0) + botRealProfit;
            users['_SYSTEM_'].bot_profit_bonus = (users['_SYSTEM_'].bot_profit_bonus || 0) + botBonusProfit;
            
            let bot = BOTS.find(b => b.id === winnerData.telegram_id);
            if (bot) {
                bot.totalWonReal = (bot.totalWonReal || 0) + botRealProfit;
                bot.totalWonBonus = (bot.totalWonBonus || 0) + botBonusProfit;
            }
        } else {
            if (users[winnerData.telegram_id]) {
                users[winnerData.telegram_id].balance_real += winAmountReal;
                users[winnerData.telegram_id].balance_bonus += winAmountBonus;
                users[winnerData.telegram_id].stats.wins++;
                users[winnerData.telegram_id].stats.totalWon += winAmountTotal;
                users[winnerData.telegram_id].stats.totalWonReal = (users[winnerData.telegram_id].stats.totalWonReal || 0) + winAmountReal;
                users[winnerData.telegram_id].stats.totalWonBonus = (users[winnerData.telegram_id].stats.totalWonBonus || 0) + winAmountBonus;
            } else {
                users[winnerData.telegram_id] = createUserObject(50);
                users[winnerData.telegram_id].balance_real += winAmountReal;
                users[winnerData.telegram_id].balance_bonus += winAmountBonus;
                users[winnerData.telegram_id].stats.wins++;
                users[winnerData.telegram_id].stats.totalWon += winAmountTotal;
                users[winnerData.telegram_id].stats.totalWonReal = winAmountReal;
                users[winnerData.telegram_id].stats.totalWonBonus = winAmountBonus;
            }
        }
        
        if (winAmountTotal >= room.cellPrice * 2) {
            addEvent('WIN', `Игрок ${winnerData.username || winnerData.first_name} сорвал куш в ${winAmountTotal} монет в ${room.name}!`);
        }
        
        saveUsers();
        io.emit('users_update', users);

        room.winnerHistory.unshift({
            username: winnerData.username,
            first_name: winnerData.first_name,
            photo_url: winnerData.photo_url,
            bank: winAmountTotal,
            cell: winningIndex + 1,
            color: winnerData.color
        });
        if (room.winnerHistory.length > 10) room.winnerHistory.pop();
        io.to(room.id).emit('history_update', room.winnerHistory);
    } else {
        // Никто не выиграл - деньги уходят проекту
        if (room.bank > 0) {
            if (!users['_SYSTEM_']) users['_SYSTEM_'] = { commission_balance: 0, commission_bonus: 0 };
            users['_SYSTEM_'].commission_balance = (users['_SYSTEM_'].commission_balance || 0) + (room.bank_real || 0);
            users['_SYSTEM_'].commission_bonus = (users['_SYSTEM_'].commission_bonus || 0) + (room.bank_bonus || 0);
            saveUsers();
        }
    }
    
    io.to(room.id).emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank, rewardData: rewardData });

    setTimeout(() => {
        resetRoom(room);
    }, REWARD_TIME * 1000);
}

// --- BOTS LOGIC ---
let BOT_NAMES = [];
try {
    BOT_NAMES = require('./botNames.json');
} catch (e) {
    BOT_NAMES = ['Alina', 'Max', 'CryptoKing', 'LuckyGirl', 'Tony', 'Elena', 'Ivan', 'Sasha', 'Oleg', 'Natasha'];
}

function getRandomBotName() {
    return BOT_NAMES[Math.floor(Math.random() * BOT_NAMES.length)];
}

function getRandomBotColor() {
    const colors = ['0xFFEC4899', '0xFF3B82F6', '0xFFF59E0B', '0xFF10B981', '0xFF8B5CF6', '0xFFEF4444', '0xFF6366F1', '0xFF14B8A6', '0xFFF97316', '0xFF84CC16'];
    return colors[Math.floor(Math.random() * colors.length)];
}

function reassignBotIdentity(bot) {
    bot.name = getRandomBotName();
    bot.color = getRandomBotColor();
}

const BOTS = [];
for (let i = 1; i <= 20; i++) {
    BOTS.push({
        id: 'bot_' + i,
        name: getRandomBotName(),
        color: getRandomBotColor(),
        currentRoom: null,
        targetCells: 0,
        boughtCells: 0,
        nextActionTime: 0,
        totalWonReal: 0,
        totalWonBonus: 0,
        state: 'WAITING',
        enabled: true,
        emptyRoomSince: 0,
        gamesPlayedInRoom: 0,
        hasSeenRealPlayer: false
    });
}

function botLogic() {
    if (!gameSettings.botsEnabled) {
        BOTS.forEach(bot => {
            if (bot.currentRoom) {
                const room = getRoom(bot.currentRoom);
                if (room) {
                    room.players.delete(bot.id);
                    room.playersData.delete(bot.id);
                    io.to(room.id).emit('room_players', Array.from(room.playersData.values()));
                    broadcastRoomsUpdate();
                }
                bot.currentRoom = null;
                bot.state = 'DISABLED';
                bot.emptyRoomSince = 0;
                reassignBotIdentity(bot);
            }
        });
        return;
    }

    const now = Date.now();
    BOTS.forEach(bot => {
        if (!bot.enabled) {
            if (bot.currentRoom) {
                const room = getRoom(bot.currentRoom);
                if (room) {
                    room.players.delete(bot.id);
                    room.playersData.delete(bot.id);
                    io.to(room.id).emit('room_players', Array.from(room.playersData.values()));
                    broadcastRoomsUpdate();
                }
                bot.currentRoom = null;
                bot.state = 'DISABLED';
                bot.emptyRoomSince = 0;
                reassignBotIdentity(bot);
            } else {
                bot.state = 'DISABLED';
            }
            return;
        }

        if (bot.nextActionTime > now) return;

        if (!bot.currentRoom) {
            bot.state = 'SEARCHING';
            const availableRooms = rooms.filter(r => r.currency === 'BONUS' && (r.gamePhase === 'WAITING' || r.gamePhase === 'BETTING'));
            const getRoomNum = (id) => parseInt(id.split('_').pop(), 10) || 0;
            const roomsWithNoBots = availableRooms.filter(r => {
                let botCount = 0;
                r.players.forEach(pid => { if (String(pid).startsWith('bot_')) botCount++; });
                
                // Псевдослучайный лимит ботов для конкретной комнаты от 2 до 4
                let maxBotsForThisRoom = 2 + (r.id.split('').reduce((sum, char) => sum + char.charCodeAt(0), 0) % 3);
                
                return botCount < maxBotsForThisRoom && r.players.size < r.maxPlayers && getRoomNum(r.id) <= 3;
            });

            if (roomsWithNoBots.length > 0) {
                let priorityRooms = roomsWithNoBots.filter(r => r.players.size > 0);
                let targetRooms = priorityRooms.length > 0 ? priorityRooms : roomsWithNoBots;

                const room = targetRooms[Math.floor(Math.random() * targetRooms.length)];
                bot.currentRoom = room.id;
                bot.targetCells = Math.floor(Math.random() * 16) + 5; // 5 to 20
                bot.boughtCells = 0;
                bot.state = 'IN_ROOM';
                bot.emptyRoomSince = 0;
                bot.gamesPlayedInRoom = 0;
                bot.hasSeenRealPlayer = false;
                
                room.players.add(bot.id);
                room.playersData.set(bot.id, {
                    telegram_id: bot.id,
                    username: bot.name,
                    first_name: bot.name,
                    photo_url: '',
                    color: bot.color
                });
                
                if (room.gamePhase === 'WAITING' && room.players.size >= 2) {
                    room.gamePhase = 'BETTING';
                    room.timeLeft = BETTING_TIME;
                    io.to(room.id).emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank, cellPrice: room.cellPrice });
                }
                
                io.to(room.id).emit('room_players', Array.from(room.playersData.values()));
                broadcastRoomsUpdate();
                bot.nextActionTime = now + 2000 + Math.random() * 3000;
            } else {
                bot.nextActionTime = now + 5000;
            }
        } else {
            const room = getRoom(bot.currentRoom);
            if (!room) {
                bot.currentRoom = null;
                bot.state = 'WAITING';
                bot.emptyRoomSince = 0;
                bot.nextActionTime = now + 5000 + Math.random() * 5000;
                return;
            }

            let hasRealPlayer = false;
            room.players.forEach(pid => {
                if (!String(pid).startsWith('bot_')) hasRealPlayer = true;
            });

            if (hasRealPlayer) {
                bot.hasSeenRealPlayer = true;
                bot.emptyRoomSince = 0;
            }

            if (room.gamePhase === 'REWARD') {
                bot.state = 'WATCHING_ROULETTE';
                bot.nextActionTime = now + 2000;
                return;
            }

            // Round reset check (bank is 0, meaning reset just happened)
            if (bot.boughtCells > 0 && room.bank === 0 && (room.gamePhase === 'WAITING' || room.gamePhase === 'BETTING')) {
                bot.gamesPlayedInRoom++;
                bot.boughtCells = 0;
                bot.targetCells = Math.floor(Math.random() * 16) + 5;
                
                let leaveLimit = hasRealPlayer ? 10 : 3;
                if (bot.gamesPlayedInRoom >= leaveLimit) {
                    room.players.delete(bot.id);
                    room.playersData.delete(bot.id);
                    io.to(room.id).emit('room_players', Array.from(room.playersData.values()));
                    broadcastRoomsUpdate();
                    bot.currentRoom = null;
                    bot.state = 'WAITING';
                    bot.emptyRoomSince = 0;
                    bot.gamesPlayedInRoom = 0;
                    reassignBotIdentity(bot);
                    bot.nextActionTime = now + 5000 + Math.random() * 5000;
                    return;
                }
                
                bot.nextActionTime = now + 2000;
                return;
            }

            if (room.gamePhase === 'BETTING') {
                bot.state = 'BETTING';
                
                if (bot.boughtCells < bot.targetCells) {
                    let emptyIndices = [];
                    room.gameState.forEach((cell, idx) => { if (cell === null) emptyIndices.push(idx); });
                    
                    if (emptyIndices.length > 0) {
                        const idx = emptyIndices[Math.floor(Math.random() * emptyIndices.length)];
                        
                        room.bank += room.cellPrice;
                        if (room.currency === 'REAL') room.bank_real = (room.bank_real || 0) + room.cellPrice;
                        if (room.currency === 'BONUS') room.bank_bonus = (room.bank_bonus || 0) + room.cellPrice;
                        
                        room.gameState[idx] = {
                            username: bot.name,
                            telegram_id: bot.id,
                            color: bot.color,
                            first_name: bot.name,
                            photo_url: ''
                        };
                        
                        io.to(room.id).emit('update_state', room.gameState);
                        io.to(room.id).emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank, cellPrice: room.cellPrice }); 
                        bot.boughtCells++;
                        bot.nextActionTime = now + 1000 + Math.random() * 2000;
                    } else {
                        bot.nextActionTime = now + 5000; // Room is full
                    }
                } else {
                    bot.state = 'WAITING_FOR_ROULETTE';
                    bot.nextActionTime = now + 2000;
                }
            } else {
                bot.state = 'WAITING';
                bot.nextActionTime = now + 2000;
            }
        }
    });
}
setInterval(botLogic, 1000);
// --- END BOTS LOGIC ---

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

function isRateLimited(socket) {
    const now = Date.now();
    if (!socket.lastActionTime) socket.lastActionTime = 0;
    if (now - socket.lastActionTime < 300) {
        return true;
    }
    socket.lastActionTime = now;
    return false;
}

function broadcastRoomsUpdate() {
    const roomsInfo = rooms.map(r => ({
        id: r.id,
        name: r.name,
        cellPrice: r.cellPrice,
        currency: r.currency,
        maxPlayers: r.maxPlayers,
        playersCount: r.players.size
    }));
    io.emit('rooms_list', roomsInfo);
}

io.on('connection', (socket) => {
    onlineSockets.add(socket.id);
    console.log(`Игрок подключился. Socket ID: ${socket.id}`);

    // Отправляем список комнат при подключении
    socket.emit('rooms_list', rooms.map(r => ({
        id: r.id,
        name: r.name,
        cellPrice: r.cellPrice,
        currency: r.currency,
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
        if (maintenanceMode) {
            if (callback) callback({ success: false, message: 'Сервер на тех. обслуживании. Возвращайтесь позже!' });
            return;
        }
        
        const { roomId, userData } = data;
        let tgIdCheck = socket.id;
        try {
            if (userData && userData.initData) {
                const urlParams = new URLSearchParams(userData.initData);
                const userStr = urlParams.get('user');
                if (userStr) tgIdCheck = JSON.parse(userStr).id.toString();
            }
        } catch (e) {}
        
        if (users[tgIdCheck] && users[tgIdCheck].banned) {
            if (callback) callback({ success: false, message: 'Ваш аккаунт заблокирован!' });
            return;
        }

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
                        users[referrerId].balance_bonus += gameSettings.referralBonus;
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
        if (maintenanceMode) {
            socket.emit('error', 'Идут технические работы. Ставки временно недоступны.');
            return;
        }
        if (isRateLimited(socket)) return;
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
        if (userRecord.banned) {
            socket.emit('error', 'Ваш аккаунт заблокирован!');
            return;
        }
        
        let price = room.cellPrice;
        let bonus = userRecord.balance_bonus || 0;
        let real = userRecord.balance_real || 0;

        if (room.currency === 'REAL') {
            if (real >= price) {
                userRecord.balance_real -= price;
                room.bank_real = (room.bank_real || 0) + price;
            } else {
                socket.emit('error', 'Недостаточно реальных средств');
                return;
            }
        } else if (room.currency === 'BONUS') {
            if (bonus >= price) {
                userRecord.balance_bonus -= price;
                room.bank_bonus = (room.bank_bonus || 0) + price;
            } else {
                socket.emit('error', 'Недостаточно бонусных средств');
                return;
            }
        }
            
            userRecord.stats.totalSpent += price;
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
    });

    socket.on('claim_daily_bonus', () => {
        if (isRateLimited(socket)) return;
        const tgId = socket.userData.telegram_id;
        let userRecord = users[tgId];
        if (!userRecord) return;
        if (userRecord.banned) return socket.emit('daily_bonus_error', 'Аккаунт заблокирован');

        const now = Date.now();
        const lastClaim = userRecord.lastBonusClaim || 0;
        const cooldown = 24 * 60 * 60 * 1000; // 24 hours

        if (now - lastClaim >= cooldown) {
            userRecord.balance_bonus += gameSettings.dailyBonus;
            userRecord.lastBonusClaim = now;
            saveUsers();
            io.emit('users_update', users);
            socket.emit('daily_bonus_success', `Вы получили ${gameSettings.dailyBonus} бонусных монет!`);
        } else {
            socket.emit('daily_bonus_error', 'Бонус пока недоступен');
        }
    });

    socket.on('exchange_coins', () => {
        if (isRateLimited(socket)) return;
        const tgId = socket.userData.telegram_id;
        let userRecord = users[tgId];
        if (!userRecord) return;
        if (userRecord.banned) return socket.emit('error', 'Аккаунт заблокирован');

        if ((userRecord.balance_bonus || 0) >= 10000) {
            userRecord.balance_bonus -= 10000;
            userRecord.balance_real = (userRecord.balance_real || 0) + 10;
            saveUsers();
            io.emit('users_update', users);
            socket.emit('exchange_success', 'Успешно обменено 10000 бонусов на 10 реал!');
        } else {
            socket.emit('error', 'Недостаточно бонусных монет для обмена (минимум 10000)');
        }
    });

    socket.on('request_withdrawal', (data) => {
        if (isRateLimited(socket)) return;
        const tgId = socket.userData.telegram_id;
        let userRecord = users[tgId];
        if (!userRecord) return;
        if (userRecord.banned) return socket.emit('withdrawal_error', 'Аккаунт заблокирован');
        
        const amount = data.amount || 0;
        const wallet = data.wallet || '';
        
        if (typeof wallet !== 'string' || wallet.length !== 48 || !(wallet.startsWith('UQ') || wallet.startsWith('EQ'))) {
            socket.emit('withdrawal_error', 'Некорректный адрес кошелька TON. Он должен начинаться с UQ или EQ и содержать 48 символов.');
            return;
        }
        
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
        userRecord.balance_locked = (userRecord.balance_locked || 0) + amount;
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
            addEvent('WITHDRAW', `Игрок ${userRecord.name} запросил вывод ${amount} монет`);
            socket.emit('withdrawal_success', 'Заявка на вывод успешно создана');
        }).catch(err => {
            console.error('Ошибка создания вывода', err);
            socket.emit('withdrawal_error', 'Ошибка сервера при создании заявки');
        });
    });

    socket.on('disconnect', () => {
        onlineSockets.delete(socket.id);
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
                            
                            addEvent('DEPOSIT', `Игрок ${users[tgId].name} пополнил счет на ${amountInCoins} реальных монет`);
                            const depId = `dep_${Date.now()}_${tgId}`;
                            allDeposits[depId] = { tgId, username: users[tgId].name, amount: amountInCoins, valueNano: value, hash, time: Date.now() };
                            saveDeposits();
                            
                            try {
                                bot.telegram.sendMessage(tgId, `🎉 <b>Успешное пополнение!</b>\n\nВаш баланс пополнен на <b>${amountInCoins}</b> реальных монет.\n\nЖелаем приятной игры и крупных выигрышей! 🎲✨`, { parse_mode: 'HTML' });
                            } catch (e) {
                                console.error(`Ошибка отправки сообщения пользователю ${tgId}:`, e.message);
                            }
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

// ==========================================
// ADMIN API
// ==========================================
const ADMIN_PASSWORD = 'Admin2026';

app.post('/admin/login', (req, res) => {
    if (req.body.password === ADMIN_PASSWORD) {
        res.json({ success: true, token: 'admin-token-123' });
    } else {
        res.status(401).json({ success: false, message: 'Неверный пароль' });
    }
});

const requireAdmin = (req, res, next) => {
    if (req.headers.authorization === 'Bearer admin-token-123') {
        next();
    } else {
        res.status(401).json({ success: false, message: 'Необходима авторизация' });
    }
};

app.get('/admin/bots', requireAdmin, (req, res) => {
    let systemStats = users['_SYSTEM_'] || { commission_balance: 0, commission_bonus: 0 };
    res.json({
        success: true,
        botsEnabled: !!gameSettings.botsEnabled,
        systemReal: (systemStats.commission_balance || 0) + (systemStats.bot_profit_real || 0),
        systemBonus: (systemStats.commission_bonus || 0) + (systemStats.bot_profit_bonus || 0),
        bots: BOTS.map(b => ({
            id: b.id,
            name: b.name,
            currentRoom: b.currentRoom,
            state: b.state,
            boughtCells: b.boughtCells,
            targetCells: b.targetCells,
            totalWonReal: b.totalWonReal,
            totalWonBonus: b.totalWonBonus,
            enabled: b.enabled
        }))
    });
});

app.post('/admin/bots/:id/toggle', requireAdmin, (req, res) => {
    const bot = BOTS.find(b => b.id === req.params.id);
    if (!bot) return res.status(404).json({ success: false, message: 'Бот не найден' });
    bot.enabled = !!req.body.enabled;
    res.json({ success: true, botId: bot.id, enabled: bot.enabled });
});

app.post('/admin/bots/toggle', requireAdmin, (req, res) => {
    gameSettings.botsEnabled = !!req.body.enabled;
    saveSettings();
    res.json({ success: true, botsEnabled: gameSettings.botsEnabled });
});

app.get('/admin/stats', requireAdmin, (req, res) => {
    let totalUsers = Object.keys(users).filter(k => k !== '_SYSTEM_').length;
    let systemStats = users['_SYSTEM_'] || { commission_balance: 0, commission_bonus: 0 };
    res.json({
        success: true,
        online: onlineSockets.size,
        totalUsers: totalUsers,
        systemReal: systemStats.commission_balance || 0,
        systemBonus: systemStats.commission_bonus || 0,
        botProfitReal: systemStats.bot_profit_real || 0,
        botProfitBonus: systemStats.bot_profit_bonus || 0,
        maintenance: maintenanceMode
    });
});

app.get('/admin/users', requireAdmin, (req, res) => {
    res.json({ success: true, users: users });
});

app.post('/admin/users/:id', requireAdmin, (req, res) => {
    const tgId = req.params.id;
    if (!users[tgId]) return res.status(404).json({ success: false, message: 'User not found' });
    
    if (req.body.balance_real !== undefined) users[tgId].balance_real = Number(req.body.balance_real);
    if (req.body.balance_bonus !== undefined) users[tgId].balance_bonus = Number(req.body.balance_bonus);
    if (req.body.banned !== undefined) users[tgId].banned = !!req.body.banned;
    
    saveUsers();
    io.emit('users_update', users);
    res.json({ success: true, user: users[tgId] });
});

app.get('/admin/withdrawals', requireAdmin, async (req, res) => {
    try {
        let data = await fetch(DB_URL_WITHDRAWALS).then(r => r.json());
        res.json({ success: true, withdrawals: data || {} });
    } catch (e) {
        res.status(500).json({ success: false, message: 'Fetch error' });
    }
});

app.post('/admin/withdrawals/:id', requireAdmin, async (req, res) => {
    const { id } = req.params;
    const { status } = req.body;
    try {
        let data = await fetch(DB_URL_WITHDRAWALS).then(r => r.json());
        if (!data || !data[id]) return res.status(404).json({ success: false, message: 'Not found' });
        
        let wd = data[id];
        if (wd.status !== 'pending') return res.status(400).json({ success: false, message: 'Already processed' });
        
        wd.status = status;
        
        if (status === 'rejected') {
            const tgId = wd.userId;
            if (users[tgId]) {
                users[tgId].balance_locked = (users[tgId].balance_locked || 0) - wd.amount;
                if (users[tgId].balance_locked < 0) users[tgId].balance_locked = 0;
                users[tgId].balance_real += wd.amount;
                saveUsers();
                io.emit('users_update', users);
                try { bot.telegram.sendMessage(tgId, `❌ Ваша заявка на вывод ${wd.amount} монет отклонена. Монеты возвращены на баланс.`); } catch(e){}
            }
        } else if (status === 'approved') {
            const tgId = wd.userId;
            if (users[tgId]) {
                users[tgId].balance_locked = (users[tgId].balance_locked || 0) - wd.amount;
                if (users[tgId].balance_locked < 0) users[tgId].balance_locked = 0;
                saveUsers();
                io.emit('users_update', users);
            }
            try { bot.telegram.sendMessage(wd.userId, `✅ Ваша заявка на вывод ${wd.amount} монет успешно обработана!`); } catch(e){}
        }
        
        await fetch(`${DB_URL_WITHDRAWALS.replace('.json', '')}/${id}.json`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(wd)
        });
        
        res.json({ success: true, withdrawal: wd });
    } catch (e) {
        res.status(500).json({ success: false, message: 'Error' });
    }
});

app.get('/admin/settings', requireAdmin, (req, res) => {
    res.json({ success: true, settings: gameSettings });
});

app.post('/admin/settings', requireAdmin, (req, res) => {
    gameSettings = { ...gameSettings, ...req.body };
    saveSettings();
    res.json({ success: true, settings: gameSettings });
});

app.get('/admin/events', requireAdmin, (req, res) => {
    res.json({ success: true, events: liveEvents });
});

app.get('/admin/deposits', requireAdmin, (req, res) => {
    res.json({ success: true, deposits: Object.values(allDeposits).sort((a,b)=>b.time-a.time) });
});

app.post('/admin/maintenance', requireAdmin, (req, res) => {
    maintenanceMode = !!req.body.active;
    res.json({ success: true, maintenance: maintenanceMode });
});

app.post('/admin/broadcast', requireAdmin, async (req, res) => {
    const message = req.body.message;
    if (!message) return res.status(400).json({ success: false, message: 'Пустое сообщение' });
    
    res.json({ success: true, message: 'Рассылка запущена' });
    
    const userIds = Object.keys(users).filter(k => k !== '_SYSTEM_');
    for (const tgId of userIds) {
        try {
            await bot.telegram.sendMessage(tgId, message, { parse_mode: 'HTML' });
        } catch (e) {}
        await new Promise(r => setTimeout(r, 50)); // ~20 msgs per sec
    }
});
// ==========================================

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Сервер запущен на порту ${PORT}.`);
});

process.once('SIGINT', () => bot.stop('SIGINT'));
process.once('SIGTERM', () => bot.stop('SIGTERM'));