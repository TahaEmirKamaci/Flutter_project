import 'dart:math';
import 'package:flutter/material.dart';
import 'game_core.dart';

/// Batak Oyun Motoru
/// 4 kişilik, ihale bazlı el toplama oyunu
class BatakEngine extends ChangeNotifier implements GameEngine {
  final Random _random = Random();
  
  @override
  final GameType type = GameType.bridge; // Placeholder, yeni enum eklenebilir
  
  @override
  GameStatePhase phase = GameStatePhase.bidding;
  
  @override
  List<String> playerHand = [];
  
  @override
  List<String> tableCards = [];
  
  @override
  int activePlayerIndex = 0;
  
  @override
  int leaderIndex = 0;
  
  @override
  bool isDealing = false;
  
  int? _selectedIndex;
  @override
  int? get selectedIndex => _selectedIndex;
  
  // 4 oyuncu eli
  late List<List<String>> hands;
  
  @override
  List<int> get handCounts => [for (final h in hands) h.length];
  
  // İhale bilgileri
  bool _isBidding = true;
  @override
  bool get isBidding => _isBidding;
  
  int _currentBidder = 0;
  @override
  int get currentBidderIndex => _currentBidder;
  
  int _highestBid = 0;
  int? _bidWinner;
  String? _trump;
  
  @override
  int get contractLevel => _highestBid;
  
  @override
  String? get trump => _trump;
  
  final List<String> _bidHistory = [];
  @override
  List<String> get bidHistory => List.unmodifiable(_bidHistory);
  
  // Oyun bilgileri
  final List<int> _tricks = [0, 0, 0, 0]; // Her oyuncunun kazandığı el sayısı
  final List<int> _predictions = [0, 0, 0, 0]; // Her oyuncunun tahmini
  final List<int> _totalScores = [0, 0, 0, 0]; // Toplam skorlar
  
  @override
  List<int> get scores => List.unmodifiable(_totalScores);
  
  int? get currentBidder => _bidWinner;
  List<int> get tricksCaptured => List.unmodifiable(_tricks);
  List<int> get predictions => List.unmodifiable(_predictions);
  List<int> get totalScores => List.unmodifiable(_totalScores);
  
  BatakEngine() {
    _startNewRound();
  }
  
  void _startNewRound() {
    _dealCards();
    _isBidding = true;
    _currentBidder = 0;
    _highestBid = 0;
    _bidWinner = null;
    _trump = null;
    _bidHistory.clear();
    _tricks.fillRange(0, 4, 0);
    _predictions.fillRange(0, 4, 0);
    phase = GameStatePhase.bidding;
    activePlayerIndex = 0;
    notifyListeners();
    
    // Bot ihalesi
    if (_currentBidder != 0) {
      _scheduleBotBid();
    }
  }
  
  void _dealCards() {
    final deck = _createDeck();
    deck.shuffle(_random);
    
    hands = [[], [], [], []];
    for (int i = 0; i < 52; i++) {
      hands[i % 4].add(deck[i]);
    }
    
    // Kartları sırala
    for (final hand in hands) {
      hand.sort(_compareCards);
    }
    
    playerHand = hands[0];
    tableCards.clear();
  }
  
  List<String> _createDeck() {
    const suits = ['♠', '♥', '♦', '♣'];
    const ranks = ['A', 'K', 'Q', 'J', '10', '9', '8', '7', '6', '5', '4', '3', '2'];
    return [for (final suit in suits) for (final rank in ranks) '$rank$suit'];
  }
  
  int _compareCards(String a, String b) {
    final suitA = a.substring(a.length - 1);
    final suitB = b.substring(b.length - 1);
    
    if (suitA != suitB) return suitA.compareTo(suitB);
    
    return _rankPower(a) - _rankPower(b);
  }
  
  int _rankPower(String card) {
    final rank = card.substring(0, card.length - 1);
    const ranks = ['A', 'K', 'Q', 'J', '10', '9', '8', '7', '6', '5', '4', '3', '2'];
    return ranks.indexOf(rank);
  }
  
  /// İHALE YAPMA
  @override
  void placeBid({required int level, required String? trump, required bool pass}) {
    if (!_isBidding) return;
    if (_currentBidder != 0) return; // Sadece oyuncu
    
    if (pass) {
      _bidHistory.add('Pas');
      _advanceBidder();
      return;
    }
    
    if (level <= _highestBid) return;
    if (level < 1 || level > 13) return;
    
    _highestBid = level;
    _bidWinner = _currentBidder;
    _trump = trump;
    _bidHistory.add('$level ${trump ?? 'NT'}');
    
    _advanceBidder();
  }
  
  void _advanceBidder() {
    _currentBidder = (_currentBidder + 1) % 4;
    
    // 4 tur tamamlandıysa ihale bitti
    if (_bidHistory.length >= 4) {
      _finishBidding();
    } else {
      notifyListeners();
      if (_currentBidder != 0) {
        _scheduleBotBid();
      }
    }
  }
  
  void _scheduleBotBid() {
    Future.delayed(const Duration(milliseconds: 600), _botBid);
  }
  
  void _botBid() {
    if (!_isBidding) return;
    
    final hand = hands[_currentBidder];
    final analysis = _analyzeHand(hand);
    
    // Basit bot mantığı
    final shouldBid = analysis['strength'] > 6 && 
                     (_highestBid == 0 || analysis['strength'] > _highestBid + 2);
    
    if (shouldBid) {
      final bid = min(analysis['strength'], 13);
      final trump = analysis['longestSuit'];
      
      _highestBid = bid;
      _bidWinner = _currentBidder;
      _trump = trump;
      _bidHistory.add('$bid ${trump ?? 'NT'}');
    } else {
      _bidHistory.add('Pas');
    }
    
    _advanceBidder();
  }
  
  Map<String, dynamic> _analyzeHand(List<String> hand) {
    final bySuit = <String, List<String>>{};
    for (final card in hand) {
      final suit = card.substring(card.length - 1);
      bySuit[suit] = (bySuit[suit] ?? [])..add(card);
    }
    
    String? longestSuit;
    int maxLen = 0;
    int strength = 0;
    
    bySuit.forEach((suit, cards) {
      if (cards.length > maxLen) {
        maxLen = cards.length;
        longestSuit = suit;
      }
      
      // As, Kral sayısı
      for (final card in cards) {
        final rank = card.substring(0, card.length - 1);
        if (rank == 'A') strength += 2;
        else if (rank == 'K') strength += 1;
      }
    });
    
    // Uzun renk bonusu
    strength += (maxLen - 4).clamp(0, 3);
    
    return {
      'strength': strength,
      'longestSuit': longestSuit,
      'longestLength': maxLen,
    };
  }
  
  void _finishBidding() {
    if (_bidWinner == null) {
      // Kimse almadı, yeniden dağıt
      _startNewRound();
      return;
    }
    
    _isBidding = false;
    
    // Tahmin aşaması - sadece ihale kazananı tahmin yapar
    _predictions[_bidWinner!] = _highestBid;
    
    // Diğer oyuncular 0 tahmin eder (Batak kuralı)
    for (int i = 0; i < 4; i++) {
      if (i != _bidWinner) _predictions[i] = 0;
    }
    
    phase = GameStatePhase.waitingForPlayer;
    leaderIndex = (_bidWinner! + 1) % 4; // İhale kazananın solundan başlar
    activePlayerIndex = leaderIndex;
    notifyListeners();
    
    if (activePlayerIndex != 0) {
      _scheduleBotPlay();
    }
  }
  
  /// KART SEÇME
  @override
  void selectCard(int index) {
    if (phase != GameStatePhase.waitingForPlayer) return;
    if (activePlayerIndex != 0) return;
    if (index < 0 || index >= playerHand.length) return;
    
    final playable = playableIndexes();
    if (!playable.contains(index)) return;
    
    _selectedIndex = _selectedIndex == index ? null : index;
    notifyListeners();
  }
  
  /// KART OYNAMA
  @override
  void playSelected() {
    if (_selectedIndex == null) return;
    if (activePlayerIndex != 0) return;
    
    final card = playerHand.removeAt(_selectedIndex!);
    _selectedIndex = null;
    tableCards.add(card);
    
    notifyListeners();
    
    activePlayerIndex = (activePlayerIndex + 1) % 4;
    
    if (tableCards.length < 4) {
      _scheduleBotPlay();
    } else {
      _resolveTrick();
    }
  }
  
  void _scheduleBotPlay() {
    Future.delayed(const Duration(milliseconds: 800), _botPlay);
  }
  
  void _botPlay() {
    if (activePlayerIndex == 0) return;
    
    final hand = hands[activePlayerIndex];
    final legal = _getLegalCards(hand);
    
    // Akıllı kart seçimi
    String cardToPlay;
    
    if (tableCards.isEmpty) {
      // İlk kart - en yüksek kartı at
      cardToPlay = _findHighestCard(legal);
    } else {
      // Kazanmaya çalış
      final winning = _findWinningCard(legal);
      if (winning != null) {
        cardToPlay = winning;
      } else {
        // En düşük kartı at
        cardToPlay = _findLowestCard(legal);
      }
    }
    
    hand.remove(cardToPlay);
    tableCards.add(cardToPlay);
    
    notifyListeners();
    
    activePlayerIndex = (activePlayerIndex + 1) % 4;
    
    if (tableCards.length < 4) {
      if (activePlayerIndex == 0) {
        phase = GameStatePhase.waitingForPlayer;
      } else {
        _scheduleBotPlay();
      }
    } else {
      _resolveTrick();
    }
  }
  
  List<String> _getLegalCards(List<String> hand) {
    if (tableCards.isEmpty) return List.from(hand);
    
    final leadSuit = tableCards.first.substring(tableCards.first.length - 1);
    final sameSuit = hand.where((c) => c.substring(c.length - 1) == leadSuit).toList();
    
    return sameSuit.isNotEmpty ? sameSuit : hand;
  }
  
  String _findHighestCard(List<String> cards) {
    return cards.reduce((a, b) => _rankPower(a) < _rankPower(b) ? a : b);
  }
  
  String _findLowestCard(List<String> cards) {
    return cards.reduce((a, b) => _rankPower(a) > _rankPower(b) ? a : b);
  }
  
  String? _findWinningCard(List<String> hand) {
    if (tableCards.isEmpty) return null;
    
    final currentWinner = _getTrickWinner();
    final leadSuit = tableCards.first.substring(tableCards.first.length - 1);
    
    for (final card in hand) {
      if (_beats(card, tableCards[currentWinner], leadSuit)) {
        return card;
      }
    }
    
    return null;
  }
  
  bool _beats(String card, String target, String leadSuit) {
    final cardSuit = card.substring(card.length - 1);
    final targetSuit = target.substring(target.length - 1);
    
    // Koz kontrolü
    if (_trump != null) {
      if (cardSuit == _trump && targetSuit != _trump) return true;
      if (cardSuit != _trump && targetSuit == _trump) return false;
    }
    
    // Aynı renk kontrolü
    if (cardSuit == targetSuit) {
      return _rankPower(card) < _rankPower(target);
    }
    
    // Lead suit kontrolü
    if (cardSuit == leadSuit && targetSuit != leadSuit) return true;
    
    return false;
  }
  
  int _getTrickWinner() {
    if (tableCards.isEmpty) return leaderIndex;
    
    int winner = 0;
    String winnerCard = tableCards[0];
    final leadSuit = tableCards[0].substring(tableCards[0].length - 1);
    
    for (int i = 1; i < tableCards.length; i++) {
      if (_beats(tableCards[i], winnerCard, leadSuit)) {
        winner = i;
        winnerCard = tableCards[i];
      }
    }
    
    return (leaderIndex + winner) % 4;
  }
  
  void _resolveTrick() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      final winner = _getTrickWinner();
      _tricks[winner]++;
      
      tableCards.clear();
      leaderIndex = winner;
      activePlayerIndex = winner;
      
      // El bitti mi?
      if (hands[0].isEmpty) {
        _calculateScores();
        phase = GameStatePhase.scoreUpdate;
      } else {
        phase = GameStatePhase.waitingForPlayer;
        if (activePlayerIndex != 0) {
          _scheduleBotPlay();
        }
      }
      
      notifyListeners();
    });
  }
  
  void _calculateScores() {
    // Batak skorlama
    for (int i = 0; i < 4; i++) {
      if (i == _bidWinner) {
        // İhale sahibi
        if (_tricks[i] >= _predictions[i]) {
          // Başarılı
          _totalScores[i] += _predictions[i] * 10;
        } else {
          // Batık
          _totalScores[i] -= _predictions[i] * 10;
        }
      } else {
        // Diğer oyuncular aldıkları el kadar puan
        _totalScores[i] += _tricks[i];
      }
    }
  }
  
  @override
  Set<int> playableIndexes() {
    if (activePlayerIndex != 0) return {};
    if (phase != GameStatePhase.waitingForPlayer) return {};
    
    final legal = _getLegalCards(playerHand);
    final indices = <int>{};
    
    for (int i = 0; i < playerHand.length; i++) {
      if (legal.contains(playerHand[i])) {
        indices.add(i);
      }
    }
    
    return indices;
  }
  
  @override
  void submitPrediction(int value) {
    // Batak'ta tahmin ihale ile birlikte yapılır
  }
  
  @override
  void newRound() {
    _startNewRound();
  }
}
