import 'dart:math';
import 'hoskin_models.dart';

/// Hoşkin Deck (Deste) Motoru
/// 80 kart (4'er adet: A, 10, K, Q, J, 9, 8, 7)
class HoskinDeck {
  final Random _random = Random();
  final List<HoskinCard> _cards = [];

  HoskinDeck() {
    _initializeDeck();
  }

  /// 80 kartlık deste oluştur (her karttan 4'er adet)
  void _initializeDeck() {
    _cards.clear();
    int cardId = 0;

    for (final suit in Suit.values) {
      for (final rank in Rank.values) {
        // Her karttan 4 adet
        for (int copy = 1; copy <= 4; copy++) {
          _cards.add(HoskinCard(
            id: '${rank.symbol}${suit.symbol}$copy',
            rank: rank,
            suit: suit,
          ));
          cardId++;
        }
      }
    }
  }

  /// Desteyi karıştır
  void shuffle() {
    _cards.shuffle(_random);
  }

  /// Kartları dağıt (her oyuncuya 20 kart)
  List<List<HoskinCard>> deal() {
    shuffle();
    
    final hands = <List<HoskinCard>>[
      [], // Player 0
      [], // Player 1
      [], // Player 2
      [], // Player 3
    ];

    // 80 kartı 4 oyuncuya dağıt (her biri 20 kart alır)
    for (int i = 0; i < _cards.length; i++) {
      hands[i % 4].add(_cards[i]);
    }

    return hands;
  }

  /// Yeni tur için desteyi sıfırla
  void reset() {
    _initializeDeck();
  }

  /// Toplam kart sayısı
  int get cardCount => _cards.length;

  /// Kalan kartlar
  List<HoskinCard> get cards => List.unmodifiable(_cards);
}

/// Hoşkin Deste Yardımcı Fonksiyonlar
class DeckHelper {
  /// Kartları renge göre grupla
  static Map<Suit, List<HoskinCard>> groupBySuit(List<HoskinCard> cards) {
    final groups = <Suit, List<HoskinCard>>{};
    
    for (final suit in Suit.values) {
      groups[suit] = [];
    }

    for (final card in cards) {
      groups[card.suit]!.add(card);
    }

    return groups;
  }

  /// Kartları rank'e göre grupla
  static Map<Rank, List<HoskinCard>> groupByRank(List<HoskinCard> cards) {
    final groups = <Rank, List<HoskinCard>>{};
    
    for (final rank in Rank.values) {
      groups[rank] = [];
    }

    for (final card in cards) {
      groups[card.rank]!.add(card);
    }

    return groups;
  }

  /// En uzun rengi bul
  static Suit? findLongestSuit(List<HoskinCard> cards) {
    final groups = groupBySuit(cards);
    
    Suit? longest;
    int maxCount = 0;

    groups.forEach((suit, suitCards) {
      if (suitCards.length > maxCount) {
        maxCount = suitCards.length;
        longest = suit;
      }
    });

    return maxCount > 0 ? longest : null;
  }

  /// Eldeki toplam puanı hesapla
  static int calculateHandPoints(List<HoskinCard> cards) {
    return cards.fold(0, (sum, card) => sum + card.points);
  }

  /// Kartları label'a göre sırala (görsel için)
  static List<HoskinCard> sortCards(List<HoskinCard> cards) {
    final sorted = List<HoskinCard>.from(cards);
    sorted.sort((a, b) {
      // Önce suit
      final suitComp = a.suit.index.compareTo(b.suit.index);
      if (suitComp != 0) return suitComp;
      // Sonra rank
      return a.rank.index.compareTo(b.rank.index);
    });
    return sorted;
  }

  /// Kartın gücünü hesapla (kazanan belirlemek için)
  static int cardPower(HoskinCard card, {Suit? trump}) {
    // Koz varsa ve kart kozsa, özel güç
    if (trump != null && card.suit == trump) {
      return 100 + (7 - card.rank.index); // Koz kartlar 100+ güç
    }
    
    // Normal güç (As en güçlü = 7, 7 en zayıf = 0)
    return 7 - card.rank.index;
  }

  /// İki kartı karşılaştır (kazanan hangisi?)
  /// Pozitif: card1 kazanır, Negatif: card2 kazanır, 0: Eşit (playOrder'a bak)
  static int compareCards(
    HoskinCard card1,
    HoskinCard card2, {
    required Suit leadSuit,
    Suit? trump,
  }) {
    final isTrump1 = trump != null && card1.suit == trump;
    final isTrump2 = trump != null && card2.suit == trump;

    // Koz kontrolleri
    if (isTrump1 && !isTrump2) return 1; // card1 kazanır
    if (!isTrump1 && isTrump2) return -1; // card2 kazanır

    // Her ikisi de koz
    if (isTrump1 && isTrump2) {
      final rankComp = card1.rank.index.compareTo(card2.rank.index);
      if (rankComp != 0) return -rankComp; // Düşük index = güçlü
      // Aynı rank - playOrder'a bak
      return card1.playOrder.compareTo(card2.playOrder);
    }

    // Lead suit kontrolleri
    final isLead1 = card1.suit == leadSuit;
    final isLead2 = card2.suit == leadSuit;

    if (isLead1 && !isLead2) return 1;
    if (!isLead1 && isLead2) return -1;

    // Aynı suit
    if (card1.suit == card2.suit) {
      final rankComp = card1.rank.index.compareTo(card2.rank.index);
      if (rankComp != 0) return -rankComp;
      return card1.playOrder.compareTo(card2.playOrder);
    }

    return 0; // Farklı suitler, kazanan yok
  }
}
