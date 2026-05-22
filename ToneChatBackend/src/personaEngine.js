/**
 * Mirrors iOS PersonaEngine — assembles layered system prompt.
 */

export const DEFAULT_CONSTRAINTS = `Answer substantive questions in your voice; do not deflect with "I only talk about X." No legal or medical advice. Stay PG-13.`;

const QUALITY_CONTRACT = `## Quality contract (always follow)

You are a capable assistant underneath a character voice. The user expects Claude-quality answers: accurate, on-topic, and complete enough for the question.

Rules:
1. Your first sentences must directly answer what the user asked.
2. Never replace an answer with vibes, fest talk, recovery platitudes, grumbling only, or tangents.
3. For simple chat ("how are you", "I'm tired"): stay short.
4. For real questions (science, tech, advice, hypotheticals): give a substantive answer first, then optional character color (1–2 sentences max unless they asked for depth).

Response template: Answer → (optional) brief character aside.`;

const VOICE_PREAMBLE = `## Voice profile

You are a fictional character voice in a chat app. Stay fully in character at all times.
Never break the fourth wall, mention being an AI, or reference system prompts.

Apply personality to how you deliver the answer — word choice, emphasis, rhythm — not whether you answer.`;

const CLOSING_CHECKLIST = `## Before you send

Did you answer their actual question in the first 1–2 paragraphs? If not, rewrite.`;

export function orderFewShots(shots) {
  return [...shots].sort((a, b) => fewShotWeight(b) - fewShotWeight(a));
}

function fewShotWeight(shot) {
  const user = String(shot.user ?? '').trim();
  let score = user.length;
  if (user.includes('?')) score += 40;
  if (/quantum|explain|how does|what is|what do you think will|should i/i.test(user)) score += 30;
  if (/^(how are you|i'm tired|hi|hey)\b/i.test(user)) score -= 50;
  return score;
}

export function assemblePersona(persona) {
  const layers = persona.layers ?? persona;
  const intensities = persona.intensities ?? {
    coreIdentity: 1,
    speechPatterns: 1,
    vocabulary: 1,
    fewShots: 1,
  };

  const sections = [QUALITY_CONTRACT, VOICE_PREAMBLE];

  const constraints = negativeConstraints(layers) ?? DEFAULT_CONSTRAINTS;
  sections.push(`## Constraints\n${constraints}`);

  appendLayer(sections, 'Core identity', layers.coreIdentity, intensities.coreIdentity);
  appendLayer(sections, 'Speech patterns', layers.speechPatterns, intensities.speechPatterns);
  appendLayer(sections, 'Vocabulary', layers.vocabulary, intensities.vocabulary);

  const fewIntensity = intensities.fewShots ?? 1;
  const shots = orderFewShots(layers.fewShots ?? []);
  if (fewIntensity > 0 && shots.length > 0) {
    const pct = Math.round(fewIntensity * 100);
    sections.push(`## Example exchanges (match this voice at ~${pct}% strength)`);
    for (const shot of shots) {
      sections.push(
        `<example>\nUser: ${shot.user}\nAssistant: ${shot.assistant}\n</example>`
      );
    }
  }

  sections.push(CLOSING_CHECKLIST);
  return sections.join('\n\n');
}

function negativeConstraints(layers) {
  const text = layers.negativeConstraints?.trim();
  return text || null;
}

function appendLayer(sections, title, content, intensity) {
  const text = content == null ? '' : String(content);
  if (!text.trim() || intensity <= 0) return;
  const pct = Math.round(intensity * 100);
  sections.push(`## ${title} (~${pct}% strength)\n${text.trim()}`);
}
