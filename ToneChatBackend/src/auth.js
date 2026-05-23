import { createHash } from 'node:crypto';
import * as jose from 'jose';

const { createRemoteJWKSet, jwtVerify } = jose;

const users = new Map();
const APPLE_JWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** Bundle IDs accepted in Apple identity token `aud` (comma-separated in env). */
export function parseAppleClientIds() {
  const raw =
    process.env.APPLE_CLIENT_IDS ??
    process.env.APPLE_CLIENT_ID ??
    'com.personalitychat.app,com.tonechat.app';
  const ids = raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return ids.length > 0 ? ids : ['com.personalitychat.app'];
}

export function audienceMatches(payloadAud, allowedIds) {
  const audList = Array.isArray(payloadAud) ? payloadAud : payloadAud ? [payloadAud] : [];
  return audList.some((a) => allowedIds.includes(a));
}

export function getUser(sub) {
  return users.get(sub);
}

export function upsertUser(sub, appleUserId) {
  const existing = users.get(sub) ?? { sub, appleUserId, createdAt: Date.now() };
  users.set(sub, existing);
  return existing;
}

export function deleteUser(sub) {
  users.delete(sub);
}

export function isValidDeviceId(deviceId) {
  return typeof deviceId === 'string' && UUID_RE.test(deviceId);
}

export function guestSubject(deviceId) {
  return createHash('sha256').update(`guest:${deviceId}`).digest('hex').slice(0, 32);
}

export function appleSubject(appleUserId) {
  return createHash('sha256').update(`apple:${appleUserId}`).digest('hex').slice(0, 32);
}

/** @deprecated use appleSubject */
export function userSubject(appleSub) {
  return appleSubject(appleSub);
}

export async function issueToken(sub, tier, secret) {
  const key = new TextEncoder().encode(secret);
  return new jose.SignJWT({ sub, tier })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('30d')
    .sign(key);
}

export async function verifyToken(token, secret) {
  const key = new TextEncoder().encode(secret);
  const { payload } = await jwtVerify(token, key);
  return payload;
}

export function parseBearer(req) {
  const header = req.headers.authorization ?? '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1] ?? null;
}

export async function resolveIdentity(req, secret) {
  const token = parseBearer(req);
  if (!token) throw Object.assign(new Error('Unauthorized'), { status: 401 });

  let payload;
  try {
    payload = await verifyToken(token, secret);
  } catch {
    throw Object.assign(new Error('Invalid or expired session token'), { status: 401 });
  }

  const sub = payload.sub;
  if (!sub) throw Object.assign(new Error('Unauthorized'), { status: 401 });

  const tier = payload.tier === 'apple' ? 'apple' : 'guest';
  return { sub, tier };
}

/**
 * Verify Apple Sign In identity token (signature + issuer/exp) and audience (bundle ID).
 */
export async function verifyAppleIdentityToken(identityToken, clientIds = parseAppleClientIds()) {
  const allowed = Array.isArray(clientIds) ? clientIds : parseAppleClientIds();

  let payload;
  try {
    const verified = await jwtVerify(identityToken, APPLE_JWKS, {
      issuer: 'https://appleid.apple.com',
    });
    payload = verified.payload;
  } catch {
    throw Object.assign(new Error('Apple sign-in token could not be verified. Try again.'), {
      status: 401,
    });
  }

  if (!audienceMatches(payload.aud, allowed)) {
    const isDev = process.env.VERCEL !== '1' && process.env.NODE_ENV !== 'production';
    if (isDev) {
      console.warn('[ToneChat] Apple token audience mismatch', {
        aud: payload.aud,
        allowed,
      });
    }
    throw Object.assign(
      new Error(
        'Apple Sign In failed: server bundle ID does not match the app. Set APPLE_CLIENT_ID to com.personalitychat.app on Vercel.'
      ),
      { status: 401 }
    );
  }

  const sub = payload.sub;
  if (!sub) {
    throw Object.assign(new Error('Invalid Apple sign-in token'), { status: 401 });
  }

  return { sub, email: payload.email };
}
