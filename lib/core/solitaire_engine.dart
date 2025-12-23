import 'dart:math';
import 'package:flutter/material.dart';
import 'game_core.dart';

/// Klondike Solitaire Oyun Motoru
class SolitaireEngine extends ChangeNotifier implements GameEngine {
  final Random _random = Random();
  
  @override
  final GameType type = GameType.solitaire;
  
  @override
  GameStatePhase phase = GameStatePhase.waitingForPlayer;
  
  // Foundation (As'ların üzerine dizilecek)
  final List<List<String>> foundations = [[], [], [], []];
  
  // Tableau (7 sütun)
  final List<List<String>> tableau = [[], [], [], [], [], [], []];
  
  // Açık kartlar (tableau'da)
  final Set<String> faceUpCards = {};
  
  // Stock (deste)
  List<String> stock = [];
  
  // Waste (açılan kartlar)
  List<String> waste = [];
  
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
  String? _selectedSource; // 'waste', 'tableau0-6', 'foundation0-3'
  
  @override
  int? get selectedIndex => _selectedIndex;
  
  int _moves = 0;
  int get moves => _moves;
  
  bool _gameWon = false;
  bool get gameWon => _gameWon;
  
  @override
  List<int> get handCounts => const [];
  
  @override
  List<int> get scores => [_calculateScore()];
  
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
  
  SolitaireEngine() {
    _startNewGame();
  }
  
  void _startNewGame() {
    foundations.forEach((f) => f.clear());
    tableau.forEach((t) => t.clear());
    faceUpCards.clear();
    stock.clear();
    waste.clear();
    
    _moves = 0;
    _gameWon = false;
    _selectedIndex = null;
    _selectedSource = null;
    
    // Deste oluştur
    stock = _createDeck();
    stock.shuffle(_random);
    
    // Tableau'ya dağıt
    for (int col = 0; col < 7; col++) {
      for (int row = 0; row <= col; row++) {
        final card = stock.removeLast();
        tableau[col].add(card);
        
        // Son kart açık
        if (row == col) {
          faceUpCards.add(card);
        }
      }
    }
    
    phase = GameStatePhase.waitingForPlayer;
    notifyListeners();
  }
  
  List<String> _createDeck() {
    const suits = ['♠', '♥', '♦', '♣'];
    const ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    return [for (final suit in suits) for (final rank in ranks) '$rank$suit'];
  }
  
  String _rankOf(String card) => card.substring(0, card.length - 1);
  String _suitOf(String card) => card.substring(card.length - 1);
  
  int _rankValue(String rank) {
    const values = {
      'A': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7,
      '8': 8, '9': 9, '10': 10, 'J': 11, 'Q': 12, 'K': 13,
    };
    return values[rank] ?? 0;
  }
  
  bool _isRed(String card) {
    final suit = _suitOf(card);
    return suit == '♥' || suit == '♦';
  }
  
  /// STOCK'TAN KART ÇEK
  void drawFromStock() {
    if (stock.isEmpty) {
      // Waste'i stock'a çevir
      stock = waste.reversed.toList();
      waste.clear();
    } else {
      waste.add(stock.removeLast());
    }
    
    _selectedIndex = null;
    _selectedSource = null;
    notifyListeners();
  }
  
  /// KART SEÇ
  void selectWaste() {
    if (waste.isEmpty) return;
    
    _selectedIndex = waste.length - 1;
    _selectedSource = 'waste';
    notifyListeners();
  }
  
  void selectTableau(int column, int index) {
    if (column < 0 || column >= 7) return;
    if (index < 0 || index >= tableau[column].length) return;
    
    final card = tableau[column][index];
    if (!faceUpCards.contains(card)) return;
    
    _selectedIndex = index;
    _selectedSource = 'tableau$column';
    notifyListeners();
  }
  
  void selectFoundation(int index) {
    if (index < 0 || index >= 4) return;
    if (foundations[index].isEmpty) return;
    
    _selectedIndex = foundations[index].length - 1;
    _selectedSource = 'foundation$index';
    notifyListeners();
  }
  
  /// WASTE'TEN TABLEAU'YA
  void moveWasteToTableau(int column) {
    if (waste.isEmpty) return;
    if (column < 0 || column >= 7) return;
    
    final card = waste.last;
    
    if (_canPlaceOnTableau(card, column)) {
      waste.removeLast();
      tableau[column].add(card);
      faceUpCards.add(card);
      
      _moves++;
      _selectedIndex = null;
      _selectedSource = null;
      
      _checkWinCondition();
      notifyListeners();
    }
  }
  
  /// WASTE'TEN FOUNDATION'A
  void moveWasteToFoundation(int foundationIndex) {
    if (waste.isEmpty) return;
    if (foundationIndex < 0 || foundationIndex >= 4) return;
    
    final card = waste.last;
    
    if (_canPlaceOnFoundation(card, foundationIndex)) {
      waste.removeLast();
      foundations[foundationIndex].add(card);
      
      _moves++;
      _selectedIndex = null;
      _selectedSource = null;
      
      _checkWinCondition();
      notifyListeners();
    }
  }
  
  /// TABLEAU'DAN TABLEAU'YA
  void moveTableauToTableau(int fromColumn, int fromIndex, int toColumn) {
    if (fromColumn < 0 || fromColumn >= 7) return;
    if (toColumn < 0 || toColumn >= 7) return;
    if (fromIndex < 0 || fromIndex >= tableau[fromColumn].length) return;
    
    final cardsToMove = tableau[fromColumn].sublist(fromIndex);
    final topCard = cardsToMove.first;
    
    if (!faceUpCards.contains(topCard)) return;
    
    if (_canPlaceOnTableau(topCard, toColumn)) {
      tableau[fromColumn].removeRange(fromIndex, tableau[fromColumn].length);
      tableau[toColumn].addAll(cardsToMove);
      
      // Son kartı aç
      if (tableau[fromColumn].isNotEmpty) {
        faceUpCards.add(tableau[fromColumn].last);
      }
      
      _moves++;
      _selectedIndex = null;
      _selectedSource = null;
      
      notifyListeners();
    }
  }
  
  /// TABLEAU'DAN FOUNDATION'A
  void moveTableauToFoundation(int fromColumn, int foundationIndex) {
    if (fromColumn < 0 || fromColumn >= 7) return;
    if (foundationIndex < 0 || foundationIndex >= 4) return;
    if (tableau[fromColumn].isEmpty) return;
    
    final card = tableau[fromColumn].last;
    
    if (_canPlaceOnFoundation(card, foundationIndex)) {
      tableau[fromColumn].removeLast();
      foundations[foundationIndex].add(card);
      
      // Yeni üst kartı aç
      if (tableau[fromColumn].isNotEmpty) {
        faceUpCards.add(tableau[fromColumn].last);
      }
      
      _moves++;
      _selectedIndex = null;
      _selectedSource = null;
      
      _checkWinCondition();
      notifyListeners();
    }
  }
  
  bool _canPlaceOnTableau(String card, int column) {
    if (tableau[column].isEmpty) {
      // Boş sütun - sadece Kral
      return _rankOf(card) == 'K';
    }
    
    final topCard = tableau[column].last;
    final cardRank = _rankValue(_rankOf(card));
    final topRank = _rankValue(_rankOf(topCard));
    
    // Bir alt değer ve farklı renk
    return cardRank == topRank - 1 && _isRed(card) != _isRed(topCard);
  }
  
  bool _canPlaceOnFoundation(String card, int foundationIndex) {
    final foundation = foundations[foundationIndex];
    
    if (foundation.isEmpty) {
      // Boş foundation - sadece As
      return _rankOf(card) == 'A';
    }
    
    final topCard = foundation.last;
    
    // Aynı renk ve bir üst değer
    return _suitOf(card) == _suitOf(topCard) &&
           _rankValue(_rankOf(card)) == _rankValue(_rankOf(topCard)) + 1;
  }
  
  void _checkWinCondition() {
    // Tüm foundation'lar 13 kart mı?
    _gameWon = foundations.every((f) => f.length == 13);
    
    if (_gameWon) {
      phase = GameStatePhase.scoreUpdate;
    }
  }
  
  int _calculateScore() {
    int score = 0;
    
    // Foundation'daki her kart 10 puan
    for (final foundation in foundations) {
      score += foundation.length * 10;
    }
    
    // Hamle bonusu (az hamle = fazla puan)
    if (_gameWon) {
      score += max(0, 500 - _moves * 2);
    }
    
    return score;
  }
  
  /// OTOMATİK HAMLE (kolay kartları foundation'a taşı)
  void autoMoveToFoundation() {
    bool moved = true;
    
    while (moved) {
      moved = false;
      
      // Waste'ten
      if (waste.isNotEmpty) {
        final card = waste.last;
        for (int i = 0; i < 4; i++) {
          if (_canPlaceOnFoundation(card, i)) {
            moveWasteToFoundation(i);
            moved = true;
            break;
          }
        }
      }
      
      // Tableau'dan
      if (!moved) {
        for (int col = 0; col < 7; col++) {
          if (tableau[col].isEmpty) continue;
          
          final card = tableau[col].last;
          for (int i = 0; i < 4; i++) {
            if (_canPlaceOnFoundation(card, i)) {
              moveTableauToFoundation(col, i);
              moved = true;
              break;
            }
          }
          if (moved) break;
        }
      }
    }
  }
  
  @override
  Set<int> playableIndexes() => {};
  
  @override
  void selectCard(int index) {}
  
  @override
  void playSelected() {}
  
  @override
  void submitPrediction(int value) {}
  
  @override
  void placeBid({required int level, required String? trump, required bool pass}) {}
  
  @override
  void newRound() {
    _startNewGame();
  }
}
