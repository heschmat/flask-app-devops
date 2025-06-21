CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  first_name VARCHAR(50),
  last_name VARCHAR(50),
  joined_at TIMESTAMP NOT NULL,
  is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS checkins (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  created_at TIMESTAMP DEFAULT now(),
  cooldown_minutes INTEGER DEFAULT 1
);
