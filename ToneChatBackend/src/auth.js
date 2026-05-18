import { createHash } from 'node:crypto';
import * as jose from 'jose';

const users = new Map();

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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
  const { payload } = await jose.jwtVerify(token, key);
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
 * MVP Apple Sign In: decode identity token and verify issuer/audience/exp.
 * For production, also verify JWT signature against Apple JWKS.
 */
export async function verifyAppleIdentityToken(identityToken, clientId) {
  const parts = identityToken.split('.');
  if (parts.length !== 3) throw new Error('Invalid identity token');

  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));

  if (payload.iss !== 'https://appleid.apple.com') {
    throw new Error('Invalid token issuer');
  }
  if (payload.aud !== clientId) {
    throw new Error('Invalid token audience');
  }
  if (payload.exp * 1000 < Date.now()) {
    throw new Error('Token expired');
  }

  const sub = payload.sub;
  if (!sub) throw new Error('Missing subject');

  return { sub, email: payload.email };
}
