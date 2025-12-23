import 'package:flutter/material.dart';
import '../core/game_core.dart';
import '../components/players/player_hands.dart';
import '../components/cards/card_widgets.dart';
import '../components/ui/suit_badge.dart';
import '../components/ui/bidding_dialog.dart';
import '../components/ui/game_score_tracker.dart';
import '../components/ui/bridge_score_pad.dart';

class GameTableScreen extends StatefulWidget {
  final GameEngine engine;
  final String playerName;
  const GameTableScreen({
    super.key,
    required this.engine,
    this.playerName = 'Player',
  });
  @override
  State<GameTableScreen> createState() => _GameTableScreenState();
}

class _GameTableScreenState extends State<GameTableScreen>
    with TickerProviderStateMixin {
  bool _showBiddingDialog = false;
  late GameScoreTracker _scoreTracker;
  final Map<int, AnimationController> _cardAnimations = {};
  final Map<int, Animation<Offset>> _cardPositions = {};
  int _lastTableCount = 0;
  bool _collecting = false;
  int _lastDealtTotal = 0; // track total cards dealt for dealing animation
  AnimationController? _dealController;
  Animation<Offset>? _dealFlight;
  Animation<double>? _dealScale;
  Animation<double>? _dealOpacity;
  Animation<double>? _dealRotation;
  int? _dealTargetSeat;
  bool _reducedMotion = false; // accessibility toggle
  bool _hapticsEnabled = false; // optional haptics
  // Animation settings (configurable from Ayarlar)
  int _dealDurationMs = 240; // per card deal flight
  int _dealInterDelayMs = 55; // placeholder for future sequential pacing UI
  int _collectDurationMs =
      350; // trick collect flight - faster for smoother feel
  double _fanSpread = 1.0; // fan offsets multiplier

  @override
  void initState() {
    super.initState();
    _scoreTracker = GameScoreTracker();
    widget.engine.addListener(_onEngine);
    // Show bidding dialog immediately after first frame if game starts in bidding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.engine.isBidding &&
          widget.engine.phase == GameStatePhase.bidding) {
        _showBiddingDialog = true;
        _showBiddingPopup();
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _cardAnimations.values) {
      controller.dispose();
    }
    _disposeDealFlight();
    widget.engine.removeListener(_onEngine);
    super.dispose();
  }

  void _onEngine() {
    // Check if new card was played
    if (widget.engine.tableCards.length > _lastTableCount) {
      _animateNewCard(widget.engine.tableCards.length - 1);
      _lastTableCount = widget.engine.tableCards.length;
      // Dealing animation: detect new dealt card
      if (widget.engine.isDealing) {
        final total = widget.engine.handCounts.fold<int>(0, (a, b) => a + b);
        if (total > _lastDealtTotal) {
          _startDealFlight(total - 1); // zero-based index of dealt card
          _lastDealtTotal = total;
        }
      } else {
        _disposeDealFlight();
        _lastDealtTotal = widget.engine.handCounts.fold<int>(
          0,
          (a, b) => a + b,
        );
      }
      // If trick completed now, schedule collect animation
      if (_lastTableCount == 4 && !_collecting) {
        _collecting = true;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          // Ensure cards still there (not cleared yet)
          if (widget.engine.tableCards.length == 4) {
            _animateCollectToWinner();
          }
          // Reset collecting flag after animation completes
          Future.delayed(Duration(milliseconds: _collectDurationMs + 100), () {
            if (mounted) {
              setState(() {
                _collecting = false;
              });
            }
          });
        });
      }
    } else if (widget.engine.tableCards.isEmpty) {
      // Cards were collected, reset animations
      for (final controller in _cardAnimations.values) {
        controller.dispose();
      }
      _cardAnimations.clear();
      _cardPositions.clear();
      _lastTableCount = 0;
      // _collecting flag now reset after animation completes, not here
    }

    setState(() {
      // Show bidding dialog when bidding phase starts
      if (widget.engine.isBidding &&
          widget.engine.phase == GameStatePhase.bidding) {
        if (!_showBiddingDialog) {
          _showBiddingDialog = true;
          Future.microtask(() => _showBiddingPopup());
        }
      } else {
        _showBiddingDialog = false;
      }
    });
  }

  void _animateNewCard(int cardIndex) {
    final controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    // Seat who played this card for current trick order
    final seatIndex =
        (widget.engine.leaderIndex + (cardIndex % 4)) %
        4; // 0=Player, 1=East, 2=North, 3=West
    final startPos = _getStartPosition(seatIndex);
    final endPos = _getCenterPosition(cardIndex);

    final animation = Tween<Offset>(begin: startPos, end: endPos).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic),
    );

    _cardAnimations[cardIndex] = controller;
    _cardPositions[cardIndex] = animation;

    controller.forward();
  }

  void _animateCollectToWinner() {
    if (widget.engine.tableCards.length < 4) return;
    // Winner seat is set on engine when trick resolves (leaderIndex points to trick winner)
    final winnerSeat =
        widget.engine.leaderIndex; // 0:South, 1:East, 2:North, 3:West
    // Base anchor near winner's hand
    final anchor = _getStartPosition(winnerSeat);
    // Fan offsets for neat stacking near the winner
    final fan = [
      const Offset(-18, -10),
      const Offset(-6, -6),
      const Offset(6, -6),
      const Offset(18, -10),
    ];
    // Adjust fan orientation per seat to feel directional
    List<Offset> oriented;
    switch (winnerSeat) {
      case 0: // South: stack upward from bottom hand
        oriented = fan;
        break;
      case 2: // North: invert vertical
        oriented = fan.map((o) => Offset(o.dx, -o.dy)).toList();
        break;
      case 1: // East: rotate left
        oriented = fan.map((o) => Offset(-o.dy, -o.dx)).toList();
        break;
      case 3: // West: rotate right
        oriented = fan.map((o) => Offset(o.dy, o.dx)).toList();
        break;
      default:
        oriented = fan;
    }

    // All cards move with minimal stagger for ultra-smooth collection
    for (int i = 0; i < 4; i++) {
      if (!mounted) return;
      final controller = AnimationController(
        duration: Duration(milliseconds: _collectDurationMs),
        vsync: this,
      );
      final current = _cardPositions[i]?.value ?? _getCenterPosition(i);
      final dest = Offset(
        anchor.dx + oriented[i].dx * _fanSpread,
        anchor.dy + oriented[i].dy * _fanSpread,
      );

      // Smooth fast curve for natural fluid gathering
      final animation = Tween<Offset>(begin: current, end: dest).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic),
      );

      _cardAnimations[i] = controller;
      _cardPositions[i] = animation;

      // Minimal stagger for near-simultaneous movement (15ms each)
      Future.delayed(Duration(milliseconds: i * 15), () {
        if (mounted) controller.forward();
      });
    }
  }

  void _startDealFlight(int dealtIndex) {
    _disposeDealFlight();
    // Determine seat by cumulative counts
    int seat = 0;
    final counts = widget.engine.handCounts;
    int running = 0;
    for (int s = 0; s < counts.length; s++) {
      running += counts[s];
      if (running >= dealtIndex + 1) {
        seat = s;
        break;
      }
    }
    _dealTargetSeat = seat;
    _dealController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _dealDurationMs),
    );

    final start = const Offset(350.0 - 32, 235.0 - 46); // center deck origin
    final end = _getStartPosition(seat);

    if (_reducedMotion) {
      // Accessibility: Simple, clean animation without rotation or complex effects
      _dealFlight = Tween<Offset>(begin: start, end: end).animate(
        CurvedAnimation(parent: _dealController!, curve: Curves.easeOut),
      );
      _dealScale = Tween<double>(
        begin: 0.92,
        end: 0.92,
      ).animate(_dealController!);
      _dealOpacity = Tween<double>(begin: 1, end: 1).animate(_dealController!);
      _dealRotation = Tween<double>(begin: 0, end: 0).animate(_dealController!);
    } else {
      // Juicy, satisfying mobile game feel
      final control = _computeBezierControl(start, end, seat);

      // Flight path: Bezier curve with easeOutCubic for smooth deceleration
      _dealFlight = _BezierOffsetTween(begin: start, end: end, control: control)
          .animate(
            CurvedAnimation(
              parent: _dealController!,
              curve: Curves.easeOutCubic,
            ),
          );

      // Scale: Slight bounce effect - card grows then settles
      _dealScale = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 0.82,
            end: 1.08,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 60,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: 1.08,
            end: 0.92,
          ).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 40,
        ),
      ]).animate(_dealController!);

      // Opacity: Fade in smoothly at the start
      _dealOpacity = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(
          parent: _dealController!,
          curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
        ),
      );

      // Rotation: Gentle spin during flight for 'card floating through air' effect
      // Direction based on seat for variety
      final rotationDirection = (seat == 1 || seat == 2) ? 1.0 : -1.0;
      _dealRotation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 0.0,
            end: 0.12 * rotationDirection,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: 0.12 * rotationDirection,
            end: 0.0,
          ).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 50,
        ),
      ]).animate(_dealController!);
    }

    _dealController!.forward();
    setState(() {});
  }

  void _disposeDealFlight() {
    _dealController?.dispose();
    _dealController = null;
    _dealFlight = null;
    _dealScale = null;
    _dealOpacity = null;
    _dealRotation = null;
    _dealTargetSeat = null;
  }

  // Compute a subtle control point for quadratic Bezier based on target seat
  Offset _computeBezierControl(Offset start, Offset end, int seat) {
    final midX = (start.dx + end.dx) / 2;
    final midY = (start.dy + end.dy) / 2;
    final dx = (end.dx - start.dx).abs();
    final dy = (end.dy - start.dy).abs();
    // Dynamic curvature based on path length
    final mag = 0.12 * (dx + dy);
    switch (seat) {
      case 0: // South
        return Offset(midX, midY - mag);
      case 2: // North
        return Offset(midX, midY + mag);
      case 3: // West
        return Offset(midX + mag, midY);
      case 1: // East
        return Offset(midX - mag, midY);
      default:
        return Offset(midX, midY);
    }
  }

  // Quadratic Bezier tween for Offset declared at top-level below

  Offset _getStartPosition(int seatIndex) {
    final centerX = 360.0;
    final centerY = 245.0;

    switch (seatIndex) {
      case 0: // Player (bottom)
        return Offset(centerX, centerY + 170);
      case 1: // East (right)
        return Offset(centerX + 260, centerY);
      case 2: // North (top)
        return Offset(centerX, centerY - 170);
      case 3: // West (left)
        return Offset(centerX - 260, centerY);
      default:
        return Offset(centerX, centerY);
    }
  }

  // Compute play target closer to each seat from center
  Offset _getPlayPositionForSeat(int seatIndex) {
    final tableCenter = const Offset(
      350.0,
      370.0,
    ); // shifted up 35px closer to player
    final anchor = _getStartPosition(seatIndex);
    // Move from center towards anchor by a factor (closer to player)
    const factor = 0.39; // 0..1, higher = closer to player
    var pos = Offset(
      tableCenter.dx + (anchor.dx - tableCenter.dx) * factor,
      tableCenter.dy + (anchor.dy - tableCenter.dy) * factor,
    );
    // Seat-specific micro adjustments for tidy alignment
    switch (seatIndex) {
      case 0: // South
        pos = pos.translate(-4, 15);
        break;
      case 1: // East
        pos = pos.translate(-15, -2);
        break;
      case 2: // North
        pos = pos.translate(-4, -10);
        break;
      case 3: // West
        pos = pos.translate(7, -2);
        break;
    }
    // Top-left placement compensation by half card size
    return Offset(pos.dx - 32, pos.dy - 46);
  }

  Offset _getCenterPosition(int cardIndex) {
    // Seat who played this card = leader + order offset (0..3) clockwise
    final seatIndex = (widget.engine.leaderIndex + (cardIndex % 4)) % 4;
    return _getPlayPositionForSeat(seatIndex);
  }

  void _maybeShowScoreDialog() {
    if (widget.engine.phase == GameStatePhase.scoreUpdate) {
      final scores = widget.engine.scores;

      // Calculate team scores: Team 0 (Player + North), Team 1 (East + West)
      final team0Score =
          (scores.isNotEmpty ? scores[0] : 0) +
          (scores.length > 2 ? scores[2] : 0);
      final team1Score =
          (scores.length > 1 ? scores[1] : 0) +
          (scores.length > 3 ? scores[3] : 0);

      // Add round score
      _scoreTracker.addRoundScore(team0Score, team1Score);

      // Show score table dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return ScoreTableDialog(
            tracker: _scoreTracker,
            onNewGame: () {
              _scoreTracker.reset();
              widget.engine.newRound();
              Navigator.of(ctx).pop();
            },
            onContinue: () {
              widget.engine.newRound();
              Navigator.of(ctx).pop();
            },
          );
        },
      );
    }
  }

  void _showBiddingPopup() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // Use AnimatedBuilder to listen to engine changes
        return AnimatedBuilder(
          animation: widget.engine,
          builder: (context, child) {
            // Auto-close when bidding ends
            if (!widget.engine.isBidding) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(ctx)) {
                  Navigator.of(ctx).pop();
                  _showBiddingDialog = false;
                }
              });
            }

            return BiddingDialog(
              bidHistory: widget.engine.bidHistory,
              currentBidderIndex: widget.engine.currentBidderIndex,
              contractLevel: widget.engine.contractLevel,
              contractTrump: widget.engine.trump,
              tricksWon: widget.engine.scores.isNotEmpty
                  ? widget.engine.scores
                  : null,
              onBid: (level, trump, pass) {
                widget.engine.placeBid(level: level, trump: trump, pass: pass);
              },
            );
          },
        );
      },
    );
  }

  void _playSelected() => widget.engine.playSelected();

  @override
  Widget build(BuildContext context) {
    final phase = widget.engine.phase;
    final bottomCards = widget.engine.playerHand;
    final selected = widget.engine.selectedIndex;
    final playable = phase == GameStatePhase.waitingForPlayer
        ? widget.engine.playableIndexes()
        : <int>{};
    final table = widget.engine.tableCards;
    final isBidding =
        widget.engine.isBidding && phase == GameStatePhase.bidding;
    final contractLevel = widget.engine.contractLevel;
    final contractTrump = widget.engine.trump; // null => NT
    // For Bridge dummy view
    final isBridge = widget.engine.type == GameType.bridge;
    final br = isBridge ? widget.engine as dynamic : null;
    final declarer = isBridge ? (br!.declarerIndex as int?) : null;
    final dummySeat = isBridge ? (br.dummyIndex as int?) : null;

    // Helper to get role label for Bridge
    String? _getRoleForSeat(int seat) {
      if (!isBridge || declarer == null) return null;
      if (seat == declarer) return 'Deklaran';
      if (seat == dummySeat) return 'Dummy';
      return 'Savunmacı'; // Defender
    }

    // Calculate card positions for center pile (relative to each seat)
    final centerPositions = _calculateCenterPositions(table.length);

    // ensure score dialog pops when needed
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowScoreDialog(),
    );

    // Responsive layout detection
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1000;
        final isTablet =
            constraints.maxWidth > 600 && constraints.maxWidth <= 1000;
        final isMobile = constraints.maxWidth <= 600;

        // Force landscape for mobile and tablet
        final shouldBeLandscape = !isDesktop;

        return Scaffold(
          backgroundColor: const Color(0xFF1B5E20), // Green table
          body: SafeArea(
            child: shouldBeLandscape
                ? OrientationBuilder(
                    builder: (context, orientation) {
                      // If mobile/tablet and not landscape, show rotate message
                      if (orientation != Orientation.landscape) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            margin: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white24,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.screen_rotation,
                                  size: 64,
                                  color: Colors.white70,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Lütfen Cihazınızı Yatay Çevirin',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Bu oyun yatay modda oynanır',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return _buildGameLayout(
                        context,
                        constraints,
                        isDesktop,
                        isTablet,
                        isMobile,
                        phase,
                        bottomCards,
                        selected,
                        playable,
                        table,
                        isBidding,
                        contractLevel,
                        contractTrump,
                        isBridge,
                        declarer,
                        dummySeat,
                        centerPositions,
                        _getRoleForSeat,
                      );
                    },
                  )
                : _buildGameLayout(
                    context,
                    constraints,
                    isDesktop,
                    isTablet,
                    isMobile,
                    phase,
                    bottomCards,
                    selected,
                    playable,
                    table,
                    isBidding,
                    contractLevel,
                    contractTrump,
                    isBridge,
                    declarer,
                    dummySeat,
                    centerPositions,
                    _getRoleForSeat,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildGameLayout(
    BuildContext context,
    BoxConstraints constraints,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
    GameStatePhase phase,
    List<String> bottomCards,
    int? selected,
    Set<int> playable,
    List<String> table,
    bool isBidding,
    int contractLevel,
    String? contractTrump,
    bool isBridge,
    int? declarer,
    int? dummySeat,
    List<Offset> centerPositions,
    String? Function(int) _getRoleForSeat,
  ) {
    // Responsive sizing
    final tableWidth = isDesktop
        ? 700.0
        : (isTablet
              ? constraints.maxWidth * 0.85
              : constraints.maxWidth * 0.95);
    final tableHeight = isDesktop
        ? 450.0
        : (isTablet
              ? constraints.maxHeight * 0.7
              : constraints.maxHeight * 0.75);
    final scorePadScale = isDesktop ? 0.65 : (isTablet ? 0.55 : 0.45);

    return Stack(
      children: [
        // Main game area
        Column(
          children: [
            // Top spacing
            SizedBox(height: isDesktop ? 12 : 4),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: tableWidth,
                  height: tableHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (widget.engine.isDealing)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(.55),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'Dağıtılıyor...',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (widget.engine.isDealing && _dealFlight != null)
                        AnimatedBuilder(
                          animation: _dealController!,
                          builder: (context, _) {
                            return Positioned(
                              left: _dealFlight!.value.dx,
                              top: _dealFlight!.value.dy,
                              child: Opacity(
                                opacity: _dealOpacity?.value ?? 1,
                                child: Transform.rotate(
                                  angle: _dealRotation?.value ?? 0,
                                  child: Transform.scale(
                                    scale: _dealScale?.value ?? .9,
                                    child: CardBackWidget(scale: .9),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      // Subtle halo on target seat while dealing
                      if (widget.engine.isDealing && _dealTargetSeat != null)
                        ..._buildSeatHalo(_dealTargetSeat!),
                      // Center playing area circle (shifted 10px down to align)
                      Center(
                        child: Transform.translate(
                          offset: const Offset(0, 100),
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(.20),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Table pile visualization with animated positions
                      for (var i = 0; i < table.length; i++)
                        if (_cardAnimations.containsKey(i) &&
                            _cardPositions.containsKey(i))
                          AnimatedBuilder(
                            animation: _cardAnimations[i]!,
                            builder: (context, child) {
                              // subtle rotation based on seat direction
                              final seat =
                                  (widget.engine.leaderIndex + (i % 4)) % 4;
                              final rotBase = (seat == 0 || seat == 2)
                                  ? -0.08
                                  : 0.08;
                              final angle = rotBase * _cardAnimations[i]!.value;
                              return Positioned(
                                left: _cardPositions[i]!.value.dx,
                                top: _cardPositions[i]!.value.dy,
                                child: Transform.rotate(
                                  angle: angle,
                                  child: Transform.scale(
                                    scale:
                                        1.0 - (_cardAnimations[i]!.value * 0.1),
                                    child: Stack(
                                      children: [
                                        CardWidget(
                                          label: table[i],
                                          raised: true,
                                        ),
                                        // Removed order badge per request
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          Positioned(
                            left: centerPositions[i].dx,
                            top: centerPositions[i].dy,
                            child: Stack(
                              children: [
                                CardWidget(
                                  label: table[i],
                                  raised: i == table.length - 1,
                                ),
                                // Removed order badge per request
                              ],
                            ),
                          ),

                      // Position indicators for card placement
                      if (table.isEmpty) ..._buildPositionIndicators(),

                      // North opponent (top) - moved further up
                      Positioned(
                        top: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PlayerAvatar(
                                  name: 'North',
                                  active: widget.engine.activePlayerIndex == 2,
                                ),
                                if (widget.engine.scores.isNotEmpty &&
                                    widget.engine.scores.length > 2) ...[
                                  const SizedBox(width: 8),
                                  _TrickCounter(count: widget.engine.scores[2]),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (isBridge &&
                                !isBidding &&
                                dummySeat == 2 &&
                                declarer ==
                                    0) // Show dummy to declarer (human player)
                              // Dummy hand face-up: fan layout like player hand for better visibility
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final engine = widget.engine as dynamic;
                                  final cards = engine.hands[2] as List<String>;
                                  final isDummyTurn =
                                      widget.engine.activePlayerIndex == 2;
                                  final isDeclarerHuman = declarer == 0;
                                  final canPlayDummy =
                                      isDummyTurn && isDeclarerHuman;

                                  // Get playable indices directly from engine when dummy's turn
                                  Set<int> dummyPlayable = {};
                                  if (canPlayDummy) {
                                    dummyPlayable = widget.engine
                                        .playableIndexes();
                                  }

                                  // Use PlayerHand widget for dummy (no rotation needed)
                                  return Transform.scale(
                                    scale:
                                        0.85, // Slightly smaller than player hand
                                    child: PlayerHand(
                                      cards: cards,
                                      playable: dummyPlayable,
                                      selectedIndex: canPlayDummy
                                          ? selected
                                          : null,
                                      onSelect: (i) {
                                        print('DUMMY CARD TAPPED: idx=$i');
                                        widget.engine.selectCard(i);
                                      },
                                      onDoubleTap: canPlayDummy
                                          ? (i) {
                                              print(
                                                'DUMMY CARD DOUBLE-TAPPED: idx=$i',
                                              );
                                              widget.engine.selectCard(i);
                                              _playSelected();
                                            }
                                          : null,
                                      fanSpread:
                                          _fanSpread *
                                          0.8, // Slightly tighter fan
                                    ),
                                  );
                                },
                              )
                            else
                              OpponentHandHorizontal(
                                cardCount: widget.engine.handCounts.length > 2
                                    ? widget.engine.handCounts[2]
                                    : 0,
                              ),
                          ],
                        ),
                      ),
                      // West opponent (left) - moved further left
                      Positioned(
                        left: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OpponentHandVertical(
                              cardCount: widget.engine.handCounts.length > 3
                                  ? widget.engine.handCounts[3]
                                  : 0,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PlayerAvatar(
                                  name: 'West',
                                  active: widget.engine.activePlayerIndex == 3,
                                ),
                                if (widget.engine.scores.isNotEmpty &&
                                    widget.engine.scores.length > 3)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: _TrickCounter(
                                      count: widget.engine.scores[3],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // East opponent (right) - moved further right
                      Positioned(
                        right: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PlayerAvatar(
                                  name: 'East',
                                  active: widget.engine.activePlayerIndex == 1,
                                ),
                                if (widget.engine.scores.isNotEmpty &&
                                    widget.engine.scores.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: _TrickCounter(
                                      count: widget.engine.scores[1],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            OpponentHandVertical(
                              cardCount: widget.engine.handCounts.length > 1
                                  ? widget.engine.handCounts[1]
                                  : 0,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Player name with trick counter
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PlayerAvatar(
                    name: widget.playerName,
                    active:
                        widget.engine.activePlayerIndex == 0 &&
                        phase == GameStatePhase.waitingForPlayer,
                    role: _getRoleForSeat(0),
                  ),
                  if (widget.engine.scores.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _TrickCounter(count: widget.engine.scores[0]),
                  ],
                ],
              ),
            ),
            // Player hand
            PlayerHand(
              cards: bottomCards,
              playable: playable,
              selectedIndex: selected,
              onSelect: (i) {
                widget.engine.selectCard(i);
              },
              onDoubleTap: (i) {
                widget.engine.selectCard(i);
                if (widget.engine.selectedIndex != null &&
                    phase == GameStatePhase.waitingForPlayer &&
                    widget.engine.activePlayerIndex == 0) {
                  _playSelected();
                }
              },
              fanSpread: _fanSpread,
            ),
            // Bottom controls
            SizedBox(
              height: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Show "Start Bidding" button for Bridge before bidding starts
                  if (widget.engine.type == GameType.bridge &&
                      !isBidding &&
                      contractLevel == 0)
                    ElevatedButton(
                      onPressed: widget.engine.isDealing
                          ? null
                          : () {
                              (widget.engine as dynamic).startBidding();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'İhaleyi Başlat',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed:
                          (!widget.engine.isDealing &&
                              widget.engine.selectedIndex != null &&
                              phase == GameStatePhase.waitingForPlayer &&
                              widget.engine.activePlayerIndex == 0)
                          ? _playSelected
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Play Card'),
                    ),
                  const SizedBox(width: 16),
                  if (!isBidding &&
                      widget.engine.type == GameType.bridge &&
                      contractLevel > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1226),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'KONTRAT: ',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text('$contractLevel'),
                          const SizedBox(width: 8),
                          SuitBadge(suit: contractTrump ?? 'NT', size: 20),
                        ],
                      ),
                    ),
                  const SizedBox(width: 16),
                  if (widget.engine.type == GameType.bridge)
                    ElevatedButton.icon(
                      onPressed: () => _showSettingsDialog(context),
                      icon: const Icon(Icons.settings),
                      label: const Text('Ayarlar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF374151),
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),

        // Score pad - Fixed position in top right, above all other elements
        if (isBridge)
          Positioned(
            top: 15,
            right: 200,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Transform.scale(
                scale: scorePadScale,
                child: _buildScorePad(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScorePad() {
    final br = widget.engine as dynamic;
    final scores = widget.engine.scores;
    final seatPoints = br.seatPoints as List<dynamic>?;

    // Team scores: We (Player + North = 0,2), They (East + West = 1,3)
    final weScore =
        (scores.isNotEmpty ? scores[0] : 0) +
        (scores.length > 2 ? scores[2] : 0);
    final theyScore =
        (scores.length > 1 ? scores[1] : 0) +
        (scores.length > 3 ? scores[3] : 0);

    // For demo: create sample entries (in real game, track these as tricks are won)
    final weEntries = <ScoreEntry>[];
    final theyEntries = <ScoreEntry>[];

    // Below line: contract points from tricks won
    if (weScore > 0) {
      weEntries.add(ScoreEntry(points: weScore * 10, isBelowLine: true));
    }
    if (theyScore > 0) {
      theyEntries.add(ScoreEntry(points: theyScore * 10, isBelowLine: true));
    }

    // Above line: bonuses (placeholder for now)
    if (seatPoints != null && seatPoints.isNotEmpty) {
      final weHcp =
          (seatPoints[0].hcp as int) +
          (seatPoints.length > 2 ? (seatPoints[2].hcp as int) : 0);
      final theyHcp =
          (seatPoints.length > 1 ? (seatPoints[1].hcp as int) : 0) +
          (seatPoints.length > 3 ? (seatPoints[3].hcp as int) : 0);
      if (weHcp >= 10)
        weEntries.add(
          ScoreEntry(points: weHcp, isBelowLine: false, label: 'HCP'),
        );
      if (theyHcp >= 10)
        theyEntries.add(
          ScoreEntry(points: theyHcp, isBelowLine: false, label: 'HCP'),
        );
    }

    return BridgeScorePad(
      weScores: weEntries,
      theyScores: theyEntries,
      weGamesWon: 0, // Track games in real implementation
      theyGamesWon: 0,
    );
  }

  void _showSettingsDialog(BuildContext context) {
    if (widget.engine.type != GameType.bridge) return;
    final br = widget.engine as dynamic; // BridgeEngine
    int current = (br.maxTricks as int?) ?? 5;
    showDialog(
      context: context,
      builder: (ctx) {
        int temp = current;
        int dealMs = _dealDurationMs;
        int interMs = _dealInterDelayMs;
        int collectMs = _collectDurationMs;
        double fanSpread = _fanSpread;
        return AlertDialog(
          backgroundColor: const Color(0xFF0B1226),
          title: const Text(
            'Ayarlar',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tur Sayısı (maxTricks)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('5'),
                    Expanded(
                      child: Slider(
                        value: temp.toDouble(),
                        min: 5,
                        max: 13,
                        divisions: 8,
                        label: '$temp',
                        onChanged: (v) {
                          temp = v.round();
                          // rebuild dialog
                          (ctx as Element).markNeedsBuild();
                        },
                      ),
                    ),
                    const Text('13'),
                  ],
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Dağıtım hızı (ms/kart)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Row(
                  children: [
                    const Text('160'),
                    Expanded(
                      child: Slider(
                        value: dealMs.toDouble(),
                        min: 160,
                        max: 300,
                        divisions: 14,
                        label: '$dealMs',
                        onChanged: (v) {
                          dealMs = v.round();
                          (ctx as Element).markNeedsBuild();
                        },
                      ),
                    ),
                    const Text('300'),
                  ],
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Dağıtım arası (ms)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Row(
                  children: [
                    const Text('30'),
                    Expanded(
                      child: Slider(
                        value: interMs.toDouble(),
                        min: 30,
                        max: 120,
                        divisions: 9,
                        label: '$interMs',
                        onChanged: (v) {
                          interMs = v.round();
                          (ctx as Element).markNeedsBuild();
                        },
                      ),
                    ),
                    const Text('120'),
                  ],
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Toplama süresi (ms)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Row(
                  children: [
                    const Text('400'),
                    Expanded(
                      child: Slider(
                        value: collectMs.toDouble(),
                        min: 400,
                        max: 1200,
                        divisions: 8,
                        label: '$collectMs',
                        onChanged: (v) {
                          collectMs = v.round();
                          (ctx as Element).markNeedsBuild();
                        },
                      ),
                    ),
                    const Text('1200'),
                  ],
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Fan aralığı',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Row(
                  children: [
                    const Text('0.6'),
                    Expanded(
                      child: Slider(
                        value: fanSpread,
                        min: 0.6,
                        max: 1.8,
                        divisions: 12,
                        label: fanSpread.toStringAsFixed(1),
                        onChanged: (v) {
                          fanSpread = v;
                          (ctx as Element).markNeedsBuild();
                        },
                      ),
                    ),
                    const Text('1.8'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                br.setMaxTricks(temp);
                setState(() {
                  _dealDurationMs = dealMs;
                  _dealInterDelayMs = interMs;
                  _collectDurationMs = collectMs;
                  _fanSpread = fanSpread;
                });
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
              ),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  // Calculate center positions for played cards based on seat
  List<Offset> _calculateCenterPositions(int cardCount) {
    if (cardCount == 0) return [];

    final positions = <Offset>[];
    // Positions for each seat (0=bottom, 1=right, 2=top, 3=left)
    final seatOffsets = [
      _getPlayPositionForSeat(0),
      _getPlayPositionForSeat(1),
      _getPlayPositionForSeat(2),
      _getPlayPositionForSeat(3),
    ];

    // Map each played card i (order in current trick) to the correct seat relative to leader
    final leader = widget.engine.leaderIndex;
    for (int i = 0; i < cardCount && i < 4; i++) {
      final seat = (leader + i) % 4;
      positions.add(seatOffsets[seat]);
    }

    return positions;
  }

  List<Widget> _buildPositionIndicators() {
    final indicators = <Widget>[];

    final positions = [
      {'offset': _getPlayPositionForSeat(0), 'label': 'Siz'},
      {'offset': _getPlayPositionForSeat(1), 'label': 'East'},
      {'offset': _getPlayPositionForSeat(2), 'label': 'North'},
      {'offset': _getPlayPositionForSeat(3), 'label': 'West'},
    ];

    for (final pos in positions) {
      indicators.add(
        Positioned(
          left: (pos['offset'] as Offset).dx,
          top: (pos['offset'] as Offset).dy,
          child: Container(
            width: 64,
            height: 92,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(.2),
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                pos['label'] as String,
                style: TextStyle(
                  color: Colors.white.withOpacity(.3),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return indicators;
  }

  // Build subtle halo widgets for a given seat index
  List<Widget> _buildSeatHalo(int seatIndex) {
    final centerX = 350.0;
    final centerY = 245.0;
    Offset anchor;
    switch (seatIndex) {
      case 0: // South
        anchor = Offset(centerX, centerY + 180);
        break;
      case 1: // East
        anchor = Offset(centerX + 300, centerY);
        break;
      case 2: // North
        anchor = Offset(centerX, centerY - 200);
        break;
      case 3: // West
        anchor = Offset(centerX - 300, centerY);
        break;
      default:
        anchor = Offset(centerX, centerY);
    }
    return [
      Positioned(
        left: anchor.dx - 45,
        top: anchor.dy - 45,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.white24, blurRadius: 16, spreadRadius: 2),
            ],
          ),
        ),
      ),
    ];
  }
}

class _PointsPanel extends StatelessWidget {
  final GameEngine engine;
  const _PointsPanel({required this.engine});

  @override
  Widget build(BuildContext context) {
    final seats = ['Player', 'East', 'North', 'West'];
    final isBridge = engine.type == GameType.bridge;
    if (!isBridge) return const SizedBox.shrink();
    final br = engine as dynamic; // BridgeEngine
    final seatPoints = br.seatPoints as List<dynamic>?;
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1226).withOpacity(.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'PUANLAR',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          // Başlık: isimler yatay
          Row(
            children: [
              for (int s = 0; s < 4; s++)
                Expanded(
                  child: Text(
                    seats[s],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Her satırda farklı oyuncunun puanı; puanlar ilgili ismin sütununun altında
          for (int row = 0; row < 4; row++) ...[
            Row(
              children: [
                for (int col = 0; col < 4; col++)
                  Expanded(
                    child: col == row
                        ? Column(
                            children: [
                              Text(
                                'HCP: ${seatPoints != null ? (seatPoints[row].hcp as int) : 0}',
                                style: const TextStyle(fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'TOTAL: ${seatPoints != null ? (seatPoints[row].total as int) : 0}',
                                style: const TextStyle(fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'SUP: ${seatPoints != null ? (seatPoints[row].supportHalf as int) : 0}',
                                style: const TextStyle(fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
            if (row != 3)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Divider(
                  height: 1,
                  color: Colors.white12.withOpacity(.6),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SeatPointsRow extends StatelessWidget {
  final String name;
  final int hcp;
  final int total;
  final int support;
  const _SeatPointsRow({
    required this.name,
    required this.hcp,
    required this.total,
    required this.support,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        _Pill(label: 'HCP', value: hcp, color: const Color(0xFF1E3A8A)),
        const SizedBox(width: 6),
        _Pill(label: 'TOTAL', value: total, color: const Color(0xFF14532D)),
        const SizedBox(width: 6),
        _Pill(label: 'SUP', value: support, color: const Color(0xFF8B1D1D)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Pill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TrickCounter extends StatelessWidget {
  final int count;
  const _TrickCounter({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withOpacity(.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF10B981), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 14, color: Color(0xFFFBBF24)),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _orderBadge(int order) {
  return Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      color: const Color(0xFF0B1226).withOpacity(0.85),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: Colors.white24, width: 1),
    ),
    alignment: Alignment.center,
    child: Text(
      '$order',
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

// Top-level quadratic Bezier tween for Offset
class _BezierOffsetTween extends Tween<Offset> {
  final Offset control;
  _BezierOffsetTween({
    required Offset begin,
    required Offset end,
    required this.control,
  }) : super(begin: begin, end: end);
  @override
  Offset lerp(double t) {
    final p0p1 = Offset.lerp(begin!, control, t)!;
    final p1p2 = Offset.lerp(control, end!, t)!;
    return Offset.lerp(p0p1, p1p2, t)!;
  }
}
