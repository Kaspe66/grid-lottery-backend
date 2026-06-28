import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:js' as js;
import 'dart:ui'; 

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
        scaffoldBackgroundColor: const Color(0xFF0F172A), 
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        fontFamily: 'Inter',
      ),
      home: const LobbyScreen(),
    );
  }
}

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late IO.Socket socket;
  List<dynamic> rooms = [];
  bool _isConnected = false;

  String _myName = 'TestUser';
  String _myTelegramId = '123456789';
  String _myPhotoUrl = '';

  final String backendUrl = 'https://grid-lottery-backend.onrender.com';

  @override
  void initState() {
    super.initState();
    _initTelegramAndSocket();
  }

  void _initTelegramAndSocket() {
    try {
      if (js.context.hasProperty('Telegram')) {
        var tg = js.context['Telegram']['WebApp'];
        tg.callMethod('ready'); 
        
        var user = tg['initDataUnsafe']['user'];
        if (user != null) {
          _myTelegramId = (user['id'] ?? 123456789).toString();
          if (mounted) setState(() {
            _myName = user['first_name'] ?? (user['username'] ?? 'Unknown');
            _myPhotoUrl = user['photo_url'] ?? '';
          });
        }
      }
    } catch (e) {
      print("Telegram API не найдено.");
    }

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
    });

    socket.on('rooms_list', (data) {
      if (mounted) setState(() {
        rooms = data;
      });
    });

    socket.onDisconnect((_) {
      if (mounted) setState(() {
        _isConnected = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ВЫБОР КОМНАТЫ', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            radius: 1.5,
            center: Alignment.topCenter,
          ),
        ),
        child: _isConnected
            ? ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  var room = rooms[index];
                  bool isFull = room['playersCount'] >= room['maxPlayers'];

                  return Card(
                    color: Colors.white.withOpacity(0.05),
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      title: Text(
                        room['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Игроков: ${room['playersCount']} / ${room['maxPlayers']}',
                          style: TextStyle(
                            color: isFull ? Colors.redAccent : Colors.greenAccent,
                          ),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                          const SizedBox(height: 4),
                          Text('${room['cellPrice']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      onTap: () {
                        if (isFull) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Комната заполнена!')),
                          );
                          return;
                        }
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameScreen(
                              socket: socket,
                              roomId: room['id'],
                              backendUrl: backendUrl,
                              userData: {
                                'username': _myName, // Used for short names
                                'first_name': _myName,
                                'telegram_id': _myTelegramId,
                                'photo_url': _myPhotoUrl,
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  final IO.Socket socket;
  final String roomId;
  final String backendUrl;
  final Map<String, dynamic> userData;

  const GameScreen({
    super.key,
    required this.socket,
    required this.roomId,
    required this.backendUrl,
    required this.userData,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _coins = 0;
  int _bank = 0;
  int _cellPrice = 5;
  String _phase = 'WAITING';
  int _timeLeft = 60;
  String _winnerMessage = '';
  int? _rouletteCell;
  int? _winnerCell;

  List<dynamic> _history = [];
  List<dynamic> _gameState = List.filled(100, null);

  @override
  void initState() {
    super.initState();
    _setupSocketListeners();
    _joinRoom();
  }

  void _joinRoom() {
    widget.socket.emitWithAck('join_room', {
      'roomId': widget.roomId,
      'userData': widget.userData,
    }, ack: (response) {
      if (response != null && response['success'] == false) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(response['message'] ?? 'Ошибка входа в комнату')),
           );
           Navigator.pop(context);
        }
      }
    });
  }

  void _setupSocketListeners() {
    widget.socket.on('init_state', (data) {
      if (mounted) setState(() {
        if (data is List) _gameState = data;
        _rouletteCell = null;
        _winnerCell = null;
        _winnerMessage = '';
      });
    });

    widget.socket.on('update_state', (data) {
      if (mounted) setState(() {
        if (data is List) _gameState = data;
      });
    });

    widget.socket.on('history_update', (data) {
      if (mounted) setState(() {
        if (data is List) _history = data;
      });
    });

    widget.socket.on('game_update', (data) {
      if (mounted) setState(() {
        if (data['phase'] != null) _phase = data['phase'];
        if (data['timeLeft'] != null) _timeLeft = data['timeLeft'];
        if (data['bank'] != null) _bank = data['bank'];
        if (data['cellPrice'] != null) _cellPrice = data['cellPrice'];
        
        if (data['message'] != null) {
          _winnerMessage = data['message'];
        }
        
        // Очистка при рестарте
        if ((_phase == 'BETTING' || _phase == 'WAITING') && _winnerCell != null) {
          _winnerCell = null;
          _rouletteCell = null;
          _winnerMessage = '';
        }
      });
    });

    widget.socket.on('balances_update', (data) {
      if (mounted) setState(() {
        if (data is Map) {
          var k = data[widget.userData['telegram_id']] ?? data[int.tryParse(widget.userData['telegram_id']) ?? -1];
          if (k != null) {
            _coins = (k as num).toInt();
          }
        }
      });
    });

    widget.socket.on('roulette_tick', (index) {
      if (mounted) setState(() {
        _rouletteCell = index;
      });
    });

    widget.socket.on('roulette_finish', (index) {
      if (mounted) setState(() {
        _winnerCell = index;
        _rouletteCell = null;
      });
    });
  }

  @override
  void dispose() {
    widget.socket.emit('leave_room');
    
    // Remove listeners specifically added for game screen to avoid duplicates if re-entering
    widget.socket.off('init_state');
    widget.socket.off('update_state');
    widget.socket.off('history_update');
    widget.socket.off('game_update');
    widget.socket.off('balances_update');
    widget.socket.off('roulette_tick');
    widget.socket.off('roulette_finish');
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String timerText = '';
    if (_phase == 'WAITING') {
      timerText = 'ОЖИДАНИЕ ИГРОКОВ';
    } else if (_phase == 'BETTING') {
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
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                'Банк\n$_bank',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, height: 1.1),
              ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                          fontSize: (_phase == 'BETTING' || _phase == 'ROULETTE') ? 32 : 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: _phase == 'BETTING' ? 4 : 2,
                          color: _phase == 'REWARD' ? Colors.greenAccent : (_phase == 'WAITING' ? Colors.grey : Colors.white),
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
                              if (!isTaken && _coins >= _cellPrice) {
                                widget.socket.emit('click_cell', index);
                              } else if (_coins < _cellPrice) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Недостаточно монет! Стоимость: $_cellPrice'),
                                    duration: const Duration(seconds: 1),
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
                     '🏆 ИСТОРИЯ ПОБЕД (ЭТА КОМНАТА)',
                     style: TextStyle(
                       color: Colors.white,
                       fontSize: 14,
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
                                    backgroundImage: NetworkImage('${widget.backendUrl}/avatar?url=${Uri.encodeComponent(item['photo_url'])}'),
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
