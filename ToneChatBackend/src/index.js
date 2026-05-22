import { config } from 'dotenv';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createServer } from 'node:http';

// Load ToneChatBackend/.env (Node does not read .env automatically)
const __dirname = dirname(fileURLToPath(import.meta.url));
config({ path: resolve(__dirname, '../.env') });
import { assemblePersona } from './personaEngine.js';
import { completeAnthropic, streamAnthropicToSSE } from './anthropic.js';
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
import { checkChatRateLimits } from './rateLimit.js';
import {
  checkTokenBudget,
  estimateChatCostUsd,
  formatUsageResponse,
  recordTokenUsage,
} from './tokenBudget.js';
import {
  buildStylizeSystem,
  buildStylizeUserMessage,
  DRAFT_SYSTEM,
} from './stylize.js';
import {
  classifyTurn,
  maxTokensForMode,
  turnHintForMode,
} from './turnClassifier.js';

const PORT = Number(process.env.PORT ?? 8787);
const JWT_SECRET = process.env.JWT_SECRET ?? 'dev-secret-change-in-production';
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY ?? '';
const APPLE_CLIENT_ID = process.env.APPLE_CLIENT_ID ?? 'com.personalitychat.app';
const ANTHROPIC_MODEL = process.env.ANTHROPIC_MODEL ?? 'claude-sonnet-4-20250514';
const MAX_TOKENS = Number(process.env.MAX_TOKENS ?? 2048);
const CHAT_TEMPERATURE = Number(process.env.CHAT_TEMPERATURE ?? 0.7);
const HIGH_FIDELITY_ENABLED = process.env.HIGH_FIDELITY_ENABLED !== 'false';
const HIGH_FIDELITY_APPLE_ONLY = process.env.HIGH_FIDELITY_APPLE_ONLY !== 'false';
const BURST_GUEST_PER_MIN = Number(process.env.GUEST_BURST_PER_MINUTE ?? 5);
const BURST_APPLE_PER_MIN = Number(process.env.APPLE_BURST_PER_MINUTE ?? 10);
const CHAT_HISTORY_LIMIT = Number(process.env.CHAT_HISTORY_LIMIT ?? 10);
const TOKEN_TTL_SECONDS = 30 * 24 * 3600;
const IS_DEV = process.env.VERCEL !== '1' && process.env.NODE_ENV !== 'production';

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

function lastUserMessage(messages) {
  for (let i = messages.length - 1; i >= 0; i -= 1) {
    if (messages[i].role === 'user' && messages[i].content?.trim()) {
      return messages[i].content.trim();
    }
  }
  return '';
}

function buildSystemWithTurnHint(persona, lastUser) {
  const mode = classifyTurn(lastUser);
  const system = `${assemblePersona(persona)}\n\n${turnHintForMode(mode)}`;
  return { system, mode };
}

async function streamAnthropic(res, system, messages, options = {}) {
  const finish = (payload) => {
    if (payload?.usage && options.sub) {
      recordTokenUsage(options.sub, payload.usage);
    }
    if (payload?.type === 'error') sendSSE(res, payload);
    sendSSE(res, { type: 'done' });
    res.end();
  };

  if (!ANTHROPIC_API_KEY) {
    finish({ type: 'error', message: 'ANTHROPIC_API_KEY not configured on server' });
    return;
  }

  await streamAnthropicToSSE({
    apiKey: ANTHROPIC_API_KEY,
    model: ANTHROPIC_MODEL,
    system,
    messages,
    maxTokens: options.maxTokens ?? MAX_TOKENS,
    temperature: options.temperature ?? CHAT_TEMPERATURE,
    sendSSE: (obj) => sendSSE(res, obj),
    finish,
  });
}

async function handleHighFidelityChat(res, persona, recent, lastUser, options) {
  const finish = (payload) => {
    if (payload?.usage && options.sub) {
      recordTokenUsage(options.sub, payload.usage);
    }
    if (payload?.type === 'error') sendSSE(res, payload);
    sendSSE(res, { type: 'done' });
    res.end();
  };

  if (!ANTHROPIC_API_KEY) {
    finish({ type: 'error', message: 'ANTHROPIC_API_KEY not configured on server' });
    return;
  }

  const maxTokens = options.maxTokens ?? MAX_TOKENS;
  const temperature = options.temperature ?? CHAT_TEMPERATURE;

  let draftResult;
  try {
    draftResult = await completeAnthropic({
      apiKey: ANTHROPIC_API_KEY,
      model: ANTHROPIC_MODEL,
      system: DRAFT_SYSTEM,
      messages: recent,
      maxTokens,
      temperature: 0.5,
    });
  } catch (e) {
    finish({ type: 'error', message: e.message ?? 'Draft failed' });
    return;
  }

  const draft = draftResult.text;
  if (!draft) {
    finish({ type: 'error', message: 'Draft returned empty' });
    return;
  }

  if (options.sub && draftResult.usage) {
    recordTokenUsage(options.sub, draftResult.usage);
  }

  const stylizeSystem = buildStylizeSystem(persona);
  const stylizeMessages = [
    { role: 'user', content: buildStylizeUserMessage(lastUser, draft) },
  ];

  await streamAnthropicToSSE({
    apiKey: ANTHROPIC_API_KEY,
    model: ANTHROPIC_MODEL,
    system: stylizeSystem,
    messages: stylizeMessages,
    maxTokens,
    temperature,
    sendSSE: (obj) => sendSSE(res, obj),
    finish,
  });
}

function estimateHighFidelityCostUsd(persona, recent, lastUser, maxTokens) {
  const draftUsd = estimateChatCostUsd({
    system: DRAFT_SYSTEM,
    messages: recent,
    maxOutputTokens: maxTokens,
  });
  const stylizeSystem = buildStylizeSystem(persona);
  const draftPlaceholder = 'x'.repeat(maxTokens * 4);
  const stylizeUsd = estimateChatCostUsd({
    system: stylizeSystem,
    messages: [{ role: 'user', content: buildStylizeUserMessage(lastUser, draftPlaceholder) }],
    maxOutputTokens: maxTokens,
  });
  return draftUsd + stylizeUsd;
}

async function handleChat(req, res, identity) {
  const body = await readBody(req);
  const { persona, messages, highFidelity } = body;

  if (!persona || !Array.isArray(messages) || messages.length === 0) {
    return json(res, 400, { error: 'persona and messages required' });
  }

  const isApple = identity.tier === 'apple';
  const wantsHighFidelity = Boolean(highFidelity) && HIGH_FIDELITY_ENABLED;

  if (wantsHighFidelity && HIGH_FIDELITY_APPLE_ONLY && !isApple) {
    return json(res, 403, {
      error: 'High fidelity replies require Sign in with Apple.',
    });
  }

  const useHighFidelity = wantsHighFidelity && (isApple || !HIGH_FIDELITY_APPLE_ONLY);
  const burstCost = useHighFidelity ? 2 : 1;
  const burstLimit = isApple ? BURST_APPLE_PER_MIN : BURST_GUEST_PER_MIN;

  const burst = checkChatRateLimits({
    sub: identity.sub,
    tier: identity.tier,
    cost: burstCost,
    burstLimit,
  });

  if (!burst.ok) {
    const resetAt = new Date(Date.now() + (burst.retryAfterMs ?? 0)).toISOString();
    return json(res, 429, {
      error: 'usage_limit',
      message: "You're sending messages too fast.",
      resetAt,
    });
  }

  const recent = messages.slice(-CHAT_HISTORY_LIMIT);
  const lastUser = lastUserMessage(recent);
  const mode = classifyTurn(lastUser);
  const maxTokens = maxTokensForMode(mode, MAX_TOKENS);
  const streamOptions = {
    maxTokens,
    temperature: CHAT_TEMPERATURE,
    sub: identity.sub,
  };

  const estimatedUsd = useHighFidelity
    ? estimateHighFidelityCostUsd(persona, recent, lastUser, maxTokens)
    : estimateChatCostUsd({
        system: buildSystemWithTurnHint(persona, lastUser).system,
        messages: recent,
        maxOutputTokens: maxTokens,
      });

  const tokenBudget = checkTokenBudget({
    sub: identity.sub,
    tier: identity.tier,
    estimatedUsd,
  });

  if (!tokenBudget.ok) {
    const resetAt = new Date(Date.now() + (tokenBudget.retryAfterMs ?? 0)).toISOString();
    const payload = {
      error: 'usage_limit',
      message: "You've reached your usage limit for this period.",
      resetAt,
    };
    if (!isApple) {
      payload.hint = 'Sign in with Apple for higher limits.';
    }

    return json(res, 429, payload);
  }

  if (IS_DEV) {
    console.log('[ToneChat] chat', {
      mode,
      highFidelity: useHighFidelity,
      systemChars: assemblePersona(persona).length,
    });
  }

  sseHeaders(res);
  try {
    if (useHighFidelity) {
      await handleHighFidelityChat(res, persona, recent, lastUser, streamOptions);
    } else {
      const { system } = buildSystemWithTurnHint(persona, lastUser);
      await streamAnthropic(res, system, recent, streamOptions);
    }
  } catch (e) {
    sendSSE(res, { type: 'error', message: e.message ?? 'Chat failed' });
    sendSSE(res, { type: 'done' });
    res.end();
  }
}

function requestPath(req) {
  const raw = req.url ?? '/';
  const url = new URL(raw, 'http://localhost');

  // Vercel rewrite: /v1/health → /api?__path=v1/health
  const fromQuery = url.searchParams.get('__path');
  if (fromQuery !== null) {
    const segment = fromQuery.trim();
    return segment ? `/${segment.replace(/^\/+/, '')}` : '/';
  }

  const headerUrl =
    req.headers['x-vercel-original-url'] ??
    req.headers['x-forwarded-uri'] ??
    req.headers['x-invoke-path'];

  if (headerUrl) {
    const value = Array.isArray(headerUrl) ? headerUrl[0] : headerUrl;
    const pathname = new URL(
      value.startsWith('http') ? value : `http://localhost${value}`,
      'http://localhost'
    ).pathname;
    return pathname.replace(/^\/api(?=\/|$)/, '') || '/';
  }

  return url.pathname.replace(/^\/api(?=\/|$)/, '') || '/';
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

    if (req.method === 'GET' && (pathname === '/' || pathname === '/api')) {
      return json(res, 200, { ok: true, service: 'tonechat-api', health: '/v1/health' });
    }

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

    if (req.method === 'GET' && pathname === '/v1/usage') {
      const identity = await resolveIdentity(req, JWT_SECRET);
      return json(res, 200, formatUsageResponse(identity.sub, identity.tier));
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
