import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:js' as js;
import 'dart:ui'; 

void main() {
  runApp(const GridLotteryApp());
}

class AppTranslations {
  static String langCode = 'en'; // default

  static final Map<String, Map<String, String>> _translations = {
    'en': {
      'room_selection': 'ROOM SELECTION',
      'players': 'Players',
      'room_full': 'Room is full!',
      'waiting_players': 'WAITING FOR PLAYERS',
      'bets_placed': 'BETS ARE PLACED',
      'winner_decided': 'Winner determined!',
      'bank': 'Bank',
      'not_enough_coins': 'Not enough coins! Price:',
      'history_title': '🏆 VICTORY HISTORY (THIS ROOM)',
      'win_amount': 'Win',
      'cell': 'Cell',
      'nobody_won': 'Cell {cell}. Nobody won!',
      'player_won': '{username} won! Win: {bank} coins.',
      'error_join': 'Error joining room',
      'leaderboard': 'Leaderboard',
      'quests': 'Quests',
      'profile': 'Profile',
      'lobby': 'Lobby',
      'daily_bonus': 'Daily Bonus',
      'claim': 'Claim',
      'invite_friend': 'Invite Friend',
      'referral_desc': 'Get 500 coins for each friend!',
      'games_played': 'Games Played',
      'total_won': 'Total Won',
      'chat': 'Chat',
      'Песочница': 'Sandbox',
      'Любитель': 'Amateur',
      'Профи': 'Pro',
      'Элита': 'Elite'
    },
    'ru': {
      'room_selection': 'ВЫБОР КОМНАТЫ',
      'players': 'Игроков',
      'room_full': 'Комната заполнена!',
      'waiting_players': 'ОЖИДАНИЕ ИГРОКОВ',
      'bets_placed': 'СТАВКИ СДЕЛАНЫ',
      'winner_decided': 'Победитель определен!',
      'bank': 'Банк',
      'not_enough_coins': 'Недостаточно монет! Стоимость:',
      'history_title': '🏆 ИСТОРИЯ ПОБЕД (ЭТА КОМНАТА)',
      'win_amount': 'Выигрыш',
      'cell': 'Ячейка',
      'nobody_won': 'Выпала ячейка {cell}. Никто не выиграл!',
      'player_won': 'Победил {username}! Выигрыш: {bank} монет.',
      'error_join': 'Ошибка входа в комнату',
      'leaderboard': 'Таблица Лидеров',
      'quests': 'Задания',
      'profile': 'Профиль',
      'lobby': 'Лобби',
      'daily_bonus': 'Ежедневный Бонус',
      'claim': 'Получить',
      'invite_friend': 'Пригласить Друга',
      'referral_desc': 'Получи 500 монет за каждого!',
      'games_played': 'Сыграно игр',
      'total_won': 'Всего выиграно',
      'chat': 'Чат',
      'Песочница': 'Песочница',
      'Любитель': 'Любитель',
      'Профи': 'Профи',
      'Элита': 'Элита'
    }
  };

  static String t(String key, [Map<String, String>? params]) {
    String str = _translations[langCode]?[key] ?? _translations['en']![key] ?? key;
    if (params != null) {
      params.forEach((k, v) {
        str = str.replaceAll('{$k}', v);
      });
    }
    return str;
  }
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
      home: const MainScreen(),
    );
  }
}


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late IO.Socket socket;
  List<dynamic> rooms = [];
  Map<String, dynamic> users = {};
  bool _isConnected = false;
  int _currentIndex = 0;

  String _myName = 'User';
  String _myTelegramId = '123456789';
  String _myPhotoUrl = '';
  String _initData = '';

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
        
        _initData = tg['initData'] ?? '';
        
        var user = tg['initDataUnsafe']['user'];
        if (user != null) {
          _myTelegramId = (user['id'] ?? 123456789).toString();
          
          String lang = user['language_code'] ?? 'en';
          if (lang.startsWith('ru')) {
            AppTranslations.langCode = 'ru';
          } else {
            AppTranslations.langCode = 'en';
          }
          
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
      socket.emitWithAck('auth', {
        'initData': _initData,
        'telegram_id': _myTelegramId,
        'username': _myName,
        'color': '#FFFFFF'
      }, ack: (response) {
        if (response != null && response['success'] == true) {
          print("Authenticated successfully");
        }
      });
    });

    socket.on('rooms_list', (data) {
      if (mounted) setState(() {
        rooms = data;
      });
    });

    socket.on('users_update', (data) {
      if (mounted) setState(() {
        if (data is Map) {
          users = Map<String, dynamic>.from(data);
        }
      });
    });

    socket.onDisconnect((_) {
      if (mounted) setState(() {
        _isConnected = false;
      });
    });
  }

  void _claimBonus() {
    socket.emitWithAck('claim_bonus', null, ack: (data) {
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.t('bonus_claimed'))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? AppTranslations.t('bonus_error'))));
      }
    });
  }

  Widget _buildLobby() {
    if (!_isConnected) return const Center(child: CircularProgressIndicator());
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        var room = rooms[index];
        bool isFull = room['playersCount'] >= room['maxPlayers'];
        String translatedRoomName = AppTranslations.t(room['name']);

        return Card(
          color: Colors.white.withOpacity(0.05),
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            title: Text(
              translatedRoomName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '${AppTranslations.t('players')}: ${room['playersCount']} / ${room['maxPlayers']}',
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
                  SnackBar(content: Text(AppTranslations.t('room_full'))),
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
                      'initData': _initData,
                      'username': _myName, 
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
    );
  }

  Widget _buildLeaderboard() {
    var sortedUsers = users.values.toList();
    sortedUsers.sort((a, b) => (b['balance'] ?? 0).compareTo(a['balance'] ?? 0));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedUsers.length,
      itemBuilder: (context, index) {
        var u = sortedUsers[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blueAccent.withOpacity(0.3),
            backgroundImage: u['photo_url'] != null && u['photo_url'].toString().isNotEmpty
                ? NetworkImage('$backendUrl/avatar?url=${Uri.encodeComponent(u['photo_url'])}')
                : null,
            child: u['photo_url'] == null || u['photo_url'].toString().isEmpty
                ? Text('${index + 1}')
                : null,
          ),
          title: Text(u['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text('${u['balance'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }
    );
  }

  Widget _buildQuests() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: Colors.greenAccent.withOpacity(0.2),
            ),
            icon: const Icon(Icons.card_giftcard, color: Colors.greenAccent),
            label: Text(AppTranslations.t('daily_bonus'), style: const TextStyle(fontSize: 18)),
            onPressed: _claimBonus,
          ),
          const SizedBox(height: 40),
          Text(AppTranslations.t('invite_friend'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(AppTranslations.t('referral_desc'), style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: Colors.blueAccent.withOpacity(0.2),
            ),
            icon: const Icon(Icons.share, color: Colors.blueAccent),
            label: const Text('Share Link', style: TextStyle(fontSize: 18)),
            onPressed: () {
               String link = 'https://t.me/GridLotteryBot/app?startapp=ref_$_myTelegramId';
               try {
                 js.context['Telegram']['WebApp'].callMethod('openTelegramLink', [link]);
               } catch(e) {
                 print(link);
               }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    var myData = users[_myTelegramId];
    if (myData == null) return const Center(child: CircularProgressIndicator());
    var stats = myData['stats'] ?? {};
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white12,
            backgroundImage: _myPhotoUrl.isNotEmpty 
                ? NetworkImage('$backendUrl/avatar?url=${Uri.encodeComponent(_myPhotoUrl)}') 
                : null,
            child: _myPhotoUrl.isEmpty ? const Icon(Icons.person, size: 50) : null,
          ),
          const SizedBox(height: 16),
          Text(_myName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          ListTile(
            title: Text(AppTranslations.t('bank')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.monetization_on, color: Colors.amber),
              const SizedBox(width: 8),
              Text('${myData['balance'] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
          ListTile(
            title: Text(AppTranslations.t('games_played')),
            trailing: Text('${stats['gamesPlayed'] ?? 0}', style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text(AppTranslations.t('total_won')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.emoji_events, color: Colors.amber),
              const SizedBox(width: 8),
              Text('${stats['totalWon'] ?? 0}', style: const TextStyle(fontSize: 18)),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> pages = [
      _buildLobby(),
      _buildLeaderboard(),
      _buildQuests(),
      _buildProfile(),
    ];

    List<String> titles = [
      AppTranslations.t('lobby'),
      AppTranslations.t('leaderboard'),
      AppTranslations.t('quests'),
      AppTranslations.t('profile'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex], style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
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
        child: pages[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.casino), label: AppTranslations.t('lobby')),
          BottomNavigationBarItem(icon: const Icon(Icons.leaderboard), label: AppTranslations.t('leaderboard')),
          BottomNavigationBarItem(icon: const Icon(Icons.card_giftcard), label: AppTranslations.t('quests')),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: AppTranslations.t('profile')),
        ],
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
  List<dynamic> _roomPlayers = [];

  
  List<Widget> _floatingEmojis = [];
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
             SnackBar(content: Text(response['message'] ?? AppTranslations.t('error_join'))),
           );
           Navigator.pop(context);
        }
      }
    });
  }

  void _setupSocketListeners() {
    widget.socket.on('emoji_message', (data) {
      if (mounted) setState(() {
        final key = UniqueKey();
        // Generate pseudo-random X between 20 and 300
        double startX = 20 + (DateTime.now().millisecondsSinceEpoch % 280).toDouble();
        _floatingEmojis.add(
          AnimatedEmoji(
            key: key,
            emoji: data['emoji'] ?? '👍',
            startX: startX,
          )
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() {
            _floatingEmojis.removeWhere((w) => w.key == key);
          });
        });
      });
    });

    widget.socket.on('room_players', (data) {
      if (mounted) setState(() {
        if (data is List) _roomPlayers = data;
      });
    });

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
        
        if (data['rewardData'] != null) {
          var rd = data['rewardData'];
          if (rd['hasWinner'] == true) {
            _winnerMessage = AppTranslations.t('player_won', {
              'username': rd['username'].toString(),
              'bank': rd['bank'].toString(),
            });
          } else {
             _winnerMessage = AppTranslations.t('nobody_won', {
               'cell': rd['cell'].toString(),
             });
          }
        } else if (data['message'] != null) {
          // Fallback for backward compatibility
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

    widget.socket.on('users_update', (data) {
      if (mounted) setState(() {
        if (data is Map) {
          var k = data[widget.userData['telegram_id']] ?? data[int.tryParse(widget.userData['telegram_id']) ?? -1];
          if (k != null && k['balance'] != null) {
            _coins = (k['balance'] as num).toInt();
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
    widget.socket.off('emoji_message');
    
    widget.socket.off('room_players');
    widget.socket.off('init_state');
    widget.socket.off('update_state');
    widget.socket.off('history_update');
    widget.socket.off('game_update');
    widget.socket.off('users_update');
    widget.socket.off('roulette_tick');
    widget.socket.off('roulette_finish');
    
    super.dispose();
  }

  @override
  
  Widget build(BuildContext context) {
    String timerText = '';
    if (_phase == 'WAITING') {
      timerText = AppTranslations.t('waiting_players');
    } else if (_phase == 'BETTING') {
      timerText = '00:${_timeLeft.toString().padLeft(2, '0')}';
    } else if (_phase == 'ROULETTE') {
      timerText = AppTranslations.t('bets_placed');
    } else if (_phase == 'REWARD') {
      timerText = _winnerMessage.isNotEmpty ? _winnerMessage : AppTranslations.t('winner_decided');
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
                '${AppTranslations.t('bank')}\n$_bank',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, height: 1.1),
              ),
            ),
          )
        ],
      ),
      body: Stack(children: [ Container(
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

                // Players in room list
                if (_roomPlayers.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${AppTranslations.t('players')}: ${_roomPlayers.length} / 7',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView.builder(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _roomPlayers.length,
                      itemBuilder: (context, index) {
                        var p = _roomPlayers[index];
                        String name = p['first_name'] ?? p['username'] ?? 'User';
                        String initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
                        Color hColor = Colors.blueAccent;
                        if (p['color'] != null) {
                           hColor = Color(int.parse(p['color']));
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Tooltip(
                            message: name,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: hColor.withOpacity(0.3),
                              backgroundImage: p['photo_url'] != null && p['photo_url'].toString().isNotEmpty
                                ? NetworkImage('${widget.backendUrl}/avatar?url=${Uri.encodeComponent(p['photo_url'])}')
                                : null,
                              child: p['photo_url'] == null || p['photo_url'].toString().isEmpty
                                ? Text(initial, style: TextStyle(color: hColor, fontWeight: FontWeight.bold))
                                : null,
                            ),
                          ),
                        );
                      }
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
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
                                    content: Text('${AppTranslations.t('not_enough_coins')} $_cellPrice'),
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
                   Text(
                     AppTranslations.t('history_title'),
                     style: const TextStyle(
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
                                '${AppTranslations.t('cell')} ${item['cell']}',
                                style: TextStyle(color: Colors.white.withOpacity(0.5)),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(AppTranslations.t('win_amount'), style: const TextStyle(color: Colors.white54, fontSize: 10)),
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
      ..._floatingEmojis,
      _buildEmojiPicker(),
    ],),
    );
  }

  Widget _buildEmojiPicker() {
    final emojis = ['👍', '😂', '😭', '😡', '🎉', '🤑'];
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: emojis.map((e) => GestureDetector(
            onTap: () {
              widget.socket.emit('send_emoji', e);
            },
            child: Text(e, style: const TextStyle(fontSize: 32)),
          )).toList(),
        ),
      ),
    );
  }
}

class AnimatedEmoji extends StatefulWidget {
  final String emoji;
  final double startX;
  const AnimatedEmoji({super.key, required this.emoji, required this.startX});
  @override
  State<AnimatedEmoji> createState() => _AnimatedEmojiState();
}

class _AnimatedEmojiState extends State<AnimatedEmoji> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _yAnimation = Tween<double>(begin: 0, end: -300).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.startX,
          bottom: 100 - _yAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Text(widget.emoji, style: const TextStyle(fontSize: 40)),
          ),
        );
      },
    );
  }
}

