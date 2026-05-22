import assert from 'node:assert/strict';
import {
  checkChatRateLimits,
  consumeRollingLimit,
  formatRetryHint,
} from './rateLimit.js';

const burst = new Map();
const quota = new Map();

assert.equal(
  consumeRollingLimit(burst, 'u1', 3, 60_000, 1).ok,
  true
);
assert.equal(
  consumeRollingLimit(burst, 'u1', 3, 60_000, 1).ok,
  true
);
assert.equal(
  consumeRollingLimit(burst, 'u1', 3, 60_000, 1).ok,
  true
);
assert.equal(
  consumeRollingLimit(burst, 'u1', 3, 60_000, 1).ok,
  false
);

const chat = checkChatRateLimits({
  sub: 'guest-abc',
  tier: 'guest',
  cost: 1,
  burstLimit: 10,
});
assert.equal(chat.ok, true);

assert.ok(formatRetryHint(90_000).includes('minute'));

console.log('rateLimit tests passed');
