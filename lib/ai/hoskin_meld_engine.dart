import '../core/hoskin_models.dart';
import '../core/hoskin_deck.dart';

/// Hoşkin Barış Sayıları (Meld) Hesaplama Motoru
/// Kombinasyonları otomatik tespit eder ve puan hesaplar
class HoskinMeldEngine {
  
  /// Tüm barış sayılarını hesapla
  static MeldResult calculateMelds(List<HoskinCard> hand) {
    final result = MeldResult();
    
    // Kartları gruplara ayır
    final byRank = DeckHelper.groupByRank(hand);
    final bySuit = DeckHelper.groupBySuit(hand);

    // 1. HOŞKİN kontrolü (4 adet Maça Ası) - 200 puan
    if (_hasHoskin(byRank)) {
      result.addMeld(MeldType.hoskin, 200, 'Hoşkin (4 Maça Ası)');
    }

    // 2. ÇİFT PİNİK kontrolü (Maça Kız + Karo Vale) - 40 puan
    final pinikCount = _countPinik(bySuit);
    if (pinikCount > 0) {
      result.addMeld(
        MeldType.ciftPinik,
        pinikCount * 40,
        'Çift Pinik ($pinikCount adet)',
      );
    }

    // 3. SERİ kontrolü (aynı renkte ardışık 3+ kart)
    _findSeries(bySuit, result);

    // 4. TAKIM kontrolü (aynı değerde farklı renkte 4 kart)
    _findTeams(byRank, result);

    return result;
  }

  /// Hoşkin var mı? (4 adet Maça Ası)
  static bool _hasHoskin(Map<Rank, List<HoskinCard>> byRank) {
    final aces = byRank[Rank.as] ?? [];
    final macaAces = aces.where((c) => c.suit == Suit.maca).toList();
    return macaAces.length == 4;
  }

  /// Çift Pinik sayısını hesapla (Maça Kız + Karo Vale)
  static int _countPinik(Map<Suit, List<HoskinCard>> bySuit) {
    final macaCards = bySuit[Suit.maca] ?? [];
    final karoCards = bySuit[Suit.karo] ?? [];

    final macaQueens = macaCards.where((c) => c.rank == Rank.kiz).length;
    final karoJacks = karoCards.where((c) => c.rank == Rank.vale).length;

    // Her Maça Kız ile her Karo Vale eşleşir
    return macaQueens * karoJacks;
  }

  /// Seri (ardışık 3+ kart) bul
  static void _findSeries(
    Map<Suit, List<HoskinCard>> bySuit,
    MeldResult result,
  ) {
    for (final suit in Suit.values) {
      final cards = bySuit[suit] ?? [];
      if (cards.isEmpty) continue;

      // Rank'leri çıkar ve sırala
      final ranks = cards.map((c) => c.rank).toSet().toList();
      ranks.sort((a, b) => a.index.compareTo(b.index));

      // Ardışık rank gruplarını bul
      final sequences = <List<Rank>>[];
      List<Rank> current = [ranks[0]];

      for (int i = 1; i < ranks.length; i++) {
        if (ranks[i].index == current.last.index + 1) {
          current.add(ranks[i]);
        } else {
          if (current.length >= 3) {
            sequences.add(List.from(current));
          }
          current = [ranks[i]];
        }
      }
      if (current.length >= 3) {
        sequences.add(current);
      }

      // Her seri için puan hesapla
      for (final seq in sequences) {
        final length = seq.length;
        int points = 0;

        if (length == 3) points = 20;
        else if (length == 4) points = 50;
        else if (length == 5) points = 100;
        else if (length >= 6) points = 150;

        if (points > 0) {
          final ranksStr = seq.map((r) => r.symbol).join('-');
          result.addMeld(
            MeldType.seri,
            points,
            'Seri ($ranksStr ${suit.symbol}) - $length kart',
          );
        }
      }
    }
  }

  /// Takım (aynı değerde 4 kart) bul
  static void _findTeams(
    Map<Rank, List<HoskinCard>> byRank,
    MeldResult result,
  ) {
    for (final rank in Rank.values) {
      final cards = byRank[rank] ?? [];
      
      // Her 4 farklı renkten kart varsa bir takım
      final suits = cards.map((c) => c.suit).toSet();
      
      if (suits.length == 4) {
        // Kaç set yapılabilir?
        final minCount = Suit.values
            .map((s) => cards.where((c) => c.suit == s).length)
            .reduce((a, b) => a < b ? a : b);

        for (int i = 0; i < minCount; i++) {
          int points = 0;

          if (rank == Rank.as) points = 100;
          else if (rank == Rank.on) points = 80;
          else if (rank == Rank.kiz) points = 60;
          else if (rank == Rank.vale) points = 40;
          else if (rank == Rank.bacak) points = 20;

          if (points > 0) {
            result.addMeld(
              MeldType.takim,
              points,
              'Takım (4 ${rank.symbol})',
            );
          }
        }
      }
    }
  }

  /// Potansiyel barış puanını tahmin et (ihale için)
  static int estimatePotentialMelds(List<HoskinCard> hand) {
    final byRank = DeckHelper.groupByRank(hand);
    final bySuit = DeckHelper.groupBySuit(hand);
    int potential = 0;

    // Kesin puanlar
    final current = calculateMelds(hand);
    potential += current.totalPoints;

    // Potansiyel eklemeler
    for (final suit in Suit.values) {
      final cards = bySuit[suit] ?? [];
      final ranks = cards.map((c) => c.rank).toSet().toList();
      ranks.sort((a, b) => a.index.compareTo(b.index));

      // 2'li ardışık varsa 3'lü yapma şansı
      for (int i = 0; i < ranks.length - 1; i++) {
        if (ranks[i].index + 1 == ranks[i + 1].index) {
          potential += 5; // Muhtemel seri
        }
      }
    }

    // 3'lü kartlar varsa takım olma şansı
    for (final rank in Rank.values) {
      final cards = byRank[rank] ?? [];
      if (cards.length == 3) {
        potential += 10; // Muhtemel takım
      }
    }

    return potential;
  }
}

/// Barış türleri
enum MeldType {
  hoskin, // 4 Maça Ası - 200 puan
  ciftPinik, // Maça Kız + Karo Vale - 40 puan
  seri, // Ardışık 3+ kart - 20-150 puan
  takim, // Aynı değerde 4 kart - 20-100 puan
}

/// Tek bir barış bilgisi
class Meld {
  final MeldType type;
  final int points;
  final String description;

  Meld({
    required this.type,
    required this.points,
    required this.description,
  });

  @override
  String toString() => '$description: $points puan';
}

/// Barış hesaplama sonucu
class MeldResult {
  final List<Meld> melds = [];
  int totalPoints = 0;

  void addMeld(MeldType type, int points, String description) {
    melds.add(Meld(type: type, points: points, description: description));
    totalPoints += points;
  }

  bool get hasHoskin => melds.any((m) => m.type == MeldType.hoskin);
  bool get hasCiftPinik => melds.any((m) => m.type == MeldType.ciftPinik);

  int get seriCount => melds.where((m) => m.type == MeldType.seri).length;
  int get takimCount => melds.where((m) => m.type == MeldType.takim).length;

  @override
  String toString() {
    if (melds.isEmpty) return 'Barış yok';
    return melds.join('\n');
  }
}
