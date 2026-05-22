export function classifyTurn(text) {
  const t = String(text ?? '').trim().toLowerCase();
  if (!t) return 'casual';

  if (
    /\b(politics?|election|president|democrat|republican|vote for|left wing|right wing)\b/.test(
      t
    )
  ) {
    return 'boundary';
  }

  if (
    t.length > 120 ||
    /\?/.test(t) ||
    /\b(explain|how does|how do|what is|what are|why does|why do|compare|difference between|quantum|should i)\b/.test(
      t
    )
  ) {
    return 'substantive';
  }

  return 'casual';
}

export function turnHintForMode(mode) {
  switch (mode) {
    case 'substantive':
      return '## This turn\nThis turn requires a direct, accurate answer before any character color.';
    case 'boundary':
      return '## This turn\nThe user raised a boundary topic. Decline politely in character without a lecture or rant.';
    default:
      return '## This turn\nKeep it brief and conversational.';
  }
}

export function maxTokensForMode(mode, baseMax) {
  if (mode === 'substantive') return Math.max(baseMax, 2048);
  return baseMax;
}
