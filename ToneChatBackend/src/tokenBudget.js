/**
 * Rolling 4-hour API spend limits based on Anthropic token usage.
 */

const FOUR_HOURS_MS = 4 * 60 * 60 * 1000;
const tokenBuckets = new Map();

/** USD per million tokens (Claude Sonnet 4 class) */
const INPUT_USD_PER_MTOK = Number(process.env.INPUT_USD_PER_MTOK ?? 3);
const OUTPUT_USD_PER_MTOK = Number(process.env.OUTPUT_USD_PER_MTOK ?? 15);

export const GUEST_BUDGET_USD_4H = Number(process.env.GUEST_BUDGET_USD_4H ?? 0.1);
export const APPLE_BUDGET_USD_4H = Number(process.env.APPLE_BUDGET_USD_4H ?? 0.2);

export function usageToUsd(inputTokens, outputTokens) {
  const input = Number(inputTokens) || 0;
  const output = Number(outputTokens) || 0;
  return (input / 1_000_000) * INPUT_USD_PER_MTOK + (output / 1_000_000) * OUTPUT_USD_PER_MTOK;
}

export function estimateTokensFromText(text) {
  const len = String(text ?? '').length;
  return Math.ceil(len / 4);
}

export function estimateChatCostUsd({ system, messages, maxOutputTokens }) {
  let input = estimateTokensFromText(system);
  for (const m of messages ?? []) {
    input += estimateTokensFromText(m.content);
  }
  const output = Number(maxOutputTokens) || 0;
  return usageToUsd(input, output);
}

function budgetForTier(tier) {
  return tier === 'apple' ? APPLE_BUDGET_USD_4H : GUEST_BUDGET_USD_4H;
}

function getBucket(sub, now = Date.now()) {
  let bucket = tokenBuckets.get(sub);
  if (!bucket || now - bucket.windowStart >= FOUR_HOURS_MS) {
    bucket = { windowStart: now, spentUsd: 0, inputTokens: 0, outputTokens: 0 };
    tokenBuckets.set(sub, bucket);
  }
  return bucket;
}

export function getTokenBudgetStatus(sub, tier) {
  const budgetUsd = budgetForTier(tier);
  const bucket = getBucket(sub);
  const spentUsd = bucket.spentUsd;
  const remainingUsd = Math.max(0, budgetUsd - spentUsd);
  const now = Date.now();
  return {
    budgetUsd,
    spentUsd,
    remainingUsd,
    inputTokens: bucket.inputTokens,
    outputTokens: bucket.outputTokens,
    retryAfterMs: Math.max(0, bucket.windowStart + FOUR_HOURS_MS - now),
    windowStart: bucket.windowStart,
  };
}

/**
 * Reject if current spend + estimated cost would exceed the 4h budget.
 */
export function checkTokenBudget({ sub, tier, estimatedUsd = 0 }) {
  const budgetUsd = budgetForTier(tier);
  const bucket = getBucket(sub);
  const estimate = Math.max(0, Number(estimatedUsd) || 0);
  const projected = bucket.spentUsd + estimate;
  const now = Date.now();

  if (projected > budgetUsd) {
    return {
      ok: false,
      reason: 'tokens',
      tier,
      budgetUsd,
      spentUsd: bucket.spentUsd,
      estimatedUsd: estimate,
      retryAfterMs: Math.max(0, bucket.windowStart + FOUR_HOURS_MS - now),
    };
  }

  return {
    ok: true,
    tier,
    budgetUsd,
    spentUsd: bucket.spentUsd,
    remainingUsd: budgetUsd - bucket.spentUsd,
  };
}

export function recordTokenUsage(sub, usage) {
  if (!usage) return { spentUsd: 0 };
  const input = Number(usage.input_tokens) || 0;
  const output = Number(usage.output_tokens) || 0;
  const usd = usageToUsd(input, output);
  const bucket = getBucket(sub);
  bucket.spentUsd += usd;
  bucket.inputTokens += input;
  bucket.outputTokens += output;
  return { spentUsd: usd, inputTokens: input, outputTokens: output };
}

/** Fallback when Anthropic stream omits usage events — still charge the pre-flight estimate. */
export function recordUsdSpend(sub, usd) {
  const amount = Math.max(0, Number(usd) || 0);
  if (amount === 0) return { spentUsd: 0 };
  const bucket = getBucket(sub);
  bucket.spentUsd += amount;
  return { spentUsd: amount };
}

export function formatUsageResponse(sub, tier) {
  const status = getTokenBudgetStatus(sub, tier);
  const percentUsed =
    status.budgetUsd > 0
      ? Math.min(100, (status.spentUsd / status.budgetUsd) * 100)
      : 0;

  return {
    tier,
    inputTokens: status.inputTokens,
    outputTokens: status.outputTokens,
    totalTokens: status.inputTokens + status.outputTokens,
    percentUsed: Math.round(percentUsed * 10) / 10,
    resetAt: new Date(Date.now() + status.retryAfterMs).toISOString(),
  };
}

export function mergeUsage(a, b) {
  if (!a) return b ?? null;
  if (!b) return a;
  return {
    input_tokens: (a.input_tokens ?? 0) + (b.input_tokens ?? 0),
    output_tokens: (a.output_tokens ?? 0) + (b.output_tokens ?? 0),
  };
}
