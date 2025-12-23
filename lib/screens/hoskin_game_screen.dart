import 'package:flutter/material.dart';
import '../core/hoskin_game_engine.dart';
import '../core/hoskin_models.dart';
import '../components/players/player_hands.dart';
import '../components/cards/card_widgets.dart';
import '../ai/hoskin_meld_engine.dart';
import '../ai/hoskin_bot_ai.dart';

class HoskinGameScreen extends StatefulWidget {
  final BotDifficulty difficulty;

  const HoskinGameScreen({
    super.key,
    this.difficulty = BotDifficulty.medium,
  });

  @override
  State<HoskinGameScreen> createState() => _HoskinGameScreenState();
}

class _HoskinGameScreenState extends State<HoskinGameScreen> {
  late HoskinGameEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = HoskinGameEngine(botDifficulty: widget.difficulty);
    _engine.addListener(_onEngineUpdate);
    _engine.startGame();
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngineUpdate);
    super.dispose();
  }

  void _onEngineUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A5F38), // Yeşil masa
      appBar: AppBar(
        title: const Text('Hoşkin'),
        backgroundColor: const Color(0xFF094028),
        actions: [
          if (_engine.phase == GamePhase.playing)
            IconButton(
              icon: Icon(
                _engine.showMelds ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: _engine.toggleShowMelds,
              tooltip: 'Barışları Göster',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showGameInfo,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Ana oyun alanı
          Column(
            children: [
              // Üst bilgi ve skor
              _buildTopBar(),
              
              // Oyun masası
              Expanded(
                child: _buildGameTable(),
              ),

              // Alt oyuncu eli
              _buildPlayerHand(),
            ],
          ),

          // İhale dialog'u
          if (_engine.phase == GamePhase.bidding && _engine.currentBidder == 0)
            _buildBiddingDialog(),

          // Kart açma dialog'u
          if (_engine.phase == GamePhase.opening && _engine.currentPlayer == 0)
            _buildOpeningDialog(),

          // Koz seçimi dialog'u
          if (_engine.phase == GamePhase.selectingTrump)
            _buildTrumpSelectionDialog(),

          // Skor ekranı
          if (_engine.phase == GamePhase.scoring)
            _buildScoringScreen(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF094028),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTeamScore(0),
          if (_engine.trump != null)
            Column(
              children: [
                const Text(
                  'Koz',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  _engine.trump!.symbol,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          _buildTeamScore(1),
        ],
      ),
    );
  }

  Widget _buildTeamScore(int teamId) {
    final team = _engine.teams[teamId];
    final isWinnerTeam = _engine.winnerSeat != null &&
        _engine.players[_engine.winnerSeat!].teamId == teamId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isWinnerTeam ? Colors.amber.withOpacity(0.3) : Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: isWinnerTeam
            ? Border.all(color: Colors.amber, width: 2)
            : null,
      ),
      child: Column(
        children: [
          Text(
            'Takım ${teamId + 1}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          Text(
            '${team.totalScore}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_engine.phase != GamePhase.bidding)
            Text(
              'B:${team.meldPoints} O:${team.gamePoints}',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameTable() {
    return Center(
      child: Stack(
        children: [
          // Masa ortası - oynanan kartlar
          Center(
            child: _buildTableCards(),
          ),

          // Diğer oyuncular (üst, sol, sağ)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: _buildOpponentHand(2), // Üst
          ),
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            child: Center(child: _buildOpponentHand(3)), // Sol
          ),
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: Center(child: _buildOpponentHand(1)), // Sağ
          ),

          // Mevcut oyuncu göstergesi
          _buildCurrentPlayerIndicator(),
        ],
      ),
    );
  }

  Widget _buildTableCards() {
    if (_engine.tableCards.isEmpty) {
      return Container(
        width: 200,
        height: 140,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Kartlar buraya\natılacak',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white30),
          ),
        ),
      );
    }

    return SizedBox(
      width: 250,
      height: 200,
      child: Stack(
        children: [
          for (int i = 0; i < _engine.tableCards.length; i++)
            _buildTableCard(_engine.tableCards[i], i),
        ],
      ),
    );
  }

  Widget _buildTableCard(HoskinCard card, int index) {
    final positions = [
      const Offset(75, 120), // Alt (oyuncu)
      const Offset(150, 75), // Sağ
      const Offset(75, 30), // Üst
      const Offset(0, 75), // Sol
    ];

    final pos = positions[index];

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: CardWidget(
        label: card.label,
        scale: 0.9,
      ),
    );
  }

  Widget _buildOpponentHand(int seat) {
    final player = _engine.players[seat];
    final cardCount = player.hand.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          player.name,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < min(cardCount, 10); i++)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: CardBackWidget(scale: 0.6),
              ),
          ],
        ),
        Text(
          '$cardCount kart',
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildPlayerHand() {
    final hand = _engine.playerHand;
    final playable = _engine.getPlayableIndices();

    return Container(
      height: 180,
      color: const Color(0xFF094028),
      child: hand.isEmpty
          ? const Center(
              child: Text(
                'El bitti',
                style: TextStyle(color: Colors.white60),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  for (int i = 0; i < hand.length; i++)
                    GestureDetector(
                      onTap: playable.contains(i)
                          ? () => _onCardTapped(i)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: CardWidget(
                          label: hand[i].label,
                          selected: _engine.selectedCardIndex == i,
                          selectable: playable.contains(i),
                          raised: _engine.selectedCardIndex == i,
                          scale: 1.1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentPlayerIndicator() {
    if (_engine.phase != GamePhase.playing) return const SizedBox();

    final positions = [
      const Offset(0, -40), // Alt
      const Offset(80, 0), // Sağ
      const Offset(0, 80), // Üst
      const Offset(-80, 0), // Sol
    ];

    final pos = positions[_engine.currentPlayer];

    return Positioned(
      left: MediaQuery.of(context).size.width / 2 + pos.dx,
      top: MediaQuery.of(context).size.height / 2 + pos.dy,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.amber,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.person, color: Colors.black87),
      ),
    );
  }

  Widget _buildBiddingDialog() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'İhale',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mevcut İhale: ${_engine.highestBid}',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int bid = _engine.highestBid + 10;
                        bid <= 200;
                        bid += 10)
                      ElevatedButton(
                        onPressed: () => _engine.placeBid(bid),
                        child: Text('$bid'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _engine.passBid,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Pas'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpeningDialog() {
    final selectedIndices = <int>{};

    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '4 Kart Açın',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Seçilen: ${selectedIndices.length}/4',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (int i = 0; i < _engine.playerHand.length; i++)
                              GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    if (selectedIndices.contains(i)) {
                                      selectedIndices.remove(i);
                                    } else if (selectedIndices.length < 4) {
                                      selectedIndices.add(i);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: CardWidget(
                                    label: _engine.playerHand[i].label,
                                    selected: selectedIndices.contains(i),
                                    raised: selectedIndices.contains(i),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: selectedIndices.length == 4
                          ? () => _engine.selectOpenCards(selectedIndices.toList())
                          : null,
                      child: const Text('Kartları Aç'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrumpSelectionDialog() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Koz Seçin',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final suit in Suit.values)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: ElevatedButton(
                          onPressed: () => _engine.selectTrump(suit),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(24),
                          ),
                          child: Text(
                            suit.symbol,
                            style: TextStyle(
                              fontSize: 36,
                              color: suit.isRed ? Colors.red : Colors.black,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoringScreen() {
    final winnerTeam = _engine.teams[
        _engine.players[_engine.winnerSeat!].teamId
    ];
    final total = winnerTeam.calculateTotal();
    final success = total >= _engine.highestBid;

    return Container(
      color: Colors.black87,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  success ? 'İhale Başarılı!' : 'İhale Batık!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: success ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'İhale: ${_engine.highestBid}',
                  style: const TextStyle(fontSize: 18),
                ),
                Text(
                  'Toplam: $total',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                for (final team in _engine.teams) ...[
                  Text(
                    'Takım ${team.id + 1}: ${team.totalScore}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _engine.nextRound,
                  child: const Text('Sonraki Tur'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onCardTapped(int index) {
    if (_engine.phase != GamePhase.playing) return;
    if (_engine.currentPlayer != 0) return;

    if (_engine.selectedCardIndex == index) {
      _engine.playSelectedCard();
    } else {
      _engine.selectCard(index);
    }
  }

  void _showGameInfo() {
    final melds = HoskinMeldEngine.calculateMelds(_engine.playerHand);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oyun Bilgisi'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Barış Sayılarınız:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (melds.melds.isEmpty)
                const Text('Barış yok')
              else
                for (final meld in melds.melds)
                  Text('• ${meld.description}'),
              const SizedBox(height: 16),
              Text(
                'Toplam Barış: ${melds.totalPoints}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  int min(int a, int b) => a < b ? a : b;
}
