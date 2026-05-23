import assert from 'node:assert/strict';
import { audienceMatches, parseAppleClientIds } from './auth.js';

assert.equal(audienceMatches('com.personalitychat.app', ['com.personalitychat.app']), true);
assert.equal(
  audienceMatches(['com.tonechat.app', 'com.personalitychat.app'], ['com.personalitychat.app']),
  true
);
assert.equal(audienceMatches('com.other.app', ['com.personalitychat.app']), false);

const prev = process.env.APPLE_CLIENT_ID;
process.env.APPLE_CLIENT_ID = 'com.test.app';
assert.deepEqual(parseAppleClientIds(), ['com.test.app']);
if (prev === undefined) delete process.env.APPLE_CLIENT_ID;
else process.env.APPLE_CLIENT_ID = prev;

console.log('auth tests passed');
