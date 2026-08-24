ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS min_monthly_budget NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS max_monthly_budget NUMERIC(10,2);

-- Eski tek bütçe değeri varsa kaybolmasın.
-- Eski değer maksimum bütçeye aktarılır.
UPDATE user_profiles
SET max_monthly_budget = monthly_budget
WHERE max_monthly_budget IS NULL
  AND monthly_budget IS NOT NULL;

ALTER TABLE user_profiles
    DROP COLUMN IF EXISTS monthly_budget;

ALTER TABLE user_profiles
    ADD CONSTRAINT ck_user_profiles_budget_range
    CHECK (
        min_monthly_budget IS NULL
        OR max_monthly_budget IS NULL
        OR min_monthly_budget <= max_monthly_budget
    );