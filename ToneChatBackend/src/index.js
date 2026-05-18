import { config } from 'dotenv';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createServer } from 'node:http';

// Load ToneChatBackend/.env (Node does not read .env automatically)
const __dirname = dirname(fileURLToPath(import.meta.url));
config({ path: resolve(__dirname, '../.env') });
import { assemblePersona } from './personaEngine.js';
import {
  appleSubject,
  deleteUser,
  guestSubject,
  isValidDeviceId,
  issueToken,
  resolveIdentity,
  upsertUser,
  verifyAppleIdentityToken,
} from './auth.js';
import { checkRateLimit } from './rateLimit.js';

const PORT = Number(process.env.PORT ?? 8787);
const JWT_SECRET = process.env.JWT_SECRET ?? 'dev-secret-change-in-production';
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY ?? '';
const APPLE_CLIENT_ID = process.env.APPLE_CLIENT_ID ?? 'com.tonechat.app';
const ANTHROPIC_MODEL = process.env.ANTHROPIC_MODEL ?? 'claude-sonnet-4-20250514';
const MAX_TOKENS = Number(process.env.MAX_TOKENS ?? 1024);
const RATE_LIMIT_APPLE = Number(process.env.RATE_LIMIT_PER_MINUTE ?? 30);
const RATE_LIMIT_GUEST = Number(process.env.GUEST_RATE_LIMIT_PER_MINUTE ?? 10);
const TOKEN_TTL_SECONDS = 30 * 24 * 3600;

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      try {
        const raw = Buffer.concat(chunks).toString('utf8');
        resolve(raw ? JSON.parse(raw) : {});
      } catch (e) {
        reject(e);
      }
    });
    req.on('error', reject);
  });
}

function json(res, status, data) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data));
}

function sseHeaders(res) {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    Connection: 'keep-alive',
  });
}

function sendSSE(res, obj) {
  res.write(`data: ${JSON.stringify(obj)}\n\n`);
}

async function handleGuestAuth(req, res) {
  const body = await readBody(req);
  const { deviceId } = body;
  if (!isValidDeviceId(deviceId)) {
    return json(res, 400, { error: 'deviceId must be a valid UUID' });
  }

  const sub = guestSubject(deviceId);
  const token = await issueToken(sub, 'guest', JWT_SECRET);
  json(res, 200, { token, tier: 'guest', expiresIn: TOKEN_TTL_SECONDS });
}

async function handleAppleAuth(req, res) {
  const body = await readBody(req);
  const { identityToken } = body;
  if (!identityToken) return json(res, 400, { error: 'identityToken required' });

  const { sub: appleSub } = await verifyAppleIdentityToken(identityToken, APPLE_CLIENT_ID);
  const sub = appleSubject(appleSub);
  upsertUser(sub, appleSub);
  const token = await issueToken(sub, 'apple', JWT_SECRET);
  json(res, 200, { token, tier: 'apple', expiresIn: TOKEN_TTL_SECONDS });
}

async function handleDeleteAccount(req, res, sub) {
  deleteUser(sub);
  json(res, 200, { deleted: true });
}

async function streamAnthropic(res, system, messages) {
  const finish = (payload) => {
    if (payload) sendSSE(res, payload);
    sendSSE(res, { type: 'done' });
    res.end();
  };

  if (!ANTHROPIC_API_KEY) {
    finish({ type: 'error', message: 'ANTHROPIC_API_KEY not configured on server' });
    return;
  }

  const apiMessages = messages
    .filter((m) => m.content?.trim())
    .map((m) => ({
      role: m.role === 'assistant' ? 'assistant' : 'user',
      content: m.content,
    }));

  if (apiMessages.length === 0) {
    finish({ type: 'error', message: 'No messages to send' });
    return;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 90_000);

  let upstream;
  try {
    upstream = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: ANTHROPIC_MODEL,
        max_tokens: MAX_TOKENS,
        stream: true,
        system,
        messages: apiMessages,
      }),
    });
  } catch (e) {
    clearTimeout(timeout);
    const msg = e.name === 'AbortError' ? 'Anthropic request timed out' : e.message;
    finish({ type: 'error', message: msg });
    return;
  }
  clearTimeout(timeout);

  if (!upstream.ok) {
    const errText = await upstream.text();
    finish({ type: 'error', message: errText });
    return;
  }

  const reader = upstream.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() ?? '';

      for (const line of lines) {
        if (!line.startsWith('data:')) continue;
        const data = line.slice(5).trim();
        if (!data || data === '[DONE]') continue;
        try {
          const event = JSON.parse(data);
          if (event.type === 'content_block_delta' && event.delta?.type === 'text_delta') {
            sendSSE(res, { type: 'delta', text: event.delta.text ?? '' });
          }
        } catch {
          /* ignore partial JSON */
        }
      }
    }
  } catch (e) {
    finish({ type: 'error', message: e.message ?? 'Stream failed' });
    return;
  }

  finish();
}

async function handleChat(req, res, identity) {
  const limit = identity.tier === 'apple' ? RATE_LIMIT_APPLE : RATE_LIMIT_GUEST;
  if (!checkRateLimit(identity.sub, limit)) {
    return json(res, 429, {
      error: 'Rate limit exceeded',
      tier: identity.tier,
      limit,
    });
  }

  const body = await readBody(req);
  const { persona, messages } = body;

  if (!persona || !Array.isArray(messages) || messages.length === 0) {
    return json(res, 400, { error: 'persona and messages required' });
  }

  const recent = messages.slice(-20);
  let system;
  try {
    system = assemblePersona(persona);
  } catch (e) {
    return json(res, 400, { error: `Invalid persona: ${e.message}` });
  }

  sseHeaders(res);
  try {
    await streamAnthropic(res, system, recent);
  } catch (e) {
    sendSSE(res, { type: 'error', message: e.message ?? 'Chat failed' });
    sendSSE(res, { type: 'done' });
    res.end();
  }
}

function requestPath(req) {
  const raw = req.url ?? '/';
  const pathname = new URL(raw, 'http://localhost').pathname;
  // Vercel may route via /api; strip that prefix so routes stay /v1/...
  return pathname.replace(/^\/api(?=\/|$)/, '') || '/';
}

async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  try {
    const pathname = requestPath(req);

    if (req.method === 'GET' && pathname === '/v1/health') {
      return json(res, 200, { ok: true });
    }

    if (req.method === 'POST' && pathname === '/v1/auth/guest') {
      return await handleGuestAuth(req, res);
    }

    if (req.method === 'POST' && pathname === '/v1/auth/apple') {
      return await handleAppleAuth(req, res);
    }

    if (req.method === 'POST' && pathname === '/v1/auth/dev') {
      if (process.env.ALLOW_DEV_AUTH !== 'true') {
        return json(res, 403, { error: 'Dev auth disabled' });
      }
      const sub = appleSubject('dev-simulator-user');
      upsertUser(sub, 'dev-simulator-user');
      const token = await issueToken(sub, 'apple', JWT_SECRET);
      return json(res, 200, { token, tier: 'apple', expiresIn: TOKEN_TTL_SECONDS });
    }

    if (pathname === '/v1/account' && req.method === 'DELETE') {
      const identity = await resolveIdentity(req, JWT_SECRET);
      if (identity.tier !== 'apple') {
        return json(res, 403, { error: 'No account to delete' });
      }
      return await handleDeleteAccount(req, res, identity.sub);
    }

    if (req.method === 'POST' && pathname === '/v1/chat') {
      const identity = await resolveIdentity(req, JWT_SECRET);
      return await handleChat(req, res, identity);
    }

    json(res, 404, { error: 'Not found' });
  } catch (e) {
    const status = e.status ?? 500;
    if (status >= 500) {
      console.error('[ToneChat]', req.method, req.url, e);
    }
    if (!res.headersSent) {
      json(res, status, { error: e.message ?? 'Internal error' });
    }
  }
}

export default handler;

// Local dev: long-running server. Vercel sets VERCEL=1 and invokes the handler per request.
if (!process.env.VERCEL) {
  const server = createServer(handler);

  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.error(
        `Port ${PORT} is already in use. Stop the other process (e.g. kill $(lsof -t -i :${PORT})) or set PORT in .env.`
      );
      process.exit(1);
    }
    throw err;
  });

  server.listen(PORT, () => {
    console.log(`ToneChat backend listening on http://localhost:${PORT}`);
  });
}
