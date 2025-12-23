import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/batak_engine.dart';
import '../components/cards/playing_card.dart';

class BatakGameScreen extends StatelessWidget {
  const BatakGameScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BatakEngine(),
      child: const _BatakGameView(),
    );
  }
}

class _BatakGameView extends StatelessWidget {
  const _BatakGameView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<BatakEngine>();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D7C34),
      appBar: AppBar(
        title: const Text('Batak'),
        backgroundColor: Colors.green[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => engine.newRound(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Skorlar ve durum
          _buildStatusBar(engine),
          
          // Oyun alanı
          Expanded(
            child: Stack(
              children: [
                // Oyun masası
                _buildGameTable(context, engine),
                
                // İhale dialogu
                if (engine.isBidding)
                  _buildBiddingOverlay(context, engine),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusBar(BatakEngine engine) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black26,
      child: Column(
        children: [
          // Skorlar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < 4; i++)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      i == 0 ? 'SİZ' : 'BOT $i',
                      style: TextStyle(
                        color: engine.activePlayerIndex == i
                            ? Colors.yellowAccent
                            : Colors.white70,
                        fontWeight: engine.activePlayerIndex == i
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${engine.scores[i]}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Oyun durumu
          if (!engine.isBidding && engine.currentBidder != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    engine.currentBidder == 0
                        ? 'Siz ${engine.contractLevel} el ihale ettiniz'
                        : 'BOT ${engine.currentBidder} ${engine.contractLevel} el ihale etti',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (engine.trump != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(Koz: ${engine.trump})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Alınan: ${engine.tricksCaptured[engine.currentBidder!]}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildGameTable(BuildContext context, BatakEngine engine) {
    return Column(
      children: [
        // Üst oyuncular (BOT 1, 2, 3)
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOpponentHand(context, engine, 1, 'Sol'),
              _buildOpponentHand(context, engine, 2, 'Üst'),
              _buildOpponentHand(context, engine, 3, 'Sağ'),
            ],
          ),
        ),
        
        // Masa ortası (oynanan kartlar)
        _buildTrickArea(context, engine),
        
        // Oyuncu eli
        _buildPlayerHand(context, engine),
        
        const SizedBox(height: 16),
      ],
    );
  }
  
  Widget _buildOpponentHand(
    BuildContext context,
    BatakEngine engine,
    int playerIndex,
    String position,
  ) {
    final count = engine.handCounts[playerIndex];
    final isActive = engine.activePlayerIndex == playerIndex;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.yellowAccent : Colors.white24,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            position,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            for (int i = 0; i < count.clamp(0, 5); i++)
              Padding(
                padding: EdgeInsets.only(left: i * 3.0),
                child: Transform.scale(
                  scale: 0.6,
                  child: const PlayingCard(cardId: ''),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$count kart',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTrickArea(BuildContext context, BatakEngine engine) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: engine.tableCards.isEmpty
          ? const Text(
              'Kart bekleniyor...',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                // 4 pozisyon (üst, alt, sol, sağ)
                for (int i = 0; i < engine.tableCards.length; i++)
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 400),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      final pos = _getCardPosition(i);
                      final startPos = _getStartPosition(i);
                      
                      return Positioned(
                        top: startPos['top'] != null 
                            ? startPos['top']! + (pos['top']! - startPos['top']!) * value
                            : null,
                        bottom: startPos['bottom'] != null
                            ? startPos['bottom']! + (pos['bottom']! - startPos['bottom']!) * value
                            : null,
                        left: startPos['left'] != null
                            ? startPos['left']! + (pos['left']! - startPos['left']!) * value
                            : null,
                        right: startPos['right'] != null
                            ? startPos['right']! + (pos['right']! - startPos['right']!) * value
                            : null,
                        child: Transform.scale(
                          scale: 0.8 + (value * 0.2),
                          child: child,
                        ),
                      );
                    },
                    child: PlayingCard(
                      cardId: engine.tableCards[i],
                      isFaceUp: true,
                      scale: 1.1,
                    ),
                  ),
              ],
            ),
    );
  }
  
  Map<String, double?> _getStartPosition(int index) {
    // Kartlar ortadan başlayıp pozisyonlarına gider
    return {'top': 90.0, 'bottom': null, 'left': null, 'right': null};
  }
  
  Map<String, double?> _getCardPosition(int index) {
    // 0: Alt (oyuncu), 1: Sol, 2: Üst, 3: Sağ
    switch (index) {
      case 0:
        return {'top': null, 'bottom': 10.0, 'left': null, 'right': null};
      case 1:
        return {'top': null, 'bottom': null, 'left': 10.0, 'right': null};
      case 2:
        return {'top': 10.0, 'bottom': null, 'left': null, 'right': null};
      case 3:
        return {'top': null, 'bottom': null, 'left': null, 'right': 10.0};
      default:
        return {'top': null, 'bottom': null, 'left': null, 'right': null};
    }
  }
  
  Widget _buildPlayerHand(BuildContext context, BatakEngine engine) {
    final hand = engine.playerHand;
    final isMyTurn = engine.activePlayerIndex == 0 && !engine.isBidding;
    final playable = engine.playableIndexes();
    
    return Column(
      children: [
        if (!isMyTurn && !engine.isBidding)
          const Text(
            'Rakip oynuyor...',
            style: TextStyle(
              color: Colors.yellowAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        
        SizedBox(
          height: 140,
          child: hand.isEmpty
              ? const Center(
                  child: Text(
                    'Elinizdeki kartlar bitti',
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              : Center(
                  child: Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (int i = 0; i < hand.length; i++)
                        TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 300 + (i * 50)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOutBack,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: child,
                            );
                          },
                          child: GestureDetector(
                            onTap: playable.contains(i) ? () => engine.selectCard(i) : null,
                            child: PlayingCard(
                              cardId: hand[i],
                              isFaceUp: true,
                              isSelected: engine.selectedIndex == i,
                              isRaised: engine.selectedIndex == i,
                              scale: 1.0,
                              animateEntry: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        
        if (isMyTurn)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ElevatedButton.icon(
              onPressed: engine.selectedIndex != null
                  ? () => engine.playSelected()
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Kartı Oyna'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                elevation: 8,
                shadowColor: Colors.orange.withValues(alpha: 0.5),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildBiddingOverlay(BuildContext context, BatakEngine engine) {
    final isMyTurn = engine.currentBidderIndex == 0;
    
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          color: Colors.green[800],
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMyTurn ? 'İhale Sırası Sizde!' : 'İhale Devam Ediyor...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // İhale geçmişi
                if (engine.bidHistory.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        for (final bid in engine.bidHistory.reversed.take(3))
                          Text(
                            bid,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                if (!isMyTurn)
                  const CircularProgressIndicator(color: Colors.white),
                
                if (isMyTurn) ...[
                  // İhale seçenekleri
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (int bid = engine.contractLevel + 1; bid <= 13; bid++)
                        ElevatedButton(
                          onPressed: () {
                            _showTrumpSelection(context, engine, bid);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('$bid El'),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Pas butonu
                  OutlinedButton.icon(
                    onPressed: () {
                      engine.placeBid(level: 0, trump: null, pass: true);
                    },
                    icon: const Icon(Icons.block),
                    label: const Text('Pas'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _showTrumpSelection(BuildContext context, BatakEngine engine, int bid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Koz Seç'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final suit in ['♠', '♥', '♦', '♣'])
              ListTile(
                leading: Text(
                  suit,
                  style: TextStyle(
                    fontSize: 32,
                    color: (suit == '♥' || suit == '♦')
                        ? Colors.red
                        : Colors.black,
                  ),
                ),
                title: Text(_getSuitName(suit)),
                onTap: () {
                  Navigator.pop(context);
                  engine.placeBid(level: bid, trump: suit, pass: false);
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.block, size: 32),
              title: const Text('Kozsuz'),
              onTap: () {
                Navigator.pop(context);
                engine.placeBid(level: bid, trump: null, pass: false);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  String _getSuitName(String suit) {
    switch (suit) {
      case '♠':
        return 'Maça';
      case '♥':
        return 'Kupa';
      case '♦':
        return 'Karo';
      case '♣':
        return 'Sinek';
      default:
        return '';
    }
  }
}
