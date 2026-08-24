-- Staging veritabanı eski migrate.sh davranışı yüzünden 005 ve 007
-- dosyalarını çalıştırmadan uygulanmış işaretleyebiliyordu. Migration defteri
-- gerçeği yansıtmadığı için aynı dosyaları yeniden çalıştırmak çözüm değil;
-- yeni, idempotent bir uzlaştırma migrationı eksik profil nesnelerini kurar.

ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS first_name TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS last_name TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS min_monthly_budget NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS max_monthly_budget NUMERIC(10,2);

-- Bazı eski kurulumlarda tek bütçe sütunu hâlâ bulunabilir. Veri kaybolmadan
-- yeni aralığın üst sınırına taşınır; sütun yoksa bu blok hiçbir şey yapmaz.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'user_profiles'
          AND column_name = 'monthly_budget'
    ) THEN
        EXECUTE '
            UPDATE user_profiles
            SET max_monthly_budget = monthly_budget
            WHERE max_monthly_budget IS NULL
              AND monthly_budget IS NOT NULL';
        EXECUTE 'ALTER TABLE user_profiles DROP COLUMN monthly_budget';
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'user_profiles'::regclass
          AND conname = 'ck_user_profiles_budget_range'
    ) THEN
        ALTER TABLE user_profiles
            ADD CONSTRAINT ck_user_profiles_budget_range
            CHECK (
                min_monthly_budget IS NULL
                OR max_monthly_budget IS NULL
                OR min_monthly_budget <= max_monthly_budget
            );
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS user_profile_category_order (
    profile_id UUID NOT NULL
        REFERENCES user_profiles(id)
        ON DELETE CASCADE,
    category_code TEXT NOT NULL
        REFERENCES poi_categories(code)
        ON DELETE CASCADE,
    priority SMALLINT NOT NULL
        CHECK (priority BETWEEN 1 AND 8),
    PRIMARY KEY (profile_id, category_code),
    UNIQUE (profile_id, priority)
        DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX IF NOT EXISTS idx_profile_category_order_profile
    ON user_profile_category_order(profile_id, priority);

COMMENT ON TABLE user_profile_category_order IS
    'Kullanıcının yaşam kriterleri için kişisel önem sırası.';
