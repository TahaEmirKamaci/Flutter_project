import 'dart:math';
import 'package:flutter/material.dart';
import 'game_core.dart';

/// Gelişmiş Pişti Oyun Motoru
/// Oyuncu vs 3 Bot
class PistiGameEngine extends ChangeNotifier implements GameEngine {
  final Random _random = Random();
  
  @override
  final GameType type = GameType.pisti;
  
  @override
  GameStatePhase phase = GameStatePhase.waitingForPlayer;
  
  @override
  List<String> playerHand = [];
  
  @override
  List<String> tableCards = [];
  
  @override
  int activePlayerIndex = 0;
  
  @override
  int get leaderIndex => 0;
  
  @override
  bool get isDealing => false;
  
  int? _selectedIndex;
  @override
  int? get selectedIndex => _selectedIndex;
  
  // 4 oyuncu eli
  late List<List<String>> hands;
  
  @override
  List<int> get handCounts => [for (final h in hands) h.length];
  
  // Skorlar
  final List<int> _scores = [0, 0, 0, 0];
  final List<int> _pistiCounts = [0, 0, 0, 0];
  final List<int> _cardsCaptured = [0, 0, 0, 0];
  
  @override
  List<int> get scores => List.unmodifiable(_scores);
  
  List<int> get pistiCounts => List.unmodifiable(_pistiCounts);
  List<int> get cardsCaptured => List.unmodifiable(_cardsCaptured);
  
  List<String> _deck = [];
  String? _lastPlayedCard;
  
  @override
  bool get isBidding => false;
  
  @override
  int get contractLevel => 0;
  
  @override
  String? get trump => null;
  
  @override
  List<String> get bidHistory => const [];
  
  @override
  int get currentBidderIndex => 0;
  
  PistiGameEngine() {
    _startNewGame();
  }
  
  void _startNewGame() {
    _deck = _createDeck();
    _deck.shuffle(_random);
    
    hands = [[], [], [], []];
    tableCards.clear();
    _scores.fillRange(0, 4, 0);
    _pistiCounts.fillRange(0, 4, 0);
    _cardsCaptured.fillRange(0, 4, 0);
    
    // Masaya 4 kart aç
    for (int i = 0; i < 4; i++) {
      tableCards.add(_deck.removeLast());
    }
    
    // İlk dağıtım - her oyuncuya 4 kart
    _dealCards();
    
    activePlayerIndex = 0;
    phase = GameStatePhase.waitingForPlayer;
    notifyListeners();
  }
  
  void _dealCards() {
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (_deck.isNotEmpty) {
          hands[j].add(_deck.removeLast());
        }
      }
    }
    
    playerHand = hands[0];
    notifyListeners();
  }
  
  List<String> _createDeck() {
    const suits = ['♠', '♥', '♦', '♣'];
    const ranks = ['A', 'K', 'Q', 'J', '10', '9', '8', '7', '6', '5', '4', '3', '2'];
    return [for (final suit in suits) for (final rank in ranks) '$rank$suit'];
  }
  
  String _rankOf(String card) => card.substring(0, card.length - 1);
  String _suitOf(String card) => card.substring(card.length - 1);
  
  /// KART SEÇME
  @override
  void selectCard(int index) {
    if (phase != GameStatePhase.waitingForPlayer) return;
    if (activePlayerIndex != 0) return;
    if (index < 0 || index >= playerHand.length) return;
    
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
    
    _playCard(0, card);
  }
  
  void _playCard(int playerIndex, String card) {
    final topCard = tableCards.isNotEmpty ? tableCards.last : null;
    final captures = _canCapture(card, topCard);
    
    _lastPlayedCard = card;
    tableCards.add(card);
    
    phase = GameStatePhase.playingCard;
    notifyListeners();
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (captures) {
        final isPisti = tableCards.length == 2 && 
                       _rankOf(card) == _rankOf(topCard!) &&
                       _rankOf(card) != 'J';
        
        if (isPisti) {
          _pistiCounts[playerIndex]++;
        }
        
        _cardsCaptured[playerIndex] += tableCards.length;
        tableCards.clear();
      }
      
      // Sonraki oyuncu
      activePlayerIndex = (activePlayerIndex + 1) % 4;
      
      // Tüm eller boşaldı mı?
      if (hands[activePlayerIndex].isEmpty) {
        if (_deck.isNotEmpty) {
          _dealCards();
          activePlayerIndex = 0;
          phase = GameStatePhase.waitingForPlayer;
        } else {
          _calculateFinalScores();
          phase = GameStatePhase.scoreUpdate;
        }
      } else {
        if (activePlayerIndex == 0) {
          phase = GameStatePhase.waitingForPlayer;
        } else {
          phase = GameStatePhase.playingCard;
          _scheduleBotPlay();
        }
      }
      
      notifyListeners();
    });
  }
  
  bool _canCapture(String card, String? topCard) {
    if (topCard == null) return false;
    
    final cardRank = _rankOf(card);
    final topRank = _rankOf(topCard);
    
    // Vale (J) hepsini alır
    if (cardRank == 'J') return true;
    
    // Aynı değer
    if (cardRank == topRank) return true;
    
    return false;
  }
  
  void _scheduleBotPlay() {
    Future.delayed(const Duration(milliseconds: 1000), _botPlay);
  }
  
  void _botPlay() {
    if (activePlayerIndex == 0) return;
    if (phase == GameStatePhase.scoreUpdate) return;
    
    final hand = hands[activePlayerIndex];
    if (hand.isEmpty) return;
    
    // Akıllı kart seçimi
    final cardToPlay = _selectBestCard(hand);
    hand.remove(cardToPlay);
    
    _playCard(activePlayerIndex, cardToPlay);
  }
  
  String _selectBestCard(List<String> hand) {
    final topCard = tableCards.isNotEmpty ? tableCards.last : null;
    
    if (topCard == null) {
      // Masa boş - en düşük kartı at
      return _findLowestCard(hand);
    }
    
    final topRank = _rankOf(topCard);
    
    // 1. Vale varsa at (her şeyi alır)
    final jacks = hand.where((c) => _rankOf(c) == 'J').toList();
    if (jacks.isNotEmpty) return jacks.first;
    
    // 2. Eşleşen kart varsa at
    final matching = hand.where((c) => _rankOf(c) == topRank).toList();
    if (matching.isNotEmpty) {
      // Pişti yapma ihtimali - 2 kart varsa daha değerli
      if (tableCards.length == 1) {
        return matching.first;
      }
      return matching.first;
    }
    
    // 3. Eşleşme yok - en düşük kartı at
    return _findLowestCard(hand);
  }
  
  String _findLowestCard(List<String> cards) {
    const rankOrder = ['A', 'K', 'Q', 'J', '10', '9', '8', '7', '6', '5', '4', '3', '2'];
    
    return cards.reduce((a, b) {
      final rankA = rankOrder.indexOf(_rankOf(a));
      final rankB = rankOrder.indexOf(_rankOf(b));
      return rankA > rankB ? a : b;
    });
  }
  
  void _calculateFinalScores() {
    // Pişti puanlama
    for (int i = 0; i < 4; i++) {
      int score = 0;
      
      // Her pişti 10 puan
      score += _pistiCounts[i] * 10;
      
      // Kart sayısı puanları
      final cards = _cardsCaptured[i];
      if (cards > 26) {
        score += (cards - 26) * 3; // Çoğunluk bonusu
      }
      
      _scores[i] += score;
    }
    
    // En son alan bonus
    // (Basitleştirilmiş - normalde son eli alan 3 puan alır)
  }
  
  @override
  Set<int> playableIndexes() {
    if (activePlayerIndex != 0) return {};
    if (phase != GameStatePhase.waitingForPlayer) return {};
    
    return Set.from(List.generate(playerHand.length, (i) => i));
  }
  
  @override
  void submitPrediction(int value) {}
  
  @override
  void placeBid({required int level, required String? trump, required bool pass}) {}
  
  @override
  void newRound() {
    _startNewGame();
  }
}
