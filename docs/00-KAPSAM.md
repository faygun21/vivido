# Kapsam Sözleşmesi ve Kabul Kriterleri

> Bu dosya, `README.md` §1'deki kapsam listesinin **test edilebilir** halidir.
> Bir gereksinim, ancak buradaki kriteri geçtiğinde "bitti" sayılır.

---

## W1 — Kayıt / giriş

```gherkin
Given kayıtlı olmayan bir e-posta adresim var
When  kayıt formunu doldurup gönderirim
Then  201 döner ve access + refresh token alırım
 And  aynı e-postayla ikinci kez kayıt denersem 409 alırım
 And  yanlış şifreyle giriş denersem 401 alırım
```

---

## W2 — Persona ve bütçe seçimi

```gherkin
Given kayıt olmuş ve onboarding'de olan bir kullanıcıyım
When  "Öğrenci" personasını seçip bütçeye 20.000 girerim ve kaydederim
Then  GET /profile yanıtı persona_code="student", monthly_budget=20000 döner
 And  ana ekrana yönlendirilirim
 And  liste boş değildir (en az 1 skorlanmış ev gelir)
```

---

## W3 — Skorlu varsayılan görünüm

```gherkin
Given persona seçilmiş, henüz anchor eklenmemiş
When  /explore ekranını açarım
Then  liste skora göre azalan sıralıdır (items[i].score >= items[i+1].score)
 And  ilk sayfadaki evlerin en az %60'ının skoru ≥ 65'tir
 And  her ev kartında sayısal skor ve renk bandı görünür
 And  skor yalnızca POI bileşeninden gelir (anchor yok → YaşamSkoru = POISkoru)
```

---

## W4 — Anchor sıralaması ⭐ en kritik test

```gherkin
Given 3 anchor eklemiş bir öğrenciyim (① Üniversite ② Spor salonu ③ Aile evi)
 And  4312 numaralı evin skoru 71.0
When  sürükle-bırak ile spor salonunu 1. sıraya taşırım
Then  PUT /profile/anchors/order çağrılır ve 200 döner
 And  3 saniye içinde liste yeniden yüklenir
 And  4312'nin yeni skoru eskisinden EN AZ 5 puan farklıdır
 And  gerekçe tablosunda spor salonunun ağırlığı 0.571'e yükselmiştir
 And  anchor öncelikleri veritabanında 1..n kesintisizdir
```

---

## W5 — Skor ve düşük skorlu evler

```gherkin
Given "Düşük skorlu evleri göster" işaretli
When  arama yaparım
Then  sonuçlar arasında skoru < 55 olan en az 1 ev vardır
 And  scoreDistribution alanı 4 bandın da sayısını döner
When  işareti kaldırırım
Then  skoru < 55 olan hiç ev dönmez
```

---

## W6 — Gerekçe tablosu ⭐ değişmezlik testi

```gherkin
Given herhangi bir ev ve profil kombinasyonu
When  GET /properties/{id}/score çağrılır
Then  rows[].contribution toplamı total'a ±0.05 içinde eşittir
 And  "güçlü" listesi en az 3, "zayıf" listesi en az 1 satır içerir
 And  her satırda measured, target, subScore, weight, contribution doludur
 And  anchor satırları öncelik sırasına göre sıralıdır
 And  CES düzeltmesi ayrı bir satır olarak görünür
```

---

## W7 — Ziyaret rotası

```gherkin
Given 5 ev seçtim ve başlangıç noktası olarak Kızılay'ı belirledim
When  "Rota Oluştur" derim
Then  POST /routes 200 döner, 5 saniye içinde
 And  route_stops 5 satır içerir, seq 1..5 kesintisizdir
 And  toplam süre, aynı evlerin SEÇİM SIRASIYLA gezilmesinden
      küçük veya eşittir          ← optimizasyon gerçekten çalışıyor
 And  geometry bir LineString'dir ve boş değildir
 And  steps her bacak için en az 1 manevra içerir
When  9 ev seçmeye çalışırım
Then  422 döner ("en fazla 8 ev")
```

---

## M1 / M2 — Mobil giriş ve rota listesi

```gherkin
Given web'de kullandığım hesapla mobilde giriş yaparım
Then  aynı token akışı çalışır (ayrı hesap yok)
When  rota listesini açarım
Then  web'de oluşturduğum rotalar ad, tarih, ev sayısı ve toplam süreyle görünür
```

---

## M3 — Rota görüntüleme

```gherkin
Given kayıtlı bir rotam var
When  rota listesinden birini seçerim
Then  harita rotanın tamamını kapsayacak şekilde otomatik yakınlaşır
 And  numaralı duraklar (1..n) doğru sırada görünür
 And  alt listede her ev için skor rozeti görünür
```

---

## M4 — Navigasyon

```gherkin
Given navigasyon başlatılmış ve mock GPS izi oynatılıyor
When  kullanıcı bir manevra noktasına 15 m'den yaklaşır
Then  aktif adım bir sonrakine geçer
 And  üst kartta yeni manevra metni Türkçe görünür
 And  kalan mesafe azalarak güncellenir
When  kullanıcı rota çizgisinden 50 m'den fazla saparsa (3 ardışık konum)
Then  "Rotadan çıktınız" uyarısı görünür
When  navigasyon ekranından çıkarım
Then  watchPositionAsync durdurulur (pil sızıntısı yok)
```

---

## M5 — Skor kartı ve ziyaret işaretleme

```gherkin
Given bir durağa 30 m'den yakınım
When  "Ziyaret ettim" derim
Then  PATCH /routes/{id}/stops/{seq} çağrılır
 And  durak listede ✓ ile işaretlenir
 And  web'de aynı rota açıldığında ✓ görünür (aynı veritabanı)
```

---

## Skorlama motoru — değişmezlikler

Bunlar her koşulda doğru olmalı; `Category=Invariant` etiketiyle test edilir.

| # | Değişmezlik |
|---|---|
| **I1** | Skor her zaman `[0, 100]` aralığında |
| **I2** | Bir kategorinin süresi azalırsa skor artmalı veya aynı kalmalı (monotonluk) |
| **I3** | Tüm alt skorlar 100 ve bütçe rahatsa → toplam 100 |
| **I4** | `Σ rows[].contribution == total` (±0.05) |
| **I5** | Anchor sırası değişince skor değişmeli — aynı kalmamalı |
| **I6** | Aynı girdi iki kez → bit-bit aynı çıktı (determinizm) |
| **I7** | Anchor listesi boşken skor = POISkoru (bütçe girilmemişse) |
| **I8** | Her persona için ağırlıklar toplamı 1.000 |

---

## Veri kalitesi kapıları

`pnpm db:check` ile çalışır. `error` seviyesi başarısızsa ETL durur.

| Kod | Kural | Seviye |
|---|---|---|
| DQ-01 | Her konut kendi bina poligonunun içinde (`ST_Within`) — %100 | **error** |
| DQ-02 | `rent_per_m2` mahalle medyanının [0.3×, 3×] aralığında — %98 | warn |
| DQ-03 | Her persona için ağırlık toplamı = 1.000 | **error** |
| DQ-04 | Erişim matrisi tam (6.000 × 10 = 60.000 satır) | warn |
| DQ-05 | Kira dağılımı çeyreklikleri makul | warn |
| DQ-06 | Anchor öncelikleri 1..n kesintisiz | **error** |

---

## Sistem seviyesi hedefler

| Endpoint | p95 hedef |
|---|---|
| `GET /properties` | < 300 ms |
| `GET /properties/{id}/score` | < 250 ms |
| `POST /routes` (8 ev) | < 5 s |
| Hata oranı | < %1 |
