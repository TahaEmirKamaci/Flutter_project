# Hoşkin - Dijital Kart Oyunu

## Oyun Hakkında

Hoşkin, 80 kartlık özel bir Türk kart oyunudur. 4 kişi ile oynanır ve takım bazlıdır (0-2 vs 1-3).

### Kart Destesi
- **80 kart** (Her karttan 4'er adet)
- **Renkler:** Maça (♠), Kupa (♥), Karo (♦), Sinek (♣)
- **Değerler:** As (11 puan), 10 (10 puan), Kız (4 puan), Vale (3 puan), Bacak (2 puan), 9, 8, 7 (0 puan)

## Oyun Aşamaları

### 1. Dağıtım
- Her oyuncuya 20 kart dağıtılır

### 2. İhale
- Minimum ihale: 80 puan
- Artış: 10'ar puan
- 3 kişi pas geçerse ihale biter
- Kimse almassa yeniden dağıtım

### 3. Kart Açma
- İhale kazananı 4 kart açar
- Bu kartlar oyun dışı kalır
- Kalan 16 kart ile oynanır

### 4. Koz Seçimi
- İhale kazananı kozu belirler
- En uzun/güçlü rengi seçmek önemlidir

### 5. Oyun
- 16 el oynanır (her elde 4 kart)
- İlk el ihale kazananı başlatır
- Renk takibi zorunlu
- Yoksa koz veya başka renk atılır

## Barış Sayıları (Meld)

Oyun başında elde bulunan kombinasyonlar:

### Hoşkin (200 puan)
- 4 adet Maça Ası

### Çift Pinik (40 puan/adet)
- Her Maça Kız + Karo Vale çifti

### Seri (Ardışık kartlar)
- 3 kart: 20 puan
- 4 kart: 50 puan
- 5 kart: 100 puan
- 6+ kart: 150 puan

### Takım (Aynı değerde 4 farklı renk)
- 4 As: 100 puan
- 4 On: 80 puan
- 4 Kız: 60 puan
- 4 Vale: 40 puan
- 4 Bacak: 20 puan

## Oyun İçi Kurallar

### Renk Takibi
- İlk atılan kartın rengi varsa atılmalı
- Yoksa herhangi bir kart atılabilir

### Koz Üstünlüğü
- Koz, normal rengi her zaman yener
- Aynı renkte en yüksek rank kazanır

### Aynı Kartlar
- Her karttan 4 adet olduğu için
- Aynı kartlarda ilk atılan kazanır (playOrder)

### El Kazanma
- En yüksek kartı atan eli kazanır
- Kazanan bir sonraki eli başlatır

## Puan Hesaplama

### Tur Sonu
- **İhale Takımı:** Barış + Oyun puanı ≥ İhale → Kazanır
- Batarsa: -İhale puanı
- **Karşı Takım:** Her zaman kendi puanını alır

### Toplam Skor
- İlk 1000'e ulaşan kazanır (standart)

## Bot Yapay Zekası

### Zorluk Seviyeleri

#### Kolay
- Basit mantık
- Rastgele + temel kurallar
- Risk almaz

#### Orta
- Temel strateji
- Uzun renkten oynar
- Minimal kazanan arar
- Risk faktörü: 0.7

#### Zor
- İleri seviye
- Hafıza (oynanan kartları sayar)
- Ölümsüz kartları kullanır
- Partner analizi
- Renk establish
- Risk faktörü: 0.8

### İhale Stratejisi

Bot el analizi yapar:
```
Potansiyel = Barış Puanı + (Tahmini El × 11 × Risk)
```

- As sayısı
- En uzun renk
- Barış kombinasyonları
- Hoşkin/Çift Pinik varlığı

### Oyun Stratejisi

#### İlk El
- Ölümsüz kartlarla başla
- Uzun renkten establish et
- Güçlü kartlarla kontrol

#### Takip
- Partner kazanıyorsa düşük at
- Kazanabiliyorsan minimal kazanan
- Kaçış gerekirse en düşük

#### Hafıza
- Çıkan kartları sayar
- Ölümsüz kartları tespit eder
- Renk dağılımını takip eder

## Teknik Yapı

### Dosya Organizasyonu

```
lib/
├── core/
│   ├── hoskin_models.dart          # Kart, Oyuncu, Takım modelleri
│   ├── hoskin_deck.dart            # Deste yönetimi
│   └── hoskin_game_engine.dart     # Ana oyun motoru
├── ai/
│   ├── hoskin_meld_engine.dart     # Barış hesaplama
│   └── hoskin_bot_ai.dart          # Bot yapay zekası
└── screens/
    └── hoskin_game_screen.dart     # UI
```

### State Yönetimi

- **ChangeNotifier** pattern
- Reactive UI updates
- Phase-based game flow

### Animasyonlar

- Kart oynatma animasyonları
- El toplama efektleri
- Smooth transitions

## Özellikler

✅ **Tam Hoşkin Kuralları**
- 80 kart sistemi
- Barış sayıları
- İhale mekanizması
- Koz sistemi

✅ **Akıllı Bot AI**
- 3 zorluk seviyesi
- İhale analizi
- Strateji motoru
- Hafıza sistemi

✅ **Profesyonel UI**
- Briç arayüzünden adapte
- Smooth animasyonlar
- Responsive design
- Kullanıcı dostu

✅ **Takım Oyunu**
- 2v2 sistem
- Partner koordinasyonu
- Takım skorları

## Gelecek Geliştirmeler

- [ ] Online multiplayer
- [ ] Replay sistemi
- [ ] İstatistikler
- [ ] Turnuva modu
- [ ] Özelleştirilebilir kurallar
- [ ] Sesli anlatım
- [ ] Animasyon ayarları

## Nasıl Oynanır?

1. **Ana Menü:** Hoşkin'i seçin
2. **İhale:** Elinizi değerlendirin, ihale yapın veya pas geçin
3. **Kart Açma:** İhale kazanırsanız 4 kart açın
4. **Koz:** En güçlü renginizi seçin
5. **Oyun:** Kartlarınızı stratejik oynayın
6. **Skor:** Barış + Oyun puanınızı hesaplayın

## İpuçları

### İhale
- Hoşkin varsa agresif olun (200 puan garanti!)
- Barış puanınızı bilin
- As ve 10'ları sayın
- Uzun renklere değer verin

### Koz Seçimi
- En uzun renginizi seçin
- As/10 sayısı önemli
- Barış kombinasyonlarını koruyun

### Oyun
- Güçlü kartları zamanında kullanın
- Partner kazanıyorsa düşük atın
- Koz çakmasını iyi değerlendirin
- Son ellerde avantaj kullanın

## Lisans

Bu proje eğitim amaçlıdır.
