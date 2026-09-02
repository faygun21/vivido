# Mobil Gereksinim Durum Raporu

> **Tarih:** 2026-08-26 (2026-09-02'de düzeltildi — bkz. not)
> **İncelenen branch:** `feat/mobile-property-favorites-routes`
> **Kapsam kaynağı:** Kullanıcının paylaştığı son mobil gereksinim listesi (`R-1`–`R-78`)

> ⚠️ **2026-09-02 düzeltmesi.** R-51–R-55, "Yapılmayan gereksinimler"
> tablosunda listelenmiş ama açıklama sütunlarının tamamı zaten
> "**Tamamlandı.**" diyordu — yanlış tabloda kalmışlardı, "Yapılan
> gereksinimler"e taşındı. R-28 de kodda (`mobile/lib/features/home/
> presentation/pages/home_page.dart`, `UserLocationController`) canlı GPS
> konumunun izin akışıyla birlikte haritada gösterildiği doğrulanarak
> "Yapıldı"ya taşındı. Özet tablo buna göre güncellendi.

Bu raporda yalnızca son paylaşılan 78 mobil gereksinim kabul kapsamı olarak
alınmıştır. Repodaki eski `M1`–`M5` veya `W1`–`W7` kapsamları, bu durum
değerlendirmesinde ölçüt olarak kullanılmamıştır.

## 1. Durum özeti

| Durum | Adet | Toplam içindeki oran |
|---|---:|---:|
| ✅ Yapıldı | **52** | **%66,7** |
| 🟡 Yarım yapıldı | **16** | **%20,5** |
| ❌ Yapılmadı | **10** | **%12,8** |
| **Toplam** | **78** | **%100** |

Tam veya kısmi olarak ele alınmış gereksinim sayısı **62/78 (%79,5)**'dır.
Bir gereksinim, bütün maddeleri mobil arayüz ve gerekli backend desteğiyle
karşılanıyorsa “Yapıldı” kabul edilmiştir. Gereksinimin yalnızca bir bölümü
varsa “Yarım yapıldı” olarak işaretlenmiştir.

## 2. Yapılan gereksinimler

| ID | Alt modül | Gereksinim | Uygulamadaki karşılığı |
|---|---|---|---|
| **R-1** | Açılış | Uygulama açıldığında Vivido logosunun bulunduğu açılış ekranı gösterilmelidir. | Açılış ekranı `vivido_logo.svg` marka varlığını gösteriyor. |
| **R-2** | Kullanıcı İşlemleri | Sistem Giriş Yap, Kayıt Ol ve Misafir Olarak Keşfet seçeneklerini sunmalıdır. | Karşılama ekranında üç seçenek de bulunuyor ve ayrı akışlara yönlendiriyor. |
| **R-4** | Kayıt Ol | Aynı e-posta adresiyle birden fazla hesap oluşturulması engellenmelidir. | API e-posta benzersizliğini kontrol ediyor ve tekrar kayıtta `409 EMAIL_ALREADY_EXISTS` döndürüyor. |
| **R-5** | Kayıt Ol | Şifre ve şifre tekrar bilgileri eşleşmiyorsa kayıt tamamlanmamalı ve uyarı gösterilmelidir. | Kayıt formundaki parola tekrar alanı eşleşmeyi doğruluyor ve eşleşmeden isteği göndermiyor. |
| **R-6** | Kullanıcı Girişi | Kullanıcı kayıtlı e-posta adresi ve şifresiyle giriş yapabilmelidir. | Mobil giriş formu gerçek `/auth/login` endpoint'ine bağlıdır. |
| **R-7** | Kullanıcı Girişi | E-posta veya şifre hatalı olduğunda anlaşılır hata mesajı gösterilmelidir. | `INVALID_CREDENTIALS`, kullanıcıya “E-posta veya parola hatalı” olarak gösteriliyor. |
| **R-8** | Şifre İşlemleri | Kullanıcı Şifremi Unuttum üzerinden kayıtlı e-postasıyla şifre yenileme başlatabilmelidir. | Mobilde kod isteme, 6 haneli kodu doğrulama ve yeni parolayı kaydetme akışı gerçek auth endpoint'lerine bağlıdır. |
| **R-9** | Kullanıcı Girişi | Girişten sonra profili olan kullanıcı ana ekrana, profili olmayan kullanıcı profil oluşturma ekranına yönlendirilmelidir. | `GET /profile` sonucuna göre `authenticated` veya `onboarding` aşamasına geçiliyor. |
| **R-10** | Misafir Kullanıcı | Misafir Olarak Keşfet ile giriş yapmadan harita ekranına ulaşılabilmelidir. | Misafir oturum açmadan Çankaya haritasına ulaşabiliyor. |
| **R-11** | Misafir Kullanıcı | Misafir kiralık konutları ve temel bilgilerini inceleyebilmeli; hesap gerektiren işlemlerde giriş/kayıt ekranına yönlendirilmelidir. | Misafir görünür alandaki kiralık konut pinlerini ve kira, oda, metrekare, bina yaşı/asansör gibi mevcut temel bilgileri inceleyebiliyor; kişiselleştirilmiş işlemler için Giriş Yap/Kayıt Ol çağrıları gösteriliyor. |
| **R-13** | Profil | Kullanıcı öğrenci, uzaktan çalışan, çocuklu aile ve emekli hazır profillerinden birini seçebilmelidir. | Dört persona backend'den alınıyor ve onboarding ekranında seçilebiliyor. |
| **R-14** | Profil | Hazır profil seçildiğinde ilgili yaşam kriterleri ve başlangıç önem seviyeleri otomatik gösterilmelidir. | Persona `categoryWeights` verisi ağırlığa göre sıralanıyor; kriterler ve başlangıçtaki göreli önem yüzdeleri onboarding ve profil editöründe gösteriliyor. |
| **R-16** | Tercihler | Kullanıcı yaşam kriterlerinin önem sırasını sürükle-bırakla değiştirebilmelidir. | Sekiz yaşam kriteri yeniden sıralanabilir listede sürükle-bırakla değiştirilebiliyor. |
| **R-19** | Özel Konumlar | Kullanıcı iş yeri, okul, üniversite, spor salonu veya aile evi gibi bir veya birden fazla özel konum tanımlayabilmelidir. | Kullanıcı serbest etiketle en fazla üç anchor ekleyebiliyor. |
| **R-20** | Özel Konumlar | Kullanıcı özel konumu haritadan seçebilmeli veya adres aramasıyla ekleyebilmelidir. | Gereksinimdeki alternatiflerden haritadan nokta seçme yöntemi çalışıyor. |
| **R-21** | Özel Konumlar | Kullanıcı özel konumlara isim verebilmeli, silebilmeli ve önem seviyelerini belirleyebilmelidir. | Konum etiketi, silme ve sürükle-bırakla öncelik/ağırlık sıralaması bulunuyor. |
| **R-23** | Ana Menü | Alt menüden Harita, Rotalarım, Favorilerim ve Profilim ekranlarına geçilebilmelidir. | Alt menüde Harita, Konutlar, Favoriler, Rotalar ve Profil ekranları bulunuyor; konut/favori/rota state'i ortak controller'larda korunuyor. |
| **R-24** | Ana Menü | Kullanıcının bulunduğu aktif ekran alt menüde ayırt edilebilir şekilde gösterilmelidir. | Flutter `NavigationBar` seçili sekmeyi farklı renk ve ikonla gösteriyor. |
| **R-25** | Harita | Ana harita ekranında Ankara Çankaya bölgesi ve proje kapsamındaki kiralık konutlar gösterilmelidir. | Çankaya vektör haritası üzerinde giriş yapan kullanıcıya bütçesine uygun skorlanmış konutlar, misafire görünür alandaki temel konut verileri pinleniyor. |
| **R-26** | Harita | Kullanıcı harita üzerinde yakınlaştırma, uzaklaştırma ve sürükleme işlemleri yapabilmelidir. | MapLibre'ın yakınlaştırma ve kaydırma hareketleri aktiftir. |
| **R-27** | Harita | Konut ve POI gösterimleri yakınlaştırma seviyesine göre düzenlenmeli; uzak görünümde gizlenmeli/gruplanmalı, yakında detaylanmalıdır. | Konut ve POI GeoJSON kaynakları uzak görünümde MapLibre kümeleri olarak çiziliyor; yakınlaştırıldığında tekil, dokunulabilir noktalara ayrılıyor. |
| **R-29** | POI Katmanları | Market, eczane, sağlık, eğitim, toplu taşıma, restoran/kafe, park/yeşil alan ve spor POI katmanları ayrı ayrı açılıp kapatılabilmelidir. | Backend'den alınan aktif POI kategorileri mobil katman panelinde ayrı ayrı açılıp kapatılabiliyor. |
| **R-30** | POI Katmanları | Aynı anda birden fazla POI kategorisi haritada görüntülenebilmelidir. | Seçili kategori kodları tek bbox sorgusunda virgülle ayrılmış olarak gönderiliyor ve birden çok kategori birlikte çiziliyor. |
| **R-31** | POI Detayı | Bir hizmet noktasına dokununca adı, kategorisi ve temel bilgileri gösterilmelidir. | Tekil POI noktasına dokunulduğunda adı, Türkçe kategori adı ve koordinatı alt bilgi panelinde gösteriliyor. |
| **R-32** | Konut | Haritadan kiralık konut seçilerek konut detay ekranına geçilebilmelidir. | Haritadaki tekil konut pinine dokunulduğunda `GET /properties/{id}` verisiyle ayrı ve kapsamlı konut detay sayfası açılıyor. |
| **R-34** | Konut Detayı | Seçilen konutun konumu haritada gösterilmelidir. | Konut detay sayfasında seçilen konuta odaklanan MapLibre haritası ve konut pini bulunuyor. |
| **R-36** | Uygunluk Skoru | Kullanıcı toplam uygunluk skorunu ve kriterlere ait alt skorları görüntüleyebilmelidir. | Detay sayfası toplam skoru, skor bandını ve her kriterin ölçülen süresini, hedefini ve alt skorunu gösteriyor. |
| **R-37** | Skor Açıklaması | Sistem konutun kullanıcı açısından güçlü yönlerini ve dikkat edilmesi gereken noktalarını gösterebilmelidir. | Backend skor kırılımındaki güçlü/zayıf yönler, bütçe uyumu ve varsa zayıf halka etkisi mobil detay ekranında açıklanıyor. |
| **R-40** | Favoriler | Konut favorilere eklenebilmeli ve favorilerden çıkarılabilmelidir. | Liste ve detay ekranları gerçek `POST/DELETE /profile/favorites` endpoint'leriyle favori durumunu güncelliyor. |
| **R-41** | Favoriler | Favorilerim ekranında kayıtlı konutlar görüntülenmeli ve detaylarına ulaşılabilmelidir. | Favoriler sekmesi `GET /profile/favorites` kartlarını gösteriyor; karta dokununca tam konut detayı açılıyor. |
| **R-42** | Favoriler | Favorilerdeki konutlar ziyaret rotasına eklenebilmelidir. | Her favori kartındaki “Rotaya ekle” işlemi konutu ortak rota taslağına ekliyor. |
| **R-43** | Rota Optimizasyonu | Sistem seçilen konutların mesafe ve sürelerine göre uygun ziyaret sırası oluşturmalıdır. | Mobil 2–8 seçili konutu başlangıç ve ulaşım moduyla `POST /routes` endpoint'ine gönderiyor; backend OSRM süre matrisi ve Held-Karp TSP ile sırayı optimize ediyor. |
| **R-44** | Rota | Oluşturulan rota haritada; ziyaret sırası, toplam mesafe ve tahmini toplam süreyle gösterilmelidir. | GeoJSON rota çizgisi, başlangıç ve numaralı duraklar MapLibre üzerinde; toplam mesafe/süre ve sıralı duraklar rota kartında gösteriliyor. |
| **R-45** | Rota | Kullanıcı rotadan bir konut çıkarabilmeli ve rota kalan konutlara göre yeniden oluşturulmalıdır. | Kullanıcı durağı kaldırabiliyor; mobil kalan konutlarla yeni optimize rotayı oluşturup aktif ediyor, ardından eski rotayı siliyor; eski kayıt silinemezse kullanıcı açıkça uyarılıyor. |
| **R-46** | Rota | Kullanıcı oluşturduğu ziyaret rotasını hesabına kaydedebilmelidir. | `POST /routes` oluşturma sırasında rotayı kullanıcı hesabına kalıcı kaydediyor ve mobil başarı durumunu gösteriyor. |
| **R-47** | Rotalarım | Kullanıcı kayıtlı ziyaret rotalarını Rotalarım ekranında görüntüleyebilmelidir. | Rotalar sekmesi `GET /routes` ile kullanıcının kayıtlı rotalarını en yeniden eskiye listeliyor. |
| **R-48** | Rotalarım | Kayıtlı rota için rota adı, konut sayısı, toplam mesafe ve tahmini toplam süre gösterilmelidir. | Kayıtlı rota kartlarında ad, ulaşım modu, durak sayısı, mesafe ve süre gösteriliyor. |
| **R-49** | Rotalarım | Kullanıcı kayıtlı rotanın detayları ve konutların ziyaret sırasını harita üzerinde görüntüleyebilmelidir. | Kayıtlı rota açıldığında `GET /routes/{id}` ile geometri ve duraklar alınarak rota haritası ve ziyaret sırası gösteriliyor. |
| **R-50** | Rotalarım | Kullanıcı kayıtlı rotayı silebilmelidir. | Onay diyaloğundan sonra `DELETE /routes/{id}` çağrılıyor ve rota listeden kaldırılıyor. |
| **R-58** | Kullanıcı İşlemleri | Kullanıcı Profilim ekranından hesabından çıkış yapabilmelidir. | Profil ekranındaki “Çıkış yap” işlemi oturumu kapatıyor. |
| **R-59** | Şifre Güvenliği | Şifre en az 8 karakter; büyük harf, küçük harf, rakam ve özel karakter içermelidir. | Mobil kayıt ve şifre sıfırlama formları ortak parola politikasıyla bütün kuralları doğruluyor; backend de kayıt ve sıfırlama isteklerinde aynı kuralları zorunlu tutuyor. |
| **R-60** | Yetkilendirme | Kullanıcı yalnızca kendi profil, tercih, favori ve kayıtlı rota bilgilerine erişebilmelidir. | Profil, anchor, favori ve rota endpoint'leri JWT `NameIdentifier` kullanıcısına göre sorgulanıyor; rota detayı da `id + userId` sahipliğiyle açılıyor. |
| **R-62** | Oturum Güvenliği | Kullanıcı çıkış yaptıktan sonra hesabına özel ekranlara yetkisiz erişim sağlanamamalıdır. | Güvenli depodaki oturum siliniyor, uygulama guest aşamasına dönüyor ve korumalı API endpoint'leri JWT istiyor. |
| **R-65** | Veri Tutarlılığı | Profil, tercih, favori, skor ve rota bilgileri güncel ve Web uygulamasındaki bilgilerle tutarlı olmalıdır. | Mobil ve web profil, konut, skor, favori ve rota için aynı backend endpoint'lerini kullanıyor; favori mutasyonu sonrası ilgili mobil listeler sunucudan yenileniyor. |
| **R-70** | Sistem Yapısı | Mobil kullanıcı arayüzü, Backend ve Data bileşenleri birbirinden ayrılmış geliştirilebilir yapıda olmalıdır. | Mobilde `core/features`, backend'de Application/Domain/Infrastructure/API katmanları ayrılmıştır. |
| **R-71** | Entegrasyon | Mobil uygulama kullanıcı, profil, konut, POI, skor, favori ve rota bilgilerine Backend üzerinden erişmelidir. | Bütün sayılan kaynaklar ayrı mobil gateway/controller katmanlarından gerçek `/api/v1` endpoint'lerine bağlıdır. |
| **R-28** | Konum | Konum izni açıkken kullanıcının GPS konumu haritada gösterilmelidir. | Ana harita ekranı `UserLocationController` ile izin akışını yönetiyor ve canlı GPS konumunu haritada işaretçiyle gösteriyor (`home_page.dart`). |
| **R-51** | Navigasyon | Kullanıcı seçtiği ziyaret rotası için navigasyonu başlatabilmelidir. | Önizlenen, aktif ve kayıtlı rotalardan canlı konuma göre navigasyon başlatılabiliyor; çevrimdışıyken işlem açıklayıcı mesajla engelleniyor. |
| **R-52** | Navigasyon | Navigasyon öncesi konum izni kontrol edilmeli, izin kapalıysa uyarı gösterilmelidir. | Paylaşılan konum denetleyicisi servis/izin durumunu navigasyon ekranından önce kontrol ediyor; kalıcı ret için ayarlara yönlendiriyor. Android ve iOS kullanım açıklamaları tanımlı. |
| **R-53** | Navigasyon | Navigasyon sırasında GPS konumu ve oluşturulan ziyaret rotası haritada gösterilmelidir. | 5 m filtreli sürekli GPS akışı, yönlü kullanıcı işareti, 16.5 yakınlaştırma/45° eğimle kamera takibi, rota ve gri tamamlanan rota bölümü MapLibre haritasında gösteriliyor. |
| **R-54** | Navigasyon | Sıradaki konut, temel manevra bilgisi ve manevraya kalan mesafe gösterilmelidir. | OSRM adımları Türkçe manevra metni ve yön ikonu olarak; manevra mesafesi, durak sırası, konut özeti, kalan durak mesafesi ve tahmini süreyle gösteriliyor. |
| **R-55** | Navigasyon | Kullanıcı rotadan belirlenen mesafeden fazla uzaklaşınca sapma uyarısı gösterilmelidir. | 50 m sapma/30 m dönüş histerezisi ve üç ardışık GPS ölçümüyle sapma algılanıyor; mesafeli uyarı ve canlı konumdan rota yenileme sunuluyor. 35 m üzeri doğruluk hesaplamaya alınmıyor. |

## 3. Yarım yapılan gereksinimler

| ID | Alt modül | Gereksinim | Yapılan bölüm | Eksik bölüm |
|---|---|---|---|---|
| **R-3** | Kayıt Ol | Kullanıcı ad, soyad, e-posta ve şifre bilgileriyle hesap oluşturabilmelidir. | Kayıt e-posta/parola ile tamamlanıyor; hemen sonraki profil adımı ad ve soyadı ayrı ve zorunlu alıp backend'e kaydediyor. | Ad ve soyad henüz doğrudan hesap kayıt isteğinin parçası değil. |
| **R-15** | Tercihler | Kullanıcı ulaşım, sağlık, eğitim, sosyal yaşam, günlük ihtiyaçlar, yeşil alan ve spor kriterlerinin önem seviyelerini belirleyebilmelidir. | Bütün kriterler listeleniyor ve kullanıcının sırasından göreli önem yüzdeleri üretiliyor. | Her kriter için sıradan bağımsız ayrı bir seviye/ağırlık kontrolü yok. |
| **R-17** | Tercihler | Yaşam kriterlerindeki değişiklikler kaydedilmeli ve konut uygunluk skorunda kullanılmalıdır. | Sıralama `PUT /profile` ile `UserProfileCategoryOrders` tablosuna kaydediliyor ve web ile aynı profilden geri okunuyor. | Konut skorlama motoru kaydedilen sıralamayı henüz skora uygulamıyor. |
| **R-18** | Bütçe | Kullanıcı aylık kira bütçesini belirleyebilmeli ve bu bilgi konut uygunluk skorunda kullanılmalıdır. | Minimum–maksimum kira aralığı onboarding ve profil ekranından kaydedilip güncellenebiliyor. | Yeni skorlama servisi kira aralığını henüz skora uygulamıyor. |
| **R-22** | Profil | Profil ekranında profil bilgileri, bütçe, tercihler ve özel konumlar görüntülenip güncellenebilmelidir. | Ad, soyad, persona, bütçe ve yaşam kriterleri görüntülenip profil editöründen güncellenebiliyor; özel konum sayısı gösteriliyor ve Profil içindeki bağlantıdan yönetiliyor. | Yaş/cinsiyet/çalışma/medeni hâl alanları yok. |
| **R-33** | Konut Detayı | Fotoğraf, kira, mahalle, oda, metrekare, asansör, otopark, bina katı ve konut katı bilgileri gösterilmelidir. | Detay API'sinden kira, mahalle/adres, oda, metrekare, asansör, otopark, toplam kat ve konut katı gösteriliyor; sentetik veri için temsili görsel açıkça etiketleniyor. | Backend DTO/veri modelinde gerçek ilana ait fotoğraf URL'si bulunmadığı için gerçek konut fotoğrafı gösterilemiyor. |
| **R-35** | Uygunluk Skoru | Profil, bütçe, tercihler, özel konumlar ve çevre analiziyle kişiselleştirilmiş konut uygunluk skoru oluşturulmalıdır. | Backend POI erişim süreleri ve persona ağırlıklarından 0–100 skor üretiyor; bütçe aralığına uygun konutlar mobil haritada gösteriliyor ve pin detayında toplam skor sunuluyor. | Kaydedilen kriter sırası, kira aralığı ve özel konumlar skor hesabının bütün bileşenlerine henüz katılmıyor. |
| **R-38** | Erişim Analizi | Konut ile çevresindeki hizmet noktaları arasındaki mesafe ve erişim süresi gösterilmelidir. | Kullanıcının haritadan veya aramadan seçtiği nokta çevresinde 0,5–5 km analiz alanı ile 5–30 dakikalık yaklaşık yürüme erişim alanı jeodezik poligon olarak gösteriliyor. | Kiralık konut ve POI seçimi ile her hizmet noktası için gerçek yol mesafesi/erişim süresi verisi ve sonuç listesi henüz yok. |
| **R-61** | Skor Tutarlılığı | Aynı profil, tercihler ve konut için aynı koşullarda aynı uygunluk skoru gösterilmelidir. | Mobil, web ile aynı `/properties` endpoint'inin backend'de hesaplayıp sıraladığı toplam skoru değiştirmeden gösteriyor. | Aynı koşul sonucunu uçtan uca doğrulayan deterministik mobil/backend kabul testi bulunmuyor. |
| **R-63** | Performans | Harita, konut, rota ve detay ekranları kullanıcıyı uzun süre bekletmeden yüklenmelidir. | Konut/POI kaynakları kümeleniyor; liste ve rota özet endpoint'leri ağır detay/geometriden ayrılıyor; ekranlarda loading/error durumları var. | Gerçek cihazda süre eşikleriyle çalışan ölçülmüş performans kabul testi bulunmuyor. |
| **R-64** | CBS Performansı | Haritada kullanılan konut, POI ve rota verileri performanslı ve zoom seviyesine göre optimize edilmelidir. | Vektör tile, görünür alan bbox, GPU tabanlı konut/POI cluster'ları ve GeoJSON rota line katmanı kullanılıyor. | Gerçek cihaz ve yüksek veri hacmi için ölçülmüş CBS performans testi bulunmuyor. |
| **R-66** | Kişisel Veri Gizliliği | Yalnızca gerekli kişisel bilgiler alınmalı ve kullanım amacı belirtilmelidir. | Uygulama şu an sınırlı kullanıcı verisi topluyor. | Gizlilik metni, açık amaç bildirimi ve onay akışı yok. |
| **R-68** | Hata Yönetimi | Veri, bağlantı, GPS veya servis hatalarında anlaşılır mesaj gösterilmeli ve uygulamanın tamamı kullanılamaz olmamalıdır. | API timeout, bağlantı ve rota `OSRM_UNAVAILABLE`/doğrulama hataları kullanıcı mesajlarına çevriliyor; liste ekranları tekrar deneme sunuyor. | Tile/harita ve GPS için merkezi hata/fallback yönetimi yok. |
| **R-69** | Kullanılabilirlik | Temel işlemler kolay anlaşılmalı ve arayüz farklı hedef ekran boyutlarında bozulmamalıdır. | SafeArea, kaydırma, küçük ekran ve klavye taşması düzeltmeleri bulunuyor. | Birden fazla cihaz boyutu için kapsamlı responsive/golden test matrisi yok. |
| **R-73** | Veri Gereksinimi | Konut, uygunluk skoru, çevre analizi ve rota bilgilerinin görüntülenmesi için gerekli veriler sistemde bulunmalıdır. | Sentetik konut, POI, erişim matrisi, açıklanabilir skor, OSRM geometrisi, rota/durak/bacak verileri sistemde ve mobilde görüntüleniyor. | Konut çevresindeki POI'leri tek tek mesafe/süreyle veren erişim sonuç listesi tamamlanmadı. |
| **R-74** | Bağlantı | İnternet/servis bağlantısı yokken çevrimiçi işlemler yapılmamalı ve kullanıcı bilgilendirilmelidir. | API bağlantı hatalarında kullanıcıya sunucuya ulaşılamadığı bildiriliyor. | Harita tile, konut, rota ve navigasyon için ortak çevrimdışı durum ekranı yok. |

## 4. Yapılmayan gereksinimler

| ID | Alt modül | Gereksinim | Eksik durum |
|---|---|---|---|
| **R-12** | Profil | Kullanıcı yaş, cinsiyet, çalışma durumu ve medeni hâl bilgileriyle profil oluşturabilmelidir. | Bu alanlar modelde, API'de ve mobil formda yok. |
| **R-39** | Özel Konum Analizi | Konut ile kullanıcının kayıtlı özel konumları arasındaki tahmini mesafe ve ulaşım süresi gösterilmelidir. | Konut-anchor analiz servisi ve ekranı yok. |
| **R-56** | Ziyaret Takibi | Ulaşılan konut “Ziyaret Ettim” ile işaretlenmeli ve rota ilerlemesi güncellenmelidir. | Ziyaret işaretleme yok. |
| **R-57** | Ziyaret Takibi | Ziyaretten sonra sıradaki konuta yönlendirilmeli; tümü tamamlanınca rota tamamlandı bildirimi gösterilmelidir. | Ziyaret ilerleme akışı yok. |
| **R-67** | Konum Gizliliği | Mevcut konum yalnızca izin alındıktan sonra harita ve navigasyon amacıyla kullanılmalıdır. | GPS/konum izni özelliği yok. |
| **R-72** | Geliştirilebilirlik | Mobil uygulama ileride farklı ilçe veya bölgelerin eklenmesine uygun geliştirilmelidir. | Harita merkezi, stil ve sınıf isimleri Çankaya'ya sabitlenmiş durumda. |
| **R-75** | Paylaşım | Seçilen konut veya ziyaret rotası paylaşılabilir bağlantıyla cihaz uygulamalarında paylaşılabilmelidir. | Deep link/share özelliği yok. |
| **R-76** | Kullanıcı Puanlaması | Giriş yapan kullanıcı konuta puan verebilmeli ve önceki puanını değiştirebilmelidir. | Kullanıcı puanı modeli, endpoint'i ve ekranı yok. |
| **R-77** | Kullanıcı Puanlaması | Kullanıcı puanı, sistemin kişiselleştirilmiş uygunluk skorundan ayrı gösterilmelidir. | Kişiselleştirilmiş uygunluk skoru ayrı gösteriliyor; ancak kullanıcı puanı modeli, endpoint'i ve ekranı yok. |
| **R-78** | Offline Kullanım | İnternet yokken cihazda saklanan favori konutların temel bilgileri gösterilmeli; çevrimiçi gereken işlemler için kullanıcı bilgilendirilmelidir. | Favori cache'i ve offline kullanım desteği yok. |

## 5. Kodda doğrulanan başlıca karşılıklar

- Açılış ve oturum aşamaları: [`mobile/lib/app/app.dart`](../mobile/lib/app/app.dart)
- Giriş/kayıt/şifre yenileme akışları: [`mobile/lib/features/auth/presentation/pages`](../mobile/lib/features/auth/presentation/pages)
- Ortak güçlü parola politikası: [`mobile/lib/features/auth/domain/password_policy.dart`](../mobile/lib/features/auth/domain/password_policy.dart)
- Oturum, profil ve hata yönetimi: [`mobile/lib/features/auth/application/session_controller.dart`](../mobile/lib/features/auth/application/session_controller.dart)
- Güvenli token saklama: [`mobile/lib/core/storage/token_store.dart`](../mobile/lib/core/storage/token_store.dart)
- Profil, bütçe ve tercih düzenleme: [`mobile/lib/features/home/presentation/pages/home_page.dart`](../mobile/lib/features/home/presentation/pages/home_page.dart)
- Persona/profil/tercih onboarding: [`mobile/lib/features/onboarding/presentation/pages/onboarding_page.dart`](../mobile/lib/features/onboarding/presentation/pages/onboarding_page.dart)
- Yaşam kriteri sıralama modeli ve bileşeni: [`mobile/lib/features/preferences`](../mobile/lib/features/preferences)
- Özel konum ekleme/silme/sıralama: [`mobile/lib/features/anchors/presentation/pages/anchor_manager_page.dart`](../mobile/lib/features/anchors/presentation/pages/anchor_manager_page.dart)
- Konum analizi hesabı ve kontrolleri: [`mobile/lib/features/location_analysis`](../mobile/lib/features/location_analysis)
- POI/konut API, model, controller ve katman paneli: [`mobile/lib/features/map_data`](../mobile/lib/features/map_data)
- En uygun konut listesi, gerçek konut detayı ve skor açıklamaları: [`mobile/lib/features/properties`](../mobile/lib/features/properties)
- Favori konut API'si, ortak durum yönetimi ve Favoriler ekranı: [`mobile/lib/features/favorites`](../mobile/lib/features/favorites)
- Rota taslağı, optimizasyon, kayıtlı rotalar ve rota haritası: [`mobile/lib/features/routes`](../mobile/lib/features/routes)
- Çankaya MapLibre haritası: [`mobile/lib/features/map/presentation/widgets/cankaya_map.dart`](../mobile/lib/features/map/presentation/widgets/cankaya_map.dart)
- Mobil API istemcisi: [`mobile/lib/core/network/api_client.dart`](../mobile/lib/core/network/api_client.dart)
- Backend auth endpoint'leri: [`api/src/Vivido.Api/controllers/AuthController.cs`](../api/src/Vivido.Api/controllers/AuthController.cs)
- Backend profil/anchor endpoint'leri: [`api/src/Vivido.Api/controllers/ProfilesController.cs`](../api/src/Vivido.Api/controllers/ProfilesController.cs), [`api/src/Vivido.Api/controllers/AnchorsController.cs`](../api/src/Vivido.Api/controllers/AnchorsController.cs)
- Backend POI/konut endpoint'leri: [`api/src/Vivido.Api/controllers/PoisController.cs`](../api/src/Vivido.Api/controllers/PoisController.cs), [`api/src/Vivido.Api/controllers/PropertiesController.cs`](../api/src/Vivido.Api/controllers/PropertiesController.cs)
- Backend favori ve rota endpoint'leri: [`api/src/Vivido.Api/controllers/FavoritesController.cs`](../api/src/Vivido.Api/controllers/FavoritesController.cs), [`api/src/Vivido.Api/controllers/RoutesController.cs`](../api/src/Vivido.Api/controllers/RoutesController.cs)

## 6. Öncelikli eksik özellik sırası

Bağımlılıklar dikkate alındığında önerilen geliştirme sırası:

1. **Konut analizi ve skor tamamlamaları:** R-33, R-35, R-38, R-39, R-61 ve R-73; gerçek ilan fotoğrafı ile anchor/POI mesafe-süre verileri tamamlanmalı, kaydedilen kriter sırası R-17 kapsamında skora bağlanmalı
2. **Profil tamamlamaları:** R-3, R-12, R-15, R-22
3. **GPS ve POI erişim analizi:** R-38, R-67 *(R-28 tamamlandı, düşürüldü)*
4. **Ziyaret takibi:** R-56–R-57 *(R-51–R-55 navigasyon tamamlandı, düşürüldü)*
5. **Güvenlik, gizlilik ve hata yönetimi:** R-62, R-66, R-68 ve R-74
6. **Paylaşım, kullanıcı puanı ve çevrimdışı kullanım:** R-75–R-78
