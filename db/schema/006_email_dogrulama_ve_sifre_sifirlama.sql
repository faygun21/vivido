-- ══════════════════════════════════════════════════════════════════════
--  004 — E-posta doğrulama ve şifre sıfırlama
--
--  Kaynak: docs/02-KARARLAR.md K-09
--
--  ⚠️ K-02 gereği bu dosya bir kez uygulandıktan SONRA DÜZENLENMEZ.
--  Değişiklik gerekirse 005_*.sql açın — migrate.sh checksum'ı tutmazsa
--  exit 2 ile durur.
--
--  Uygulama:  pnpm db:migrate
-- ══════════════════════════════════════════════════════════════════════


-- ─── 1. Kullanıcı e-postası doğrulandı mı? ───
--
-- NULL  → doğrulanmamış. Giriş 403 EMAIL_NOT_VERIFIED ile reddedilir.
-- dolu  → doğrulanmış, hesap tam yetkili.
--
-- Sütun NULL kabul ediyor çünkü bu şema zaten dolu veritabanlarına da
-- uygulanacak; var olan kullanıcılar aşağıda toplu olarak doğrulanmış
-- sayılıyor (geriye dönük kilitlenme olmasın).
ALTER TABLE users ADD COLUMN email_verified_at timestamptz;

-- Bu göç öncesinde açılmış hesapların doğrulama şansı hiç olmadı;
-- onları kilitlemek mevcut demo hesaplarını kullanılamaz hale getirirdi.
UPDATE users SET email_verified_at = created_at WHERE email_verified_at IS NULL;

COMMENT ON COLUMN users.email_verified_at IS
  'NULL ise e-posta dogrulanmamis; login 403 EMAIL_NOT_VERIFIED doner (K-09).';


-- ─── 2. Tek kullanımlık kodlar ───
--
-- Hem e-posta doğrulama hem şifre sıfırlama AYNI tabloda tutuluyor.
-- İki tablo yerine tek tablo + `purpose` sütunu: alanlar birebir aynı
-- (kod, son kullanma, tüketildi mi, kaç kez yanlış denendi) ve doğrulama
-- mantığı tek yerde yaşıyor. Ayırmak iki nüsha kod demekti.
--
-- ⚠️ Ham kod ASLA saklanmaz — refresh_tokens ile aynı kural. Veritabanı
-- sızarsa kodla şifre sıfırlanabilir olurdu.
CREATE TABLE auth_codes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  purpose     text NOT NULL CHECK (purpose IN ('email_verify', 'password_reset')),

  -- SHA-256(kod + ':' + user_id). Kullanıcı kimliği tuz olarak giriyor:
  -- aksi halde 6 haneli kodun 1.000.000 hash'lik gökkuşağı tablosu
  -- saniyeler içinde üretilebilirdi.
  code_hash   text NOT NULL,

  expires_at  timestamptz NOT NULL,
  consumed_at timestamptz,

  -- Kaba kuvvet koruması: 6 hane = 1.000.000 olasılık, ama sınırsız
  -- deneme hakkı olsaydı bu koruma değil süsleme olurdu.
  attempts    smallint NOT NULL DEFAULT 0,

  created_at  timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT ck_auth_code_omru CHECK (expires_at > created_at)
);

-- Doğrulama sorgusu her zaman "bu kullanıcının bu amaçla ürettiği EN SON
-- kodu" arıyor — indeks bu erişim desenine göre.
CREATE INDEX idx_auth_codes_lookup
  ON auth_codes (user_id, purpose, created_at DESC);

-- Süresi geçmiş kodların temizliği için (henüz zamanlanmış iş yok,
-- elle `DELETE FROM auth_codes WHERE expires_at < now()` çalıştırılabilir).
CREATE INDEX idx_auth_codes_expiry ON auth_codes (expires_at);

COMMENT ON TABLE auth_codes IS
  'Tek kullanimlik 6 haneli kodlar (e-posta dogrulama + sifre sifirlama). Ham kod saklanmaz, SHA-256 hash tutulur.';
