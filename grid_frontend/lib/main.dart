import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:js' as js;
import 'dart:ui'; // Для BackdropFilter

void main() {
  runApp(const GridLotteryApp());
}

class GridLotteryApp extends StatelessWidget {
  const GridLotteryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grid Lottery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        fontFamily: 'Inter',
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _coins = 1000;
  int _bank = 0;
  String _phase = 'BETTING';
  int _timeLeft = 60;
  String _winnerMessage = '';
  int? _rouletteCell;
  int? _winnerCell;

  String _myTelegramId = ''; 
  List<dynamic> _history = [];

  late IO.Socket socket;
  List<dynamic> _gameState = List.filled(100, null);
  bool _isConnected = false;

  String _myName = '';
  String _myPhotoUrl = '';

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() {
    String username = 'TestUser';
    String telegramId = '123456789';

    try {
      if (js.context.hasProperty('Telegram')) {
        var tg = js.context['Telegram']['WebApp'];
        tg.callMethod('ready'); 
        
        var user = tg['initDataUnsafe']['user'];
        if (user != null) {
          username = user['username'] ?? 'Unknown';
          telegramId = (user['id'] ?? 123456789).toString();
          if (mounted) setState(() {
            _myName = user['first_name'] ?? username;
            _myPhotoUrl = user['photo_url'] ?? '';
          });
        }
      }
    } catch (e) {
      print("Telegram API не найдено.");
    }

    _myTelegramId = telegramId;

    // TODO: После деплоя бэкенда на Render/Railway, замените 'http://localhost:3000' на ваш новый URL
    const String backendUrl = 'https://grid-lottery-backend.onrender.com';

    socket = IO.io(backendUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build()
    );

    socket.connect();

    socket.onConnect((_) {
      if (mounted) setState(() {
        _isConnected = true;
      });
      socket.emit('join_game', {
        'username': username,
        'telegram_id': telegramId,
        'first_name': _myName,
        'photo_url': _myPhotoUrl,
      });
    });

    socket.on('init_state', (data) {
      if (mounted) setState(() {
        if (data is List) _gameState = data;
        _rouletteCell = null;
        _winnerCell = null;
        _winnerMessage = '';
      });
    });

    socket.on('update_state', (data) {
      if (mounted) setState(() {
        if (data is List) _gameState = data;
      });
    });

    socket.on('history_update', (data) {
      if (mounted) setState(() {
        if (data is List) _history = data;
      });
    });

    socket.on('game_update', (data) {
      if (mounted) setState(() {
        _phase = data['phase'] ?? 'BETTING';
        _timeLeft = data['timeLeft'] ?? 0;
        _bank = data['bank'] ?? 0;
        if (data['message'] != null) {
          _winnerMessage = data['message'];
        }
        
        // Очистка при рестарте
        if (_phase == 'BETTING' && _winnerCell != null) {
          _winnerCell = null;
          _rouletteCell = null;
          _winnerMessage = '';
        }
      });
    });

    socket.on('balances_update', (data) {
      if (mounted) setState(() {
        if (data is Map) {
          var k = data[_myTelegramId] ?? data[int.tryParse(_myTelegramId) ?? -1];
          if (k != null) {
            _coins = (k as num).toInt();
          }
        }
      });
    });

    socket.on('roulette_tick', (index) {
      if (mounted) setState(() {
        _rouletteCell = index;
      });
    });

    socket.on('roulette_finish', (index) {
      if (mounted) setState(() {
        _winnerCell = index;
        _rouletteCell = null;
      });
    });

    socket.onDisconnect((_) {
      if (mounted) setState(() {
        _isConnected = false;
      });
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String timerText = '';
    if (_phase == 'BETTING') {
      timerText = '00:${_timeLeft.toString().padLeft(2, '0')}';
    } else if (_phase == 'ROULETTE') {
      timerText = 'СТАВКИ СДЕЛАНЫ';
    } else if (_phase == 'REWARD') {
      timerText = _winnerMessage.isNotEmpty ? _winnerMessage : 'Победитель определен!';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              '$_coins',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1),
            ),
          ],
        ),
        centerTitle: true,
        leading: Center(
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text(
              'Банк\n$_bank',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, height: 1.1),
            ),
          ),
        ),
        leadingWidth: 80,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                if (_myName.isNotEmpty)
                  Text(_myName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (_myPhotoUrl.isNotEmpty)
                  CircleAvatar(radius: 16, backgroundImage: NetworkImage('$backendUrl/avatar?url=${Uri.encodeComponent(_myPhotoUrl)}'))
                else
                  const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 16)),
                const SizedBox(width: 12),
                Icon(
                  _isConnected ? Icons.wifi : Icons.wifi_off,
                  color: _isConnected ? Colors.green : Colors.redAccent,
                  size: 16,
                ),
              ],
            ),
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            radius: 1.5,
            center: Alignment.topCenter,
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Column(
              children: [
                // Glassmorphic Timer Box
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: [
                          if (_phase == 'ROULETTE') 
                             BoxShadow(color: Colors.amber.withOpacity(0.15), blurRadius: 20, spreadRadius: 5)
                          else if (_phase == 'REWARD')
                             BoxShadow(color: Colors.greenAccent.withOpacity(0.15), blurRadius: 20, spreadRadius: 5)
                        ]
                      ),
                      child: Text(
                        timerText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _phase == 'BETTING' ? 42 : 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: _phase == 'BETTING' ? 4 : 2,
                          color: _phase == 'REWARD' ? Colors.greenAccent : Colors.white,
                          shadows: [
                            Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
                            if (_phase == 'BETTING')
                              Shadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 20)
                          ]
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Grid
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 10,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                        itemCount: 100,
                        itemBuilder: (context, index) {
                          dynamic cellData = _gameState[index];
                          bool isTaken = cellData != null;
                          bool isRoulette = _phase == 'ROULETTE' && _rouletteCell == index;
                          bool isWinner = _phase == 'REWARD' && _winnerCell == index;

                          Color? userColor;
                          if (isTaken && cellData['color'] != null) {
                             userColor = Color(int.parse(cellData['color']));
                          }

                          BoxDecoration decor;
                          if (isWinner) {
                            decor = BoxDecoration(
                              color: Colors.greenAccent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.8), blurRadius: 15, spreadRadius: 2)],
                            );
                          } else if (isRoulette) {
                            decor = BoxDecoration(
                              color: Colors.amberAccent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.8), blurRadius: 15, spreadRadius: 2)],
                            );
                          } else if (isTaken) {
                            decor = BoxDecoration(
                              gradient: LinearGradient(
                                colors: [userColor!.withOpacity(0.8), userColor.withOpacity(0.4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                              boxShadow: [BoxShadow(color: userColor.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)],
                            );
                          } else {
                            // Empty
                            decor = BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            );
                          }

                          String initial = '';
                          if (isTaken && cellData['username'] != null) {
                            initial = cellData['username'].toString().substring(0, 1).toUpperCase();
                          }

                          return InkWell(
                            onTap: () {
                              if (_phase != 'BETTING') return; 
                              if (!isTaken && _isConnected && _coins >= 5) {
                                socket.emit('click_cell', index);
                              } else if (_coins < 5) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Недостаточно монет! Стоимость: 5'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: decor,
                              alignment: Alignment.center,
                              child: isTaken 
                                ? Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 1))]
                                    ),
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.15),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // History Section
                if (_history.isNotEmpty) ...[
                   const Text(
                     '🏆 ИСТОРИЯ ПОБЕД',
                     style: TextStyle(
                       color: Colors.white,
                       fontSize: 18,
                       fontWeight: FontWeight.w800,
                       letterSpacing: 2
                     ),
                   ),
                   const SizedBox(height: 16),
                   ConstrainedBox(
                     constraints: const BoxConstraints(maxWidth: 500),
                     child: ListView.builder(
                       shrinkWrap: true,
                       physics: const NeverScrollableScrollPhysics(),
                       itemCount: _history.length,
                       itemBuilder: (context, idx) {
                          var item = _history[idx];
                          Color hColor = Colors.blueAccent;
                          if (item['color'] != null) {
                             hColor = Color(int.parse(item['color']));
                          }
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              leading: item['photo_url'] != null && item['photo_url'].toString().isNotEmpty
                                ? CircleAvatar(
                                    radius: 24,
                                    backgroundImage: NetworkImage('$backendUrl/avatar?url=${Uri.encodeComponent(item['photo_url'])}'),
                                  )
                                : CircleAvatar(
                                    backgroundColor: hColor.withOpacity(0.2),
                                    radius: 24,
                                    child: Text(
                                      item['username'].toString().substring(0, 1).toUpperCase(),
                                      style: TextStyle(color: hColor, fontWeight: FontWeight.w900, fontSize: 20),
                                    ),
                                  ),
                              title: Text(
                                item['first_name'] ?? item['username'].toString(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Text(
                                'Ячейка ${item['cell']}',
                                style: TextStyle(color: Colors.white.withOpacity(0.5)),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Выигрыш', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                  Text(
                                    '+${item['bank']}',
                                    style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          );
                       }
                     ),
                   )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
