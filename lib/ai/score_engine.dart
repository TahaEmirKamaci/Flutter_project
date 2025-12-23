/// Skor hesaplama motoru - ACBL/WBF kurallari
/// Vulnerable, overtrick, undertrick, bonus hesaplama
class ScoreEngine {
  /// Ana skor hesaplama
  static ScoreResult calculateScore({
    required int contractLevel,
    required String? contractSuit, // null = NT
    required int tricksTaken,
    required bool vulnerable,
    required bool doubled,
    required bool redoubled,
  }) {
    final contractTricks = 6 + contractLevel;
    final diff = tricksTaken - contractTricks;

    // Kontrat başarısız (down)
    if (diff < 0) {
      return _calculateUndertricks(
        undertricks: -diff,
        vulnerable: vulnerable,
        doubled: doubled,
        redoubled: redoubled,
      );
    }

    // Kontrat başarılı
    return _calculateMadeContract(
      level: contractLevel,
      suit: contractSuit,
      overtricks: diff,
      vulnerable: vulnerable,
      doubled: doubled,
      redoubled: redoubled,
    );
  }

  /// Başarılı kontrat skoru
  static ScoreResult _calculateMadeContract({
    required int level,
    required String? suit,
    required int overtricks,
    required bool vulnerable,
    required bool doubled,
    required bool redoubled,
  }) {
    // Temel puan (per trick)
    int basePerTrick;
    if (suit == null) {
      // NT: ilk 40, sonraki 30
      basePerTrick = 30;
    } else if (suit == '♠' || suit == '♥') {
      // Majör: 30
      basePerTrick = 30;
    } else {
      // Minör: 20
      basePerTrick = 20;
    }

    // Kontrat puanı
    int contractPoints;
    if (suit == null) {
      // NT: ilk el +10
      contractPoints = 40 + (level - 1) * 30;
    } else {
      contractPoints = level * basePerTrick;
    }

    // Double/Redouble çarpanı
    if (redoubled) {
      contractPoints *= 4;
    } else if (doubled) {
      contractPoints *= 2;
    }

    // Overtrick puanları
    int overtrickPoints = 0;
    if (doubled || redoubled) {
      final perOvertrick = vulnerable ? 200 : 100;
      final multiplier = redoubled ? 2 : 1;
      overtrickPoints = overtricks * perOvertrick * multiplier;
    } else {
      overtrickPoints = overtricks * basePerTrick;
    }

    // Game bonus
    int gameBonus = 0;
    if (contractPoints >= 100) {
      // Game
      gameBonus = vulnerable ? 500 : 300;
    } else {
      // Part-score
      gameBonus = 50;
    }

    // Slam bonus
    int slamBonus = 0;
    if (level == 7) {
      // Grand slam
      slamBonus = vulnerable ? 1500 : 1000;
    } else if (level == 6) {
      // Small slam
      slamBonus = vulnerable ? 750 : 500;
    }

    // Double/Redouble bonus
    int doubleBonus = 0;
    if (redoubled) {
      doubleBonus = 100; // Redouble bonus
    } else if (doubled) {
      doubleBonus = 50; // Double bonus
    }

    final totalScore =
        contractPoints + overtrickPoints + gameBonus + slamBonus + doubleBonus;

    return ScoreResult(
      score: totalScore,
      contractPoints: contractPoints,
      overtrickPoints: overtrickPoints,
      bonusPoints: gameBonus + slamBonus + doubleBonus,
      undertricks: 0,
      made: true,
      isGame: contractPoints >= 100,
      isSlam: level >= 6,
      breakdown: {
        'Contract': contractPoints,
        'Overtricks': overtrickPoints,
        'Game Bonus': gameBonus,
        'Slam Bonus': slamBonus,
        'Double Bonus': doubleBonus,
      },
    );
  }

  /// Başarısız kontrat (undertrick) skoru
  static ScoreResult _calculateUndertricks({
    required int undertricks,
    required bool vulnerable,
    required bool doubled,
    required bool redoubled,
  }) {
    int penalty = 0;

    if (!doubled && !redoubled) {
      // Normal undertrick
      penalty = undertricks * (vulnerable ? 100 : 50);
    } else {
      // Doubled/Redouble undertrick - kademeli
      final multiplier = redoubled ? 2 : 1;

      for (int i = 1; i <= undertricks; i++) {
        if (i == 1) {
          // İlk undertrick
          penalty += (vulnerable ? 200 : 100) * multiplier;
        } else if (i <= 3) {
          // 2-3. undertrick
          penalty += (vulnerable ? 300 : 200) * multiplier;
        } else {
          // 4+. undertrick
          penalty += (vulnerable ? 300 : 300) * multiplier;
        }
      }
    }

    return ScoreResult(
      score: -penalty,
      contractPoints: 0,
      overtrickPoints: 0,
      bonusPoints: 0,
      undertricks: undertricks,
      made: false,
      isGame: false,
      isSlam: false,
      breakdown: {'Undertricks': -penalty},
    );
  }

  /// IMP (International Match Points) hesaplama
  static int calculateIMP(int scoreDifference) {
    final abs = scoreDifference.abs();

    if (abs < 20) return 0;
    if (abs < 50) return 1;
    if (abs < 90) return 2;
    if (abs < 130) return 3;
    if (abs < 170) return 4;
    if (abs < 220) return 5;
    if (abs < 270) return 6;
    if (abs < 320) return 7;
    if (abs < 370) return 8;
    if (abs < 430) return 9;
    if (abs < 500) return 10;
    if (abs < 600) return 11;
    if (abs < 750) return 12;
    if (abs < 900) return 13;
    if (abs < 1100) return 14;
    if (abs < 1300) return 15;
    if (abs < 1500) return 16;
    if (abs < 1750) return 17;
    if (abs < 2000) return 18;
    if (abs < 2250) return 19;
    if (abs < 2500) return 20;
    if (abs < 3000) return 21;
    if (abs < 3500) return 22;
    if (abs < 4000) return 23;
    return 24;
  }

  /// Matchpoint (duplicate) hesaplama
  static double calculateMatchpoints({
    required int ourScore,
    required List<int> allScores,
  }) {
    double mp = 0.0;

    for (final score in allScores) {
      if (ourScore > score) {
        mp += 2.0; // Beat
      } else if (ourScore == score) {
        mp += 1.0; // Tie
      }
      // ourScore < score → 0 puan
    }

    return mp;
  }
}

/// Skor sonucu
class ScoreResult {
  final int score; // Toplam skor
  final int contractPoints; // Kontrat puanı
  final int overtrickPoints; // Fazla el puanı
  final int bonusPoints; // Bonus puanlar (game, slam, double)
  final int undertricks; // Kaç el eksik
  final bool made; // Kontrat başarılı mı?
  final bool isGame; // Game mi?
  final bool isSlam; // Slam mi?
  final Map<String, int> breakdown; // Detaylı dökü m

  const ScoreResult({
    required this.score,
    required this.contractPoints,
    required this.overtrickPoints,
    required this.bonusPoints,
    required this.undertricks,
    required this.made,
    required this.isGame,
    required this.isSlam,
    required this.breakdown,
  });

  @override
  String toString() {
    if (!made) {
      return 'Down $undertricks: ${score} points';
    }
    return 'Made${overtrickPoints > 0 ? ' +${overtrickPoints ~/ contractPoints}' : ''}: $score points';
  }
}

/// Vulnerable durumu
class VulnerabilityCondition {
  final bool nsVulnerable; // North-South vulnerable
  final bool ewVulnerable; // East-West vulnerable

  const VulnerabilityCondition({
    required this.nsVulnerable,
    required this.ewVulnerable,
  });

  bool isVulnerable(int seat) {
    // 0=S, 1=W, 2=N, 3=E
    return (seat == 0 || seat == 2) ? nsVulnerable : ewVulnerable;
  }

  static const none = VulnerabilityCondition(
    nsVulnerable: false,
    ewVulnerable: false,
  );
  static const ns = VulnerabilityCondition(
    nsVulnerable: true,
    ewVulnerable: false,
  );
  static const ew = VulnerabilityCondition(
    nsVulnerable: false,
    ewVulnerable: true,
  );
  static const both = VulnerabilityCondition(
    nsVulnerable: true,
    ewVulnerable: true,
  );

  /// Board numarasına göre vulnerability
  static VulnerabilityCondition fromBoardNumber(int board) {
    final mod = board % 16;
    if (mod == 1 || mod == 8 || mod == 11 || mod == 14) return none;
    if (mod == 2 || mod == 5 || mod == 12 || mod == 15) return ns;
    if (mod == 3 || mod == 6 || mod == 9 || mod == 0) return ew;
    return both; // 4, 7, 10, 13
  }
}
