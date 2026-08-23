-- Kullanıcının yaşam kriterleri için kişisel önem sırası.
--
-- Persona'nın varsayılan ağırlıkları persona_category_weights tablosunda kalır.
-- Kullanıcı sıralamayı değiştirdiğinde yalnızca kişisel sıra burada saklanır.
--
-- Ağırlıklar priority değerinden uygulama tarafından hesaplanır.

CREATE TABLE user_profile_category_order (
    profile_id uuid NOT NULL
        REFERENCES user_profiles(id)
        ON DELETE CASCADE,

    category_code text NOT NULL
        REFERENCES poi_categories(code)
        ON DELETE CASCADE,

    priority smallint NOT NULL
        CHECK (priority BETWEEN 1 AND 8),

    PRIMARY KEY (profile_id, category_code),

    UNIQUE (profile_id, priority)
        DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX idx_profile_category_order_profile
    ON user_profile_category_order(profile_id, priority);

COMMENT ON TABLE user_profile_category_order IS
    'Kullanıcının yaşam kriterleri için kişisel önem sırası.';