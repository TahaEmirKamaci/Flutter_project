import 'dart:math';

/// El değerlendirme sistemi - Briç kurallarına %100 uyumlu
/// HCP (Honor Card Points) + Dağılım puanları
class HandEvaluator {
  // Onör puanları (A=4, K=3, Q=2, J=1)
  static const Map<String, int> _honorPoints = {'A': 4, 'K': 3, 'Q': 2, 'J': 1};

  /// El değerlendirme sonucu
  static HandEvaluation evaluate(List<String> hand) {
    final suits = _groupBySuit(hand);

    // HCP hesaplama
    int hcp = 0;
    for (final card in hand) {
      final rank = _rankOf(card);
      hcp += _honorPoints[rank] ?? 0;
    }

    // Renk dağılımı
    final suitCounts = {
      '♠': suits['♠']?.length ?? 0,
      '♥': suits['♥']?.length ?? 0,
      '♦': suits['♦']?.length ?? 0,
      '♣': suits['♣']?.length ?? 0,
    };

    // Uzunluk puanları (5+ kartlı her renk için +1)
    int lengthPoints = 0;
    suitCounts.forEach((suit, count) {
      if (count >= 5) {
        lengthPoints += (count - 4);
      }
    });

    // Kısa renk puanları
    int shortHalf = 0; // Yarım destek
    int shortFull = 0; // Tam destek
    suitCounts.forEach((suit, count) {
      if (count == 0) {
        // Void
        shortHalf += 3;
        shortFull += 5;
      } else if (count == 1) {
        // Singleton
        shortHalf += 2;
        shortFull += 3;
      } else if (count == 2) {
        // Doubleton
        shortHalf += 1;
        shortFull += 1;
      }
    });

    // El şekli belirleme
    final shape = _determineShape(suitCounts);

    return HandEvaluation(
      hcp: hcp,
      lengthPoints: lengthPoints,
      shortnessHalf: shortHalf,
      shortnessFull: shortFull,
      totalPoints: hcp + lengthPoints,
      supportHalf: hcp + shortHalf,
      supportFull: hcp + shortFull,
      suitCounts: suitCounts,
      shape: shape,
      isBalanced: _isBalanced(suitCounts),
    );
  }

  /// Fit kontrolü (8+ kart kuralı)
  static bool hasFit(
    Map<String, int> counts1,
    Map<String, int> counts2,
    String suit,
  ) {
    return (counts1[suit] ?? 0) + (counts2[suit] ?? 0) >= 8;
  }

  /// En uzun renk
  static String? longestSuit(Map<String, int> counts) {
    String? longest;
    int maxCount = 0;
    counts.forEach((suit, count) {
      if (count > maxCount) {
        maxCount = count;
        longest = suit;
      }
    });
    return maxCount >= 4 ? longest : null;
  }

  /// Majör renk (♠ veya ♥) var mı?
  static bool hasMajor(Map<String, int> counts, {int minLength = 5}) {
    return (counts['♠'] ?? 0) >= minLength || (counts['♥'] ?? 0) >= minLength;
  }

  /// En uzun majör
  static String? longestMajor(Map<String, int> counts) {
    final spades = counts['♠'] ?? 0;
    final hearts = counts['♥'] ?? 0;
    if (spades >= 5 && spades >= hearts) return '♠';
    if (hearts >= 5) return '♥';
    return null;
  }

  /// En uzun minör
  static String? longestMinor(Map<String, int> counts) {
    final diamonds = counts['♦'] ?? 0;
    final clubs = counts['♣'] ?? 0;
    if (diamonds >= clubs && diamonds >= 3) return '♦';
    if (clubs >= 3) return '♣';
    return null;
  }

  // === Yardımcı fonksiyonlar ===

  static Map<String, List<String>> _groupBySuit(List<String> hand) {
    final suits = <String, List<String>>{};
    for (final card in hand) {
      final suit = _suitOf(card);
      suits[suit] = (suits[suit] ?? [])..add(card);
    }
    return suits;
  }

  static String _rankOf(String card) => card.substring(0, card.length - 1);
  static String _suitOf(String card) => card.substring(card.length - 1);

  static bool _isBalanced(Map<String, int> counts) {
    final sorted = counts.values.toList()..sort();
    // 4-3-3-3, 4-4-3-2, 5-3-3-2 dengelidir
    if (sorted[0] >= 2 && sorted[3] <= 5) {
      // Void veya singleton yoksa dengeli
      return sorted[0] >= 2;
    }
    return false;
  }

  static HandShape _determineShape(Map<String, int> counts) {
    final sorted = counts.values.toList()..sort((a, b) => b.compareTo(a));

    if (sorted[0] >= 7) return HandShape.veryUnbalanced;
    if (sorted[0] >= 6) return HandShape.unbalanced;
    if (sorted[0] == 5 && sorted[1] >= 4) return HandShape.twoSuiter;
    if (_isBalanced(counts)) return HandShape.balanced;
    return HandShape.semiBalanced;
  }

  /// Renk kalitesi değerlendirmesi
  static SuitQuality evaluateSuitQuality(List<String> suitCards) {
    if (suitCards.isEmpty) return SuitQuality.none;

    final length = suitCards.length;
    int honors = 0;
    int hcp = 0;

    for (final card in suitCards) {
      final rank = _rankOf(card);
      if (_honorPoints.containsKey(rank)) {
        honors++;
        hcp += _honorPoints[rank]!;
      }
    }

    // Kalite belirleme
    if (length >= 5 && hcp >= 6) return SuitQuality.excellent;
    if (length >= 5 && hcp >= 4) return SuitQuality.good;
    if (length >= 4 && hcp >= 3) return SuitQuality.fair;
    if (length >= 3) return SuitQuality.weak;
    return SuitQuality.none;
  }

  /// Stopper kontrolü (NT için)
  static bool hasStopper(List<String> suitCards) {
    if (suitCards.isEmpty) return false;

    final ranks = suitCards.map((c) => _rankOf(c)).toList();

    // A varsa kesin stopper
    if (ranks.contains('A')) return true;

    // K + 1 kart
    if (ranks.contains('K') && suitCards.length >= 2) return true;

    // Q + 2 kart
    if (ranks.contains('Q') && suitCards.length >= 3) return true;

    // J + 3 kart
    if (ranks.contains('J') && suitCards.length >= 4) return true;

    return false;
  }

  /// Quick tricks (hızlı el) hesaplama
  static double quickTricks(List<String> hand) {
    final suits = _groupBySuit(hand);
    double qt = 0.0;

    suits.forEach((suit, cards) {
      final ranks = cards.map((c) => _rankOf(c)).toList();

      // A-K = 2 QT
      if (ranks.contains('A') && ranks.contains('K')) {
        qt += 2.0;
      }
      // A = 1 QT
      else if (ranks.contains('A')) {
        qt += 1.0;
      }
      // K-Q = 1 QT
      else if (ranks.contains('K') && ranks.contains('Q')) {
        qt += 1.0;
      }
      // K = 0.5 QT
      else if (ranks.contains('K')) {
        qt += 0.5;
      }
    });

    return qt;
  }

  /// Losing Trick Count (kaybedici el sayısı)
  static int losingTrickCount(List<String> hand) {
    final suits = _groupBySuit(hand);
    int ltc = 0;

    suits.forEach((suit, cards) {
      final count = cards.length;
      if (count == 0) return; // Void = 0 loser

      final ranks = cards.map((c) => _rankOf(c)).toList();
      int losers = min(3, count); // Maksimum 3 loser per suit

      // A varsa -1
      if (ranks.contains('A')) losers--;
      // K varsa -1
      if (ranks.contains('K')) losers--;
      // Q varsa (eğer 3+ kart varsa) -1
      if (ranks.contains('Q') && count >= 3) losers--;

      ltc += max(0, losers);
    });

    return ltc;
  }
}

/// El değerlendirme sonucu
class HandEvaluation {
  final int hcp; // Honor card points
  final int lengthPoints; // Uzunluk puanı
  final int shortnessHalf; // Yarım tutuş puanı
  final int shortnessFull; // Tam tutuş puanı
  final int totalPoints; // HCP + uzunluk
  final int supportHalf; // HCP + yarım tutuş
  final int supportFull; // HCP + tam tutuş
  final Map<String, int> suitCounts; // Her renkteki kart sayısı
  final HandShape shape; // El şekli
  final bool isBalanced; // Dengeli mi?

  const HandEvaluation({
    required this.hcp,
    required this.lengthPoints,
    required this.shortnessHalf,
    required this.shortnessFull,
    required this.totalPoints,
    required this.supportHalf,
    required this.supportFull,
    required this.suitCounts,
    required this.shape,
    required this.isBalanced,
  });

  @override
  String toString() {
    return 'HCP: $hcp, Total: $totalPoints, Shape: $shape, Balanced: $isBalanced';
  }
}

/// El şekli kategorileri
enum HandShape {
  balanced, // 4-3-3-3, 4-4-3-2, 5-3-3-2
  semiBalanced, // 5-4-2-2, 6-3-2-2
  twoSuiter, // 5-5-2-1, 6-5-1-1
  unbalanced, // 6-4-2-1, 7-3-2-1
  veryUnbalanced, // 7-4+, 8+
}

/// Renk kalitesi
enum SuitQuality {
  none, // 0-2 kart
  weak, // 3+ kart ama düşük onör
  fair, // 4+ kart, orta onör
  good, // 5+ kart, iyi onör
  excellent, // 5+ kart, çok iyi onör
}
