-- Schema do banco D1 da transmissão (cbbc-quadra-live).
-- Rode uma vez após criar o banco:
--   npx wrangler d1 execute cbbc-quadra-live --remote --file=schema.sql

CREATE TABLE IF NOT EXISTS sessions (
  id          TEXT PRIMARY KEY,
  state_json  TEXT NOT NULL,
  write_token TEXT NOT NULL,
  updated_at  INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_updated ON sessions(updated_at);
