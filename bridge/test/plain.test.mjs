// node --test bridge/test/*.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { plain } from '../plain.mjs';

test('JSON values pass unchanged', () => {
  const value = { s: 'a', n: 1.5, b: false, z: null, list: [1, 'x', { deep: [true] }] };
  assert.deepEqual(plain(value, 'the result'), value);
  const bare = Object.assign(Object.create(null), { k: 1 });
  assert.deepEqual({ ...plain(bare, 'the result') }, { k: 1 });
});

test('undefined keeps its JSON meaning: null in an array, left out of an object', () => {
  assert.deepEqual(plain([1, undefined, 3], 'r'), [1, null, 3]);
  assert.deepEqual(plain({ a: 1, gone: undefined }, 'r'), { a: 1 });
});

test('values with no wire form are refused, naming where and what', () => {
  class Box {}
  const cases = [
    [new Box(), /the result is a Box, which has no wire form/],
    [Buffer.from('hi'), /the result is a Buffer/],
    [new Map(), /the result is a Map/],
    [new Date(0), /the result is a Date/],
    [{ list: [1, Number.NaN] }, /the result\.list\[1\] is NaN, which JSON cannot carry/],
    [Number.POSITIVE_INFINITY, /is Infinity/],
    [() => 1, /the result is a function/],
    [10n, /the result is a bigint/],
    [Symbol('s'), /the result is a symbol/],
  ];
  for (const [value, message] of cases) {
    assert.throws(() => plain(value, 'the result'), (error) => error.code === 'BRIDGE_PROTOCOL' && message.test(error.message));
  }
});
