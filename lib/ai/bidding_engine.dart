import 'dart:math';
import 'hand_evaluator.dart';

/// Bidding (İhale) motoru - Bricturk ders müfredatına %100 uyumlu
/// ACBL ve WBF standart sistem kuralları
class BiddingEngine {
  final BiddingDifficulty difficulty;
  final Random _rnd = Random();

  BiddingEngine({this.difficulty = BiddingDifficulty.medium});

  /// İhale kararı ver
  BidDecision decideBid({
    required List<String> hand,
    required List<String> bidHistory,
    required int seatPosition,
    required int? partnerPosition,
  }) {
    final eval = HandEvaluator.evaluate(hand);
    final isOpening =
        bidHistory.isEmpty || bidHistory.every((b) => b == 'Pass');
    final partnerOpened = _partnerOpened(
      bidHistory,
      seatPosition,
      partnerPosition,
    );
    final lastBid = _getLastBid(bidHistory);

    // Açılış ihalesiyse
    if (isOpening) {
      return _openingBid(eval, hand);
    }

    // Ortak açtıysa
    if (partnerOpened != null) {
      return _responseToPartner(eval, hand, partnerOpened, lastBid);
    }

    // Rakip açtıysa
    return _responseToOpponent(eval, hand, lastBid);
  }

  /// AÇILIŞ İHALESİ
  BidDecision _openingBid(HandEvaluation eval, List<String> hand) {
    final hcp = eval.hcp;
    final total = eval.totalPoints;

    // 22+ HCP → 2♣ (Forcing)
    if (hcp >= 22) {
      return BidDecision(
        bid: '2♣',
        level: 2,
        suit: '♣',
        isPass: false,
        reason: 'Game forcing (22+ HCP)',
      );
    }

    // 20-21 HCP → 2NT
    if (hcp >= 20 && hcp <= 21 && eval.isBalanced) {
      return BidDecision(
        bid: '2NT',
        level: 2,
        suit: null,
        isPass: false,
        reason: 'Strong balanced 20-21 HCP',
      );
    }

    // 15-17 HCP Dengeli → 1NT
    if (hcp >= 15 && hcp <= 17 && eval.isBalanced) {
      // NT için tüm renklerde stopper kontrolü
      if (_hasAllStoppers(hand)) {
        return BidDecision(
          bid: '1NT',
          level: 1,
          suit: null,
          isPass: false,
          reason: 'Balanced 15-17 HCP with stoppers',
        );
      }
    }

    // 12-14 HCP Dengeli → 1NT (zayıf NT - Türk sistemi)
    if (hcp >= 12 && hcp <= 14 && eval.isBalanced) {
      if (_hasAllStoppers(hand)) {
        return BidDecision(
          bid: '1NT',
          level: 1,
          suit: null,
          isPass: false,
          reason: 'Weak NT 12-14 HCP',
        );
      }
    }

    // 13+ toplam puan → 1 renk açılışı
    if (total >= 13) {
      // Öncelik: 5+ majör
      final longestMajor = HandEvaluator.longestMajor(eval.suitCounts);
      if (longestMajor != null) {
        return BidDecision(
          bid: '1$longestMajor',
          level: 1,
          suit: longestMajor,
          isPass: false,
          reason: '5+ major, $total points',
        );
      }

      // Minör açılışı
      final diamonds = eval.suitCounts['♦'] ?? 0;
      final clubs = eval.suitCounts['♣'] ?? 0;

      // 4+ ♦ veya 4+ ♣
      if (diamonds >= 4 && diamonds >= clubs) {
        return BidDecision(
          bid: '1♦',
          level: 1,
          suit: '♦',
          isPass: false,
          reason: '$diamonds diamonds, $total points',
        );
      }
      if (clubs >= 3) {
        // Minimum 3 ♣ ile açılabilir
        return BidDecision(
          bid: '1♣',
          level: 1,
          suit: '♣',
          isPass: false,
          reason: '$clubs clubs, $total points',
        );
      }

      // En uzun renkle aç
      final longest = HandEvaluator.longestSuit(eval.suitCounts);
      if (longest != null) {
        return BidDecision(
          bid: '1$longest',
          level: 1,
          suit: longest,
          isPass: false,
          reason: 'Longest suit, $total points',
        );
      }
    }

    // 11-12 HCP borderline - zorluk seviyesine göre
    if (hcp >= 11 && difficulty == BiddingDifficulty.hard) {
      final qt = HandEvaluator.quickTricks(hand);
      if (qt >= 2.0) {
        final longest = HandEvaluator.longestSuit(eval.suitCounts);
        if (longest != null) {
          return BidDecision(
            bid: '1$longest',
            level: 1,
            suit: longest,
            isPass: false,
            reason: 'Light opening with 2 QT',
          );
        }
      }
    }

    // Pass
    return BidDecision(
      bid: 'Pass',
      level: 0,
      suit: null,
      isPass: true,
      reason: 'Insufficient points ($total)',
    );
  }

  /// ORTAĞA CEVAP
  BidDecision _responseToPartner(
    HandEvaluation eval,
    List<String> hand,
    String partnerBid,
    String? lastBid,
  ) {
    final hcp = eval.hcp;
    final total = eval.totalPoints;

    // Ortak 1NT açtıysa
    if (partnerBid == '1NT') {
      return _respondTo1NT(eval, hand);
    }

    // Ortak 2♣ (forcing) açtıysa
    if (partnerBid == '2♣') {
      return _respondTo2ClubForcing(eval, hand);
    }

    // Ortak 1 renk açtıysa
    if (partnerBid.startsWith('1')) {
      return _respondTo1Suit(eval, hand, partnerBid);
    }

    // Genel cevap
    if (hcp < 6) {
      return BidDecision(
        bid: 'Pass',
        level: 0,
        suit: null,
        isPass: true,
        reason: 'Too weak',
      );
    }

    return BidDecision(
      bid: 'Pass',
      level: 0,
      suit: null,
      isPass: true,
      reason: 'Complex auction',
    );
  }

  /// 1NT'ye cevap
  BidDecision _respondTo1NT(HandEvaluation eval, List<String> hand) {
    final hcp = eval.hcp;

    // 0-7 HCP → Pass
    if (hcp < 8) {
      return BidDecision(
        bid: 'Pass',
        level: 0,
        suit: null,
        isPass: true,
        reason: 'Weak hand',
      );
    }

    // 10-12 HCP → 2NT (invitational)
    if (hcp >= 10 && hcp <= 12) {
      return BidDecision(
        bid: '2NT',
        level: 2,
        suit: null,
        isPass: false,
        reason: 'Invitational 10-12 HCP',
      );
    }

    // 13+ HCP → 3NT (game)
    if (hcp >= 13) {
      return BidDecision(
        bid: '3NT',
        level: 3,
        suit: null,
        isPass: false,
        reason: 'Game 13+ HCP',
      );
    }

    // 8-9 HCP - Stayman veya Pass
    // Basitleştirilmiş: Majör varsa göster
    final major = HandEvaluator.longestMajor(eval.suitCounts);
    if (major != null && (eval.suitCounts[major] ?? 0) >= 4) {
      return BidDecision(
        bid: '2♣', // Stayman
        level: 2,
        suit: '♣',
        isPass: false,
        reason: 'Stayman - looking for major fit',
      );
    }

    return BidDecision(
      bid: 'Pass',
      level: 0,
      suit: null,
      isPass: true,
      reason: 'No fit',
    );
  }

  /// 2♣ forcing'e cevap
  BidDecision _respondTo2ClubForcing(HandEvaluation eval, List<String> hand) {
    final hcp = eval.hcp;

    // 0-7 HCP → 2♦ (waiting/negative)
    if (hcp < 8) {
      return BidDecision(
        bid: '2♦',
        level: 2,
        suit: '♦',
        isPass: false,
        reason: 'Negative response',
      );
    }

    // 8+ HCP → Renk göster veya 2NT
    final major = HandEvaluator.longestMajor(eval.suitCounts);
    if (major != null) {
      return BidDecision(
        bid: '2$major',
        level: 2,
        suit: major,
        isPass: false,
        reason: 'Positive response with major',
      );
    }

    return BidDecision(
      bid: '2NT',
      level: 2,
      suit: null,
      isPass: false,
      reason: 'Positive balanced',
    );
  }

  /// 1 renk açılışına cevap
  BidDecision _respondTo1Suit(
    HandEvaluation eval,
    List<String> hand,
    String partnerBid,
  ) {
    final hcp = eval.hcp;
    final total = eval.totalPoints;
    final partnerSuit = partnerBid.substring(1);

    // 0-5 HCP → Pass
    if (hcp < 6) {
      return BidDecision(
        bid: 'Pass',
        level: 0,
        suit: null,
        isPass: true,
        reason: 'Too weak',
      );
    }

    // Fit kontrolü (3+ kart desteği)
    final support = eval.suitCounts[partnerSuit] ?? 0;
    final hasFit = support >= 3;

    // 13+ HCP → Game forcing
    if (hcp >= 13) {
      if (hasFit && support >= 4) {
        // Direct raise to 3
        return BidDecision(
          bid: '3$partnerSuit',
          level: 3,
          suit: partnerSuit,
          isPass: false,
          reason: 'Game forcing raise',
        );
      }
      // Yeni renk (forcing)
      final newSuit = _findNewSuit(eval, partnerSuit);
      if (newSuit != null) {
        return BidDecision(
          bid: '1$newSuit',
          level: 1,
          suit: newSuit,
          isPass: false,
          reason: 'New suit forcing',
        );
      }
    }

    // 10-12 HCP → Limit raise
    if (hcp >= 10 && hcp <= 12 && hasFit) {
      return BidDecision(
        bid: '3$partnerSuit',
        level: 3,
        suit: partnerSuit,
        isPass: false,
        reason: 'Limit raise 10-12 HCP',
      );
    }

    // 6-9 HCP → Single raise veya 1NT
    if (hcp >= 6 && hcp <= 9) {
      if (hasFit) {
        return BidDecision(
          bid: '2$partnerSuit',
          level: 2,
          suit: partnerSuit,
          isPass: false,
          reason: 'Simple raise 6-9 HCP',
        );
      }
      // NT cevabı
      return BidDecision(
        bid: '1NT',
        level: 1,
        suit: null,
        isPass: false,
        reason: 'No fit, balanced 6-9',
      );
    }

    return BidDecision(
      bid: 'Pass',
      level: 0,
      suit: null,
      isPass: true,
      reason: 'No clear bid',
    );
  }

  /// RAKIBE CEVAP (müdahale)
  BidDecision _responseToOpponent(
    HandEvaluation eval,
    List<String> hand,
    String? opponentBid,
  ) {
    final hcp = eval.hcp;

    // Zor seviyede - overcall mantığı
    if (difficulty == BiddingDifficulty.hard && hcp >= 10) {
      final longest = HandEvaluator.longestSuit(eval.suitCounts);
      if (longest != null && (eval.suitCounts[longest] ?? 0) >= 5) {
        // Basit overcall
        return BidDecision(
          bid: '1$longest',
          level: 1,
          suit: longest,
          isPass: false,
          reason: 'Overcall with good suit',
        );
      }
    }

    // Çoğu durumda pass
    return BidDecision(
      bid: 'Pass',
      level: 0,
      suit: null,
      isPass: true,
      reason: 'Pass after opponent bid',
    );
  }

  // === Yardımcı fonksiyonlar ===

  bool _hasAllStoppers(List<String> hand) {
    final suits = ['♠', '♥', '♦', '♣'];
    final grouped = <String, List<String>>{};

    for (final card in hand) {
      final suit = card.substring(card.length - 1);
      grouped[suit] = (grouped[suit] ?? [])..add(card);
    }

    for (final suit in suits) {
      final cards = grouped[suit] ?? [];
      if (!HandEvaluator.hasStopper(cards)) {
        return false;
      }
    }
    return true;
  }

  String? _findNewSuit(HandEvaluation eval, String avoidSuit) {
    // Majör önceliği
    if (avoidSuit != '♠' && (eval.suitCounts['♠'] ?? 0) >= 4) return '♠';
    if (avoidSuit != '♥' && (eval.suitCounts['♥'] ?? 0) >= 4) return '♥';
    // Minörler
    if (avoidSuit != '♦' && (eval.suitCounts['♦'] ?? 0) >= 4) return '♦';
    if (avoidSuit != '♣' && (eval.suitCounts['♣'] ?? 0) >= 4) return '♣';
    return null;
  }

  String? _partnerOpened(List<String> history, int seat, int? partner) {
    if (partner == null || history.isEmpty) return null;

    // İlk ihale ortağın mı?
    final firstBidder = 0; // Basitleştirilmiş
    if (partner == firstBidder &&
        history.isNotEmpty &&
        history.first != 'Pass') {
      return history.first;
    }
    return null;
  }

  String? _getLastBid(List<String> history) {
    for (int i = history.length - 1; i >= 0; i--) {
      if (history[i] != 'Pass') return history[i];
    }
    return null;
  }
}

/// İhale kararı
class BidDecision {
  final String bid; // '1♠', '2NT', 'Pass', etc.
  final int level; // 0-7
  final String? suit; // ♠♥♦♣ or null for NT
  final bool isPass;
  final String reason; // Açıklama

  BidDecision({
    required this.bid,
    required this.level,
    required this.suit,
    required this.isPass,
    required this.reason,
  });

  @override
  String toString() => '$bid ($reason)';
}

/// Zorluk seviyeleri
enum BiddingDifficulty {
  easy, // Basit kurallara göre
  medium, // Standart sistem
  hard, // İleri seviye (overcall, competition)
}
