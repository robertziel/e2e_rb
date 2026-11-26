// Results cross the wire as JSON values only. A class instance, a Buffer, a Map, a function,
// a non-finite number has no faithful wire form, so it is refused with its type instead of
// arriving in Ruby as {} or a byte array. `undefined` keeps its JSON meaning: null inside
// an array, left out of an object.

export function wireError(message) {
  const error = new Error(message);
  error.name = 'BridgeProtocolError';
  error.code = 'BRIDGE_PROTOCOL';
  return error;
}

export function plain(value, where) {
  if (value === null || typeof value === 'string' || typeof value === 'boolean') return value;
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw wireError(`${where} is ${value}, which JSON cannot carry`);
    return value;
  }
  if (Array.isArray(value)) {
    return value.map((inner, index) => (inner === undefined ? null : plain(inner, `${where}[${index}]`)));
  }
  if (typeof value === 'object') {
    const proto = Object.getPrototypeOf(value);
    if (proto !== Object.prototype && proto !== null) {
      throw wireError(`${where} is a ${value.constructor?.name ?? 'non-plain object'}, which has no wire form`);
    }
    const out = {};
    for (const [key, inner] of Object.entries(value)) {
      if (inner !== undefined) out[key] = plain(inner, `${where}.${key}`);
    }
    return out;
  }
  throw wireError(`${where} is a ${typeof value}, which has no wire form`);
}
