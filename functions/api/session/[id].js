// Rotas da sessão por id:
//   GET    /api/session/:id  → viewer lê o estado  { state, updated_at, age_ms }
//   POST   /api/session/:id  → tablet atualiza estado (exige write_token)
//   DELETE /api/session/:id  → tablet encerra a sessão (exige write_token)

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

export function onRequestOptions() {
  return new Response(null, { status: 204, headers: CORS });
}

export async function onRequestGet({ env, params }) {
  const row = await env.DB.prepare(
    'SELECT state_json, updated_at FROM sessions WHERE id = ?1'
  )
    .bind(params.id)
    .first();
  if (!row) return json({ error: 'not_found' }, 404);
  let state = {};
  try {
    state = JSON.parse(row.state_json);
  } catch (_) {
    state = {};
  }
  // age_ms é calculado AQUI (relógio do servidor): o viewer o usa pra
  // detectar tablet sem transmitir, imune a relógio errado do espectador.
  const updatedAt = row.updated_at ?? null;
  return json({
    state,
    updated_at: updatedAt,
    age_ms: updatedAt == null ? null : Math.max(0, Date.now() - updatedAt),
  });
}

export async function onRequestPost({ env, params, request }) {
  const body = await request.json().catch(() => ({}));
  const row = await env.DB.prepare('SELECT write_token FROM sessions WHERE id = ?1')
    .bind(params.id)
    .first();
  if (!row) return json({ error: 'not_found' }, 404);
  if (!body.write_token || body.write_token !== row.write_token) {
    return json({ error: 'forbidden' }, 403);
  }
  await env.DB.prepare('UPDATE sessions SET state_json = ?1, updated_at = ?2 WHERE id = ?3')
    .bind(JSON.stringify(body.state ?? {}), Date.now(), params.id)
    .run();
  return json({ ok: true });
}

export async function onRequestDelete({ env, params, request }) {
  const body = await request.json().catch(() => ({}));
  const row = await env.DB.prepare('SELECT write_token FROM sessions WHERE id = ?1')
    .bind(params.id)
    .first();
  if (!row) return json({ ok: true }); // já não existe — idempotente
  if (!body.write_token || body.write_token !== row.write_token) {
    return json({ error: 'forbidden' }, 403);
  }
  await env.DB.prepare('DELETE FROM sessions WHERE id = ?1').bind(params.id).run();
  return json({ ok: true });
}
