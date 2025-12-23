import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/solitaire_engine.dart';
import '../components/cards/playing_card.dart';

class SolitaireGameScreen extends StatelessWidget {
  const SolitaireGameScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SolitaireEngine(),
      child: const _SolitaireGameView(),
    );
  }
}

class _SolitaireGameView extends StatelessWidget {
  const _SolitaireGameView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<SolitaireEngine>();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D7C34),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Solitaire'),
            const SizedBox(width: 16),
            Text(
              'Hamle: ${engine.moves}',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const Spacer(),
            Text(
              'Puan: ${engine.scores[0]}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.green[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            onPressed: () => engine.autoMoveToFoundation(),
            tooltip: 'Otomatik Hamle',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => engine.newRound(),
            tooltip: 'Yeni Oyun',
          ),
        ],
      ),
      body: engine.gameWon
          ? _buildWinScreen(context, engine)
          : _buildGameBoard(context, engine),
    );
  }
  
  Widget _buildWinScreen(BuildContext context, SolitaireEngine engine) {
    return Center(
      child: Card(
        color: Colors.green[700],
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events,
                size: 80,
                color: Colors.yellowAccent,
              ),
              const SizedBox(height: 16),
              const Text(
                'TEBRİKLER!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${engine.moves} hamle ile kazandınız!',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Puan: ${engine.scores[0]}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.yellowAccent,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => engine.newRound(),
                icon: const Icon(Icons.refresh),
                label: const Text('Yeni Oyun'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildGameBoard(BuildContext context, SolitaireEngine engine) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Üst kısım: Stock, Waste, Foundations
          Row(
            children: [
              // Stock
              GestureDetector(
                onTap: () => engine.drawFromStock(),
                child: _buildCardPile(
                  engine.stock.isNotEmpty
                      ? const PlayingCard(cardId: '')
                      : _buildEmptySlot('↻'),
                ),
              ),
              const SizedBox(width: 16),
              
              // Waste
              GestureDetector(
                onTap: () => engine.selectWaste(),
                child: _buildCardPile(
                  engine.waste.isNotEmpty
                      ? PlayingCard(
                          cardId: engine.waste.last,
                          isFaceUp: true,
                        )
                      : _buildEmptySlot(),
                ),
              ),
              
              const Spacer(),
              
              // Foundations (4 adet)
              for (int i = 0; i < 4; i++) ...[
                GestureDetector(
                  onTap: () {
                    if (engine.waste.isNotEmpty) {
                      engine.moveWasteToFoundation(i);
                    }
                  },
                  child: _buildCardPile(
                    engine.foundations[i].isNotEmpty
                        ? PlayingCard(
                            cardId: engine.foundations[i].last,
                            isFaceUp: true,
                          )
                        : _buildEmptySlot('A'),
                  ),
                ),
                if (i < 3) const SizedBox(width: 8),
              ],
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Tableau (7 sütun)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int col = 0; col < 7; col++)
                Expanded(
                  child: _buildTableauColumn(context, engine, col),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCardPile(Widget child) {
    return SizedBox(
      width: 60,
      height: 84,
      child: child,
    );
  }
  
  Widget _buildEmptySlot([String? label]) {
    return Container(
      width: 60,
      height: 84,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white30, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: Colors.black12,
      ),
      alignment: Alignment.center,
      child: label != null
          ? Text(
              label,
              style: const TextStyle(
                color: Colors.white30,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
  
  Widget _buildTableauColumn(
    BuildContext context,
    SolitaireEngine engine,
    int column,
  ) {
    final cards = engine.tableau[column];
    
    if (cards.isEmpty) {
      return GestureDetector(
        onTap: () {
          if (engine.waste.isNotEmpty) {
            engine.moveWasteToTableau(column);
          }
        },
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1000),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: 0.3 + (value * 0.2),
              child: child,
            );
          },
          child: _buildEmptySlot('K'),
        ),
      );
    }
    
    return Column(
      children: [
        for (int i = 0; i < cards.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 24),
            child: TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (i * 50)),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - value) * -30),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onTap: () {
                  if (engine.faceUpCards.contains(cards[i])) {
                    engine.selectTableau(column, i);
                    
                    // Akıllı taşıma
                    if (engine.waste.isEmpty) {
                      // Foundation'a taşınabilir mi?
                      for (int f = 0; f < 4; f++) {
                        engine.moveTableauToFoundation(column, f);
                      }
                    }
                  }
                },
                onDoubleTap: () {
                  // Çift tıklama - foundation'a otomatik taşı
                  if (i == cards.length - 1) {
                    for (int f = 0; f < 4; f++) {
                      engine.moveTableauToFoundation(column, f);
                    }
                  }
                },
                child: Transform.scale(
                  scale: 0.9,
                  child: PlayingCard(
                    cardId: cards[i],
                    isFaceUp: engine.faceUpCards.contains(cards[i]),
                    scale: 0.95,
                    animateEntry: true,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
