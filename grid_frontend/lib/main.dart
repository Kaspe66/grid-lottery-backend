import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:js' as js;
import 'dart:async';
import 'dart:ui';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

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
      'referral_desc': 'Get 50 coins for each friend!',
      'games_played': 'Games Played',
      'total_won': 'Total Won',
      'chat': 'Chat',
      'Песочница': 'Sandbox',
      'Любитель': 'Amateur',
      'Профи': 'Pro',
      'Элита': 'Elite',
      'deposit': 'Deposit',
      'connected_wallet': 'Connected Wallet',
      'unlink': 'Unlink',
      'emojis_btn': 'Emojis 😀',
      'error_funds': 'Transaction cancelled. Ensure enough balance for transfer and network fees.',
      'error_tx': 'Transaction error: ',
      'withdraw': 'Withdraw',
      'real_balance': 'Real Balance',
      'bonus_balance': 'Bonus Balance',
      'enter_wallet': 'Wallet address (TON)',
      'amount': 'Amount',
      'withdraw_btn': 'Submit Withdrawal',
      'real_rooms': 'REAL',
      'bonus_rooms': 'BONUS',
      'real_room': 'Real',
      'bonus_room': 'Bonus',
      'room': 'Room',
      'total_won_real': 'Total Won (Real)',
      'total_won_bonus': 'Total Won (Bonus)',
      'settings': 'Settings',
      'sound': 'Sound',
      'vibration': 'Vibration',
      'not_enough_funds_deposit': 'Not enough funds on balance, please deposit!',
      'error_telegram_only': 'Access only via Telegram',
      'error_signature': 'Telegram signature error',
      'error_banned': 'Your account is banned!',
      'error_room_not_found': 'Room not found',
      'error_room_full': 'Room is full',
      'error_maintenance': 'Maintenance in progress. Bets are temporarily unavailable.',
      'error_cell_taken': 'Cell is already taken',
      'error_not_enough_real': 'Not enough real coins',
      'error_not_enough_bonus': 'Not enough bonus coins',
      'daily_bonus_success': 'You received your daily bonus!',
      'error_daily_bonus_cooldown': 'Bonus is not available yet',
      'exchange_success': 'Successfully exchanged 10000 bonus for 10 real!',
      'error_exchange_not_enough': 'Not enough bonus coins for exchange (min 10000)',
      'error_invalid_wallet': 'Invalid TON wallet address.',
      'error_min_withdrawal': 'Minimum withdrawal amount is 500 coins',
      'error_no_deposit': 'At least one deposit is required to withdraw',
      'error_server_withdrawal': 'Server error while creating request',
      'withdrawal_success': 'Withdrawal request created successfully',
      'exchange_btn_1': 'Exchange 10000 ',
      'exchange_btn_2': ' for 10 '
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
      'referral_desc': 'Получи 50 монет за каждого!',
      'games_played': 'Сыграно игр',
      'total_won': 'Всего выиграно',
      'chat': 'Чат',
      'Песочница': 'Песочница',
      'Любитель': 'Любитель',
      'Профи': 'Профи',
      'Элита': 'Элита',
      'deposit': 'Пополнить',
      'connected_wallet': 'Привязанный кошелек',
      'unlink': 'Отвязать',
      'emojis_btn': 'Эмодзи 😀',
      'error_funds': 'Транзакция отменена. Убедитесь, что на балансе достаточно средств для перевода и оплаты комиссии сети.',
      'error_tx': 'Ошибка транзакции: ',
      'withdraw': 'Вывести',
      'real_balance': 'Реальный баланс',
      'bonus_balance': 'Бонусный баланс',
      'enter_wallet': 'Адрес кошелька (TON)',
      'amount': 'Сумма',
      'withdraw_btn': 'Отправить заявку',
      'real_rooms': 'РЕАЛЬНЫЕ',
      'bonus_rooms': 'БОНУСНЫЕ',
      'real_room': 'Реал',
      'bonus_room': 'Бонус',
      'room': 'Комната',
      'total_won_real': 'Выиграно (Реал)',
      'total_won_bonus': 'Выиграно (Бонусы)',
      'settings': 'Настройки',
      'sound': 'Звук',
      'vibration': 'Вибрация',
      'not_enough_funds_deposit': 'Недостаточно средств на балансе! Пожалуйста, пополните счет.',
      'error_telegram_only': 'Доступ только через Telegram',
      'error_signature': 'Ошибка подписи Telegram',
      'error_banned': 'Ваш аккаунт заблокирован!',
      'error_room_not_found': 'Комната не найдена',
      'error_room_full': 'Комната переполнена',
      'error_maintenance': 'Идут технические работы. Ставки временно недоступны.',
      'error_cell_taken': 'Ячейка уже занята',
      'error_not_enough_real': 'Недостаточно реальных средств',
      'error_not_enough_bonus': 'Недостаточно бонусных средств',
      'daily_bonus_success': 'Вы получили ежедневный бонус!',
      'error_daily_bonus_cooldown': 'Бонус пока недоступен',
      'exchange_success': 'Успешно обменено 10000 бонусов на 10 реал!',
      'error_exchange_not_enough': 'Недостаточно бонусных монет для обмена (минимум 10000)',
      'error_invalid_wallet': 'Некорректный адрес кошелька TON.',
      'error_min_withdrawal': 'Минимальная сумма вывода - 500 монет',
      'error_no_deposit': 'Для вывода средств необходим хотя бы один депозит (пополнение)',
      'error_server_withdrawal': 'Ошибка сервера при создании заявки',
      'withdrawal_success': 'Заявка на вывод успешно создана',
      'exchange_btn_1': 'Обменять 10000 ',
      'exchange_btn_2': ' на 10 '
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
  String _selectedCurrency = 'REAL';
  int _selectedPrice = 5;
  bool _sortRoomsAscending = true;

  String _myName = 'User';
  String _myTelegramId = '123456789';
  String _myPhotoUrl = '';
  String _initData = '';
  String? _connectedWallet;
  Timer? _walletTimer;
  Timer? _uiTimer;

  String _formatBalance(num balance) {
    if (balance >= 1000) {
      double k = balance / 1000.0;
      if (k == k.truncateToDouble()) {
        return '${k.toInt()}K';
      } else {
        return '${k.toStringAsFixed(1)}K';
      }
    }
    return balance.toString();
  }

  final String backendUrl = 'https://grid-lottery-backend.onrender.com';

  bool _isSoundEnabled = true;
  bool _isVibrationEnabled = true;
  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadSettings();
    _initTelegramAndSocket();
    _walletTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
       _checkWallet();
    });
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
       if (mounted && _currentIndex == 2) setState(() {});
    });
  }

  void _checkWallet() {
    try {
      var wallet = js.context.callMethod('getConnectedWallet');
      if (wallet != null && wallet.toString() != _connectedWallet) {
        if (mounted) setState(() { _connectedWallet = wallet.toString(); });
      } else if (wallet == null && _connectedWallet != null) {
        if (mounted) setState(() { _connectedWallet = null; });
      }
    } catch(e) {}
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isSoundEnabled = prefs.getBool('sound_enabled') ?? true;
        _isVibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      });
    }
  }

  void _toggleSound(bool val) {
    setState(() {
      _isSoundEnabled = val;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('sound_enabled', val);
    }).catchError((e) {});
  }

  void _toggleVibration(bool val) {
    setState(() {
      _isVibrationEnabled = val;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('vibration_enabled', val);
    }).catchError((e) {});
  }

  void _playHaptic(String type) {
    if (!_isVibrationEnabled) return;
    try {
      if (type == 'success' || type == 'warning' || type == 'error') {
        js.context['Telegram']['WebApp']['HapticFeedback'].callMethod('notificationOccurred', [type]);
      } else {
        js.context['Telegram']['WebApp']['HapticFeedback'].callMethod('impactOccurred', [type]);
      }
    } catch(e) {}
  }

  Future<void> _playSound(String url) async {
    if (!_isSoundEnabled) return;
    try {
      await _audioPlayer.play(UrlSource(url));
    } catch(e) {}
  }

  @override
  void dispose() {
    _walletTimer?.cancel();
    _uiTimer?.cancel();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _initTelegramAndSocket() {
    try {
      js.context.callMethod('initTonConnect');
    } catch(e) {
      print("Failed to init ton connect: $e");
    }

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

    socket.on('error', (msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.t(msg.toString()), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      }
    });

    socket.on('daily_bonus_success', (msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.t(msg.toString()), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      }
    });

    socket.on('daily_bonus_error', (msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.t(msg.toString()), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      }
    });

    socket.on('withdrawal_success', (msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.t(msg.toString()), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      }
    });

    socket.on('withdrawal_error', (msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.t(msg.toString()), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      }
    });

    socket.on('exchange_success', (msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.t(msg.toString()), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      }
    });

    socket.onDisconnect((_) {
      if (mounted) setState(() {
        _isConnected = false;
      });
    });
  }

  Widget _buildLobby() {
    if (!_isConnected) return const Center(child: CircularProgressIndicator());
    
    // 1. Filter rooms by currency and price
    List<dynamic> filteredRooms = rooms.where((r) {
      String roomCurrency = r['currency'] ?? 'REAL';
      int roomPrice = (r['cellPrice'] as num).toInt();
      return roomCurrency == _selectedCurrency && roomPrice == _selectedPrice;
    }).toList();

    // 2. Sort by room index (stable sorting)
    filteredRooms.sort((a, b) {
      int getIndex(dynamic r) {
        if (r['id'] == null) return 0;
        final match = RegExp(r'\d+').firstMatch(r['id'].toString());
        return match != null ? int.parse(match.group(0)!) : 0;
      }
      int numA = getIndex(a);
      int numB = getIndex(b);
      return _sortRoomsAscending ? numA.compareTo(numB) : numB.compareTo(numA);
    });

    return Column(
      children: [
        // Currency Selector
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: Text(AppTranslations.t('real_rooms')),
                selected: _selectedCurrency == 'REAL',
                selectedColor: Colors.green.withOpacity(0.3),
                onSelected: (val) {
                  if (val) setState(() => _selectedCurrency = 'REAL');
                },
              ),
              const SizedBox(width: 16),
              ChoiceChip(
                label: Text(AppTranslations.t('bonus_rooms')),
                selected: _selectedCurrency == 'BONUS',
                selectedColor: Colors.blue.withOpacity(0.3),
                onSelected: (val) {
                  if (val) setState(() => _selectedCurrency = 'BONUS');
                },
              ),
            ],
          ),
        ),
        
        // Price Selector and Sort Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [5, 10, 20, 30, 50].map((price) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text('$price'),
                          selected: _selectedPrice == price,
                          selectedColor: Colors.amber.withOpacity(0.3),
                          onSelected: (val) {
                            if (val) setState(() => _selectedPrice = price);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(_sortRoomsAscending ? Icons.arrow_downward : Icons.arrow_upward, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    _sortRoomsAscending = !_sortRoomsAscending;
                  });
                },
                tooltip: 'Сортировка',
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Rooms List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: filteredRooms.length,
            itemBuilder: (context, index) {
              var room = filteredRooms[index];
              bool isFull = room['playersCount'] >= room['maxPlayers'];
              
              String translatedRoomName = AppTranslations.t(room['name'] ?? '');
              if (room['currency'] != null) {
                String prefix = room['currency'] == 'REAL' ? AppTranslations.t('real_room') : AppTranslations.t('bonus_room');
                String roomIdx = room['id'].toString().split('_').last;
                translatedRoomName = '$prefix ${room['cellPrice']} (${AppTranslations.t('room')} $roomIdx)';
              }

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
                      Icon(Icons.monetization_on, color: _selectedCurrency == 'REAL' ? Colors.green : Colors.blue, size: 20),
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
                    
                    var myData = users[_myTelegramId] ?? {};
                    num realBalance = (myData['balance_real'] ?? 0) as num;
                    num bonusBalance = (myData['balance_bonus'] ?? 0) as num;
                    num cellPrice = (room['cellPrice'] ?? 0) as num;
                    bool isRealRoom = room['currency'] == 'REAL';

                    if (isRealRoom && realBalance < cellPrice) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppTranslations.t('not_enough_funds_deposit'))),
                      );
                      return;
                    } else if (!isRealRoom && bonusBalance < cellPrice) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppTranslations.t('not_enough_funds_deposit'))),
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
                          playHaptic: _playHaptic,
                          playSound: _playSound,
                          confettiController: _confettiController,
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
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboard() {
    var sortedUsers = users.values.toList();
    if (_selectedCurrency == 'REAL') {
      sortedUsers.sort((a, b) => ((b['stats']?['totalWonReal'] ?? 0) as num).compareTo((a['stats']?['totalWonReal'] ?? 0) as num));
    } else {
      sortedUsers.sort((a, b) => ((b['stats']?['totalWonBonus'] ?? 0) as num).compareTo((a['stats']?['totalWonBonus'] ?? 0) as num));
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: Text(AppTranslations.t('real_rooms')),
                selected: _selectedCurrency == 'REAL',
                selectedColor: Colors.green.withOpacity(0.3),
                onSelected: (val) {
                  if (val) setState(() => _selectedCurrency = 'REAL');
                },
              ),
              const SizedBox(width: 16),
              ChoiceChip(
                label: Text(AppTranslations.t('bonus_rooms')),
                selected: _selectedCurrency == 'BONUS',
                selectedColor: Colors.blue.withOpacity(0.3),
                onSelected: (val) {
                  if (val) setState(() => _selectedCurrency = 'BONUS');
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: sortedUsers.length,
            itemBuilder: (context, index) {
              var u = sortedUsers[index];
              var stats = u['stats'] ?? {};
              var wonValue = _selectedCurrency == 'REAL' ? (stats['totalWonReal'] ?? 0) : (stats['totalWonBonus'] ?? 0);
              var iconColor = _selectedCurrency == 'REAL' ? Colors.green : Colors.blue;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: iconColor.withOpacity(0.3),
                  backgroundImage: u['photo_url'] != null && u['photo_url'].toString().isNotEmpty
                      ? NetworkImage('$backendUrl/avatar?url=${Uri.encodeComponent(u['photo_url'])}')
                      : null,
                  child: u['photo_url'] == null || u['photo_url'].toString().isEmpty
                      ? Text('${index + 1}', style: TextStyle(color: Colors.white))
                      : null,
                ),
                title: Text(u['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monetization_on, color: iconColor, size: 20),
                    const SizedBox(width: 6),
                    Text('$wonValue', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildQuests() {
    var myData = users[_myTelegramId] ?? {};
    var lastClaim = (myData['lastBonusClaim'] ?? 0) as num;
    var now = DateTime.now().millisecondsSinceEpoch;
    var cooldown = 24 * 60 * 60 * 1000;
    var timePassed = now - lastClaim;
    bool canClaim = timePassed >= cooldown;

    String timerText = '';
    if (!canClaim) {
      var remaining = cooldown - timePassed;
      var h = (remaining / (1000 * 60 * 60)).floor();
      var m = ((remaining % (1000 * 60 * 60)) / (1000 * 60)).floor();
      var s = ((remaining % (1000 * 60)) / 1000).floor();
      timerText = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          
          Card(
            color: Colors.blueAccent.withOpacity(0.05),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.blueAccent.withOpacity(0.3))),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Icon(Icons.card_giftcard, size: 64, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  Text(AppTranslations.t('daily_bonus'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('+10 Бонусных Монет', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      backgroundColor: canClaim ? Colors.green : Colors.grey.withOpacity(0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: canClaim ? () {
                      socket.emit('claim_daily_bonus');
                    } : null,
                    child: Text(canClaim ? AppTranslations.t('claim') : timerText, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 48),

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
               String botUrl = 'https://t.me/GridLottery_bot/app?startapp=ref_$_myTelegramId';
               String text = AppTranslations.langCode == 'ru' ? 'Присоединяйся к игре и получи 50 монет!' : 'Join the game and get 50 coins!';
               String encodedBotUrl = Uri.encodeComponent(botUrl);
               String encodedText = Uri.encodeComponent(text);
               String shareUrl = 'https://t.me/share/url?url=$encodedBotUrl&text=$encodedText';
               try {
                 js.context['Telegram']['WebApp'].callMethod('openTelegramLink', [shareUrl]);
               } catch(e) {
                 print(shareUrl);
               }
            },
          ),
        ],
      ),
    );
  }

  
  Widget _buildDepositDialog() {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(AppTranslations.t('deposit'), style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDepositOption(1, 1000),
          const SizedBox(height: 10),
          _buildDepositOption(5, 5000),
          const SizedBox(height: 10),
          _buildDepositOption(10, 10000),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppTranslations.t('cancel'), style: const TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _buildDepositOption(int gram, int coins) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent.withOpacity(0.2),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () {
        final amountNano = gram * 1000000000;
        final wallet = 'UQBxu51QZAAzUfi1WJLSS6SOYuEDu9W18Bsjw4ZfCMtF_TUh';
        final memo = 'deposit_$_myTelegramId';
        try {
          js.context.callMethod('sendTonTransaction', [
            wallet, 
            amountNano.toString(), 
            memo,
            AppTranslations.t('error_funds'),
            AppTranslations.t('error_tx')
          ]);
        } catch (e) {
          print(e);
        }
        Navigator.pop(context);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$gram Gram', style: const TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          const Icon(Icons.arrow_forward, color: Colors.white54),
          Row(
            children: [
              Text('$coins ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.amber)),
              const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildWithdrawDialog() {
    var myData = users[_myTelegramId];
    int maxAmount = (myData != null && myData['balance_real'] != null) ? (myData['balance_real'] as num).toInt() : 0;
    
    int amount = maxAmount >= 500 ? 500 : maxAmount;
    String wallet = _connectedWallet ?? '';
    
    TextEditingController amountController = TextEditingController(text: amount > 0 ? amount.toString() : '');
    TextEditingController walletController = TextEditingController(text: wallet)..selection = TextSelection.collapsed(offset: wallet.length);
    
    return StatefulBuilder(builder: (context, setState) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(AppTranslations.t('withdraw'), style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${AppTranslations.t('real_balance')}: $maxAmount', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                InkWell(
                  onTap: () {
                    setState(() {
                      amount = maxAmount;
                      amountController.text = amount.toString();
                    });
                  },
                  child: const Text('MAX', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ],
            ),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: AppTranslations.t('amount'),
                labelStyle: const TextStyle(color: Colors.white54),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => amount = int.tryParse(v) ?? 0,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: AppTranslations.t('enter_wallet'),
                labelStyle: const TextStyle(color: Colors.white54),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
              controller: walletController,
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => wallet = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.t('cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              socket.emit('request_withdrawal', {'amount': amount, 'wallet': wallet});
              Navigator.pop(context);
            },
            child: Text(AppTranslations.t('withdraw_btn'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      );
    });
  }

  Widget _buildProfile() {
    var myData = users[_myTelegramId];
    if (myData == null) return const Center(child: CircularProgressIndicator());
    var stats = myData['stats'] ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white12,
            backgroundImage: _myPhotoUrl.isNotEmpty 
                ? NetworkImage('$backendUrl/avatar?url=${Uri.encodeComponent(_myPhotoUrl)}') 
                : null,
            child: _myPhotoUrl.isEmpty ? const Icon(Icons.person, size: 40) : null,
          ),
          const SizedBox(height: 8),
          Text(_myName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            color: Colors.white.withOpacity(0.05),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${AppTranslations.t('real_balance')} (~${(((myData['balance_real'] ?? 0) as num) / 1000).toString()} Gram)', style: const TextStyle(fontSize: 14)),
                      Row(
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text('${myData['balance_real'] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      )
                    ],
                  ),
                  if (((myData['balance_locked'] ?? 0) as num) > 0) ...[
                    const Divider(color: Colors.white12, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('На подтверждении на вывод:', style: TextStyle(fontSize: 14, color: Colors.amber)),
                        Row(
                          children: [
                            const Icon(Icons.lock_clock, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Text('${myData['balance_locked']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
                          ],
                        )
                      ],
                    ),
                  ],
                  const Divider(color: Colors.white12, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppTranslations.t('bonus_balance'), style: const TextStyle(fontSize: 14)),
                      Row(
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text('${myData['balance_bonus'] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      minimumSize: const Size(double.infinity, 40),
                    ),
                    icon: const Icon(Icons.sync_alt, color: Colors.blueAccent),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(AppTranslations.t('exchange_btn_1'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const Icon(Icons.monetization_on, color: Colors.blue, size: 18),
                        Text(AppTranslations.t('exchange_btn_2'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const Icon(Icons.monetization_on, color: Colors.green, size: 18),
                      ],
                    ),
                    onPressed: () {
                      if (((myData['balance_bonus'] ?? 0) as num) >= 10000) {
                        socket.emit('exchange_coins');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppTranslations.t('error_exchange_not_enough'))),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: Text(AppTranslations.t('games_played')),
            trailing: Text('${stats['gamesPlayed'] ?? 0}', style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text(AppTranslations.t('total_won_real')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.monetization_on, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text('${stats['totalWonReal'] ?? 0}', style: const TextStyle(fontSize: 18)),
            ]),
          ),
          ListTile(
            title: Text(AppTranslations.t('total_won_bonus')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.monetization_on, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text('${stats['totalWonBonus'] ?? 0}', style: const TextStyle(fontSize: 18)),
            ]),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(AppTranslations.t('settings'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
            ),
          ),
          SwitchListTile(
            title: Text(AppTranslations.t('sound')),
            value: _isSoundEnabled,
            onChanged: _toggleSound,
            activeColor: Colors.blueAccent,
            secondary: Icon(_isSoundEnabled ? Icons.volume_up : Icons.volume_off, color: Colors.blueAccent),
          ),
          SwitchListTile(
            title: Text(AppTranslations.t('vibration')),
            value: _isVibrationEnabled,
            onChanged: _toggleVibration,
            activeColor: Colors.blueAccent,
            secondary: Icon(_isVibrationEnabled ? Icons.vibration : Icons.smartphone, color: Colors.blueAccent),
          ),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          
          if (_connectedWallet != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.05),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.blueAccent.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wallet, color: Colors.blueAccent, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppTranslations.t('connected_wallet'), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          '${_connectedWallet!.substring(0, 4)}...${_connectedWallet!.substring(_connectedWallet!.length - 4)}',
                          style: const TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.15),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      try { js.context.callMethod('disconnectWallet'); } catch(e) {}
                    },
                    child: Text(AppTranslations.t('unlink'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              backgroundColor: Colors.greenAccent.withOpacity(0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            icon: const Icon(Icons.account_balance_wallet, color: Colors.greenAccent),
            label: Text(AppTranslations.t('deposit'), style: const TextStyle(fontSize: 20, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => _buildDepositDialog(),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              backgroundColor: Colors.blueAccent.withOpacity(0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            icon: const Icon(Icons.account_balance_wallet, color: Colors.blueAccent),
            label: Text(AppTranslations.t('withdraw'), style: const TextStyle(fontSize: 20, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => _buildWithdrawDialog(),
              );
            },
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
        actions: [
          if (_currentIndex == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monetization_on,
                      color: _selectedCurrency == 'REAL' ? Colors.green : Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatBalance((users[_myTelegramId]?['balance_${_selectedCurrency.toLowerCase()}'] ?? 0) as num),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _selectedCurrency == 'REAL' ? Colors.green : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
  final Function(String) playHaptic;
  final Function(String) playSound;
  final ConfettiController confettiController;

  const GameScreen({
    super.key,
    required this.socket,
    required this.roomId,
    required this.backendUrl,
    required this.userData,
    required this.playHaptic,
    required this.playSound,
    required this.confettiController,
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
  bool _showEmojis = false;

  void _onUsersUpdate(dynamic data) {
    if (mounted) setState(() {
      if (data is Map) {
        var k = data[widget.userData['telegram_id']] ?? data[int.tryParse(widget.userData['telegram_id']) ?? -1];
        if (k != null) {
          String roomType = 'REAL';
          if (widget.roomId.split('_').length > 1) {
            roomType = widget.roomId.split('_')[1];
          }
          if (roomType == 'REAL') {
            _coins = ((k['balance_real'] ?? 0) as num).toInt();
          } else {
            _coins = ((k['balance_bonus'] ?? 0) as num).toInt();
          }
        }
      }
    });
  }

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
        String oldPhase = _phase;
        if (data['phase'] != null) _phase = data['phase'];
        if (oldPhase == 'WAITING' && _phase == 'BETTING') {
           widget.playHaptic('warning');
           widget.playSound('https://actions.google.com/sounds/v1/alarms/beep_short.ogg'); // neutral start beep
        }

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
            if (rd['telegram_id'].toString() == widget.userData['telegram_id'].toString()) {
               widget.playHaptic('success');
               widget.playSound('https://assets.mixkit.co/active_storage/sfx/2013/2013-preview.mp3'); // win fanfare
               widget.confettiController.play();
            }
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

    widget.socket.on('users_update', _onUsersUpdate);

    widget.socket.on('roulette_tick', (index) {
      widget.playHaptic('light');
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
    widget.socket.off('users_update', _onUsersUpdate);
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
            Icon(Icons.monetization_on, color: widget.roomId.split('_')[1] == 'REAL' ? Colors.green : Colors.blue),
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
                                widget.playHaptic('light');
                                widget.playSound('https://actions.google.com/sounds/v1/ui/button_click.ogg');
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
                
                const SizedBox(height: 20),
                _buildEmojiPicker(),
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
      Align(
        alignment: Alignment.center,
        child: ConfettiWidget(
          confettiController: widget.confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
          numberOfParticles: 50,
          gravity: 0.1,
        ),
      ),
    ],),
    );
  }

  Widget _buildEmojiPicker() {
    if (!_showEmojis) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent.withOpacity(0.8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          icon: const Icon(Icons.emoji_emotions, color: Colors.white),
          label: Text(AppTranslations.t('emojis_btn'), style: const TextStyle(color: Colors.white)),
          onPressed: () {
            setState(() { _showEmojis = true; });
          },
        ),
      );
    }

    final emojis = ['👍', '😂', '😭', '😡', '🎉', '🤑'];
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ...emojis.map((e) => GestureDetector(
            onTap: () {
              widget.socket.emit('send_emoji', e);
              setState(() { _showEmojis = false; });
            },
            child: Text(e, style: const TextStyle(fontSize: 32)),
          )).toList(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () {
              setState(() { _showEmojis = false; });
            },
          )
        ],
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

