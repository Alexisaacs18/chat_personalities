const burstBuckets = new Map();

const ONE_MINUTE_MS = 60_000;

function rollBucket(store, key, windowMs, now) {
  let bucket = store.get(key);
  if (!bucket || now - bucket.windowStart >= windowMs) {
    bucket = { windowStart: now, count: 0 };
    store.set(key, bucket);
  }
  return bucket;
}

/**
 * Rolling window counter. Returns false if adding `cost` would exceed `limit`.
 */
export function consumeRollingLimit(store, key, limit, windowMs, cost = 1) {
  const now = Date.now();
  const bucket = rollBucket(store, key, windowMs, now);
  if (bucket.count + cost > limit) {
    return {
      ok: false,
      count: bucket.count,
      limit,
      windowMs,
      retryAfterMs: Math.max(0, bucket.windowStart + windowMs - now),
    };
  }
  bucket.count += cost;
  return { ok: true, count: bucket.count, limit, windowMs };
}

/** @deprecated use consumeRollingLimit — kept for tests */
export function checkRateLimit(key, limitPerMinute, cost = 1) {
  return consumeRollingLimit(burstBuckets, key, limitPerMinute, ONE_MINUTE_MS, cost).ok;
}

/** Anti-spam burst limit only; token spend is enforced in tokenBudget.js */
export function checkChatRateLimits({ sub, tier, cost = 1, burstLimit }) {
  const burst = consumeRollingLimit(
    burstBuckets,
    `${sub}:burst`,
    burstLimit,
    ONE_MINUTE_MS,
    cost
  );
  if (!burst.ok) {
    return { ...burst, reason: 'burst', tier };
  }

  return { ok: true, tier, burstLimit };
}

export function formatRetryHint(retryAfterMs) {
  const minutes = Math.ceil(retryAfterMs / 60_000);
  if (minutes < 60) return `Try again in about ${minutes} minute${minutes === 1 ? '' : 's'}.`;
  const hours = Math.ceil(minutes / 60);
  return `Try again in about ${hours} hour${hours === 1 ? '' : 's'}.`;
}
