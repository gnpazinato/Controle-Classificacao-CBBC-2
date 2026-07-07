// POST /api/session — cria uma sessão de transmissão e devolve {id, write_token}.
//
// Regras:
// - o link é **por tablet**: o app guarda {id, write_token} e reutiliza a
//   mesma sessão em todas as partidas, então este POST só roda quando o
//   tablet ainda não tem sessão (ou quando a dele expirou);
// - sessões sem atividade há mais de 24h são removidas antes da contagem —
//   com jogos de manhã à noite, o mesmo link dura a semana inteira da
//   competição e só expira quando ela termina;
// - máximo de 6 sessões ativas: 3 quadras simultâneas + margem para
//   sessões de tablets trocados/reinstalados que ainda não expiraram;
// - id = código de 5 caracteres legível (sem 0/o/1/l/i pra evitar confusão).

const ALPHABET = '23456789abcdefghjkmnpqrstuvwxyz';
const MAX_SESSIONS = 6;
const TTL_MS = 24 * 60 * 60 * 1000; // 24 horas

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,DELETE,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', ...CORS },
  });
}

function newCode() {
  const bytes = new Uint8Array(5);
  crypto.getRandomValues(bytes);
  let s = '';
  for (let i = 0; i < 5; i++) s += ALPHABET[bytes[i] % ALPHABET.length];
  return s;
}

export function onRequestOptions() {
  return new Response(null, { status: 204, headers: CORS });
}

export async function onRequestPost({ env }) {
  const now = Date.now();
  await env.DB.prepare('DELETE FROM sessions WHERE updated_at < ?1')
    .bind(now - TTL_MS)
    .run();

  const countRow = await env.DB.prepare('SELECT COUNT(*) AS c FROM sessions').first();
  if (countRow && countRow.c >= MAX_SESSIONS) {
    return json({ error: 'max_sessions' }, 429);
  }

  let id = newCode();
  for (let i = 0; i < 5; i++) {
    const exists = await env.DB.prepare('SELECT 1 FROM sessions WHERE id = ?1').bind(id).first();
    if (!exists) break;
    id = newCode();
  }

  const writeToken = crypto.randomUUID();
  await env.DB.prepare(
    'INSERT INTO sessions (id, state_json, write_token, updated_at) VALUES (?1, ?2, ?3, ?4)'
  )
    .bind(id, '{}', writeToken, now)
    .run();

  return json({ id, write_token: writeToken });
}
