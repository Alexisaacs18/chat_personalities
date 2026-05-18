import assert from 'node:assert/strict';
import { assemblePersona } from './personaEngine.js';

const persona = {
  layers: {
    coreIdentity: 'Test core',
    speechPatterns: 'Short sentences.',
    vocabulary: 'yeah, bro',
    fewShots: [{ user: 'Hi', assistant: 'Yo.' }],
  },
  intensities: {
    coreIdentity: 1,
    speechPatterns: 0.5,
    vocabulary: 0,
    fewShots: 1,
  },
};

const prompt = assemblePersona(persona);
assert.ok(prompt.includes('Test core'));
assert.ok(prompt.includes('~50% strength'));
assert.ok(!prompt.includes('## Vocabulary'));
assert.ok(prompt.includes('<example>'));
console.log('personaEngine tests passed');
