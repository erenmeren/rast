import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

// Load as ESM even while the parent app's package.json is being created.
const source = await readFile(new URL('../dist/rules.js', import.meta.url), 'utf8');
const rules = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
const { ageFromBirthDate, ageLabel, isAdultDate, ageInRange, effectiveDelay, canRevealEncounter, UPDATE_INTERVAL_SECONDS, REVEAL_DELAY_HOURS, shuffleIds } = rules;
const today = new Date('2026-10-17T13:00:00.000Z');

test('birth dates reject impossible, malformed, future, and underage values', () => {
  for (const value of ['2026-02-30', '2025-02-29', '2000-13-01', '2000-00-01', '2000-01-00', '2008-1-01', '2026-10-18', '', null]) {
    assert.equal(ageFromBirthDate(value, today), null, String(value));
    assert.equal(isAdultDate(value, today), false, String(value));
  }
  assert.equal(ageFromBirthDate('2008-10-18', today), 17);
  assert.equal(isAdultDate('2008-10-18', today), false);
  assert.equal(ageFromBirthDate('2008-10-17', today), 18);
  assert.equal(isAdultDate('2008-10-17', today), true);
  assert.equal(ageFromBirthDate('2000-02-29', today), 26);
  assert.equal(ageFromBirthDate('2000-01-01', new Date('invalid')), null);
});

test('99+ is a display and range boundary, while actual adults may be older', () => {
  assert.equal(ageLabel(98), '98');
  assert.equal(ageLabel(99), '99+');
  assert.equal(ageLabel(105), '99+');
  assert.equal(isAdultDate('1920-01-01', today), true);
  assert.equal(isAdultDate('1800-01-01', today), false);
  assert.equal(ageInRange(105, 18, 99), true);
  assert.equal(ageInRange(99, 18, 98), false);
  assert.equal(ageInRange(17, 18, 99), false);
  assert.equal(ageInRange(NaN, 18, 99), false);
});

test('the longer privacy delay wins and invalid delays fall back to two hours', () => {
  assert.equal(effectiveDelay(0, 2), 2);
  assert.equal(effectiveDelay(1, 0), 1);
  assert.equal(effectiveDelay(0, 0), 0);
  assert.equal(effectiveDelay(undefined, 0), 2);
  assert.equal(effectiveDelay('0', 0), 2);
  assert.equal(effectiveDelay(-1, 0), 2);
  for (const a of [0, 1, 2, 4, 6, 12, 18, 24]) {
    for (const b of [0, 1, 2, 4, 6, 12, 18, 24]) assert.equal(effectiveDelay(a, b), Math.max(a, b), `${a}, ${b}`);
  }
  for (const invalid of [3, 5, 23, 25, Infinity, NaN, '24']) assert.equal(effectiveDelay(invalid, 0), 2, String(invalid));
});

test('location intervals cover 15 to 120 seconds and reveal choices cover immediate to 24 hours', () => {
  assert.deepEqual(UPDATE_INTERVAL_SECONDS, [15, 30, 45, 60, 75, 90, 105, 120]);
  assert.deepEqual(REVEAL_DELAY_HOURS, [0, 1, 2, 4, 6, 12, 18, 24]);
});

const encounter = {
  distanceMeters: 20,
  encounterAt: '2026-10-17T10:00:00.000Z',
  now: '2026-10-17T12:00:00.000Z',
  delayA: 0,
  delayB: 2,
  ageA: 24,
  ageB: 28,
  visibleA: true,
  visibleB: true,
  mutualPreferences: true,
  blocked: false,
  accurate: true,
};

test('an encounter requires at most 20 metres and the complete mutual delay', () => {
  assert.equal(canRevealEncounter(encounter), true);
  assert.equal(canRevealEncounter({ ...encounter, distanceMeters: 40 }), false);
  assert.equal(canRevealEncounter({ ...encounter, distanceMeters: 20.001 }), false);
  assert.equal(canRevealEncounter({ ...encounter, distanceMeters: -1 }), false);
  assert.equal(canRevealEncounter({ ...encounter, distanceMeters: NaN }), false);
  assert.equal(canRevealEncounter({ ...encounter, now: '2026-10-17T11:59:59.999Z' }), false);
  assert.equal(canRevealEncounter({ ...encounter, delayB: 0, now: encounter.encounterAt }), true);
  assert.equal(canRevealEncounter({ ...encounter, delayB: 0, now: '2026-10-17T09:59:59.999Z' }), false);
  const dayDelay = { ...encounter, delayA: 0, delayB: 24 };
  assert.equal(canRevealEncounter({ ...dayDelay, now: '2026-10-18T09:59:59.999Z' }), false);
  assert.equal(canRevealEncounter({ ...dayDelay, now: '2026-10-18T10:00:00.000Z' }), true);
  assert.equal(canRevealEncounter({ ...dayDelay, delayA: 24, delayB: 0, now: '2026-10-18T10:00:00.000Z' }), true);
});

test('adult, visibility, preference, block, and accuracy gates all apply', () => {
  for (const override of [
    { ageA: 17 }, { ageB: 17 }, { ageA: 131 }, { ageB: '28' },
    { visibleA: false }, { visibleB: false }, { mutualPreferences: false },
    { blocked: true }, { disconnected: true }, { disconnected: 'false' }, { disconnected: null }, { accurate: false }, { accurate: undefined },
    { encounterAt: 'invalid' }, { now: NaN },
  ]) assert.equal(canRevealEncounter({ ...encounter, ...override }), false, JSON.stringify(override));
  assert.equal(canRevealEncounter({ ...encounter, ageA: 105 }), true);
  assert.equal(canRevealEncounter(), false);
  assert.equal(canRevealEncounter({ ...encounter, encounterAt: new Date(encounter.encounterAt), now: Date.parse(encounter.now) }), true);
});

test('shuffle returns every identifier once without mutating or ordering by encounter time', () => {
  // These identifiers contain no dates; their input order represents oldest to newest.
  const ids = Object.freeze(['encounter-90', 'encounter-10', 'encounter-70', 'encounter-20']);
  let draws = 0;
  const shuffled = shuffleIds(ids, () => { draws++; return 0; });
  assert.notStrictEqual(shuffled, ids);
  assert.deepEqual([...shuffled].sort(), [...ids].sort());
  assert.equal(new Set(shuffled).size, ids.length);
  assert.notDeepEqual(shuffled, [...ids], 'a forced random draw should produce a nonchronological deck');
  assert.notDeepEqual(shuffled, [...ids].reverse(), 'reversing chronology is not a shuffle');
  assert.ok(draws > 0, 'the supplied random source must decide the order');
  assert.deepEqual(ids, ['encounter-90', 'encounter-10', 'encounter-70', 'encounter-20']);
  assert.deepEqual(shuffleIds([], () => 0), []);
  assert.deepEqual(shuffleIds(['only'], () => 0), ['only']);
});
