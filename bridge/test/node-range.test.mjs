// node --test bridge/test/*.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { satisfies } from '../node-range.mjs';

const E2E_0_23_1 = '^22.22.3 || >=24.8.0';

test("e2e 0.23.1's engines range", () => {
  assert.equal(satisfies('22.22.3', E2E_0_23_1), true);
  assert.equal(satisfies('v22.30.0', E2E_0_23_1), true);
  assert.equal(satisfies('22.22.2', E2E_0_23_1), false);
  assert.equal(satisfies('23.11.0', E2E_0_23_1), false);
  assert.equal(satisfies('24.7.9', E2E_0_23_1), false);
  assert.equal(satisfies('24.8.0', E2E_0_23_1), true);
  assert.equal(satisfies('26.0.0', E2E_0_23_1), true);
  assert.equal(satisfies('20.19.0', E2E_0_23_1), false);
});

test('comparators, caret, tilde and wildcards', () => {
  assert.equal(satisfies('18.5.0', '>=18 <20'), true);
  assert.equal(satisfies('20.0.0', '>=18 <20'), false);
  assert.equal(satisfies('20.1.0', '>= 20.1'), true);
  assert.equal(satisfies('20.2.0', '~20.1.4'), false);
  assert.equal(satisfies('20.1.9', '~20.1.4'), true);
  assert.equal(satisfies('0.3.9', '^0.3.1'), true);
  assert.equal(satisfies('0.4.0', '^0.3.1'), false);
  assert.equal(satisfies('22.9.1', '22.x'), true);
  assert.equal(satisfies('23.0.0', '22.x'), false);
  assert.equal(satisfies('22.0.0', '*'), true);
  assert.equal(satisfies('22.0.0', '>21'), true);
  assert.equal(satisfies('21.9.0', '>21'), false);
  assert.equal(satisfies('21.9.0', '<=21'), true);
});

test('an unreadable range throws instead of passing', () => {
  assert.throws(() => satisfies('22.0.0', ''), /cannot read engines range/);
  assert.throws(() => satisfies('22.0.0', '>=lts'), /cannot read version/);
  assert.throws(() => satisfies('22.0.0', '20 - 22'), /hyphen ranges/);
  assert.throws(() => satisfies('22.0.0', undefined), /cannot read engines range/);
});
