ALTER TABLE user_profiles
ADD COLUMN first_name text NOT NULL DEFAULT '',
ADD COLUMN last_name text NOT NULL DEFAULT '';