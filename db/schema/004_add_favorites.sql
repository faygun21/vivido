-- Favori konutları tutacağımız tablo
CREATE TABLE favorite_properties (
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  property_id   bigint NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, property_id)
);

-- Hızlı sorgular için indeks
CREATE INDEX idx_favorite_user ON favorite_properties (user_id, created_at DESC);