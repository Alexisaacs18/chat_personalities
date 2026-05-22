const buckets = new Map();

export function checkRateLimit(key, limitPerMinute, cost = 1) {
  const now = Date.now();
  const windowMs = 60_000;
  let bucket = buckets.get(key);

  if (!bucket || now - bucket.windowStart > windowMs) {
    bucket = { windowStart: now, count: 0 };
    buckets.set(key, bucket);
  }

  bucket.count += cost;
  if (bucket.count > limitPerMinute) {
    return false;
  }
  return true;
}
