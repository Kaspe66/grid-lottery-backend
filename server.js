const { Telegraf } = require('telegraf');
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const token = '7675654779:AAGiBuHXrNzX_VFnd6n1MGig1o1N2w8O3tg'; 
const webAppUrl = 'https://grid-lottery-game.web.app'; 

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
    ctx.reply('Добро пожаловать в Grid Lottery! 🎲\nНажми кнопку ниже, чтобы зайти в комнату:', {
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

let balances = {}; 
const DB_URL = 'https://grid-lottery-game-default-rtdb.firebaseio.com/balances.json';

// Загрузка балансов при старте сервера
fetch(DB_URL)
    .then(res => res.json())
    .then(data => {
        if (data) balances = data;
        console.log('Балансы успешно загружены из БД.');
    })
    .catch(err => console.error('Ошибка загрузки базы данных:', err));

function saveBalances() {
    fetch(DB_URL, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(balances)
    }).catch(err => console.error('Ошибка сохранения базы данных:', err));
}

function getColorForId(id) {
    const colors = ['0xFFF43F5E', '0xFF8B5CF6', '0xFFD946EF', '0xFF0EA5E9', '0xFF10B981', '0xFFF59E0B', '0xFFEC4899', '0xFF6366F1'];
    let hash = 0;
    let str = String(id);
    for (let i = 0; i < str.length; i++) hash = str.charCodeAt(i) + ((hash << 5) - hash);
    return colors[Math.abs(hash) % colors.length];
}

// --- Игровые комнаты ---
const rooms = [
    { id: 'room_5', name: 'Песочница', cellPrice: 5, maxPlayers: 7, players: new Set(), gameState: Array(100).fill(null), gamePhase: 'WAITING', timeLeft: BETTING_TIME, bank: 0, winnerHistory: [], rouletteInterval: null },
    { id: 'room_10', name: 'Любитель', cellPrice: 10, maxPlayers: 7, players: new Set(), gameState: Array(100).fill(null), gamePhase: 'WAITING', timeLeft: BETTING_TIME, bank: 0, winnerHistory: [], rouletteInterval: null },
    { id: 'room_25', name: 'Профи', cellPrice: 25, maxPlayers: 7, players: new Set(), gameState: Array(100).fill(null), gamePhase: 'WAITING', timeLeft: BETTING_TIME, bank: 0, winnerHistory: [], rouletteInterval: null },
    { id: 'room_50', name: 'Элита', cellPrice: 50, maxPlayers: 7, players: new Set(), gameState: Array(100).fill(null), gamePhase: 'WAITING', timeLeft: BETTING_TIME, bank: 0, winnerHistory: [], rouletteInterval: null },
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
    room.gamePhase = 'ROULETTE';
    room.timeLeft = ROULETTE_TIME;
    io.to(room.id).emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank });
    
    let jumps = 0;
    const maxJumps = (ROULETTE_TIME * 1000) / 150; 
    let currentCell = Math.floor(Math.random() * 100);

    room.rouletteInterval = setInterval(() => {
        currentCell = Math.floor(Math.random() * 100);
        io.to(room.id).emit('roulette_tick', currentCell);
        
        jumps++;
        if (jumps >= maxJumps) {
            clearInterval(room.rouletteInterval);
            finishRoulette(room, currentCell);
        }
    }, 150);
}

function finishRoulette(room, winningIndex) {
    room.gamePhase = 'REWARD';
    room.timeLeft = REWARD_TIME;
    io.to(room.id).emit('roulette_finish', winningIndex);
    
    let winnerMsg = `Выпала ячейка ${winningIndex + 1}. Никто не выиграл!`;
    const winnerData = room.gameState[winningIndex];
    
    if (winnerData) {
        winnerMsg = `Победил ${winnerData.username}! Выигрыш: ${room.bank} монет.`;
        if (balances[winnerData.telegram_id] !== undefined) {
            balances[winnerData.telegram_id] += room.bank;
        } else {
            balances[winnerData.telegram_id] = 1000 + room.bank; 
        }
        saveBalances();
        io.emit('balances_update', balances);

        room.winnerHistory.unshift({
            username: winnerData.username,
            first_name: winnerData.first_name,
            photo_url: winnerData.photo_url,
            bank: room.bank,
            cell: winningIndex + 1,
            color: winnerData.color
        });
        if (room.winnerHistory.length > 10) room.winnerHistory.pop();
        io.to(room.id).emit('history_update', room.winnerHistory);
    }
    
    io.to(room.id).emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank, message: winnerMsg });

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

        socket.userData = userData;
        const tgId = userData.telegram_id || socket.id; 
        socket.userData.telegram_id = tgId;
        socket.userData.color = getColorForId(tgId);
        socket.roomId = roomId;

        if (balances[tgId] === undefined) {
            balances[tgId] = 1000;
            saveBalances();
        }

        room.players.add(socket.id);
        socket.join(roomId);

        // Если было ОЖИДАНИЕ и стало >= 2 игроков, запускаем таймер
        if (room.gamePhase === 'WAITING' && room.players.size >= 2) {
            room.gamePhase = 'BETTING';
            room.timeLeft = BETTING_TIME;
        }

        socket.emit('init_state', room.gameState);
        socket.emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank, cellPrice: room.cellPrice });
        socket.emit('history_update', room.winnerHistory);
        io.emit('balances_update', balances);
        
        broadcastRoomsUpdate();
        
        // Оповещаем остальных в комнате об обновлении фазы (если она сменилась)
        io.to(roomId).emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank });
        
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
        if (room.gameState[index] !== null) return; 

        const tgId = socket.userData.telegram_id;
        let userBalance = balances[tgId] || 0;

        if (userBalance >= room.cellPrice) {
            balances[tgId] -= room.cellPrice; 
            room.bank += room.cellPrice;           
            saveBalances();
            
            room.gameState[index] = {
                username: socket.userData.username,
                telegram_id: tgId,
                color: socket.userData.color,
                first_name: socket.userData.first_name,
                photo_url: socket.userData.photo_url
            };
            
            io.to(room.id).emit('update_state', room.gameState);
            io.emit('balances_update', balances);
            io.to(room.id).emit('game_update', { phase: room.gamePhase, timeLeft: room.timeLeft, bank: room.bank, cellPrice: room.cellPrice }); 
        }
    });

    socket.on('disconnect', () => {
        handleLeaveRoom(socket);
        console.log(`Игрок отключился: ${socket.id}`);
    });

    function handleLeaveRoom(socket) {
        if (socket.roomId) {
            const room = getRoom(socket.roomId);
            if (room) {
                room.players.delete(socket.id);
                socket.leave(socket.roomId);
                
                // Если после выхода игроков стало меньше 2, но раунд уже начат,
                // мы просто даем ему закончиться (чтобы ставки не пропали).
                
                broadcastRoomsUpdate();
            }
            socket.roomId = null;
        }
    }
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Сервер запущен на порту ${PORT}.`);
});

process.once('SIGINT', () => bot.stop('SIGINT'));
process.once('SIGTERM', () => bot.stop('SIGTERM'));