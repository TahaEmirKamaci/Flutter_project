import 'dart:math';
import 'hand_evaluator.dart';

/// Play Engine - Kart oynatma yapay zekası
/// Stratejik kart seçimi, finesse, trump çekme, plan yapma
class PlayEngine {
  final PlayDifficulty difficulty;
  final Random _rnd = Random();

  PlayEngine({this.difficulty = PlayDifficulty.medium});

  /// Kart seçimi - Ana karar fonksiyonu
  PlayDecision selectCard({
    required List<String> hand,
    required List<String> cardsPlayed, // Bu elde masadaki kartlar
    required String? trump,
    required bool isLeading, // İlk kart mı atılıyor?
    required int position, // 0-3 (saat yönünde)
    required bool isDummy,
    required List<String> dummyHand, // Eğer declarer oynuyorsa dummy görünür
    required bool isDeclarer,
  }) {
    // Legal kartları bul
    final legalCards = _getLegalCards(hand, cardsPlayed);
    if (legalCards.isEmpty)
      return PlayDecision(card: hand.first, reason: 'No legal cards');
    if (legalCards.length == 1) {
      return PlayDecision(card: legalCards.first, reason: 'Only legal card');
    }

    // Zorluk seviyesine göre
    switch (difficulty) {
      case PlayDifficulty.easy:
        return _easyPlay(legalCards, cardsPlayed, trump);
      case PlayDifficulty.medium:
        return _mediumPlay(legalCards, cardsPlayed, trump, hand, isLeading);
      case PlayDifficulty.hard:
        return _hardPlay(
          legalCards,
          cardsPlayed,
          trump,
          hand,
          dummyHand,
          isLeading,
          isDeclarer,
          position,
        );
    }
  }

  /// KOLAY - Rastgele ama kurallı
  PlayDecision _easyPlay(
    List<String> legalCards,
    List<String> cardsPlayed,
    String? trump,
  ) {
    // İlk kart atılıyorsa - en yüksek kart
    if (cardsPlayed.isEmpty) {
      final highest = _findHighestCard(legalCards, trump);
      return PlayDecision(card: highest, reason: 'Leading with highest');
    }

    // Kazanmaya çalış
    final winning = _findWinningCard(legalCards, cardsPlayed, trump);
    if (winning != null) {
      return PlayDecision(card: winning, reason: 'Trying to win');
    }

    // Kazanamazsan en düşük at
    final lowest = _findLowestCard(legalCards, trump);
    return PlayDecision(card: lowest, reason: 'Cannot win, throw low');
  }

  /// ORTA - Temel strateji
  PlayDecision _mediumPlay(
    List<String> legalCards,
    List<String> cardsPlayed,
    String? trump,
    List<String> hand,
    bool isLeading,
  ) {
    // İlk kart - uzun renkten veya güçlü karttan
    if (isLeading) {
      // En uzun rengi bul
      final suits = _groupBySuit(hand);
      String? longestSuit;
      int maxLen = 0;
      suits.forEach((suit, cards) {
        if (cards.length > maxLen) {
          maxLen = cards.length;
          longestSuit = suit;
        }
      });

      // Uzun renkten varsa at
      if (longestSuit != null) {
        final fromLongest = legalCards
            .where((c) => _suitOf(c) == longestSuit)
            .toList();
        if (fromLongest.isNotEmpty) {
          // Üstten at (A, K)
          final top = _findHighestCard(fromLongest, trump);
          return PlayDecision(card: top, reason: 'Leading from longest suit');
        }
      }

      // Yoksa en yüksek kart
      final highest = _findHighestCard(legalCards, trump);
      return PlayDecision(card: highest, reason: 'Leading high');
    }

    // Son sıradaysan
    if (cardsPlayed.length == 3) {
      // Kazanabiliyorsan minimum kazanan
      final winning = _findMinimalWinningCard(legalCards, cardsPlayed, trump);
      if (winning != null) {
        return PlayDecision(card: winning, reason: 'Winning with minimal card');
      }
      // Kazanamazsan en düşük
      final lowest = _findLowestCard(legalCards, trump);
      return PlayDecision(card: lowest, reason: 'Cannot win, discarding low');
    }

    // İkinci veya üçüncü sırada
    final currentWinner = _getCurrentWinner(cardsPlayed, trump);
    final canWin = legalCards.any(
      (c) => _beats(c, currentWinner, cardsPlayed.first, trump),
    );

    if (canWin) {
      // Partner kazanıyorsa, onun üstüne atma
      final partnerWinning = _isPartnerWinning(
        cardsPlayed.length,
        currentWinner,
        cardsPlayed,
      );
      if (partnerWinning) {
        final lowest = _findLowestCard(legalCards, trump);
        return PlayDecision(
          card: lowest,
          reason: 'Partner winning, playing low',
        );
      }

      // Rakip kazanıyorsa, üstünü bul
      final winning = _findMinimalWinningCard(legalCards, cardsPlayed, trump);
      if (winning != null) {
        return PlayDecision(
          card: winning,
          reason: 'Opponent winning, trying to beat',
        );
      }
    }

    // Kazanamazsan düşük at
    final lowest = _findLowestCard(legalCards, trump);
    return PlayDecision(card: lowest, reason: 'Cannot win, playing low');
  }

  /// ZOR - İleri seviye strateji
  PlayDecision _hardPlay(
    List<String> legalCards,
    List<String> cardsPlayed,
    String? trump,
    List<String> hand,
    List<String> dummyHand,
    bool isLeading,
    bool isDeclarer,
    int position,
  ) {
    // Declarer ise - iki eli birlikte değerlendir
    if (isDeclarer && dummyHand.isNotEmpty) {
      return _declarerPlay(
        legalCards,
        cardsPlayed,
        trump,
        hand,
        dummyHand,
        isLeading,
      );
    }

    // Savunmada - partner ile koordinasyon
    return _defenderPlay(
      legalCards,
      cardsPlayed,
      trump,
      hand,
      isLeading,
      position,
    );
  }

  /// Declarer oyunu (iki el birlikte)
  PlayDecision _declarerPlay(
    List<String> legalCards,
    List<String> cardsPlayed,
    String? trump,
    List<String> hand,
    List<String> dummyHand,
    bool isLeading,
  ) {
    // İlk kart - plan yap
    if (isLeading) {
      // Koz varsa, kozları çek
      if (trump != null) {
        final trumpsInHand = hand.where((c) => _suitOf(c) == trump).toList();
        final trumpsInDummy = dummyHand
            .where((c) => _suitOf(c) == trump)
            .toList();
        final totalTrumps = trumpsInHand.length + trumpsInDummy.length;

        // Çoğunluk kozdaysa, çekmeye başla
        if (totalTrumps >= 8) {
          final topTrump = trumpsInHand.isNotEmpty
              ? _findHighestCard(trumpsInHand, trump)
              : null;
          if (topTrump != null && legalCards.contains(topTrump)) {
            return PlayDecision(card: topTrump, reason: 'Drawing trumps');
          }
        }
      }

      // Uzun renkten establish et
      final suits = _groupBySuit([...hand, ...dummyHand]);
      String? longestSuit;
      int maxLen = 0;
      suits.forEach((suit, cards) {
        if (suit != trump && cards.length > maxLen) {
          maxLen = cards.length;
          longestSuit = suit;
        }
      });

      if (longestSuit != null) {
        final fromLongest = legalCards
            .where((c) => _suitOf(c) == longestSuit)
            .toList();
        if (fromLongest.isNotEmpty) {
          final top = _findHighestCard(fromLongest, trump);
          return PlayDecision(card: top, reason: 'Establishing long suit');
        }
      }
    }

    // Normal strateji
    return _mediumPlay(legalCards, cardsPlayed, trump, hand, isLeading);
  }

  /// Savunma oyunu
  PlayDecision _defenderPlay(
    List<String> legalCards,
    List<String> cardsPlayed,
    String? trump,
    List<String> hand,
    bool isLeading,
    int position,
  ) {
    // İlk kart - 4. en büyük kart kuralı (uzun renkten)
    if (isLeading) {
      final suits = _groupBySuit(hand);
      String? longestSuit;
      int maxLen = 0;
      suits.forEach((suit, cards) {
        if (suit != trump && cards.length > maxLen) {
          maxLen = cards.length;
          longestSuit = suit;
        }
      });

      if (longestSuit != null) {
        final fromLongest = legalCards
            .where((c) => _suitOf(c) == longestSuit)
            .toList();
        if (fromLongest.isNotEmpty && fromLongest.length >= 4) {
          // 4. en büyük kartı bul
          fromLongest.sort(
            (a, b) => _compareCards(b, a, trump),
          ); // Yüksekten alçağa
          final fourthBest = fromLongest.length >= 4
              ? fromLongest[3]
              : fromLongest.last;
          return PlayDecision(
            card: fourthBest,
            reason: 'Fourth best from longest',
          );
        }
      }
    }

    // Normal savunma
    return _mediumPlay(legalCards, cardsPlayed, trump, hand, isLeading);
  }

  // === Yardımcı fonksiyonlar ===

  List<String> _getLegalCards(List<String> hand, List<String> cardsPlayed) {
    if (cardsPlayed.isEmpty) return hand; // İlk kart - hepsi legal

    final leadSuit = _suitOf(cardsPlayed.first);
    final followSuit = hand.where((c) => _suitOf(c) == leadSuit).toList();

    return followSuit.isNotEmpty ? followSuit : hand;
  }

  String _findHighestCard(List<String> cards, String? trump) {
    if (cards.isEmpty) return '';
    return cards.reduce((a, b) => _compareCards(a, b, trump) > 0 ? a : b);
  }

  String _findLowestCard(List<String> cards, String? trump) {
    if (cards.isEmpty) return '';
    return cards.reduce((a, b) => _compareCards(a, b, trump) < 0 ? a : b);
  }

  String? _findWinningCard(
    List<String> hand,
    List<String> played,
    String? trump,
  ) {
    if (played.isEmpty) return null;

    final leadSuit = _suitOf(played.first);
    final currentWinner = _getCurrentWinner(played, trump);

    for (final card in hand) {
      if (_beats(card, currentWinner, played.first, trump)) {
        return card;
      }
    }
    return null;
  }

  String? _findMinimalWinningCard(
    List<String> hand,
    List<String> played,
    String? trump,
  ) {
    if (played.isEmpty) return null;

    final winners = <String>[];
    final currentWinner = _getCurrentWinner(played, trump);

    for (final card in hand) {
      if (_beats(card, currentWinner, played.first, trump)) {
        winners.add(card);
      }
    }

    return winners.isEmpty ? null : _findLowestCard(winners, trump);
  }

  String _getCurrentWinner(List<String> played, String? trump) {
    if (played.isEmpty) return '';

    final leadSuit = _suitOf(played.first);
    String winner = played.first;

    for (int i = 1; i < played.length; i++) {
      if (_beats(played[i], winner, played.first, trump)) {
        winner = played[i];
      }
    }
    return winner;
  }

  bool _beats(String card, String target, String leadCard, String? trump) {
    final cardSuit = _suitOf(card);
    final targetSuit = _suitOf(target);
    final leadSuit = _suitOf(leadCard);

    // Koz kontrolleri
    final cardIsTrump = trump != null && cardSuit == trump;
    final targetIsTrump = trump != null && targetSuit == trump;

    if (cardIsTrump && !targetIsTrump) return true;
    if (!cardIsTrump && targetIsTrump) return false;

    // Aynı renkteyse rank karşılaştır
    if (cardSuit == targetSuit) {
      return _rankPower(_rankOf(card)) < _rankPower(_rankOf(target));
    }

    // Follow suit kontrolü
    if (cardSuit == leadSuit && targetSuit != leadSuit) return true;
    if (cardSuit != leadSuit && targetSuit == leadSuit) return false;

    return false;
  }

  int _compareCards(String a, String b, String? trump) {
    final suitA = _suitOf(a);
    final suitB = _suitOf(b);

    // Trump kontrolü
    if (trump != null) {
      if (suitA == trump && suitB != trump) return 1;
      if (suitA != trump && suitB == trump) return -1;
    }

    // Aynı renk - rank karşılaştır
    if (suitA == suitB) {
      final powerA = _rankPower(_rankOf(a));
      final powerB = _rankPower(_rankOf(b));
      return powerB.compareTo(powerA); // Düşük power = yüksek kart
    }

    return 0;
  }

  bool _isPartnerWinning(int playedCount, String winner, List<String> played) {
    // Basit: 1. veya 3. pozisyon partner (0-2, 1-3)
    // Bu oyuncu 2. veya 4. sıradaysa (playedCount = 1 veya 3)
    // Partner 1. veya 3. sırada
    if (playedCount == 1) return played.indexOf(winner) == 0;
    if (playedCount == 3) return played.indexOf(winner) == 2;
    return false;
  }

  Map<String, List<String>> _groupBySuit(List<String> cards) {
    final groups = <String, List<String>>{};
    for (final card in cards) {
      final suit = _suitOf(card);
      groups[suit] = (groups[suit] ?? [])..add(card);
    }
    return groups;
  }

  String _rankOf(String card) => card.substring(0, card.length - 1);
  String _suitOf(String card) => card.substring(card.length - 1);

  int _rankPower(String rank) {
    const ranks = [
      'A',
      'K',
      'Q',
      'J',
      '10',
      '9',
      '8',
      '7',
      '6',
      '5',
      '4',
      '3',
      '2',
    ];
    return ranks.indexOf(rank);
  }
}

/// Oyun kararı
class PlayDecision {
  final String card;
  final String reason;

  PlayDecision({required this.card, required this.reason});

  @override
  String toString() => '$card ($reason)';
}

/// Oyun zorluk seviyeleri
enum PlayDifficulty {
  easy, // Rastgele + temel kurallar
  medium, // Temel strateji
  hard, // İleri seviye (plan, count)
}
