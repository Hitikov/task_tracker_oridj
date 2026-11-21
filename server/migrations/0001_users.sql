-- Первая миграция этапа 1: расширение `citext` (email нечувствителен к регистру)
-- и таблица `users` по архитектуре (docs/architecture.md, схема БД этапа 1).

-- citext делает UNIQUE на email нечувствительным к регистру.
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email CITEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
