# Ekran görüntüleri

Kök dizindeki [`README.md`](../../README.md) ve [`README.tr.md`](../../README.tr.md)
bu klasördeki dosyalara **tam olarak aşağıdaki adlarla** bağ veriyor.

## Durum

| Dosya | Durum | Ne gösteriyor |
|---|---|---|
| `01-explore-map.png` | ✅ | Keşfet haritası, puanlanmış konut pinleri + "En uygun evler" paneli |
| `02-score-breakdown.png` | ✅ | Skor gerekçesi — neden uygun / neden uygun değil, ölçülen süre vs hedef |
| `03-persona-budget.png` | ✅ | Persona seçimi (Öğrenci seçili) |
| `04-anchors.png` | ✅ | 3 anchor eklenmiş, önem sırasına dizilmiş |
| `05-route.png` | ✅ | 3/8 ev seçili, rota haritada çizili, mesafe/süre panelde |
| `06-mobile-navigation.jpeg` | ✅ | Mobil navigasyon: "Sola dön" manevra kartı, numaralı duraklar, "Sıradaki konut 1/5" |

Altısı da yerinde; iki README'deki bağlantıların tamamı çözülüyor.

> ℹ️ **`06` neden JPEG:** tam ekran harita karoları fotoğrafımsı gradyan
> içeriyor ve PNG bunları sıkıştıramıyor — aynı görsel PNG olarak **1,4 MB**,
> JPEG olarak **178 KB**. Metin keskinliği kaybolmadığı için JPEG bırakıldı.
> Aşağıdaki "PNG kaydedin" tavsiyesi **arayüz ağırlıklı** ekranlar için
> geçerli; baştan sona harita olan bir görselde JPEG doğru tercih.

## 🔒 E-posta redaksiyonu — yeni görsel eklerken tekrarlayın

`01`, `03`, `04` ve `05` görsellerinde sağ üst köşedeki nav çubuğunda giriş
yapılmış hesabın **gerçek e-posta adresi** görünüyordu. Depo herkese açık
olacağı için bu adres nav arka plan rengiyle kapatıldı (2026-09-07).

Yeni bir görsel eklerken aynı kontrolü yapın: kadrajda e-posta, gerçek ad/soyad
ya da başka kişisel bilgi kalmasın. En temizi baştan bir **test hesabıyla**
çekmek — sonradan kapatmak her zaman iz bırakma riski taşır.

> `03` görselinde üstteki form alanlarında hâlâ gerçek ad/soyad görünüyor.
> Kişisel veri sayılabilir; rahatsızlık verirse o görseli test hesabıyla
> yeniden çekmek gerekir.

## Çekim ipuçları

- **Genişlik 1900 px** civarı ideal; mevcut geniş görseller 1917×870.
- **Açık tema** — hepsi aynı temada olsun.
- **Arayüz ağırlıklı ekranlarda PNG** (keskin metin, küçük dosya). **Baştan
  sona harita olan ekranlarda JPEG** — bkz. yukarıdaki `06` notu.
- Tarayıcı sekmelerini ve masaüstünü kadraja almayın, sadece uygulama.
- Mobilde mümkünse **bildirim simgelerini temizleyin** ve pili şarj edin;
  `06`'da durum çubuğunda WhatsApp/Telegram/Instagram simgeleri ve %14 pil
  görünüyor. Gizlilik riski değil, sadece dağınık duruyor.
- İlanlar sentetik olduğu için konut verisinde mahremiyet sorunu yok; dikkat
  edilecek tek şey hesap bilgileri.

## Düzen notu

README'lerdeki yerleşim görsellerin en-boy oranına göre kurgulandı:

- **Geniş** olanlar (`01`, `03`, `04`, `05` — 1917×870) tam genişlikte, alt alta.
- **Dar/uzun** olanlar (`02` — 450×745 ve `06` — 945×2048) yan yana, iki sütunlu.

İkisinin en-boy oranı farklı (1:1,66 ve 1:2,17), bu yüzden `width` değerleri
elle dengelendi: `02` **420 px**, `06` **320 px**. İkisi de ~695 px yüksekliğe
oturuyor, yani yan yana eşit görünüyorlar. Eşit genişlik verilseydi telefon
görseli diğerini bir buçuk katı boyunda ezerdi.

Farklı oranda bir görsel eklerseniz iki README'deki bu yerleşimi de gözden
geçirin; geniş bir ekran görüntüsünü 420 px'e sıkıştırmak onu okunmaz yapar.
