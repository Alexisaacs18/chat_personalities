import assert from 'node:assert/strict';
import {
  classifyTurn,
  maxTokensForMode,
  turnHintForMode,
} from './turnClassifier.js';

assert.equal(classifyTurn("I'm tired"), 'casual');
assert.equal(classifyTurn('Explain quantum entanglement in simple terms?'), 'substantive');
assert.equal(classifyTurn('What do you think of politics?'), 'boundary');
assert.ok(turnHintForMode('substantive').includes('direct'));
assert.equal(maxTokensForMode('substantive', 1024), 2048);
assert.equal(maxTokensForMode('casual', 1024), 1024);

console.log('turnClassifier tests passed');
