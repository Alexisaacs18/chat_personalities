import assert from 'node:assert/strict';
import {
  assemblePersona,
  DEFAULT_CONSTRAINTS,
  orderFewShots,
} from './personaEngine.js';

const persona = {
  layers: {
    coreIdentity: 'Test core',
    speechPatterns: 'Short sentences.',
    vocabulary: 'yeah, bro',
    fewShots: [
      { user: "I'm tired", assistant: 'Rest up.' },
      { user: 'Explain quantum entanglement?', assistant: 'Pairs of particles...' },
    ],
  },
  intensities: {
    coreIdentity: 1,
    speechPatterns: 0.5,
    vocabulary: 0,
    fewShots: 1,
  },
};

const prompt = assemblePersona(persona);
assert.ok(prompt.includes('## Quality contract'));
assert.ok(prompt.includes('## Before you send'));
assert.ok(prompt.includes('Test core'));
assert.ok(prompt.includes('~50% strength'));
assert.ok(!prompt.includes('## Vocabulary'));
assert.ok(prompt.includes('<example>'));

const ordered = orderFewShots(persona.layers.fewShots);
assert.ok(ordered[0].user.includes('quantum'));

const noConstraints = assemblePersona({
  layers: {
    coreIdentity: 'X',
    speechPatterns: 'Y',
    vocabulary: 'Z',
    fewShots: [],
  },
  intensities: { coreIdentity: 1, speechPatterns: 1, vocabulary: 1, fewShots: 0 },
});
assert.ok(noConstraints.includes(DEFAULT_CONSTRAINTS));

console.log('personaEngine tests passed');
