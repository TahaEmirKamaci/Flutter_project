import 'dart:math';
import 'package:flutter/material.dart';
import 'game_core.dart';
import '../ai/hand_evaluator.dart';
import '../ai/bidding_engine.dart';
import '../ai/play_engine.dart';
import '../ai/score_engine.dart';

const _ranksHighToLow = [
  'A',
  'K',
  'Q',
  'J',
  '10',
  '9',
  '8',
  '7',
  '6',
  '5',
  '4',
  '3',
  '2',
];
int _rankPower(String r) => _ranksHighToLow.indexOf(r); // lower is stronger
String rankOf(String label) => label.substring(0, label.length - 1);
String suitOf(String label) => label.substring(label.length - 1);

abstract class BaseTrickEngine extends GameEngine {
  final Random _rnd = Random();
  @override
  GameStatePhase phase = GameStatePhase.waitingForPlayer;
  @override
  List<String> playerHand = [];
  @override
  List<String> tableCards = [];
  @override
  int activePlayerIndex = 0;
  int leaderIndex = 0;
  int? declarerIndex; // who won the contract (bridge)
  int? dummyIndex; // partner of declarer, shown open
  int? _selectedIndex;
  @override
  int? get selectedIndex => _selectedIndex;

  late List<List<String>> hands; // 4 players
  @override
  List<int> get handCounts => [for (final h in hands) h.length];
  @override
  List<int> get scores => _tricks;

  late List<int> _tricks; // tricks per seat

  String? trump; // e.g. '♠' or null for NT

  @mustCallSuper
  void initDeal() {
    final deck = List.of(standardDeck());
    deck.shuffle(_rnd);
    hands = [[], [], [], []];
    for (int i = 0; i < 52; i++) {
      hands[i % 4].add(deck[i]);
    }
    for (final h in hands) {
      h.sort((a, b) {
        final sComp = suitOf(a).compareTo(suitOf(b));
        if (sComp != 0) return sComp;
        return _rankPower(rankOf(a)).compareTo(_rankPower(rankOf(b)));
      });
    }
    playerHand = hands[0];
    tableCards.clear();
    leaderIndex = 0;
    activePlayerIndex = leaderIndex;
    _tricks = [0, 0, 0, 0];
    phase = GameStatePhase.waitingForPlayer;
    notifyListeners();
  }

  @override
  void selectCard(int index) {
    if (phase != GameStatePhase.waitingForPlayer) return;

    // In Bridge: if human is declarer and it's dummy's turn, allow selecting dummy cards
    final isDeclarerControllingDummy =
        (declarerIndex == 0 && activePlayerIndex == dummyIndex);
    final activeHand = isDeclarerControllingDummy
        ? hands[dummyIndex!]
        : playerHand;

    if (index < 0 || index >= activeHand.length) return;

    // Check playability
    Set<int> playable;
    if (tableCards.isEmpty) {
      playable = {for (var i = 0; i < activeHand.length; i++) i};
    } else {
      final leadSuit = suitOf(tableCards.first);
      final indicesLead = <int>{};
      for (var i = 0; i < activeHand.length; i++) {
        if (suitOf(activeHand[i]) == leadSuit) indicesLead.add(i);
      }
      playable = indicesLead.isEmpty
          ? {for (var i = 0; i < activeHand.length; i++) i}
          : indicesLead;
    }

    if (!playable.contains(index)) return;
    _selectedIndex = _selectedIndex == index ? null : index;
    notifyListeners();
  }

  @override
  Set<int> playableIndexes() {
    // In Bridge: if declarer controls dummy, return dummy's playable cards
    final isDeclarerControllingDummy =
        (declarerIndex == 0 && activePlayerIndex == dummyIndex);
    final activeHand = isDeclarerControllingDummy
        ? hands[dummyIndex!]
        : playerHand;

    if (tableCards.isEmpty) {
      return {for (var i = 0; i < activeHand.length; i++) i};
    }
    final leadSuit = suitOf(tableCards.first);
    final indicesLead = <int>{};
    for (var i = 0; i < activeHand.length; i++) {
      if (suitOf(activeHand[i]) == leadSuit) indicesLead.add(i);
    }
    return indicesLead.isEmpty
        ? {for (var i = 0; i < activeHand.length; i++) i}
        : indicesLead;
  }

  int _trickWinnerIndex(List<String> trick, int trickLeader) {
    final leadSuit = suitOf(trick.first);
    int winnerOffset = 0;
    String winnerCard = trick.first;
    for (int i = 1; i < trick.length; i++) {
      final cand = trick[i];
      final ws = suitOf(winnerCard);
      final cs = suitOf(cand);
      final winnerIsTrump = trump != null && ws == trump;
      final candIsTrump = trump != null && cs == trump;
      if (candIsTrump && !winnerIsTrump) {
        winnerOffset = i;
        winnerCard = cand;
        continue;
      }
      if ((!winnerIsTrump && cs == leadSuit && ws != leadSuit) ||
          (cs == ws &&
              _rankPower(rankOf(cand)) < _rankPower(rankOf(winnerCard)))) {
        winnerOffset = i;
        winnerCard = cand;
        continue;
      }
    }
    return (trickLeader + winnerOffset) % 4;
  }

  void _aiPlayForSeat(int seat) {
    // Prevent playing out of turn or multiple cards in same trick from a seat
    if (seat != activePlayerIndex) return;
    final hand = hands[seat];
    int pickIndex = 0;
    if (tableCards.isNotEmpty) {
      final leadSuit = suitOf(tableCards.first);
      final options = <int>[];
      for (var i = 0; i < hand.length; i++)
        if (suitOf(hand[i]) == leadSuit) options.add(i);
      if (options.isNotEmpty) pickIndex = options[_rnd.nextInt(options.length)];
    }
    final played = hand.removeAt(pickIndex);
    tableCards.add(played);
    // Advance to next seat within this trick
    activePlayerIndex = (activePlayerIndex + 1) % 4;
  }

  @override
  void playSelected() {
    if (_selectedIndex == null) return;
    // Only allow when it's this engine's active seat turn
    if (activePlayerIndex != 0) return;

    final played = playerHand.removeAt(_selectedIndex!);
    _selectedIndex = null;
    tableCards.add(played);
    phase = GameStatePhase.playingCard;
    // Advance active player immediately after playing
    activePlayerIndex = (activePlayerIndex + 1) % 4;
    notifyListeners();

    // Simulate other three players in correct order, one card at a time
    void playNext() {
      if (tableCards.length < 4) {
        _aiPlayForSeat(activePlayerIndex);
        Future.delayed(const Duration(milliseconds: 260), playNext);
      } else {
        final winner = _trickWinnerIndex(List.of(tableCards), leaderIndex);
        _tricks[winner] += 1;
        leaderIndex = winner;
        activePlayerIndex = leaderIndex;
        // Hold cards on table; UI will animate collection toward winner at 2000ms
        // Clear after 3200ms to allow animation to complete
        Future.delayed(const Duration(milliseconds: 3200), () {
          tableCards.clear();
          if (playerHand.isEmpty) {
            phase = GameStatePhase.scoreUpdate;
          } else {
            phase = GameStatePhase.waitingForPlayer;
          }
          notifyListeners();
        });
      }
    }

    Future.delayed(const Duration(milliseconds: 260), playNext);
  }

  @override
  void submitPrediction(int value) {}

  @override
  void newRound() {
    initDeal();
  }
}

class BridgeEngine extends BaseTrickEngine {
  @override
  final GameType type = GameType.bridge;

  bool _isBidding = true;
  int _contractLevel = 0; // 0 means none
  String? _trump; // null => NT
  @override
  bool get isBidding => _isBidding;
  @override
  int get contractLevel => _contractLevel;
  @override
  String? get trump => _trump;
  final List<String> _bidHistory = [];
  @override
  List<String> get bidHistory => List.unmodifiable(_bidHistory);
  int _currentBidderIndex = 0;
  @override
  int get currentBidderIndex => _currentBidderIndex;

  int _passesInRow = 0;
  int? _winningBidSeat;
  bool _isDealing = false; // animated initial deal in progress
  int _startingDealSeat = 0; // rotates each round
  bool _dummyOpened =
      false; // dummy opens AFTER opening lead (first card played)
  // Trick limit (configurable): default 5 for now
  int maxTricks = 5;

  // AI Engines - Profesyonel briç bot sistemi
  late BiddingEngine _biddingAI;
  late PlayEngine _playAI;
  BiddingDifficulty _biddingDifficulty = BiddingDifficulty.medium;
  PlayDifficulty _playDifficulty = PlayDifficulty.medium;
  
  // Vulnerability tracking
  VulnerabilityCondition _vulnerability = VulnerabilityCondition.none;
  int _boardNumber = 1;

  // Per-seat points (computed after dealing)
  List<BridgeSeatPoints> seatPoints = [
    BridgeSeatPoints.empty(),
    BridgeSeatPoints.empty(),
    BridgeSeatPoints.empty(),
    BridgeSeatPoints.empty(),
  ];

  // Point calculations for the player's hand
  int hcpPoints = 0; // Onör (A,K,Q,J)
  int lengthPoints = 0; // length >4 per suit
  int shortnessHalfPoints = 0; // yarım tutuş: void+3, singleton+2, doubleton+1
  int shortnessFullPoints = 0; // tam tutuş: void+5, singleton+3, doubleton+1
  int totalPoints = 0; // HCP + length
  int supportPointsHalf = 0; // HCP + shortnessHalf (if half fit scenario)
  int supportPointsFull = 0; // HCP + shortnessFull (if full fit scenario)

  @override
  bool get isDealing => _isDealing;

  // Dummy opens after opening lead in Bridge
  bool get isDummyOpen => _dummyOpened;

  // Suit order for Bridge bidding: ♣ < ♦ < ♥ < ♠ < NT
  final List<String?> _suitOrder = const ['♣', '♦', '♥', '♠', null];
  int _bidRank(int level, String? suit) {
    final suitRank = _suitOrder.indexOf(suit);
    return (level - 1) * 5 + suitRank; // 0..34
  }

  BridgeEngine() {
    _biddingAI = BiddingEngine(difficulty: _biddingDifficulty);
    _playAI = PlayEngine(difficulty: _playDifficulty);
    _startAnimatedDeal();
  }

  // === AI Difficulty Settings ===
  void setBiddingDifficulty(BiddingDifficulty difficulty) {
    _biddingDifficulty = difficulty;
    _biddingAI = BiddingEngine(difficulty: difficulty);
    notifyListeners();
  }

  void setPlayDifficulty(PlayDifficulty difficulty) {
    _playDifficulty = difficulty;
    _playAI = PlayEngine(difficulty: difficulty);
    notifyListeners();
  }

  BiddingDifficulty get biddingDifficulty => _biddingDifficulty;
  PlayDifficulty get playDifficulty => _playDifficulty;

  void setVulnerability(VulnerabilityCondition vuln) {
    _vulnerability = vuln;
    notifyListeners();
  }

  VulnerabilityCondition get vulnerability => _vulnerability;

  void startBidding() {
    _startBidding();
  }

  void _startBidding() {
    _isBidding = true;
    _contractLevel = 0;
    _trump = null;
    _bidHistory.clear();
    _passesInRow = 0;
    _winningBidSeat = null;
    _currentBidderIndex = 0; // dealer = player for now
    phase = GameStatePhase.bidding;
    activePlayerIndex = _currentBidderIndex;
    notifyListeners();
    _maybeAutoBid();
  }

  void _advanceBidder() {
    _currentBidderIndex = (_currentBidderIndex + 1) % 4;
    activePlayerIndex = _currentBidderIndex;
  }

  void _endBidding() {
    if (_winningBidSeat == null) {
      // Passed out: redeal
      newRound();
      return;
    }
    _isBidding = false;
    _dummyOpened = false; // Dummy will open after opening lead
    // Declarer is winning bid seat; opening lead is left of declarer
    declarerIndex = _winningBidSeat!;
    dummyIndex = (declarerIndex! + 2) % 4; // partner opposite
    leaderIndex = (declarerIndex! + 1) % 4;
    activePlayerIndex = leaderIndex;
    phase = GameStatePhase.waitingForPlayer;
    // Set BaseTrickEngine trump used in trick resolution
    trump = _trump; // null => NT
    notifyListeners();
    // If opening lead is not the player, start auto-play until it's player's turn
    _scheduleAutoPlayIfNeeded();
  }

  void _maybeAutoBid() {
    if (!_isBidding) return;
    if (_currentBidderIndex == 0) return; // player's turn
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isBidding) return;
      
      // === YENİ: Profesyonel AI ile ihale ===
      final botHand = hands[_currentBidderIndex];
      final partnerSeat = (_currentBidderIndex + 2) % 4;
      
      final decision = _biddingAI.decideBid(
        hand: botHand,
        bidHistory: _bidHistory,
        seatPosition: _currentBidderIndex,
        partnerPosition: partnerSeat,
      );

      if (decision.isPass) {
        placeBid(level: 0, trump: null, pass: true);
      } else {
        placeBid(
          level: decision.level,
          trump: decision.suit,
          pass: false,
        );
      }
    });
  }

  @override
  void placeBid({
    required int level,
    required String? trump,
    required bool pass,
  }) {
    if (!_isBidding || phase != GameStatePhase.bidding) return;
    if (pass) {
      _bidHistory.add('Pass');
      _passesInRow += 1;
      if (_contractLevel == 0 && _passesInRow >= 4) {
        _endBidding();
        return;
      }
      if (_contractLevel > 0 && _passesInRow >= 3) {
        _endBidding();
        return;
      }
      _advanceBidder();
      notifyListeners();
      _maybeAutoBid();
      return;
    }

    // validate bid
    if (level < 1 || level > 7) return;
    if (!['♣', '♦', '♥', '♠', null].contains(trump)) return;
    final newRank = _bidRank(level, trump);
    final currentRank = _contractLevel == 0
        ? -1
        : _bidRank(_contractLevel, _trump);
    if (newRank <= currentRank) return;

    _contractLevel = level;
    _trump = trump;
    _passesInRow = 0;
    _winningBidSeat = _currentBidderIndex;
    _bidHistory.add('${level}${trump ?? 'NT'}');
    _advanceBidder();
    notifyListeners();
    _maybeAutoBid();
  }

  @override
  void newRound() {
    _isBidding = false;
    _contractLevel = 0;
    _trump = null;
    _bidHistory.clear();
    declarerIndex = null;
    dummyIndex = null;
    _dummyOpened = false;
    leaderIndex = 0;
    activePlayerIndex = 0;
    _tricks = [0, 0, 0, 0];
    tableCards.clear();
    _startingDealSeat =
        (_startingDealSeat + 1) % 4; // rotate who receives first card
    _startAnimatedDeal();
  }

  void _startAnimatedDeal() {
    _isDealing = true;
    // Build & shuffle deck
    final deck = List.of(standardDeck());
    deck.shuffle(_rnd);
    // Prepare empty hands
    hands = [[], [], [], []];
    seatPoints = [for (int i = 0; i < 4; i++) BridgeSeatPoints.empty()];
    playerHand = hands[0];
    tableCards.clear();
    _tricks = [0, 0, 0, 0];
    leaderIndex = 0;
    activePlayerIndex = 0;
    phase = GameStatePhase.waitingForPlayer;
    notifyListeners();

    // Deal sequentially with animation-like timing
    const perCardDelay = 134; // ~= 7s total for 52 cards
    for (int i = 0; i < 52; i++) {
      Future.delayed(Duration(milliseconds: i * perCardDelay), () {
        final seat = (_startingDealSeat + i) % 4;
        hands[seat].add(deck[i]);
        if (seat == 0) {
          playerHand = hands[0];
        }
        // When all cards dealt, final sort & finish
        if (i == 51) {
          _finalizeDealing();
        } else if (i % 4 == 3) {
          // Notify after each round of 4 for smoother UI
          notifyListeners();
        }
      });
    }
  }

  // Settings API
  void setMaxTricks(int value) {
    maxTricks = value.clamp(1, 13);
    notifyListeners();
  }

  void _finalizeDealing() {
    // Sort hands in black-red-black-red suit order: ♠,♥,♣,♦ then rank high->low
    const suitOrder = ['♠', '♥', '♣', '♦'];
    int suitRank(String s) => suitOrder.indexOf(s);
    for (final h in hands) {
      h.sort((a, b) {
        final sa = suitRank(suitOf(a));
        final sb = suitRank(suitOf(b));
        if (sa != sb) return sa - sb;
        return _rankPower(rankOf(a)).compareTo(
          _rankPower(rankOf(b)),
        ); // A,K,... descending by our power mapping
      });
    }
    playerHand = hands[0];
    _isDealing = false;
    _computePointsAll();
    notifyListeners();
  }

  // === Bridge play flow helpers ===
  bool get _isHumanDeclarer => declarerIndex == 0;
  bool get _isDummyTurnForHuman =>
      dummyIndex != null && _isHumanDeclarer && activePlayerIndex == dummyIndex;

  @override
  void selectCard(int index) {
    if (phase != GameStatePhase.waitingForPlayer) return;

    // In Bridge: if human is declarer and it's dummy's turn, allow selecting dummy cards
    final isDeclarerControllingDummy =
        (declarerIndex == 0 && activePlayerIndex == dummyIndex);
    final activeHand = isDeclarerControllingDummy
        ? hands[dummyIndex!]
        : playerHand;

    if (index < 0 || index >= activeHand.length) return;

    // Check playability
    Set<int> playable;
    if (tableCards.isEmpty) {
      playable = {for (var i = 0; i < activeHand.length; i++) i};
    } else {
      final leadSuit = suitOf(tableCards.first);
      final indicesLead = <int>{};
      for (var i = 0; i < activeHand.length; i++) {
        if (suitOf(activeHand[i]) == leadSuit) indicesLead.add(i);
      }
      playable = indicesLead.isEmpty
          ? {for (var i = 0; i < activeHand.length; i++) i}
          : indicesLead;
    }

    if (!playable.contains(index)) return;
    _selectedIndex = _selectedIndex == index ? null : index;
    notifyListeners();
  }

  @override
  Set<int> playableIndexes() {
    // In Bridge: if declarer controls dummy, return dummy's playable cards
    final isDeclarerControllingDummy =
        (declarerIndex == 0 && activePlayerIndex == dummyIndex);
    final activeHand = isDeclarerControllingDummy
        ? hands[dummyIndex!]
        : playerHand;

    if (tableCards.isEmpty) {
      return {for (var i = 0; i < activeHand.length; i++) i};
    }
    final leadSuit = suitOf(tableCards.first);
    final indicesLead = <int>{};
    for (var i = 0; i < activeHand.length; i++) {
      if (suitOf(activeHand[i]) == leadSuit) indicesLead.add(i);
    }
    return indicesLead.isEmpty
        ? {for (var i = 0; i < activeHand.length; i++) i}
        : indicesLead;
  }

  void _scheduleAutoPlayIfNeeded() {
    // Auto-play whenever it's not the human's turn to act
    if (phase != GameStatePhase.waitingForPlayer) return;
    if (_isDealing) return; // wait until dealing done
    if (activePlayerIndex == 0) return; // player's own turn

    // In Bridge: if human is declarer and it's dummy's turn, don't auto-play
    if (declarerIndex == 0 && activePlayerIndex == dummyIndex) return;

    Future.delayed(const Duration(milliseconds: 750), _autoPlayFromActive);
  }

  void _autoPlayFromActive() {
    if (phase != GameStatePhase.waitingForPlayer) return;
    final seat = activePlayerIndex;
    if (seat == 0) return; // human's turn

    // In Bridge: if human is declarer and it's dummy's turn, don't auto-play
    if (declarerIndex == 0 && seat == dummyIndex) return;

    // Open dummy after opening lead (first card played)
    if (!_dummyOpened && tableCards.length == 1) {
      _dummyOpened = true;
      notifyListeners(); // Update UI to show dummy hand
    }

    // === YENİ: Profesyonel AI ile kart seçimi ===
    final hand = hands[seat];
    final isLeading = tableCards.isEmpty;
    final isDummy = seat == dummyIndex;
    final isDeclarerBot = declarerIndex != null && declarerIndex != 0;
    
    // Dummy hand (eğer declarer botsa ve dummy görünürse)
    final dummyCards = (declarerIndex == seat && dummyIndex != null)
        ? hands[dummyIndex!]
        : <String>[];

    final decision = _playAI.selectCard(
      hand: hand,
      cardsPlayed: tableCards,
      trump: _trump,
      isLeading: isLeading,
      position: seat,
      isDummy: isDummy,
      dummyHand: dummyCards,
      isDeclarer: isDeclarerBot,
    );

    // Seçilen kartı bul ve oyna
    final cardToPlay = decision.card;
    final cardIndex = hand.indexOf(cardToPlay);
    
    if (cardIndex >= 0) {
      final played = hand.removeAt(cardIndex);
      tableCards.add(played);
    } else {
      // Fallback: ilk legal kartı oyna
      final played = hand.removeAt(0);
      tableCards.add(played);
    }
    
    notifyListeners();

    // Advance turn clockwise
    activePlayerIndex = (activePlayerIndex + 1) % 4;

    if (tableCards.length < 4) {
      // Continue with next seat (auto until it's player turn)
      _scheduleAutoPlayIfNeeded();
    } else {
      // Resolve trick
      _resolveTrick();
    }
  }

  void _resolveTrick() {
    final winner = _trickWinnerIndex(List.of(tableCards), leaderIndex);
    _tricks[winner] += 1;
    leaderIndex = winner;
    activePlayerIndex = leaderIndex;
    // Hold cards on table: UI starts collection at 2000ms, animation takes up to 1200ms
    // Clear cards after 3200ms to ensure animation completes
    Future.delayed(const Duration(milliseconds: 3200), () {
      tableCards.clear();
      // Stop the round early if trick limit reached
      final tricksSoFar = _tricks.fold<int>(0, (a, b) => a + b);
      if (tricksSoFar >= maxTricks || hands[0].isEmpty) {
        phase = GameStatePhase.scoreUpdate;
        // Oyun bitti - gerçek briç skorunu hesapla
        calculateFinalScore();
      } else {
        phase = GameStatePhase.waitingForPlayer;
      }
      notifyListeners();
      // If next leader is not the human, keep auto-playing
      _scheduleAutoPlayIfNeeded();
    });
  }

  @override
  void playSelected() {
    // In Bridge: if human is declarer (seat 0) and it's dummy's turn, allow playing from dummy
    final isDeclarerPlayingDummy =
        (declarerIndex == 0 && activePlayerIndex == dummyIndex);

    // Only allow when it's player's seat to play OR declarer controlling dummy
    if (activePlayerIndex != 0 && !isDeclarerPlayingDummy) return;
    if (_isDealing) return; // cannot play while dealing animation active
    if (selectedIndex == null) return;

    // Enforce follow-suit
    final idx = selectedIndex!;

    // Determine which hand to play from
    final List<String> activeHand = isDeclarerPlayingDummy
        ? hands[dummyIndex!]
        : playerHand;

    // Check playability using follow-suit rules
    Set<int> playable;
    if (tableCards.isEmpty) {
      playable = {for (var i = 0; i < activeHand.length; i++) i};
    } else {
      final leadSuit = suitOf(tableCards.first);
      final indicesLead = <int>{};
      for (var i = 0; i < activeHand.length; i++) {
        if (suitOf(activeHand[i]) == leadSuit) indicesLead.add(i);
      }
      playable = indicesLead.isEmpty
          ? {for (var i = 0; i < activeHand.length; i++) i}
          : indicesLead;
    }

    if (!playable.contains(idx)) return;

    final played = activeHand.removeAt(idx);
    _selectedIndex = null;
    tableCards.add(played);

    // Open dummy after opening lead (first card played)
    if (!_dummyOpened && tableCards.length == 1) {
      _dummyOpened = true;
    }

    // Update playerHand reference if we modified it
    if (!isDeclarerPlayingDummy) {
      playerHand = hands[0];
    }

    notifyListeners();

    // Advance to next seat
    activePlayerIndex = (activePlayerIndex + 1) % 4;

    if (tableCards.length < 4) {
      // Let others (including dummy if not controlled by declarer) play automatically
      _scheduleAutoPlayIfNeeded();
    } else {
      _resolveTrick();
    }
  }

  // === Skor hesaplama (gerçek Briç kuralları) ===
  ScoreResult? _finalScore;
  ScoreResult? get finalScore => _finalScore;

  void calculateFinalScore() {
    if (declarerIndex == null || _contractLevel == 0) {
      _finalScore = null;
      return;
    }

    // Declarer takımının topladığı eller
    final declarerTricks = _tricks[declarerIndex!] + _tricks[dummyIndex!];
    
    // Vulnerability kontrolü
    final isVulnerable = _vulnerability.isVulnerable(declarerIndex!);

    // Skor hesapla
    _finalScore = ScoreEngine.calculateScore(
      contractLevel: _contractLevel,
      contractSuit: _trump,
      tricksTaken: declarerTricks,
      vulnerable: isVulnerable,
      doubled: false, // TODO: double/redouble tracking eklenebilir
      redoubled: false,
    );

    notifyListeners();
  }
}

// === Point calculation helpers ===
extension BridgePoints on BridgeEngine {
  void _computePointsForSeat(int seat) {
    if (hands.isEmpty || seat < 0 || seat > 3) return;
    final hand = hands[seat];
    
    // YENİ: HandEvaluator kullan - profesyonel puan hesaplama
    final eval = HandEvaluator.evaluate(hand);
    
    // Per-seat structure
    seatPoints[seat] = BridgeSeatPoints(
      hcp: eval.hcp,
      length: eval.lengthPoints,
      shortHalf: eval.shortnessHalf,
      shortFull: eval.shortnessFull,
    );
    
    // Keep legacy single-seat fields for player (seat 0)
    if (seat == 0) {
      hcpPoints = eval.hcp;
      lengthPoints = eval.lengthPoints;
      totalPoints = eval.totalPoints;
      shortnessHalfPoints = eval.shortnessHalf;
      shortnessFullPoints = eval.shortnessFull;
      supportPointsHalf = eval.supportHalf;
      supportPointsFull = eval.supportFull;
    }
  }

  void _computePointsAll() {
    for (int s = 0; s < 4; s++) {
      _computePointsForSeat(s);
    }
  }
}

class BridgeSeatPoints {
  final int hcp;
  final int length;
  final int shortHalf;
  final int shortFull;
  int get total => hcp + length;
  int get supportHalf => hcp + shortHalf;
  int get supportFull => hcp + shortFull;
  const BridgeSeatPoints({
    required this.hcp,
    required this.length,
    required this.shortHalf,
    required this.shortFull,
  });
  const BridgeSeatPoints.empty()
    : hcp = 0,
      length = 0,
      shortHalf = 0,
      shortFull = 0;
}

class BatakEngine extends BaseTrickEngine {
  @override
  final GameType type = GameType.batak;
  BatakEngine() {
    trump = '♠';
    initDeal();
  }

  // Batak uses fixed trump (spades) and no bidding in this baseline
  @override
  bool get isBidding => false;
  @override
  int get contractLevel => 0;
  @override
  String? get trump => '♠';
  @override
  List<String> get bidHistory => const [];
  @override
  int get currentBidderIndex => 0;
  @override
  void placeBid({
    required int level,
    required String? trump,
    required bool pass,
  }) {}
  // Required by GameEngine interface
  @override
  bool get isDealing => false;
}
