import 'package:flutter/material.dart';
import 'dart:async';
import 'hoskin_models.dart';
import 'hoskin_deck.dart';
import '../ai/hoskin_meld_engine.dart';
import '../ai/hoskin_bot_ai.dart';

/// Hoşkin Oyun Motoru
/// State yönetimi ve oyun akışı
class HoskinGameEngine extends ChangeNotifier {
  // Oyun durumu
  GamePhase _phase = GamePhase.bidding;
  final HoskinDeck _deck = HoskinDeck();
  final List<HoskinPlayer> _players = [];
  final List<HoskinTeam> _teams = [];
  
  // İhale bilgileri
  int _currentBidder = 0;
  int _highestBid = 0;
  int? _winnerSeat;
  int _passCount = 0;
  
  // Oyun bilgileri
  Suit? _trump;
  int _currentPlayer = 0;
  final List<HoskinCard> _tableCards = [];
  int _trickLeader = 0;
  int _playOrderCounter = 0;
  
  // Açılan kartlar (ihale kazananı için)
  final List<HoskinCard> _openCards = [];
  
  // Bot AI
  final Map<int, HoskinBotAI> _bots = {};
  
  // UI için
  int? _selectedCardIndex;
  bool _showMelds = false;
  
  // Getters
  GamePhase get phase => _phase;
  List<HoskinPlayer> get players => List.unmodifiable(_players);
  List<HoskinTeam> get teams => List.unmodifiable(_teams);
  List<HoskinCard> get playerHand => _players[0].hand;
  List<HoskinCard> get tableCards => List.unmodifiable(_tableCards);
  List<HoskinCard> get openCards => List.unmodifiable(_openCards);
  
  int get currentBidder => _currentBidder;
  int get highestBid => _highestBid;
  int? get winnerSeat => _winnerSeat;
  int get currentPlayer => _currentPlayer;
  Suit? get trump => _trump;
  int? get selectedCardIndex => _selectedCardIndex;
  bool get showMelds => _showMelds;
  
  HoskinPlayer get humanPlayer => _players[0];
  
  HoskinGameEngine({BotDifficulty botDifficulty = BotDifficulty.medium}) {
    _initializePlayers();
    _initializeTeams();
    _initializeBots(botDifficulty);
  }

  void _initializePlayers() {
    _players.clear();
    _players.addAll([
      HoskinPlayer(seat: 0, name: 'Sen', isBot: false, teamId: 0),
      HoskinPlayer(seat: 1, name: 'Bot 1', isBot: true, teamId: 1),
      HoskinPlayer(seat: 2, name: 'Takım Arkadaşın', isBot: true, teamId: 0),
      HoskinPlayer(seat: 3, name: 'Bot 3', isBot: true, teamId: 1),
    ]);
  }

  void _initializeTeams() {
    _teams.clear();
    _teams.addAll([
      HoskinTeam(id: 0, playerSeats: [0, 2]),
      HoskinTeam(id: 1, playerSeats: [1, 3]),
    ]);
  }

  void _initializeBots(BotDifficulty difficulty) {
    _bots.clear();
    for (int i = 1; i < 4; i++) {
      _bots[i] = HoskinBotAI(difficulty: difficulty);
    }
  }

  /// Oyunu başlat
  void startGame() {
    _resetRound();
    _dealCards();
    _phase = GamePhase.bidding;
    _currentBidder = 0;
    _highestBid = 70; // Minimum ihale
    _passCount = 0;
    notifyListeners();
    
    // Bot başlangıçsa ihale yap
    if (_currentBidder != 0) {
      _scheduleBotBid();
    }
  }

  void _resetRound() {
    for (final player in _players) {
      player.clearHand();
    }
    for (final team in _teams) {
      team.resetRound();
    }
    _tableCards.clear();
    _openCards.clear();
    _trump = null;
    _winnerSeat = null;
    _selectedCardIndex = null;
    _showMelds = false;
    
    for (final bot in _bots.values) {
      bot.resetMemory();
    }
  }

  void _dealCards() {
    final hands = _deck.deal();
    for (int i = 0; i < 4; i++) {
      _players[i].hand = hands[i];
      _players[i].sortHand();
    }
  }

  /// İNSAN İHALE YAPMA
  void placeBid(int amount) {
    if (_phase != GamePhase.bidding) return;
    if (_currentBidder != 0) return;
    if (amount <= _highestBid) return;

    _highestBid = amount;
    _winnerSeat = 0;
    _passCount = 0;
    _advanceBidder();
  }

  void passBid() {
    if (_phase != GamePhase.bidding) return;
    if (_currentBidder != 0) return;

    _passCount++;
    _advanceBidder();
  }

  void _advanceBidder() {
    _currentBidder = (_currentBidder + 1) % 4;
    
    // 3 kişi pas geçtiyse ihale bitti
    if (_passCount >= 3) {
      _finishBidding();
    } else {
      notifyListeners();
      if (_currentBidder != 0) {
        _scheduleBotBid();
      }
    }
  }

  void _scheduleBotBid() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_phase != GamePhase.bidding) return;
      _botMakeBid();
    });
  }

  void _botMakeBid() {
    final bot = _bots[_currentBidder]!;
    final player = _players[_currentBidder];
    
    final decision = bot.decideBid(
      hand: player.hand,
      currentBid: _highestBid,
      isFirstBidder: _passCount == 0 && _winnerSeat == null,
    );

    if (decision.shouldBid) {
      _highestBid = decision.amount;
      _winnerSeat = _currentBidder;
      _passCount = 0;
    } else {
      _passCount++;
    }

    _advanceBidder();
  }

  void _finishBidding() {
    if (_winnerSeat == null) {
      // Kimse ihale almadı, yeniden dağıt
      startGame();
      return;
    }

    _phase = GamePhase.opening;
    _currentPlayer = _winnerSeat!;
    
    // Barış puanlarını hesapla
    _calculateAllMelds();
    
    notifyListeners();

    // İhale kazananı bot ise otomatik kart aç
    if (_currentPlayer != 0) {
      _scheduleBotOpenCards();
    }
  }

  void _calculateAllMelds() {
    for (final player in _players) {
      final melds = HoskinMeldEngine.calculateMelds(player.hand);
      _teams[player.teamId].meldPoints += melds.totalPoints;
    }
  }

  /// KART AÇMA (4 kart seç ve kozu belirle)
  void selectOpenCards(List<int> indices) {
    if (_phase != GamePhase.opening) return;
    if (_currentPlayer != 0) return;
    if (indices.length != 4) return;

    _openCards.clear();
    for (final index in indices.reversed) {
      _openCards.add(playerHand.removeAt(index));
    }

    _phase = GamePhase.selectingTrump;
    notifyListeners();
  }

  void selectTrump(Suit suit) {
    if (_phase != GamePhase.selectingTrump) return;
    if (_currentPlayer != 0) return;

    _trump = suit;
    _startPlaying();
  }

  void _scheduleBotOpenCards() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (_phase != GamePhase.opening) return;
      _botOpenCards();
    });
  }

  void _botOpenCards() {
    final bot = _bots[_currentPlayer]!;
    final player = _players[_currentPlayer];

    // En düşük 4 kartı aç
    final sorted = List<HoskinCard>.from(player.hand);
    sorted.sort((a, b) => a.points.compareTo(b.points));

    for (int i = 0; i < 4; i++) {
      _openCards.add(sorted[i]);
      player.hand.remove(sorted[i]);
    }

    // Kozu seç
    final decision = bot.selectTrump(
      hand: player.hand,
      openCards: _openCards,
    );
    _trump = decision.trump;

    _startPlaying();
  }

  void _startPlaying() {
    _phase = GamePhase.playing;
    _trickLeader = _winnerSeat!;
    _currentPlayer = _trickLeader;
    notifyListeners();

    if (_currentPlayer != 0) {
      _scheduleBotPlay();
    }
  }

  /// KART OYNAMA
  void selectCard(int index) {
    if (_phase != GamePhase.playing) return;
    if (_currentPlayer != 0) return;

    _selectedCardIndex = index;
    notifyListeners();
  }

  void playSelectedCard() {
    if (_selectedCardIndex == null) return;
    if (_currentPlayer != 0) return;

    final card = humanPlayer.playCard(_selectedCardIndex!);
    _playCard(card);
    _selectedCardIndex = null;
  }

  void _scheduleBotPlay() {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (_phase != GamePhase.playing) return;
      _botPlayCard();
    });
  }

  void _botPlayCard() {
    final bot = _bots[_currentPlayer]!;
    final player = _players[_currentPlayer];

    final decision = bot.selectCard(
      hand: player.hand,
      tableCards: _tableCards,
      trump: _trump,
      isLeading: _tableCards.isEmpty,
      position: _currentPlayer,
    );

    player.hand.remove(decision.card);
    _playCard(decision.card);
  }

  void _playCard(HoskinCard card) {
    final cardWithOrder = card.withPlayOrder(_playOrderCounter++);
    _tableCards.add(cardWithOrder);
    
    if (_tableCards.length == 4) {
      // El tamamlandı
      _finishTrick();
    } else {
      _currentPlayer = (_currentPlayer + 1) % 4;
      notifyListeners();

      if (_currentPlayer != 0) {
        _scheduleBotPlay();
      }
    }
  }

  void _finishTrick() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      final winner = _findTrickWinner();
      final winnerPlayer = _players[winner];

      // Kartları topla
      winnerPlayer.collectCards(_tableCards);
      
      // Puan hesapla
      final points = _tableCards.fold(0, (sum, card) => sum + card.points);
      _teams[winnerPlayer.teamId].gamePoints += points;

      _tableCards.clear();
      _trickLeader = winner;
      _currentPlayer = winner;

      // Tüm kartlar bitti mi?
      if (winnerPlayer.hand.isEmpty) {
        _finishRound();
      } else {
        notifyListeners();
        if (_currentPlayer != 0) {
          _scheduleBotPlay();
        }
      }
    });
  }

  int _findTrickWinner() {
    if (_tableCards.isEmpty) return _trickLeader;

    var winnerIndex = 0;
    var winnerCard = _tableCards[0];
    final leadSuit = _tableCards[0].suit;

    for (int i = 1; i < _tableCards.length; i++) {
      final comp = DeckHelper.compareCards(
        _tableCards[i],
        winnerCard,
        leadSuit: leadSuit,
        trump: _trump,
      );
      
      if (comp > 0) {
        winnerIndex = i;
        winnerCard = _tableCards[i];
      }
    }

    return (_trickLeader + winnerIndex) % 4;
  }

  void _finishRound() {
    _phase = GamePhase.scoring;
    
    // İhale kontrol
    final winnerTeam = _teams[_players[_winnerSeat!].teamId];
    final total = winnerTeam.calculateTotal();

    if (total >= _highestBid) {
      // İhale başarılı
      winnerTeam.updateScore();
    } else {
      // İhale batık
      winnerTeam.totalScore -= _highestBid;
    }

    // Diğer takım her zaman puanını alır
    final otherTeam = _teams[1 - _players[_winnerSeat!].teamId];
    otherTeam.updateScore();

    notifyListeners();
  }

  void nextRound() {
    if (_phase != GamePhase.scoring) return;
    startGame();
  }

  void toggleShowMelds() {
    _showMelds = !_showMelds;
    notifyListeners();
  }

  /// Oynanabilir kart indexleri
  Set<int> getPlayableIndices() {
    if (_phase != GamePhase.playing) return {};
    if (_currentPlayer != 0) return {};

    final legal = _getLegalCardIndices();
    return legal;
  }

  Set<int> _getLegalCardIndices() {
    if (_tableCards.isEmpty) {
      return Set.from(List.generate(playerHand.length, (i) => i));
    }

    final leadSuit = _tableCards.first.suit;
    final indices = <int>{};

    for (int i = 0; i < playerHand.length; i++) {
      if (playerHand[i].suit == leadSuit) {
        indices.add(i);
      }
    }

    // Renk yoksa hepsi oynayabilir
    return indices.isEmpty 
        ? Set.from(List.generate(playerHand.length, (i) => i))
        : indices;
  }
}

/// Oyun aşamaları
enum GamePhase {
  bidding, // İhale
  opening, // Kart açma (4 kart seç)
  selectingTrump, // Koz seçimi
  playing, // Oyun
  scoring, // Skor
}
