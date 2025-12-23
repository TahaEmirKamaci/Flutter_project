import 'package:flutter/material.dart';

/// Classic Bridge "Rubber" score pad with T-shaped layout
/// WE (Biz) vs THEY (Onlar)
/// Horizontal line separates "below the line" (contract points) from "above the line" (bonuses)
class BridgeScorePad extends StatelessWidget {
  final List<ScoreEntry> weScores;
  final List<ScoreEntry> theyScores;
  final int weGamesWon;
  final int theyGamesWon;

  const BridgeScorePad({
    super.key,
    this.weScores = const [],
    this.theyScores = const [],
    this.weGamesWon = 0,
    this.theyGamesWon = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Separate below/above the line
    final weBelowLine = weScores.where((e) => e.isBelowLine).toList();
    final weAboveLine = weScores.where((e) => !e.isBelowLine).toList();
    final theyBelowLine = theyScores.where((e) => e.isBelowLine).toList();
    final theyAboveLine = theyScores.where((e) => !e.isBelowLine).toList();

    // Calculate totals
    final weTotal = weScores.fold<int>(0, (sum, e) => sum + e.points);
    final theyTotal = theyScores.fold<int>(0, (sum, e) => sum + e.points);
    final weBelowTotal = weBelowLine.fold<int>(0, (sum, e) => sum + e.points);
    final theyBelowTotal = theyBelowLine.fold<int>(0, (sum, e) => sum + e.points);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF0), // Cream paper
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF8B7355), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          const Text(
            'SKOR TABLOSU',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 8),
          
          // Headers: WE | THEY
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: const Color(0xFF8B7355), width: 1),
                    ),
                  ),
                  child: const Text(
                    'N - S',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: const Color(0xFF8B7355), width: 1),
                    ),
                  ),
                  child: const Text(
                    'E - W',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8B1D1D),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // ABOVE THE LINE section
          Container(
            constraints: const BoxConstraints(minHeight: 60),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // WE - Above
                Expanded(
                  child: _ScoreColumn(
                    entries: weAboveLine,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(width: 12),
                // THEY - Above
                Expanded(
                  child: _ScoreColumn(
                    entries: theyAboveLine,
                    color: const Color(0xFF8B1D1D),
                  ),
                ),
              ],
            ),
          ),
          
          // THE LINE (horizontal divider)
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B7355).withOpacity(0.3),
                  const Color(0xFF8B7355),
                  const Color(0xFF8B7355).withOpacity(0.3),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // BELOW THE LINE section
          Container(
            constraints: const BoxConstraints(minHeight: 60),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // WE - Below
                Expanded(
                  child: _ScoreColumn(
                    entries: weBelowLine,
                    color: const Color(0xFF1E3A8A),
                    isBelowLine: true,
                  ),
                ),
                const SizedBox(width: 12),
                // THEY - Below
                Expanded(
                  child: _ScoreColumn(
                    entries: theyBelowLine,
                    color: const Color(0xFF8B1D1D),
                    isBelowLine: true,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          
          // Game indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _GameIndicator(games: weGamesWon, color: const Color(0xFF1E3A8A)),
              const Text('│', style: TextStyle(color: Color(0xFF8B7355), fontSize: 18)),
              _GameIndicator(games: theyGamesWon, color: const Color(0xFF8B1D1D)),
            ],
          ),
          
          const SizedBox(height: 10),
          Divider(height: 1, color: const Color(0xFF8B7355)),
          const SizedBox(height: 8),
          
          // Totals
          Row(
            children: [
              Expanded(
                child: Text(
                  '$weTotal',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
              const Text(
                'TOPLAM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8B7355),
                  letterSpacing: 0.8,
                ),
              ),
              Expanded(
                child: Text(
                  '$theyTotal',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8B1D1D),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  final List<ScoreEntry> entries;
  final Color color;
  final bool isBelowLine;

  const _ScoreColumn({
    required this.entries,
    required this.color,
    this.isBelowLine = false,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox(height: 60);
    }
    
    return Column(
      children: entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${entry.points}',
                style: TextStyle(
                  fontSize: isBelowLine ? 16 : 14,
                  fontWeight: isBelowLine ? FontWeight.w800 : FontWeight.w600,
                  color: color.withOpacity(0.85),
                  fontFamily: 'monospace',
                ),
              ),
              if (entry.label != null) ...[
                const SizedBox(width: 4),
                Text(
                  entry.label!,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _GameIndicator extends StatelessWidget {
  final int games;
  final Color color;

  const _GameIndicator({required this.games, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < games; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.4), width: 1),
              ),
            ),
          ),
        if (games == 0)
          Text(
            '○',
            style: TextStyle(fontSize: 14, color: color.withOpacity(0.3)),
          ),
      ],
    );
  }
}

/// Single score entry
class ScoreEntry {
  final int points;
  final bool isBelowLine; // Contract points (trick points) below, bonuses above
  final String? label; // Optional label like "Şlem", "Onör", etc.

  const ScoreEntry({
    required this.points,
    required this.isBelowLine,
    this.label,
  });
}
