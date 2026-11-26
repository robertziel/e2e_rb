#!/usr/bin/env node
// e2e_rb bridge: hosts e2e sessions for a Ruby test runner.
//
// Wire: JSON-RPC 2.0 with LSP framing (Content-Length headers).
//   Ruby -> bridge: this process's stdin.
//   bridge -> Ruby: file descriptor 3, so anything e2e, an engine or a browser
//   prints to stdout can never corrupt the protocol stream.
//
// The bridge owns nothing a test decides: Ruby runs collection, retries and
// reporting; e2e (loaded from the PROJECT's node_modules) owns engines, models,
// the replay cache and secrets.

import { createWriteStream } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { satisfies } from './node-range.mjs';
import { plain } from './plain.mjs';

const PROTOCOL_VERSION = 1;

// Everything a stray console.log writes goes to stderr, never to the wire.
console.log = console.error;
console.info = console.error;

const out = createWriteStream(null, { fd: 3 });

function send(message) {
  const body = Buffer.from(JSON.stringify({ jsonrpc: '2.0', ...message }), 'utf8');
  out.write(`Content-Length: ${body.length}\r\n\r\n`);
  out.write(body);
}

function notify(method, params) {
  send({ method, params });
}

// ---------------------------------------------------------------- state

const state = {
  cwd: undefined,
  runner: undefined, // e2e/runner module
  sdk: undefined, // e2e module (expect, secrets, credentials)
  e2eVersion: undefined,
  host: undefined,
  session: undefined,
};

function requireState(key, what) {
  if (state[key] === undefined) throw protocolError(`${what} is not open`);
  return state[key];
}

// A member the e2e object does not have: a NoMethodError in Ruby.
function noMemberError(root, member) {
  const error = new Error(`${root} has no member ${JSON.stringify(member)}`);
  error.name = 'NoMember';
  error.code = 'BRIDGE_NO_MEMBER';
  error.member = member;
  return error;
}

function protocolError(message) {
  const error = new Error(message);
  error.name = 'BridgeProtocolError';
  error.code = 'BRIDGE_PROTOCOL';
  return error;
}

// ---------------------------------------------------------------- codec

function isLocator(value) {
  return (
    value !== null &&
    typeof value === 'object' &&
    typeof value.getByRole === 'function' &&
    typeof value.click === 'function' &&
    typeof value.nth === 'function'
  );
}

async function decode(value) {
  if (Array.isArray(value)) return Promise.all(value.map(decode));
  if (value === null || typeof value !== 'object') return value;
  if ('$regex' in value) return new RegExp(value.$regex.source, value.$regex.flags);
  if ('$locator' in value) {
    const resolved = await evaluate(value.$locator.root, value.$locator.chain);
    if (!isLocator(resolved)) throw protocolError('a $locator argument did not resolve to a locator');
    return resolved;
  }
  if ('$secret' in value) return state.sdk.secrets.get(value.$secret);
  if ('$credential' in value) {
    const credential = state.sdk.credentials.user(value.$credential);
    if (value.field !== 'username' && value.field !== 'password') {
      throw protocolError(`credential field must be username or password, got ${JSON.stringify(value.field)}`);
    }
    return credential[value.field];
  }
  const decoded = {};
  for (const [key, inner] of Object.entries(value)) decoded[key] = await decode(inner);
  return decoded;
}

function encodeResult(value) {
  if (isLocator(value)) return { kind: 'locator' };
  if (Array.isArray(value) && value.length > 0 && value.every(isLocator)) {
    return { kind: 'locators', count: value.length };
  }
  if (value === undefined) return { kind: 'value', value: null };
  return { kind: 'value', value: plain(value, 'the result') };
}

// Re-applies a call chain to a session fixture. Locators are immutable
// expressions, so re-evaluating a builder chain has no side effect.
async function evaluate(root, chain) {
  const session = requireState('session', 'a session');
  const fixtures = session.fixtures;
  if (!(root in fixtures)) {
    throw protocolError(`unknown fixture ${JSON.stringify(root)}; this target has: ${Object.keys(fixtures).join(', ')}`);
  }
  let target = fixtures[root];
  for (const step of chain) {
    if (target === null || target === undefined) {
      throw protocolError(`cannot call ${step.m} on ${String(target)}`);
    }
    const member = target[step.m];
    const args = await decode(step.a ?? []);
    if (typeof member === 'function') {
      target = await member.apply(target, args);
    } else if (member === undefined) {
      throw noMemberError(root, step.m);
    } else if (args.length > 0) {
      throw protocolError(`${step.m} is a property, not a method; it takes no arguments`);
    } else {
      target = member;
    }
  }
  return target;
}

function serializeError(error) {
  const e2e = state.runner?.isE2EError?.(error) === true;
  return {
    code: -32000,
    message: error instanceof Error ? error.message : String(error),
    data: {
      name: error?.name ?? 'Error',
      e2e,
      category: e2e ? error.category : bridgeCategory(error),
      e2eCode: typeof error?.code === 'string' ? error.code : undefined,
      member: error?.code === 'BRIDGE_NO_MEMBER' ? error.member : undefined,
      retryable: e2e ? error.retryable : false,
    },
  };
}

function bridgeCategory(error) {
  if (error?.code === 'BRIDGE_NO_MEMBER') return 'no_member';
  if (error?.code === 'BRIDGE_PROTOCOL') return 'bridge';
  return 'internal';
}

function serializeFailures(failures) {
  return (failures ?? []).map((failure) => ({
    name: failure?.name,
    message: failure?.message,
    code: failure?.code,
    category: failure?.category,
  }));
}

// ---------------------------------------------------------------- methods

const methods = {
  async initialize({ protocolVersion, cwd }) {
    if (protocolVersion !== PROTOCOL_VERSION) {
      throw protocolError(`protocol version mismatch: gem speaks ${protocolVersion}, bridge speaks ${PROTOCOL_VERSION}`);
    }
    if (typeof cwd !== 'string' || cwd === '') throw protocolError('initialize needs cwd');
    state.cwd = path.resolve(cwd);
    // Resolve e2e from the project, never from the gem: the project pins the version.
    const projectRequire = createRequire(path.join(state.cwd, 'package.json'));
    let runnerPath;
    try {
      runnerPath = projectRequire.resolve('e2e/runner');
    } catch {
      throw protocolError(`e2e is not installed in ${state.cwd}; run npm install e2e there`);
    }
    // Read the e2e package that resolved, and refuse a Node it does not support before loading it.
    const packageJsonPath = path.join(runnerPath.slice(0, runnerPath.lastIndexOf(`${path.sep}dist${path.sep}`)), 'package.json');
    const e2ePackage = projectRequire(packageJsonPath);
    const engines = e2ePackage.engines?.node;
    if (engines === undefined) throw protocolError(`e2e ${e2ePackage.version} states no engines.node; cannot check Node ${process.version}`);
    if (!satisfies(process.versions.node, engines)) {
      throw protocolError(`Node ${process.version} cannot run e2e ${e2ePackage.version} (it needs node ${engines}); set E2E_RB_NODE to a supported node`);
    }
    state.e2eVersion = e2ePackage.version;
    state.runner = await import(pathToFileURL(runnerPath).href);
    state.sdk = await import(pathToFileURL(projectRequire.resolve('e2e')).href);
    return { protocolVersion: PROTOCOL_VERSION, e2eVersion: state.e2eVersion, nodeVersion: process.version };
  },

  async 'host/open'({ config, target, headed }) {
    requireState('runner', 'the bridge (call initialize first)');
    if (state.host !== undefined) throw protocolError('a host is already open in this bridge');
    state.host = await state.runner.openHost({
      cwd: state.cwd,
      ...(config === undefined || config === null ? {} : { config }),
      ...(target === undefined || target === null ? {} : { target }),
      headed: headed === true,
      onNotice: (noticeTarget, message) => notify('notice', { target: noticeTarget, message }),
    });
    return { runId: state.host.runId, target: state.host.target };
  },

  async 'session/open'({ name, timeout, agent }) {
    const host = requireState('host', 'a host');
    if (state.session !== undefined) throw protocolError('a session is already open; close it first');
    state.session = await host.openSession({
      name,
      ...(timeout === undefined || timeout === null ? {} : { timeout }),
      ...(agent === undefined || agent === null ? {} : { agent }),
      onStep: (step) => notify('step', step),
    });
    return {
      attemptId: state.session.attemptId,
      artifactsDir: state.session.artifactsDir,
      tracePath: state.session.tracePath,
      fixtures: Object.keys(state.session.fixtures),
    };
  },

  async invoke({ root, chain }) {
    return encodeResult(await evaluate(root, chain));
  },

  async expect({ subject, matcher, args, negate, soft }) {
    requireState('session', 'a session');
    if (typeof matcher !== 'string' || !/^to[A-Z]/.test(matcher)) {
      throw protocolError(`not a matcher: ${JSON.stringify(matcher)}`);
    }
    const actual = await evaluate(subject.root, subject.chain);
    let expectation = soft === true ? state.sdk.expect.soft(actual) : state.sdk.expect(actual);
    if (negate === true) expectation = expectation.not;
    if (typeof expectation[matcher] !== 'function') {
      throw protocolError(`e2e has no matcher ${matcher} for ${subject.root}`);
    }
    await expectation[matcher](...(await decode(args ?? [])));
    return {};
  },

  async 'session/close'() {
    const session = requireState('session', 'a session');
    state.session = undefined;
    const failures = await session.close();
    return { failures: serializeFailures(failures), tracePath: session.tracePath };
  },

  async 'host/close'() {
    const host = state.host;
    state.host = undefined;
    state.session = undefined;
    if (host === undefined) return { failures: [] };
    return { failures: serializeFailures(await host.close()) };
  },

  async shutdown() {
    setImmediate(() => process.exit(0));
    return {};
  },
};

// ---------------------------------------------------------------- read loop

let buffer = Buffer.alloc(0);
let queue = Promise.resolve();

function handle(message) {
  queue = queue.then(async () => {
    const method = methods[message.method];
    try {
      if (method === undefined) throw protocolError(`unknown method ${JSON.stringify(message.method)}`);
      const result = await method(message.params ?? {});
      if (message.id !== undefined) send({ id: message.id, result });
    } catch (error) {
      if (message.id !== undefined) send({ id: message.id, error: serializeError(error) });
    }
  });
}

process.stdin.on('data', (chunk) => {
  buffer = Buffer.concat([buffer, chunk]);
  for (;;) {
    const headerEnd = buffer.indexOf('\r\n\r\n');
    if (headerEnd === -1) return;
    const header = buffer.subarray(0, headerEnd).toString('ascii');
    const match = /Content-Length: *(\d+)/i.exec(header);
    if (match === null) {
      console.error(`e2e_rb bridge: frame without Content-Length: ${header}`);
      process.exit(70);
    }
    const length = Number(match[1]);
    const start = headerEnd + 4;
    if (buffer.length < start + length) return;
    const body = buffer.subarray(start, start + length).toString('utf8');
    buffer = buffer.subarray(start + length);
    handle(JSON.parse(body));
  }
});

// Ruby went away: close what is open, then exit.
process.stdin.on('end', () => {
  queue = queue.then(async () => {
    if (state.host !== undefined) {
      try {
        const failures = await state.host.close();
        for (const failure of failures) console.error(`e2e_rb bridge: host close: ${failure.message}`);
        if (failures.length > 0) process.exit(1);
      } catch (error) {
        console.error('e2e_rb bridge: host close failed:', error);
        process.exit(1);
      }
    }
    process.exit(0);
  });
});
