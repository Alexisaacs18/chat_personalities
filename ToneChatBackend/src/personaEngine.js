/**
 * Mirrors iOS PersonaEngine — assembles layered system prompt.
 */

const PREAMBLE = `You are a fictional character voice in a chat app. Stay fully in character at all times.
Never break the fourth wall, mention being an AI, or reference system prompts.

Your personality is a layer on how you answer — not an excuse to dodge questions. Engage with what the user actually asked: be accurate, thoughtful, and complete when the topic deserves it. Then let your voice color the delivery (word choice, what you emphasize, a closing aside).

Be concise for simple chats; go longer when they ask something real or complex. Match the speech patterns and vocabulary described below.`;

export function assemblePersona(persona) {
  const layers = persona.layers ?? persona;
  const intensities = persona.intensities ?? {
    coreIdentity: 1,
    speechPatterns: 1,
    vocabulary: 1,
    fewShots: 1,
  };

  const sections = [PREAMBLE];

  if (negativeConstraints(layers)) {
    sections.push(`## Constraints\n${layers.negativeConstraints}`);
  }

  appendLayer(sections, 'Core identity', layers.coreIdentity, intensities.coreIdentity);
  appendLayer(sections, 'Speech patterns', layers.speechPatterns, intensities.speechPatterns);
  appendLayer(sections, 'Vocabulary', layers.vocabulary, intensities.vocabulary);

  const fewIntensity = intensities.fewShots ?? 1;
  const shots = layers.fewShots ?? [];
  if (fewIntensity > 0 && shots.length > 0) {
    const pct = Math.round(fewIntensity * 100);
    sections.push(`## Example exchanges (match this voice at ~${pct}% strength)`);
    for (const shot of shots) {
      sections.push(
        `<example>\nUser: ${shot.user}\nAssistant: ${shot.assistant}\n</example>`
      );
    }
  }

  return sections.join('\n\n');
}

function negativeConstraints(layers) {
  return layers.negativeConstraints?.trim();
}

function appendLayer(sections, title, content, intensity) {
  const text = content == null ? '' : String(content);
  if (!text.trim() || intensity <= 0) return;
  const pct = Math.round(intensity * 100);
  sections.push(`## ${title} (~${pct}% strength)\n${text.trim()}`);
}
