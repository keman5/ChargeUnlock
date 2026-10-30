const MAX_BODY = 96 * 1024;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

function string(value, maximum, minimum = 0) {
  if (typeof value !== 'string' || value.length < minimum || value.length > maximum) throw new Error('invalid field');
  return value;
}
function boolean(value) {
  if (typeof value !== 'boolean') throw new Error('invalid boolean');
  return value;
}
function integer(value, min, max) {
  if (!Number.isInteger(value) || value < min || value > max) throw new Error('invalid number');
  return value;
}
function date(value) {
  string(value, 40, 10);
  if (!Number.isFinite(Date.parse(value))) throw new Error('invalid date');
  return value;
}
function state(value) {
  return {
    batteryPercent: value.batteryPercent == null ? null : integer(value.batteryPercent, 0, 100),
    power: ['0', '1', '2', '3'].includes(value.power) ? value.power : (() => { throw new Error('invalid power'); })(),
    requested: boolean(value.requested), stopping: boolean(value.stopping), pipActive: boolean(value.pipActive)
  };
}

export function diagnosticReport(value) {
  if (!value || value.schemaVersion !== 1 || !Array.isArray(value.events) || value.events.length > 200) throw new Error('invalid report');
  // Reconstruct the allowlist: never store extra fields in an uploaded diagnostic file.
  return {
    schemaVersion: 1, generatedAt: date(value.generatedAt), appVersion: string(value.appVersion, 32, 1),
    build: string(value.build, 32, 1), hardware: string(value.hardware, 64, 1), osVersion: string(value.osVersion, 32, 1),
    lowPowerMode: boolean(value.lowPowerMode), thermalState: integer(value.thermalState, 0, 3), state: state(value.state),
    events: value.events.map(entry => {
      if (!/^[a-z0-9_.:-]{1,80}$/.test(entry.event)) throw new Error('invalid event');
      return { time: date(entry.time), event: entry.event, state: state(entry.state) };
    })
  };
}

export function feedback(value) {
  if (!UUID.test(value.id) || value.consent !== true || value.website) throw new Error('invalid submission');
  const message = string(value.message, 4000, 10).trim();
  if (message.length < 10) throw new Error('message too short');
  const email = string(value.email ?? '', 254).trim();
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('invalid email');
  return { id: value.id, message, email, diagnostics: value.diagnostics == null ? null : diagnosticReport(value.diagnostics) };
}

async function readBody(request) {
  if (!request.headers.get('content-type')?.startsWith('application/json')) throw new Error('JSON required');
  const reader = request.body?.getReader();
  if (!reader) throw new Error('body required');
  let size = 0;
  const chunks = [];
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.length;
    if (size > MAX_BODY) { await reader.cancel(); throw new Error('body too large'); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return JSON.parse(new TextDecoder().decode(bytes));
}

function json(value, status = 200) {
  return Response.json(value, { status, headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' } });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (!url.pathname.startsWith('/api/')) return env.ASSETS.fetch(request);
    if (url.pathname === '/api/health' && request.method === 'GET') {
      try { await env.DB.prepare('SELECT id FROM feedback LIMIT 0').all(); return json({ status: 'ok' }); }
      catch { return json({ error: 'unavailable' }, 503); }
    }
    if (request.method !== 'POST' || !['/api/feedback', '/api/feedback/delete'].includes(url.pathname)) return json({ error: 'not_found' }, 404);
    const origin = request.headers.get('Origin');
    if (origin && origin !== url.origin) return json({ error: 'origin_not_allowed' }, 403);
    try {
      const address = request.headers.get('CF-Connecting-IP') ?? 'local';
      // Only Cloudflare's short-lived rate limiter sees the IP; it is never written to D1 or application logs.
      const limit = await env.FEEDBACK_LIMITER.limit({ key: address });
      if (!limit.success) return json({ error: 'rate_limited' }, 429);
      let value;
      try { value = await readBody(request); } catch { return json({ error: 'invalid_request' }, 400); }
      if (url.pathname.endsWith('/delete')) {
        if (!UUID.test(value.id)) return json({ error: 'invalid_id' }, 400);
        await env.DB.prepare('DELETE FROM feedback WHERE id = ?').bind(value.id).run();
        return json({ deleted: true });
      }
      let item;
      try { item = feedback(value); } catch { return json({ error: 'invalid_feedback' }, 400); }
      const payload = JSON.stringify(item);
      const digest = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(payload))), b => b.toString(16).padStart(2, '0')).join('');
      await env.DB.prepare('INSERT OR IGNORE INTO feedback (id, created_at, digest, payload) VALUES (?, ?, ?, ?)').bind(item.id, Date.now(), digest, payload).run();
      const saved = await env.DB.prepare('SELECT digest FROM feedback WHERE id = ?').bind(item.id).first();
      if (saved?.digest !== digest) return json({ error: 'id_conflict' }, 409);
      return json({ id: item.id }, 201);
    } catch { return json({ error: 'temporarily_unavailable' }, 503); }
  },
  async scheduled(_event, env) {
    await env.DB.prepare('DELETE FROM feedback WHERE created_at <= ?').bind(Date.now() - 30 * 24 * 60 * 60 * 1000).run();
  }
};
