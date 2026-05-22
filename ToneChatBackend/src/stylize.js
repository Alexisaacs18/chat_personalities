import { assemblePersona } from './personaEngine.js';

export const DRAFT_SYSTEM = `You are a helpful assistant. Answer the user's question accurately and completely in plain language.
Do not use a character voice, slang persona, or roleplay. No preamble about being an AI.`;

export function buildStylizeUserMessage(userMessage, draftAnswer) {
  return `<user_message>
${userMessage.trim()}
</user_message>

<draft_answer>
${draftAnswer.trim()}
</draft_answer>

Rewrite the draft_answer in the character voice from your system instructions.
Keep every factual point and directly answer the user_message. Do not drop questions unanswered.
Shorten only if redundant. Stream only the final in-character reply.`;
}

export function buildStylizeSystem(persona) {
  return assemblePersona(persona);
}
