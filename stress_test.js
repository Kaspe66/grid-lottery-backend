const { io } = require("socket.io-client");

// Настройки теста
const SERVER_URL = "http://localhost:3000"; // Локальный сервер для тестов
const MAX_CLIENTS = 1000;
const CLIENT_CREATION_INTERVAL_MS = 20; // Ускорим создание клиентов, чтобы не ждать слишком долго

let clientCount = 0;
let connectedCount = 0;
let errorCount = 0;

console.log(`🚀 Запуск стресс-теста на ${SERVER_URL}`);
console.log(`📊 Ожидается клиентов: ${MAX_CLIENTS}`);

function createClient() {
    const clientId = `stress_bot_${clientCount++}`;
    const socket = io(SERVER_URL, {
        transports: ["websocket"],
        reconnection: false
    });

    socket.on("connect", () => {
        connectedCount++;
        process.stdout.write(`\rПодключено: ${connectedCount}/${MAX_CLIENTS} | Ошибок: ${errorCount}`);
        
        // Отправляем фейковую авторизацию
        socket.emit("auth", {
            telegram_id: clientId,
            username: clientId,
            color: "#FFFFFF",
            initData: "user=" + encodeURIComponent(JSON.stringify({id: clientId}))
        }, (response) => {
            if (response && response.success) {
                // Если авторизация успешна, присоединяемся к первой комнате через секунду
                    socket.emit('join_room', { roomId: 'room_REAL_5_1', userData: { initData: "user=" + encodeURIComponent(JSON.stringify({id: clientId, username: clientId, first_name: clientId, photo_url: ""})) } });
            }
        });
    });

    socket.on('rooms_list', (rooms) => {
        // Мы в комнате!
        // Делаем ставки случайным образом
        setInterval(() => {
            if (Math.random() < 0.1) {
                socket.emit('click_cell', Math.floor(Math.random() * 100));
            }
        }, 3000);
    });

    socket.on("connect_error", (err) => {
        errorCount++;
        process.stdout.write(`\rПодключено: ${connectedCount}/${MAX_CLIENTS} | Ошибок: ${errorCount}`);
    });
    
    socket.on("disconnect", () => {
        connectedCount--;
        process.stdout.write(`\rПодключено: ${connectedCount}/${MAX_CLIENTS} | Ошибок: ${errorCount}`);
    });
}

const interval = setInterval(() => {
    createClient();
    if (clientCount >= MAX_CLIENTS) {
        clearInterval(interval);
        console.log(`\n✅ Все ${MAX_CLIENTS} клиентов созданы. Ждем завершения...`);
    }
}, CLIENT_CREATION_INTERVAL_MS);

// Сбор статистики каждые 5 секунд
setInterval(() => {
    console.log(`\n[STAT] Активных: ${connectedCount}, Ошибок: ${errorCount}`);
}, 5000);
