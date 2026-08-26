-- ══════════════════════════════════════════════════════════════════════
--  Vivido — rotaya planlanan ziyaret zamanı
--
--  NEDEN VAR
--  Kullanıcı bir ziyaret rotası kurduğunda "bunu ne zaman gezeceğim"
--  bilgisini de saklamak istiyor: kayıtlı rotalar listesi artık
--  "Cumartesi 14:00" gibi bir plan gösterebiliyor.
--
--  NULL SERBEST — bilerek. Zaman girmek ZORUNLU değil; kullanıcı yalnızca
--  rotayı kaydedip tarihi sonra düşünebilir. Zorunlu yapmak, kaydetmenin
--  önüne gereksiz bir adım koyardı.
--
--  ⚠️ BU SÜTUN TEK BAŞINA BİLDİRİM GÖNDERMEZ.
--  Mobil bildirim ayrı ve çok daha büyük bir iş: FCM projesi, cihaz token
--  tablosu, sunucuda zamanlanmış iş altyapısı (projede hiç yok) ve mobilde
--  henüz var olmayan rota ekranı. Bu sütun o işin ÖN KOŞULU olarak duruyor;
--  bildirim geldiğinde şema yeniden değişmek zorunda kalmasın.
--  Kapsam kaydı: backlog/v2.md.
--
--  timestamptz: kullanıcı Türkiye'de ama saat dilimi taşımayan bir sütun,
--  ileride sunucu UTC'ye geçtiğinde sessizce kayardı.
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE routes
    ADD COLUMN IF NOT EXISTS scheduled_at timestamptz;

COMMENT ON COLUMN routes.scheduled_at IS
  'Kullanicinin bu rotayi gezmeyi planladigi an. NULL = plan girilmedi. Bildirim gondermez.';
