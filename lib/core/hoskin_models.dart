/// Hoşkin Kart Modeli
/// Her kartın benzersiz bir ID'si var (4 adet Maça Ası olduğu için)
class HoskinCard {
  final String id; // Benzersiz ID (örn: "AS1", "AS2", "AS3", "AS4")
  final Rank rank;
  final Suit suit;
  final int playOrder; // Atılma sırası (aynı kartlar için kazanan belirleme)
  
  HoskinCard({
    required this.id,
    required this.rank,
    required this.suit,
    this.playOrder = -1,
  });

  /// Kartın string gösterimi (A♠, K♥ vs.)
  String get label => '${rank.symbol}${suit.symbol}';

  /// Kartın puan değeri
  int get points => rank.points;

  /// Atılma sırası ile kopyala
  HoskinCard withPlayOrder(int order) => HoskinCard(
    id: id,
    rank: rank,
    suit: suit,
    playOrder: order,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HoskinCard &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => label;
}

/// Hoşkin'de kullanılan rank'ler
enum Rank {
  as('A', 11),
  on('10', 10),
  kiz('K', 4),
  vale('Q', 3),
  bacak('J', 2),
  dokuz('9', 0),
  sekiz('8', 0),
  yedi('7', 0);

  final String symbol;
  final int points;

  const Rank(this.symbol, this.points);

  static Rank fromSymbol(String symbol) {
    return Rank.values.firstWhere((r) => r.symbol == symbol);
  }
}

/// Hoşkin'de kullanılan suit'ler (renkler)
enum Suit {
  maca('♠', 'Maça'),
  kupa('♥', 'Kupa'),
  karo('♦', 'Karo'),
  sinek('♣', 'Sinek');

  final String symbol;
  final String name;

  const Suit(this.symbol, this.name);

  bool get isRed => this == kupa || this == karo;
  bool get isBlack => !isRed;

  static Suit fromSymbol(String symbol) {
    return Suit.values.firstWhere((s) => s.symbol == symbol);
  }
}

/// Hoşkin oyuncu modeli
class HoskinPlayer {
  final int seat; // 0-3 (0: İnsan, 1-3: Botlar)
  final String name;
  final bool isBot;
  final int teamId; // 0 veya 1 (0-2 takım, 1-3 takım)
  
  List<HoskinCard> hand = [];
  List<HoskinCard> wonCards = []; // Kazandığı kartlar
  int tricksWon = 0; // Kazandığı el sayısı
  
  HoskinPlayer({
    required this.seat,
    required this.name,
    required this.isBot,
    required this.teamId,
  });

  /// Eldeki kartları sırala (renk ve rank'e göre)
  void sortHand() {
    hand.sort((a, b) {
      // Önce suit'e göre
      final suitComp = a.suit.index.compareTo(b.suit.index);
      if (suitComp != 0) return suitComp;
      // Sonra rank'e göre (As en güçlü)
      return a.rank.index.compareTo(b.rank.index);
    });
  }

  /// Oyuncunun toplam puanı
  int get totalPoints => wonCards.fold(0, (sum, card) => sum + card.points);

  /// El temizle
  void clearHand() {
    hand.clear();
    wonCards.clear();
    tricksWon = 0;
  }

  /// Kart ekle
  void addCard(HoskinCard card) {
    hand.add(card);
  }

  /// Kart oyna
  HoskinCard playCard(int index) {
    return hand.removeAt(index);
  }

  /// Kazanılan kartları ekle
  void collectCards(List<HoskinCard> cards) {
    wonCards.addAll(cards);
    tricksWon++;
  }
}

/// Takım modeli
class HoskinTeam {
  final int id;
  final List<int> playerSeats; // Takımdaki oyuncu seat'leri
  
  int meldPoints = 0; // Barış puanları
  int gamePoints = 0; // Oyun içi puanlar
  int totalScore = 0; // Toplam skor
  
  HoskinTeam({required this.id, required this.playerSeats});

  /// Toplam puanı hesapla
  int calculateTotal() => meldPoints + gamePoints;

  /// Skoru güncelle
  void updateScore() {
    totalScore += calculateTotal();
  }

  /// Turü sıfırla
  void resetRound() {
    meldPoints = 0;
    gamePoints = 0;
  }
}
