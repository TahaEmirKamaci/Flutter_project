import 'dart:math';
import '../core/hoskin_models.dart';
import '../core/hoskin_deck.dart';
import 'hoskin_meld_engine.dart';

/// Hoşkin Bot Yapay Zekası
/// İhale, koz seçimi ve oyun stratejileri
class HoskinBotAI {
  final BotDifficulty difficulty;
  final Random _random = Random();

  // Hafıza: Oynanan kartlar
  final Map<String, int> _playedCards = {}; // card.id -> playOrder
  int _playOrderCounter = 0;

  HoskinBotAI({this.difficulty = BotDifficulty.medium});

  /// İHALE AŞAMASI - Risk analizi ve ihale kararı
  BidDecision decideBid({
    required List<HoskinCard> hand,
    required int currentBid,
    required bool isFirstBidder,
  }) {
    // El analizi
    final analysis = _analyzeHand(hand);
    
    // Risk faktörü (zorluk seviyesine göre)
    final riskMultiplier = switch (difficulty) {
      BotDifficulty.easy => 0.6,
      BotDifficulty.medium => 0.7,
      BotDifficulty.hard => 0.8,
    };

    // Potansiyel puan hesabı
    final guaranteedPoints = analysis.meldPoints;
    final estimatedTrickPoints = (analysis.estimatedTricks * 11).toDouble();
    final totalPotential = guaranteedPoints + (estimatedTrickPoints * riskMultiplier);

    // Minimum ihale bedeli
    final minBid = isFirstBidder ? 80 : currentBid + 10;

    // Karar
    if (totalPotential >= minBid + 20) {
      // İhale al
      final bidAmount = (totalPotential ~/ 10) * 10; // 10'a yuvarla
      return BidDecision(
        shouldBid: true,
        amount: max(minBid, bidAmount),
        reason: _buildBidReason(analysis, totalPotential),
        analysis: analysis,
      );
    } else {
      // Pas
      return BidDecision(
        shouldBid: false,
        amount: 0,
        reason: 'El zayıf (Potansiyel: ${totalPotential.toInt()}, Min: $minBid)',
        analysis: analysis,
      );
    }
  }

  /// El analizi
  HandAnalysis _analyzeHand(List<HoskinCard> hand) {
    final melds = HoskinMeldEngine.calculateMelds(hand);
    final bySuit = DeckHelper.groupBySuit(hand);
    
    // En uzun renk (potansiyel koz)
    Suit? longestSuit;
    int maxLen = 0;
    bySuit.forEach((suit, cards) {
      if (cards.length > maxLen) {
        maxLen = cards.length;
        longestSuit = suit;
      }
    });

    // Tahmini el sayısı (As sayısı + uzun renk boyu / 3)
    final aces = hand.where((c) => c.rank == Rank.as).length;
    final tens = hand.where((c) => c.rank == Rank.on).length;
    final estimatedTricks = aces + (tens ~/ 2) + (maxLen ~/ 3);

    return HandAnalysis(
      meldPoints: melds.totalPoints,
      longestSuit: longestSuit,
      longestSuitLength: maxLen,
      acesCount: aces,
      estimatedTricks: estimatedTricks,
      hasHoskin: melds.hasHoskin,
      hasCiftPinik: melds.hasCiftPinik,
    );
  }

  String _buildBidReason(HandAnalysis analysis, double potential) {
    final parts = <String>[];
    
    if (analysis.hasHoskin) parts.add('Hoşkin');
    if (analysis.hasCiftPinik) parts.add('Çift Pinik');
    if (analysis.meldPoints > 0) parts.add('Barış: ${analysis.meldPoints}');
    parts.add('Tahmini el: ${analysis.estimatedTricks}');
    
    return '${parts.join(", ")} | Potansiyel: ${potential.toInt()}';
  }

  /// KOZ SEÇİMİ - İhaleyi kazandıktan sonra
  TrumpDecision selectTrump({
    required List<HoskinCard> hand,
    required List<HoskinCard> openCards, // Açılan 4 kart
  }) {
    final allCards = [...hand, ...openCards];
    final analysis = _analyzeHand(allCards);
    
    // En uzun ve güçlü rengi seç
    final bySuit = DeckHelper.groupBySuit(allCards);
    
    Suit? bestSuit;
    int bestScore = 0;

    bySuit.forEach((suit, cards) {
      if (cards.isEmpty) return;
      
      // Puan hesapla: uzunluk + As/10 sayısı
      final length = cards.length;
      final aces = cards.where((c) => c.rank == Rank.as).length;
      final tens = cards.where((c) => c.rank == Rank.on).length;
      
      final score = (length * 10) + (aces * 20) + (tens * 10);
      
      if (score > bestScore) {
        bestScore = score;
        bestSuit = suit;
      }
    });

    return TrumpDecision(
      trump: bestSuit ?? analysis.longestSuit ?? Suit.maca,
      reason: 'En uzun/güçlü renk (Skor: $bestScore)',
    );
  }

  /// OYUN İÇİ KARAR - Hangi kartı oynayacak?
  PlayDecision selectCard({
    required List<HoskinCard> hand,
    required List<HoskinCard> tableCards,
    required Suit? trump,
    required bool isLeading,
    required int position, // 0-3
  }) {
    // Hafızayı güncelle
    for (final card in tableCards) {
      _playedCards[card.id] = card.playOrder;
    }

    final legalCards = _getLegalCards(hand, tableCards);
    
    if (legalCards.isEmpty) {
      throw Exception('Oynayacak yasal kart yok!');
    }

    return switch (difficulty) {
      BotDifficulty.easy => _easyPlay(legalCards, tableCards, trump, isLeading),
      BotDifficulty.medium => _mediumPlay(legalCards, tableCards, trump, isLeading, hand),
      BotDifficulty.hard => _hardPlay(legalCards, tableCards, trump, isLeading, hand, position),
    };
  }

  /// Yasal kartları bul (renk takibi)
  List<HoskinCard> _getLegalCards(
    List<HoskinCard> hand,
    List<HoskinCard> tableCards,
  ) {
    if (tableCards.isEmpty) return hand; // İlk kart - hepsi yasal

    final leadSuit = tableCards.first.suit;
    final followSuit = hand.where((c) => c.suit == leadSuit).toList();

    return followSuit.isNotEmpty ? followSuit : hand;
  }

  /// KOLAY - Rastgele + temel kurallar
  PlayDecision _easyPlay(
    List<HoskinCard> legal,
    List<HoskinCard> table,
    Suit? trump,
    bool isLeading,
  ) {
    if (isLeading) {
      // En yüksek kartı at
      final highest = _findHighestCard(legal, trump);
      return PlayDecision(card: highest, reason: 'En yüksek kart');
    }

    // Kazanabilir mi?
    final winning = _findWinningCard(legal, table, trump);
    if (winning != null) {
      return PlayDecision(card: winning, reason: 'Kazanmaya çalışıyor');
    }

    // En düşük kartı at
    final lowest = _findLowestCard(legal, trump);
    return PlayDecision(card: lowest, reason: 'Kaçış kartı');
  }

  /// ORTA - Temel strateji
  PlayDecision _mediumPlay(
    List<HoskinCard> legal,
    List<HoskinCard> table,
    Suit? trump,
    bool isLeading,
    List<HoskinCard> hand,
  ) {
    if (isLeading) {
      // Uzun renkten at
      final bySuit = DeckHelper.groupBySuit(hand);
      Suit? longest;
      int maxLen = 0;
      
      bySuit.forEach((suit, cards) {
        if (cards.length > maxLen) {
          maxLen = cards.length;
          longest = suit;
        }
      });

      if (longest != null) {
        final fromLongest = legal.where((c) => c.suit == longest).toList();
        if (fromLongest.isNotEmpty) {
          final top = _findHighestCard(fromLongest, trump);
          return PlayDecision(card: top, reason: 'Uzun renkten üstten');
        }
      }

      return PlayDecision(
        card: _findHighestCard(legal, trump),
        reason: 'Güçlü açılış',
      );
    }

    // Son sıradaysa minimum kazanan at
    if (table.length == 3) {
      final winning = _findMinimalWinningCard(legal, table, trump);
      if (winning != null) {
        return PlayDecision(card: winning, reason: 'Minimum kazanan');
      }
    }

    // Kazanabiliyorsa kaz
    final winning = _findWinningCard(legal, table, trump);
    if (winning != null) {
      return PlayDecision(card: winning, reason: 'Eli kazanma');
    }

    return PlayDecision(
      card: _findLowestCard(legal, trump),
      reason: 'Kaçış',
    );
  }

  /// ZOR - İleri seviye (hafıza, sayma)
  PlayDecision _hardPlay(
    List<HoskinCard> legal,
    List<HoskinCard> table,
    Suit? trump,
    bool isLeading,
    List<HoskinCard> hand,
    int position,
  ) {
    if (isLeading) {
      // Ölümsüz kartları kullan (tüm üst kartlar çıktıysa)
      for (final card in legal) {
        if (_isInvincible(card, trump)) {
          return PlayDecision(card: card, reason: 'Ölümsüz kart');
        }
      }

      // Uzun ve güçlü renkten establish et
      final bySuit = DeckHelper.groupBySuit(hand);
      Suit? bestSuit;
      int bestScore = 0;

      bySuit.forEach((suit, cards) {
        final score = cards.length * 10 + 
                     cards.where((c) => c.rank == Rank.as).length * 20;
        if (score > bestScore) {
          bestScore = score;
          bestSuit = suit;
        }
      });

      if (bestSuit != null) {
        final fromBest = legal.where((c) => c.suit == bestSuit).toList();
        if (fromBest.isNotEmpty) {
          return PlayDecision(
            card: _findHighestCard(fromBest, trump),
            reason: 'Renk establish',
          );
        }
      }
    }

    // Partner kazanıyor mu? (pozisyon 2 ise partner pozisyon 0)
    if (table.isNotEmpty && _isPartnerWinning(table, position, trump)) {
      return PlayDecision(
        card: _findLowestCard(legal, trump),
        reason: 'Partner kazanıyor, düşük at',
      );
    }

    // Son sırada minimal kazanan
    if (table.length == 3) {
      final minimal = _findMinimalWinningCard(legal, table, trump);
      if (minimal != null) {
        return PlayDecision(card: minimal, reason: 'Minimal kazanan');
      }
    }

    // Kazanma denemesi
    final winning = _findWinningCard(legal, table, trump);
    if (winning != null) {
      return PlayDecision(card: winning, reason: 'Kazanma');
    }

    return PlayDecision(
      card: _findLowestCard(legal, trump),
      reason: 'Güvenli kaçış',
    );
  }

  /// Kart ölümsüz mü? (tüm üst kartlar oynanmış mı?)
  bool _isInvincible(HoskinCard card, Suit? trump) {
    // Bu karttan güçlü kartların hepsi oynandı mı?
    for (final rank in Rank.values) {
      if (rank.index >= card.rank.index) continue; // Daha güçlü rank'ler
      
      // Bu rank'ten aynı suit'te kaç kart var ve kaçı oynanmış?
      for (int copy = 1; copy <= 4; copy++) {
        final id = '${rank.symbol}${card.suit.symbol}$copy';
        if (!_playedCards.containsKey(id)) {
          return false; // Henüz oynanmamış üst kart var
        }
      }
    }
    return true;
  }

  /// Partner kazanıyor mu?
  bool _isPartnerWinning(List<HoskinCard> table, int position, Suit? trump) {
    if (table.isEmpty) return false;
    
    final winner = _findWinnerCard(table, trump);
    final winnerIndex = table.indexOf(winner);
    
    // Takım arkadaşı: (0,2) veya (1,3)
    final partnerPosition = (position + 2) % 4;
    return winnerIndex == partnerPosition;
  }

  /// Yerdeki kartlardan kazananı bul
  HoskinCard _findWinnerCard(List<HoskinCard> table, Suit? trump) {
    if (table.isEmpty) throw Exception('Masa boş');
    
    var winner = table.first;
    final leadSuit = table.first.suit;

    for (int i = 1; i < table.length; i++) {
      final comp = DeckHelper.compareCards(
        table[i],
        winner,
        leadSuit: leadSuit,
        trump: trump,
      );
      if (comp > 0) winner = table[i];
    }

    return winner;
  }

  /// En yüksek kartı bul
  HoskinCard _findHighestCard(List<HoskinCard> cards, Suit? trump) {
    return cards.reduce((a, b) {
      final powerA = DeckHelper.cardPower(a, trump: trump);
      final powerB = DeckHelper.cardPower(b, trump: trump);
      return powerA > powerB ? a : b;
    });
  }

  /// En düşük kartı bul
  HoskinCard _findLowestCard(List<HoskinCard> cards, Suit? trump) {
    return cards.reduce((a, b) {
      final powerA = DeckHelper.cardPower(a, trump: trump);
      final powerB = DeckHelper.cardPower(b, trump: trump);
      return powerA < powerB ? a : b;
    });
  }

  /// Kazanan kart bul
  HoskinCard? _findWinningCard(
    List<HoskinCard> hand,
    List<HoskinCard> table,
    Suit? trump,
  ) {
    if (table.isEmpty) return null;

    final currentWinner = _findWinnerCard(table, trump);
    final leadSuit = table.first.suit;

    for (final card in hand) {
      final comp = DeckHelper.compareCards(
        card,
        currentWinner,
        leadSuit: leadSuit,
        trump: trump,
      );
      if (comp > 0) return card;
    }

    return null;
  }

  /// Minimal kazanan kart bul (en az güçlü ama yine de kazanan)
  HoskinCard? _findMinimalWinningCard(
    List<HoskinCard> hand,
    List<HoskinCard> table,
    Suit? trump,
  ) {
    if (table.isEmpty) return null;

    final currentWinner = _findWinnerCard(table, trump);
    final leadSuit = table.first.suit;

    HoskinCard? minimal;
    int minPower = 1000;

    for (final card in hand) {
      final comp = DeckHelper.compareCards(
        card,
        currentWinner,
        leadSuit: leadSuit,
        trump: trump,
      );
      
      if (comp > 0) {
        final power = DeckHelper.cardPower(card, trump: trump);
        if (power < minPower) {
          minPower = power;
          minimal = card;
        }
      }
    }

    return minimal;
  }

  /// Hafızayı sıfırla (yeni tur için)
  void resetMemory() {
    _playedCards.clear();
    _playOrderCounter = 0;
  }
}

/// İhale kararı
class BidDecision {
  final bool shouldBid;
  final int amount;
  final String reason;
  final HandAnalysis analysis;

  BidDecision({
    required this.shouldBid,
    required this.amount,
    required this.reason,
    required this.analysis,
  });
}

/// Koz seçim kararı
class TrumpDecision {
  final Suit trump;
  final String reason;

  TrumpDecision({required this.trump, required this.reason});
}

/// Oyun kararı
class PlayDecision {
  final HoskinCard card;
  final String reason;

  PlayDecision({required this.card, required this.reason});
}

/// El analizi
class HandAnalysis {
  final int meldPoints;
  final Suit? longestSuit;
  final int longestSuitLength;
  final int acesCount;
  final int estimatedTricks;
  final bool hasHoskin;
  final bool hasCiftPinik;

  HandAnalysis({
    required this.meldPoints,
    required this.longestSuit,
    required this.longestSuitLength,
    required this.acesCount,
    required this.estimatedTricks,
    required this.hasHoskin,
    required this.hasCiftPinik,
  });
}

/// Bot zorluk seviyeleri
enum BotDifficulty {
  easy, // Basit mantık, az risk
  medium, // Orta seviye strateji
  hard, // İleri seviye, hafıza ve sayma
}
