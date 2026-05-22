import assert from 'node:assert/strict';
import {
  checkTokenBudget,
  estimateChatCostUsd,
  GUEST_BUDGET_USD_4H,
  recordTokenUsage,
  usageToUsd,
} from './tokenBudget.js';

const sub = 'test-token-user';

assert.ok(usageToUsd(10_000, 1_000) > 0);

const estimate = estimateChatCostUsd({
  system: 'x'.repeat(4000),
  messages: [{ role: 'user', content: 'hello' }],
  maxOutputTokens: 2048,
});
assert.ok(estimate > 0.01);

assert.equal(checkTokenBudget({ sub, tier: 'guest', estimatedUsd: 0.01 }).ok, true);

recordTokenUsage(sub, { input_tokens: 200_000, output_tokens: 50_000 });
const over = checkTokenBudget({
  sub,
  tier: 'guest',
  estimatedUsd: GUEST_BUDGET_USD_4H,
});
assert.equal(over.ok, false);
assert.equal(over.reason, 'tokens');

console.log('tokenBudget tests passed');
