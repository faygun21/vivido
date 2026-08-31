-- Kullanıcının bir konut hakkında yalnızca kendisinin görebildiği kişisel not.
-- CREATE IF NOT EXISTS: bazı yerel DB'lerde eski feature denemesinden aynı
-- tablo kalmış olabilir; mevcut veriyi ve constraint'leri korur.
CREATE TABLE IF NOT EXISTS property_notes (
  id          uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  property_id bigint        NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  note        varchar(1000) NOT NULL,
  created_at  timestamptz   NOT NULL DEFAULT now(),
  updated_at  timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT uq_property_notes_user_property UNIQUE (user_id, property_id)
);

COMMENT ON TABLE property_notes IS
  'Kullanicinin bir konut icin kendine ozel notu. Kullanici ve konut basina tek kayit.';
