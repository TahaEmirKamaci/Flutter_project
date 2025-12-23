import 'dart:math';
import 'package:flutter/material.dart';

/// Supported game types in the multi-game app.
enum GameType { bridge, batak, pisti, poker, king, solitaire }

/// High-level state machine phases shared by all games.
enum GameStatePhase {
  idle,
  bidding,
  waitingForPlayer,
  playingCard,
  roundEnd,
  scoreUpdate,
}

/// Game events broadcast from engines to UI.
abstract class GameEvent {}
class CardSelectedEvent extends GameEvent {
  final int cardIndex;
  CardSelectedEvent(this.cardIndex);
}
class CardPlayedEvent extends GameEvent {
  final int cardIndex;
  CardPlayedEvent(this.cardIndex);
}
class RoundFinishedEvent extends GameEvent {}
class ScoreUpdatedEvent extends GameEvent {}
class PredictionSubmittedEvent extends GameEvent {
  final int predicted;
  PredictionSubmittedEvent(this.predicted);
}

/// Base interface all game engines implement.
abstract class GameEngine extends ChangeNotifier {
  GameType get type;
  GameStatePhase get phase;
  List<String> get playerHand; // simple string labels e.g. "A♥"
  List<String> get tableCards; // cards currently on table
  int get activePlayerIndex;
  // For trick-taking games: the seat who leads the current trick (0..3)
  int get leaderIndex;
  // Whether an initial card dealing animation/process is in progress
  bool get isDealing;
  int? get selectedIndex;
  List<int> get handCounts; // counts for all seats, index 0 is player
  List<int> get scores; // trick/point summary per seat (length 4)
  // Bidding (for Bridge-like engines)
  bool get isBidding;
  int get contractLevel; // 0 if none
  String? get trump; // '♠','♥','♦','♣' or null for NT
  List<String> get bidHistory; // e.g., ['1♥','Pass','1♠','Pass','Pass','Pass']
  int get currentBidderIndex; // seat expected to bid

  void selectCard(int index);
  void playSelected();
  void submitPrediction(int value);
  Set<int> playableIndexes();
  void newRound();
  void placeBid({required int level, required String? trump, required bool pass});
}

/// Minimal demo engine for placeholder logic.
class DemoTrickEngine extends GameEngine {
  final Random _rnd = Random();
  @override
  final GameType type;
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
  @override
  List<int> get handCounts => [playerHand.length, 0, 0, 0];
  @override
  List<int> get scores => const [0,0,0,0];
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

  DemoTrickEngine(this.type) {
    _deal();
  }

  void _deal() {
    playerHand = [
      'A♥','K♥','10♦','9♦','7♣','5♣','J♠','3♠','Q♦','2♣'
    ];
    tableCards.clear();
    phase = GameStatePhase.waitingForPlayer;
    activePlayerIndex = 0;
    notifyListeners();
  }

  @override
  void selectCard(int index) {
    if (phase != GameStatePhase.waitingForPlayer) return;
    if (index < 0 || index >= playerHand.length) return;
    _selectedIndex = _selectedIndex == index ? null : index;
    notifyListeners();
  }

  @override
  void playSelected() {
    if (_selectedIndex == null) return;
    final card = playerHand.removeAt(_selectedIndex!);
    tableCards.add(card);
    _selectedIndex = null;
    phase = GameStatePhase.playingCard;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 400), () {
      phase = GameStatePhase.waitingForPlayer;
      if (playerHand.isEmpty) {
        phase = GameStatePhase.roundEnd;
        notifyListeners();
        Future.delayed(const Duration(milliseconds: 500), () {
          phase = GameStatePhase.scoreUpdate;
          notifyListeners();
          Future.delayed(const Duration(milliseconds: 700), _deal);
        });
      } else {
        notifyListeners();
      }
    });
  }

  @override
  void submitPrediction(int value) {
    // demo: just fire event chain
    phase = GameStatePhase.playingCard;
    notifyListeners();
  }

  bool isSelected(int i) => _selectedIndex == i;

  @override
  Set<int> playableIndexes() => {for (var i=0;i<playerHand.length;i++) i};

  @override
  void newRound() { _deal(); }

  @override
  void placeBid({required int level, required String? trump, required bool pass}) { /* no-op for demo */ }
}

// Helpers
List<String> standardDeck() {
  const suits = ['♠','♥','♦','♣'];
  const ranks = ['A','K','Q','J','10','9','8','7','6','5','4','3','2'];
  return [for (final s in suits) for (final r in ranks) '$r$s'];
}
String rankOf(String label) => label.substring(0, label.length-1);

/// Simplified Pişti engine implementation (single-player vs. simulated opponents).
class PistiEngine extends GameEngine {
  final Random _rnd = Random();
  @override
  final GameType type = GameType.pisti;
  @override
  GameStatePhase phase = GameStatePhase.waitingForPlayer;
  @override
  List<String> playerHand = [];
  @override
  List<String> tableCards = [];
  @override
  int activePlayerIndex = 0; // 0: player
  @override
  int get leaderIndex => 0;
  @override
  bool get isDealing => false;
  int? _selectedIndex;
  @override
  int? get selectedIndex => _selectedIndex;
  @override
  List<int> get handCounts => [playerHand.length, 0, 0, 0];
  @override
  List<int> get scores => const [0,0,0,0];
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

  List<String> _deck = [];
  int _captured = 0;
  int _pistiCount = 0;

  PistiEngine() {
    _reset();
  }

  void _reset() {
    _deck = List.of(standardDeck())..shuffle(_rnd);
    playerHand.clear();
    tableCards.clear();
    _captured = 0;
    _pistiCount = 0;
    // initial 4 on table, last face up
    for (int i=0;i<4;i++) { tableCards.add(_deck.removeLast()); }
    _dealToPlayer();
    phase = GameStatePhase.waitingForPlayer;
    notifyListeners();
  }

  void _dealToPlayer() {
    final take = min(4, _deck.length);
    for (int i=0;i<take;i++) { playerHand.add(_deck.removeLast()); }
  }

  @override
  void selectCard(int index) {
    if (phase != GameStatePhase.waitingForPlayer) return;
    if (index < 0 || index >= playerHand.length) return;
    _selectedIndex = _selectedIndex == index ? null : index;
    notifyListeners();
  }

  @override
  void playSelected() {
    if (_selectedIndex == null) return;
    final card = playerHand.removeAt(_selectedIndex!);
    _selectedIndex = null;
    // Apply Pişti capture rules
    final top = tableCards.isNotEmpty ? tableCards.last : null;
    final captures = top != null && (rankOf(card) == rankOf(top) || rankOf(card) == 'J');
    tableCards.add(card);
    phase = GameStatePhase.playingCard;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 350), () {
      if (captures) {
        if (tableCards.length == 2 && rankOf(card) == rankOf(top)) {
          _pistiCount += 1; // basic pisti
        }
        _captured += tableCards.length;
        tableCards.clear();
      }

      if (playerHand.isEmpty) {
        if (_deck.isNotEmpty) {
          _dealToPlayer();
          phase = GameStatePhase.waitingForPlayer;
        } else {
          phase = GameStatePhase.scoreUpdate;
        }
      } else {
        phase = GameStatePhase.waitingForPlayer;
      }
      notifyListeners();
    });
  }

  @override
  void submitPrediction(int value) {}

  @override
  Set<int> playableIndexes() => {for (var i=0;i<playerHand.length;i++) i};

  @override
  void newRound() { _reset(); }

  @override
  void placeBid({required int level, required String? trump, required bool pass}) { /* not used */ }
}

// BridgeEngine and BatakEngine are implemented in core/trick_engines.dart
