# Mobil Gereksinim Durum Raporu

> **Tarih:** 2026-08-25
> **İncelenen branch:** `feat/mobile-konum-analiz-alanlari`
> **Kapsam kaynağı:** Kullanıcının paylaştığı son mobil gereksinim listesi (`R-1`–`R-78`)

Bu raporda yalnızca son paylaşılan 78 mobil gereksinim kabul kapsamı olarak
alınmıştır. Repodaki eski `M1`–`M5` veya `W1`–`W7` kapsamları, bu durum
değerlendirmesinde ölçüt olarak kullanılmamıştır.

## 1. Durum özeti

| Durum | Adet | Toplam içindeki oran |
|---|---:|---:|
| ✅ Yapıldı | **20** | **%25,6** |
| 🟡 Yarım yapıldı | **22** | **%28,2** |
| ❌ Yapılmadı | **36** | **%46,2** |
| **Toplam** | **78** | **%100** |

Tam veya kısmi olarak ele alınmış gereksinim sayısı **42/78 (%53,8)**'dır.
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
| **R-13** | Profil | Kullanıcı öğrenci, uzaktan çalışan, çocuklu aile ve emekli hazır profillerinden birini seçebilmelidir. | Dört persona backend'den alınıyor ve onboarding ekranında seçilebiliyor. |
| **R-14** | Profil | Hazır profil seçildiğinde ilgili yaşam kriterleri ve başlangıç önem seviyeleri otomatik gösterilmelidir. | Persona `categoryWeights` verisi ağırlığa göre sıralanıyor; kriterler ve başlangıçtaki göreli önem yüzdeleri onboarding ve profil editöründe gösteriliyor. |
| **R-16** | Tercihler | Kullanıcı yaşam kriterlerinin önem sırasını sürükle-bırakla değiştirebilmelidir. | Sekiz yaşam kriteri yeniden sıralanabilir listede sürükle-bırakla değiştirilebiliyor. |
| **R-19** | Özel Konumlar | Kullanıcı iş yeri, okul, üniversite, spor salonu veya aile evi gibi bir veya birden fazla özel konum tanımlayabilmelidir. | Kullanıcı serbest etiketle en fazla üç anchor ekleyebiliyor. |
| **R-20** | Özel Konumlar | Kullanıcı özel konumu haritadan seçebilmeli veya adres aramasıyla ekleyebilmelidir. | Gereksinimdeki alternatiflerden haritadan nokta seçme yöntemi çalışıyor. |
| **R-21** | Özel Konumlar | Kullanıcı özel konumlara isim verebilmeli, silebilmeli ve önem seviyelerini belirleyebilmelidir. | Konum etiketi, silme ve sürükle-bırakla öncelik/ağırlık sıralaması bulunuyor. |
| **R-24** | Ana Menü | Kullanıcının bulunduğu aktif ekran alt menüde ayırt edilebilir şekilde gösterilmelidir. | Flutter `NavigationBar` seçili sekmeyi farklı renk ve ikonla gösteriyor. |
| **R-26** | Harita | Kullanıcı harita üzerinde yakınlaştırma, uzaklaştırma ve sürükleme işlemleri yapabilmelidir. | MapLibre'ın yakınlaştırma ve kaydırma hareketleri aktiftir. |
| **R-58** | Kullanıcı İşlemleri | Kullanıcı Profilim ekranından hesabından çıkış yapabilmelidir. | Profil ekranındaki “Çıkış yap” işlemi oturumu kapatıyor. |
| **R-62** | Oturum Güvenliği | Kullanıcı çıkış yaptıktan sonra hesabına özel ekranlara yetkisiz erişim sağlanamamalıdır. | Güvenli depodaki oturum siliniyor, uygulama guest aşamasına dönüyor ve korumalı API endpoint'leri JWT istiyor. |
| **R-70** | Sistem Yapısı | Mobil kullanıcı arayüzü, Backend ve Data bileşenleri birbirinden ayrılmış geliştirilebilir yapıda olmalıdır. | Mobilde `core/features`, backend'de Application/Domain/Infrastructure/API katmanları ayrılmıştır. |

## 3. Yarım yapılan gereksinimler

| ID | Alt modül | Gereksinim | Yapılan bölüm | Eksik bölüm |
|---|---|---|---|---|
| **R-3** | Kayıt Ol | Kullanıcı ad, soyad, e-posta ve şifre bilgileriyle hesap oluşturabilmelidir. | Kayıt e-posta/parola ile tamamlanıyor; hemen sonraki profil adımı ad ve soyadı ayrı ve zorunlu alıp backend'e kaydediyor. | Ad ve soyad henüz doğrudan hesap kayıt isteğinin parçası değil. |
| **R-11** | Misafir Kullanıcı | Misafir kiralık konutları ve temel bilgilerini inceleyebilmeli; hesap gerektiren işlemlerde giriş/kayıt ekranına yönlendirilmelidir. | Misafir haritaya erişiyor; kilitli kişiselleştirme işlemlerinde Giriş Yap/Kayıt Ol çağrıları gösteriliyor. | Mobil haritada kiralık konut noktaları ve temel konut bilgi kartları henüz yok. |
| **R-15** | Tercihler | Kullanıcı ulaşım, sağlık, eğitim, sosyal yaşam, günlük ihtiyaçlar, yeşil alan ve spor kriterlerinin önem seviyelerini belirleyebilmelidir. | Bütün kriterler listeleniyor ve kullanıcının sırasından göreli önem yüzdeleri üretiliyor. | Her kriter için sıradan bağımsız ayrı bir seviye/ağırlık kontrolü yok. |
| **R-17** | Tercihler | Yaşam kriterlerindeki değişiklikler kaydedilmeli ve konut uygunluk skorunda kullanılmalıdır. | Sıralama `PUT /profile` ile `UserProfileCategoryOrders` tablosuna kaydediliyor ve web ile aynı profilden geri okunuyor. | Konut skorlama motoru kaydedilen sıralamayı henüz skora uygulamıyor. |
| **R-18** | Bütçe | Kullanıcı aylık kira bütçesini belirleyebilmeli ve bu bilgi konut uygunluk skorunda kullanılmalıdır. | Minimum–maksimum kira aralığı onboarding ve profil ekranından kaydedilip güncellenebiliyor. | Yeni skorlama servisi kira aralığını henüz skora uygulamıyor. |
| **R-22** | Profil | Profil ekranında profil bilgileri, bütçe, tercihler ve özel konumlar görüntülenip güncellenebilmelidir. | Ad, soyad, persona, bütçe ve yaşam kriterleri görüntülenip profil editöründen güncellenebiliyor; özel konum sayısı gösteriliyor ve Konumlar sekmesinden yönetiliyor. | Yaş/cinsiyet/çalışma/medeni hâl alanları ile profil ekranı içinde doğrudan özel konum düzenleme yok. |
| **R-23** | Ana Menü | Alt menüden Harita, Rotalarım, Favorilerim ve Profilim ekranlarına geçilebilmelidir. | Harita, Konumlar ve Profil sekmeleri bulunuyor. | Rotalarım ve Favorilerim sekmeleri yok; Konumlar sekmesi gereksinimdeki menüden farklıdır. |
| **R-25** | Harita | Ana harita ekranında Ankara Çankaya bölgesi ve proje kapsamındaki kiralık konutlar gösterilmelidir. | Çankaya vektör haritası gösteriliyor. | Kiralık konut noktaları/listesi gösterilmiyor. |
| **R-27** | Harita | Konut ve POI gösterimleri yakınlaştırma seviyesine göre düzenlenmeli; uzak görünümde gizlenmeli/gruplanmalı, yakında detaylanmalıdır. | Bina katmanı yalnızca yüksek zoom seviyesinde açılıyor. | Konut ve POI katmanları, clustering ve detay seviyeleri yok. |
| **R-35** | Uygunluk Skoru | Profil, bütçe, tercihler, özel konumlar ve çevre analiziyle kişiselleştirilmiş konut uygunluk skoru oluşturulmalıdır. | Backend'e POI erişim süreleri ve persona ağırlıklarından 0–100 skor üreten servis, endpoint ve cache eklendi. | Kaydedilen kriter sırası, kira aralığı ve özel konumlar hesaplamaya katılmıyor; mobil skor entegrasyonu yok. |
| **R-38** | Erişim Analizi | Konut ile çevresindeki hizmet noktaları arasındaki mesafe ve erişim süresi gösterilmelidir. | Kullanıcının haritadan veya aramadan seçtiği nokta çevresinde 0,5–5 km analiz alanı ile 5–30 dakikalık yaklaşık yürüme erişim alanı jeodezik poligon olarak gösteriliyor. | Kiralık konut ve POI seçimi ile her hizmet noktası için gerçek yol mesafesi/erişim süresi verisi ve sonuç listesi henüz yok. |
| **R-59** | Şifre Güvenliği | Şifre en az 8 karakter; büyük harf, küçük harf, rakam ve özel karakter içermelidir. | Mobil form minimum 8 karakteri kontrol ediyor. | Büyük/küçük harf, rakam ve özel karakter kuralları mobilde ve backend'de uygulanmıyor. |
| **R-60** | Yetkilendirme | Kullanıcı yalnızca kendi profil, tercih, favori ve kayıtlı rota bilgilerine erişebilmelidir. | Profil ve anchor endpoint'leri JWT kullanıcısına göre veri döndürüyor. | Tercih, favori ve rota kaynakları henüz bulunmuyor. |
| **R-63** | Performans | Harita, konut, rota ve detay ekranları kullanıcıyı uzun süre bekletmeden yüklenmelidir. | Mevcut harita ve profil ekranları çalışır durumda. | Konut/rota/detay ekranları yok; ölçülmüş performans kabul testi bulunmuyor. |
| **R-64** | CBS Performansı | Haritada kullanılan konut, POI ve rota verileri performanslı ve zoom seviyesine göre optimize edilmelidir. | Vektör tile kullanılıyor; bina katmanında `minzoom` uygulanıyor. | Konut, POI ve rota katmanları/optimizasyonları yok. |
| **R-65** | Veri Tutarlılığı | Profil, tercih, favori, skor ve rota bilgileri güncel ve web uygulamasıyla tutarlı olmalıdır. | Mobil profil, persona, kriter sırası ve anchor verileri web ile aynı API ve veritabanını kullanıyor. | Favori, skor ve rota mobil zinciri tamamlanmadı. |
| **R-66** | Kişisel Veri Gizliliği | Yalnızca gerekli kişisel bilgiler alınmalı ve kullanım amacı belirtilmelidir. | Uygulama şu an sınırlı kullanıcı verisi topluyor. | Gizlilik metni, açık amaç bildirimi ve onay akışı yok. |
| **R-68** | Hata Yönetimi | Veri, bağlantı, GPS veya servis hatalarında anlaşılır mesaj gösterilmeli ve uygulamanın tamamı kullanılamaz olmamalıdır. | API timeout, bağlantı ve iş kuralı hataları kullanıcı mesajlarına çevriliyor. | Tile/harita, GPS ve ilerideki rota servisleri için merkezi hata/fallback yönetimi yok. |
| **R-69** | Kullanılabilirlik | Temel işlemler kolay anlaşılmalı ve arayüz farklı hedef ekran boyutlarında bozulmamalıdır. | SafeArea, kaydırma, küçük ekran ve klavye taşması düzeltmeleri bulunuyor. | Birden fazla cihaz boyutu için kapsamlı responsive/golden test matrisi yok. |
| **R-71** | Entegrasyon | Kullanıcı, profil, konut, POI, skor, favori ve rota bilgileri Backend üzerinden erişilmelidir. | Kullanıcı, oturum, persona, profil ve anchor entegrasyonu gerçek API ile çalışıyor; konut skoru için ilk backend endpoint'i eklendi. | Konut/skor mobil zinciri ile POI, favori ve rota entegrasyonları tamamlanmadı. |
| **R-73** | Veri Gereksinimi | Konut, uygunluk skoru, çevre analizi ve rota bilgilerinin görüntülenmesi için gerekli veriler sistemde bulunmalıdır. | Veritabanında sentetik konutlar, POI'ler, erişim matrisi ve ilk skor/cache modeli bulunuyor; mobilde seçilen nokta için temel analiz/yürüme alanı gösteriliyor. | Rota verisi/servisleri tamamlanmadı; mobil henüz gerçek konut, POI erişim analizi ve skor verilerini görüntülemiyor. |
| **R-74** | Bağlantı | İnternet/servis bağlantısı yokken çevrimiçi işlemler yapılmamalı ve kullanıcı bilgilendirilmelidir. | API bağlantı hatalarında kullanıcıya sunucuya ulaşılamadığı bildiriliyor. | Harita tile, konut, rota ve navigasyon için ortak çevrimdışı durum ekranı yok. |

## 4. Yapılmayan gereksinimler

| ID | Alt modül | Gereksinim | Eksik durum |
|---|---|---|---|
| **R-12** | Profil | Kullanıcı yaş, cinsiyet, çalışma durumu ve medeni hâl bilgileriyle profil oluşturabilmelidir. | Bu alanlar modelde, API'de ve mobil formda yok. |
| **R-28** | Konum | Konum izni açıkken kullanıcının GPS konumu haritada gösterilmelidir. | Konum paketi, izin akışı ve GPS işaretçisi yok. |
| **R-29** | POI Katmanları | Market, eczane, sağlık, eğitim, toplu taşıma, restoran/kafe, park/yeşil alan ve spor POI katmanları ayrı ayrı açılıp kapatılabilmelidir. | POI katmanları ve filtre kontrolleri yok. |
| **R-30** | POI Katmanları | Aynı anda birden fazla POI kategorisi haritada görüntülenebilmelidir. | POI gösterimi yok. |
| **R-31** | POI Detayı | Bir hizmet noktasına dokununca adı, kategorisi ve temel bilgileri gösterilmelidir. | POI etkileşimi/detayı yok. |
| **R-32** | Konut | Haritadan kiralık konut seçilerek konut detay ekranına geçilebilmelidir. | Konut katmanı ve detay sayfası yok. |
| **R-33** | Konut Detayı | Fotoğraf, kira, mahalle, oda, metrekare, asansör, otopark, bina katı ve konut katı bilgileri gösterilmelidir. | Konut modeli/API/UI zinciri mobilde yok. |
| **R-34** | Konut Detayı | Seçilen konutun konumu haritada gösterilmelidir. | Konut detay haritası yok. |
| **R-36** | Uygunluk Skoru | Kullanıcı toplam uygunluk skorunu ve kriterlere ait alt skorları görüntüleyebilmelidir. | Toplam/alt skor modeli ve ekranı yok. |
| **R-37** | Skor Açıklaması | Sistem konutun kullanıcı açısından güçlü yönlerini ve dikkat edilmesi gereken noktalarını gösterebilmelidir. | Skor açıklaması, güçlü/zayıf yönler ve gerekçe ekranı yok. |
| **R-39** | Özel Konum Analizi | Konut ile kullanıcının kayıtlı özel konumları arasındaki tahmini mesafe ve ulaşım süresi gösterilmelidir. | Konut-anchor analiz servisi ve ekranı yok. |
| **R-40** | Favoriler | Konut favorilere eklenebilmeli ve favorilerden çıkarılabilmelidir. | Favori modeli, endpoint'i ve UI yok. |
| **R-41** | Favoriler | Favorilerim ekranında kayıtlı konutlar görüntülenmeli ve detaylarına ulaşılabilmelidir. | Favoriler ekranı yok. |
| **R-42** | Favoriler | Favorilerdeki konutlar ziyaret rotasına eklenebilmelidir. | Favori ve rota seçimi yok. |
| **R-43** | Rota Optimizasyonu | Sistem seçilen konutların mesafe ve sürelerine göre uygun ziyaret sırası oluşturmalıdır. | TSP/rota endpoint'i ve mobil akış yok. |
| **R-44** | Rota | Oluşturulan rota haritada; ziyaret sırası, toplam mesafe ve tahmini toplam süreyle gösterilmelidir. | Rota haritası ve özeti yok. |
| **R-45** | Rota | Kullanıcı rotadan bir konut çıkarabilmeli ve rota kalan konutlara göre yeniden oluşturulmalıdır. | Rota düzenleme yok. |
| **R-46** | Rota | Kullanıcı oluşturduğu ziyaret rotasını hesabına kaydedebilmelidir. | Rota kaydetme yok. |
| **R-47** | Rotalarım | Kullanıcı kayıtlı ziyaret rotalarını Rotalarım ekranında görüntüleyebilmelidir. | Rotalarım ekranı yok. |
| **R-48** | Rotalarım | Kayıtlı rota için rota adı, konut sayısı, toplam mesafe ve tahmini toplam süre gösterilmelidir. | Kayıtlı rota modeli ve kartı yok. |
| **R-49** | Rotalarım | Kayıtlı rotanın detayları ve konutların ziyaret sırası haritada gösterilmelidir. | Rota detay haritası yok. |
| **R-50** | Rotalarım | Kullanıcı kayıtlı rotayı silebilmelidir. | Rota silme yok. |
| **R-51** | Navigasyon | Kullanıcı seçtiği ziyaret rotası için navigasyonu başlatabilmelidir. | Navigasyon modülü yok. |
| **R-52** | Navigasyon | Navigasyon öncesi konum izni kontrol edilmeli, izin kapalıysa uyarı gösterilmelidir. | Konum izni/navigasyon başlangıcı yok. |
| **R-53** | Navigasyon | Navigasyon sırasında GPS konumu ve oluşturulan ziyaret rotası haritada gösterilmelidir. | Canlı GPS ve rota çizgisi yok. |
| **R-54** | Navigasyon | Sıradaki konut, temel manevra bilgisi ve manevraya kalan mesafe gösterilmelidir. | Manevra/adım listesi yok. |
| **R-55** | Navigasyon | Kullanıcı rotadan belirlenen mesafeden fazla uzaklaşınca sapma uyarısı gösterilmelidir. | Sapma algılama yok. |
| **R-56** | Ziyaret Takibi | Ulaşılan konut “Ziyaret Ettim” ile işaretlenmeli ve rota ilerlemesi güncellenmelidir. | Ziyaret işaretleme yok. |
| **R-57** | Ziyaret Takibi | Ziyaretten sonra sıradaki konuta yönlendirilmeli; tümü tamamlanınca rota tamamlandı bildirimi gösterilmelidir. | Ziyaret ilerleme akışı yok. |
| **R-61** | Skor Tutarlılığı | Aynı profil, tercihler ve konut için aynı koşullarda aynı uygunluk skoru gösterilmelidir. | Skorlama motoru ve cache eklendi; ancak mobilde skor gösterimi ve aynı koşul sonucunu doğrulayan anlamlı bir determinizm testi yok. |
| **R-67** | Konum Gizliliği | Mevcut konum yalnızca izin alındıktan sonra harita ve navigasyon amacıyla kullanılmalıdır. | GPS/konum izni özelliği yok. |
| **R-72** | Geliştirilebilirlik | Mobil uygulama ileride farklı ilçe veya bölgelerin eklenmesine uygun geliştirilmelidir. | Harita merkezi, stil ve sınıf isimleri Çankaya'ya sabitlenmiş durumda. |
| **R-75** | Paylaşım | Seçilen konut veya ziyaret rotası paylaşılabilir bağlantıyla cihaz uygulamalarında paylaşılabilmelidir. | Deep link/share özelliği yok. |
| **R-76** | Kullanıcı Puanlaması | Giriş yapan kullanıcı konuta puan verebilmeli ve önceki puanını değiştirebilmelidir. | Kullanıcı puanı modeli, endpoint'i ve ekranı yok. |
| **R-77** | Kullanıcı Puanlaması | Kullanıcı puanı, sistemin kişiselleştirilmiş uygunluk skorundan ayrı gösterilmelidir. | Konut puanı ve uygunluk skoru gösterimi yok. |
| **R-78** | Offline Kullanım | İnternet yokken cihazda saklanan favori konutların temel bilgileri gösterilmeli; çevrimiçi gereken işlemler için kullanıcı bilgilendirilmelidir. | Favori cache'i ve offline kullanım desteği yok. |

## 5. Kodda doğrulanan başlıca karşılıklar

- Açılış ve oturum aşamaları: [`mobile/lib/app/app.dart`](../mobile/lib/app/app.dart)
- Giriş/kayıt/şifre yenileme akışları: [`mobile/lib/features/auth/presentation/pages`](../mobile/lib/features/auth/presentation/pages)
- Oturum, profil ve hata yönetimi: [`mobile/lib/features/auth/application/session_controller.dart`](../mobile/lib/features/auth/application/session_controller.dart)
- Güvenli token saklama: [`mobile/lib/core/storage/token_store.dart`](../mobile/lib/core/storage/token_store.dart)
- Profil, bütçe ve tercih düzenleme: [`mobile/lib/features/home/presentation/pages/home_page.dart`](../mobile/lib/features/home/presentation/pages/home_page.dart)
- Persona/profil/tercih onboarding: [`mobile/lib/features/onboarding/presentation/pages/onboarding_page.dart`](../mobile/lib/features/onboarding/presentation/pages/onboarding_page.dart)
- Yaşam kriteri sıralama modeli ve bileşeni: [`mobile/lib/features/preferences`](../mobile/lib/features/preferences)
- Özel konum ekleme/silme/sıralama: [`mobile/lib/features/anchors/presentation/pages/anchor_manager_page.dart`](../mobile/lib/features/anchors/presentation/pages/anchor_manager_page.dart)
- Konum analizi hesabı ve kontrolleri: [`mobile/lib/features/location_analysis`](../mobile/lib/features/location_analysis)
- Çankaya MapLibre haritası: [`mobile/lib/features/map/presentation/widgets/cankaya_map.dart`](../mobile/lib/features/map/presentation/widgets/cankaya_map.dart)
- Mobil API istemcisi: [`mobile/lib/core/network/api_client.dart`](../mobile/lib/core/network/api_client.dart)
- Backend auth endpoint'leri: [`api/src/Vivido.Api/controllers/AuthController.cs`](../api/src/Vivido.Api/controllers/AuthController.cs)
- Backend profil/anchor endpoint'leri: [`api/src/Vivido.Api/controllers/ProfilesController.cs`](../api/src/Vivido.Api/controllers/ProfilesController.cs), [`api/src/Vivido.Api/controllers/AnchorsController.cs`](../api/src/Vivido.Api/controllers/AnchorsController.cs)

## 6. Öncelikli eksik özellik sırası

Bağımlılıklar dikkate alındığında önerilen geliştirme sırası:

1. **Konut ve skor zinciri:** R-25, R-27, R-32–R-39, R-61, R-73; kaydedilen kriter sırası R-17 kapsamında skora bağlanmalı
2. **Profil tamamlamaları:** R-3, R-12, R-15, R-22
3. **POI ve GPS:** R-28–R-31, R-38, R-67
4. **Favoriler:** R-40–R-42
5. **Rota ve Rotalarım:** R-43–R-50
6. **Navigasyon ve ziyaret takibi:** R-51–R-57
7. **Misafir/güvenlik/gizlilik/offline tamamlamaları:** R-11, R-59, R-66, R-74–R-78
