import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/pisti_game_engine.dart';
import '../components/cards/playing_card.dart';

class PistiGameScreen extends StatelessWidget {
  const PistiGameScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PistiGameEngine(),
      child: const _PistiGameView(),
    );
  }
}

class _PistiGameView extends StatelessWidget {
  const _PistiGameView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<PistiGameEngine>();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D7C34),
      appBar: AppBar(
        title: const Text('Pişti'),
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
          // Skorlar
          _buildScoreboard(engine),
          
          // Üst oyuncular
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
          
          // Masa ortası
          _buildTableCenter(context, engine),
          
          // Oyuncu eli
          _buildPlayerHand(context, engine),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Widget _buildScoreboard(PistiGameEngine engine) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black26,
      child: Row(
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
                  '${engine.scores[i]} puan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (engine.pistiCounts[i] > 0)
                  Text(
                    '🎯 ${engine.pistiCounts[i]} pişti',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                    ),
                  ),
                Text(
                  '${engine.cardsCaptured[i]} kart',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  Widget _buildOpponentHand(
    BuildContext context,
    PistiGameEngine engine,
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
            for (int i = 0; i < count; i++)
              Padding(
                padding: EdgeInsets.only(left: i * 2.0),
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
  
  Widget _buildTableCenter(BuildContext context, PistiGameEngine engine) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (engine.tableCards.isEmpty)
            const Text(
              'Masa Boş',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 18,
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            Stack(
              alignment: Alignment.center,
              children: [
                // Alttan kartlar (yığın efekti)
                for (int i = 0; i < engine.tableCards.length - 1; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      left: (i * 3).toDouble(),
                      top: (i * 3).toDouble(),
                    ),
                    child: Transform.scale(
                      scale: 0.8,
                      child: const PlayingCard(cardId: ''),
                    ),
                  ),
                
                // En üstteki kart
                Transform.scale(
                  scale: 1.2,
                  child: PlayingCard(
                    cardId: engine.tableCards.last,
                    isFaceUp: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${engine.tableCards.length} kart',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPlayerHand(BuildContext context, PistiGameEngine engine) {
    final hand = engine.playerHand;
    final isMyTurn = engine.activePlayerIndex == 0;
    
    if (hand.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'Elinizdeki kartlar bitti',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
        ),
      );
    }
    
    return Column(
      children: [
        if (!isMyTurn)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.yellowAccent),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Rakip oynuyor...',
                  style: TextStyle(
                    color: Colors.yellowAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        
        SizedBox(
          height: 140,
          child: Center(
            child: Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (int i = 0; i < hand.length; i++)
                  TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 250 + (i * 40)),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, (1 - value) * 50),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTap: isMyTurn ? () => engine.selectCard(i) : null,
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
            padding: const EdgeInsets.only(top: 8),
            child: ElevatedButton.icon(
              onPressed: engine.selectedIndex != null
                  ? () => engine.playSelected()
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Kartı Oyna'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                elevation: 8,
                shadowColor: Colors.orange.withValues(alpha: 0.6),
              ),
            ),
          ),
      ],
    );
  }
}
