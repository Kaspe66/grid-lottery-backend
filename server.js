const { Telegraf } = require('telegraf');
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const token = '7675654779:AAGiBuHXrNzX_VFnd6n1MGig1o1N2w8O3tg'; 
const webAppUrl = 'https://google.com'; 

const bot = new Telegraf(token);
const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

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

const CELL_PRICE = 5;
const BETTING_TIME = 60; 
const ROULETTE_TIME = 8; 
const REWARD_TIME = 5;   

let gameState = Array(100).fill(null);
let balances = {}; 
let winnerHistory = []; // Массив истории: { username, bank, cell }

let gamePhase = 'BETTING'; 
let timeLeft = BETTING_TIME;
let bank = 0;

let rouletteInterval = null;

function getColorForId(id) {
    const colors = ['0xFFF43F5E', '0xFF8B5CF6', '0xFFD946EF', '0xFF0EA5E9', '0xFF10B981', '0xFFF59E0B', '0xFFEC4899', '0xFF6366F1'];
    let hash = 0;
    let str = String(id);
    for (let i = 0; i < str.length; i++) hash = str.charCodeAt(i) + ((hash << 5) - hash);
    return colors[Math.abs(hash) % colors.length];
}

function resetGame() {
    gameState = Array(100).fill(null);
    gamePhase = 'BETTING';
    timeLeft = BETTING_TIME;
    bank = 0;
    io.emit('init_state', gameState);
    io.emit('game_update', { phase: gamePhase, timeLeft, bank });
}

function startRoulette() {
    gamePhase = 'ROULETTE';
    timeLeft = ROULETTE_TIME;
    io.emit('game_update', { phase: gamePhase, timeLeft, bank });
    
    let jumps = 0;
    const maxJumps = (ROULETTE_TIME * 1000) / 150; 
    let currentCell = Math.floor(Math.random() * 100);

    rouletteInterval = setInterval(() => {
        currentCell = Math.floor(Math.random() * 100);
        io.emit('roulette_tick', currentCell);
        
        jumps++;
        if (jumps >= maxJumps) {
            clearInterval(rouletteInterval);
            finishRoulette(currentCell);
        }
    }, 150);
}

function finishRoulette(winningIndex) {
    gamePhase = 'REWARD';
    timeLeft = REWARD_TIME;
    io.emit('roulette_finish', winningIndex);
    
    let winnerMsg = `Выпала ячейка ${winningIndex + 1}. Никто не выиграл!`;
    const winnerData = gameState[winningIndex];
    
    if (winnerData) {
        winnerMsg = `Победил ${winnerData.username}! Выигрыш: ${bank} монет.`;
        if (balances[winnerData.telegram_id] !== undefined) {
            balances[winnerData.telegram_id] += bank;
        } else {
            balances[winnerData.telegram_id] = 1000 + bank; 
        }
        io.emit('balances_update', balances);

        winnerHistory.unshift({
            username: winnerData.username,
            bank: bank,
            cell: winningIndex + 1,
            color: winnerData.color
        });
        if (winnerHistory.length > 10) winnerHistory.pop();
        io.emit('history_update', winnerHistory);
    }
    
    io.emit('game_update', { phase: gamePhase, timeLeft, bank, message: winnerMsg });

    setTimeout(() => {
        resetGame();
    }, REWARD_TIME * 1000);
}

setInterval(() => {
    if (gamePhase === 'BETTING') {
        timeLeft--;
        io.emit('game_update', { phase: gamePhase, timeLeft, bank });
        if (timeLeft <= 0) {
            startRoulette();
        }
    } else if (gamePhase === 'ROULETTE') {
        timeLeft--;
        if (timeLeft < 0) timeLeft = 0;
        io.emit('game_update', { phase: gamePhase, timeLeft, bank });
    }
}, 1000);

io.on('connection', (socket) => {
    console.log(`Игрок подключился. Socket ID: ${socket.id}`);

    socket.on('join_game', (userData) => {
        socket.userData = userData;
        const tgId = userData.telegram_id || socket.id; 
        socket.userData.telegram_id = tgId;
        socket.userData.color = getColorForId(tgId);

        if (balances[tgId] === undefined) {
            balances[tgId] = 1000;
        }

        socket.emit('init_state', gameState);
        socket.emit('game_update', { phase: gamePhase, timeLeft, bank });
        socket.emit('history_update', winnerHistory);
        
        io.emit('balances_update', balances);
    });

    socket.on('click_cell', (index) => {
        if (gamePhase !== 'BETTING') return;
        if (typeof index !== 'number' || index < 0 || index >= 100) return;
        if (gameState[index] !== null) return; 

        const tgId = socket.userData.telegram_id;
        let userBalance = balances[tgId] || 0;

        if (userBalance >= CELL_PRICE) {
            balances[tgId] -= CELL_PRICE; 
            bank += CELL_PRICE;           
            
            gameState[index] = {
                username: socket.userData.username,
                telegram_id: tgId,
                color: socket.userData.color
            };
            
            io.emit('update_state', gameState);
            io.emit('balances_update', balances);
            io.emit('game_update', { phase: gamePhase, timeLeft, bank }); 
        }
    });

    socket.on('disconnect', () => {
        console.log(`Игрок отключился: ${socket.id}`);
    });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Сервер запущен на порту ${PORT}.`);
});

process.once('SIGINT', () => bot.stop('SIGINT'));
process.once('SIGTERM', () => bot.stop('SIGTERM'));