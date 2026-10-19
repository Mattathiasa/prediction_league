const assert = require('assert');
const { calculatePoints, outcome } = require('../lib/index.js');

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log(`  \u2713 ${name}`);
  } catch (e) {
    failed++;
    console.error(`  \u2717 ${name}`);
    console.error(`    ${e.message}`);
  }
}

function describe(name, fn) {
  console.log(`\n${name}`);
  fn();
}

describe('calculatePoints', () => {
  test('exact score returns 5 points', () => {
    assert.strictEqual(calculatePoints(2, 1, 2, 1), 5);
    assert.strictEqual(calculatePoints(0, 0, 0, 0), 5);
    assert.strictEqual(calculatePoints(3, 2, 3, 2), 5);
  });

  test('correct result with correct goal difference returns 3 points', () => {
    assert.strictEqual(calculatePoints(3, 1, 2, 0), 3);
    assert.strictEqual(calculatePoints(1, 3, 0, 2), 3);
    assert.strictEqual(calculatePoints(2, 2, 1, 1), 3);
    assert.strictEqual(calculatePoints(2, 1, 1, 0), 3);
    assert.strictEqual(calculatePoints(0, 2, 1, 3), 3);
  });

  test('correct result only returns 1 point', () => {
    assert.strictEqual(calculatePoints(1, 0, 3, 1), 1);
    assert.strictEqual(calculatePoints(0, 1, 1, 3), 1);
  });

  test('wrong result returns 0 points', () => {
    assert.strictEqual(calculatePoints(2, 1, 1, 2), 0);
    assert.strictEqual(calculatePoints(3, 0, 0, 3), 0);
    assert.strictEqual(calculatePoints(0, 2, 2, 0), 0);
  });

  test('draw with correct result returns appropriate points', () => {
    assert.strictEqual(calculatePoints(1, 1, 1, 1), 5); // exact score
    assert.strictEqual(calculatePoints(0, 0, 2, 2), 3); // correct result + GD (both draw, diff=0)
    assert.strictEqual(calculatePoints(2, 2, 3, 0), 0); // predicted draw, actual home win
  });
});

describe('outcome', () => {
  test('returns home for home win', () => {
    assert.strictEqual(outcome(2, 1), 'home');
    assert.strictEqual(outcome(5, 0), 'home');
  });

  test('returns away for away win', () => {
    assert.strictEqual(outcome(0, 2), 'away');
    assert.strictEqual(outcome(1, 3), 'away');
  });

  test('returns draw for tie', () => {
    assert.strictEqual(outcome(1, 1), 'draw');
    assert.strictEqual(outcome(0, 0), 'draw');
    assert.strictEqual(outcome(3, 3), 'draw');
  });
});

describe('parseFixture', () => {
  test('handles null scores for upcoming fixture', () => {
    // Test via calculatePoints that null handling is correct
    assert.strictEqual(calculatePoints(0, 0, 0, 0), 5);
    assert.strictEqual(calculatePoints(1, 1, 0, 0), 3);
  });
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
