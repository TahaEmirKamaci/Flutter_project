import 'package:flutter/material.dart';

class GameScoreTracker extends ChangeNotifier {
  // Team scores: Team 0 (Player + North), Team 1 (East + West)
  List<int> team0RoundScores = [];
  List<int> team1RoundScores = [];
  int currentRound = 0;
  final int maxRounds = 5;

  void addRoundScore(int team0Score, int team1Score) {
    team0RoundScores.add(team0Score);
    team1RoundScores.add(team1Score);
    currentRound++;
    notifyListeners();
  }

  int get team0Total => team0RoundScores.fold(0, (a, b) => a + b);
  int get team1Total => team1RoundScores.fold(0, (a, b) => a + b);

  bool get isGameComplete => currentRound >= maxRounds;

  int? get winningTeam {
    if (!isGameComplete) return null;
    if (team0Total > team1Total) return 0;
    if (team1Total > team0Total) return 1;
    return null; // tie
  }

  void reset() {
    team0RoundScores.clear();
    team1RoundScores.clear();
    currentRound = 0;
    notifyListeners();
  }
}

class ScoreTableDialog extends StatelessWidget {
  final GameScoreTracker tracker;
  final VoidCallback onNewGame;
  final VoidCallback onContinue;

  const ScoreTableDialog({
    super.key,
    required this.tracker,
    required this.onNewGame,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = tracker.isGameComplete;
    final winningTeam = tracker.winningTeam;

    return Dialog(
      backgroundColor: const Color(0xFF0B1226),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, color: Color(0xFFFBBF24), size: 32),
                const SizedBox(width: 12),
                Text(
                  isComplete ? 'OYUN BİTTİ!' : 'TUR ${tracker.currentRound}/${tracker.maxRounds}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.white12),

            // Winner announcement
            if (isComplete && winningTeam != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: winningTeam == 0
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      winningTeam == 0 ? Icons.celebration : Icons.sentiment_dissatisfied,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      winningTeam == 0 ? 'KAZANDINIZ! 🎉' : 'KAYBETTİNİZ 😔',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      winningTeam == 0
                          ? 'Takım: Oyuncu & North'
                          : 'Takım: East & West',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              )
            else if (isComplete)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B7280),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'BERABERLİK! 🤝',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

            // Score table
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      const SizedBox(width: 60, child: Text('TUR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF9CA3AF)))),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Oyuncu + North',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF10B981)),
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'East + West',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFFEF4444)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: Colors.white12),

                  // Rounds
                  for (int i = 0; i < tracker.maxRounds; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              'Tur ${i + 1}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: i < tracker.team0RoundScores.length
                                      ? const Color(0xFF10B981).withOpacity(.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: i < tracker.team0RoundScores.length
                                        ? const Color(0xFF10B981)
                                        : Colors.white12,
                                  ),
                                ),
                                child: Text(
                                  i < tracker.team0RoundScores.length
                                      ? tracker.team0RoundScores[i].toString()
                                      : '-',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: i < tracker.team1RoundScores.length
                                      ? const Color(0xFFEF4444).withOpacity(.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: i < tracker.team1RoundScores.length
                                        ? const Color(0xFFEF4444)
                                        : Colors.white12,
                                  ),
                                ),
                                child: Text(
                                  i < tracker.team1RoundScores.length
                                      ? tracker.team1RoundScores[i].toString()
                                      : '-',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Divider(height: 16, color: Colors.white12),

                  // Totals
                  Row(
                    children: [
                      const SizedBox(
                        width: 60,
                        child: Text(
                          'TOPLAM',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF10B981), width: 2),
                            ),
                            child: Text(
                              tracker.team0Total.toString(),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFEF4444), width: 2),
                            ),
                            child: Text(
                              tracker.team1Total.toString(),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isComplete)
                  ElevatedButton.icon(
                    onPressed: onNewGame,
                    icon: const Icon(Icons.replay),
                    label: const Text('Yeni Oyun'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Devam Et'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
