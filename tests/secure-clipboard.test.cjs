// Run with Node.js 22.13+ / 24: node --test tests/secure-clipboard.test.cjs
// Executes the production ArkTS logic; only HarmonyOS and the clock are mocked.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { stripTypeScriptTypes } = require('node:module');

const source = fs.readFileSync(path.join(__dirname,
  '../entry/src/main/ets/security/SecureClipboard.ets'), 'utf8');
const script = stripTypeScriptTypes(source.replace(/^import .*;\r?\n/gm, '')
  .replace(/\bexport /g, '')) + `\n globalThis.api = {
    copySensitiveText, cancelPendingSensitiveClipboardClear,
    resumeSensitiveClipboardClear, disposeSensitiveClipboard
  };`;

function harness() {
  let now = 1000;
  let nextTimer = 0;
  const timers = new Map();
  const logs = [];
  const state = {
    text: '', source: '', revision: 0, clearCalls: 0, autoClear: true,
    failWrite: false, failMetadata: false, failSource: false, failClear: false,
    metadataZero: false, afterWrite: undefined, property: undefined,
    failureValue: Object.assign(new Error('DO-NOT-LOG-secret-payload'), { code: 12900005 })
  };
  function failure() {
    return state.failureValue;
  }
  function replace(text, source = 'Other App') {
    state.text = text;
    state.source = source;
    state.revision += 1;
  }
  const systemPasteboard = {
    getChangeCount() {
      if (state.failMetadata) throw failure();
      return state.metadataZero ? 0 : state.revision;
    },
    getDataSource() {
      if (state.failSource) throw failure();
      return state.source;
    },
    setDataSync(data) {
      if (state.failWrite) throw failure();
      replace(data.text, 'TimeAuth');
      state.property = data.property;
      state.afterWrite?.();
    },
    clearDataSync() {
      if (state.failClear) throw failure();
      state.clearCalls += 1;
      state.text = '';
      state.source = '';
    }
  };
  const context = vm.createContext({
    pasteboard: {
      getSystemPasteboard: () => systemPasteboard,
      MIMETYPE_TEXT_PLAIN: 'text/plain',
      ShareOption: { LOCALDEVICE: 1 },
      createData(mimeType, text) {
        assert.equal(mimeType, 'text/plain');
        return {
          text, property: {},
          getProperty() { return this.property; },
          setProperty(property) { this.property = property; }
        };
      }
    },
    readSecuritySettings: () => ({ clearClipboard: state.autoClear }),
    Date: { now: () => now },
    console: { error: (message) => logs.push(message) },
    setTimeout(callback, delay) {
      const id = ++nextTimer;
      timers.set(id, { callback, due: now + delay });
      return id;
    },
    clearTimeout(id) { timers.delete(id); }
  });
  vm.runInContext(script, context);
  function advance(milliseconds, runTimers = true) {
    now += milliseconds;
    if (!runTimers) return;
    for (;;) {
      const due = [...timers.entries()].filter(([, timer]) => timer.due <= now)
        .sort((a, b) => a[1].due - b[1].due)[0];
      if (!due) return;
      timers.delete(due[0]);
      due[1].callback();
    }
  }
  return { api: context.api, state, timers, logs, advance, replace };
}

test('copies locally and clears the still-owned value after 30 seconds', async () => {
  const h = harness();
  assert.equal(await h.api.copySensitiveText({}, 'generated-secret'), true);
  assert.equal(h.state.property.shareOption, 1);
  assert.equal(h.state.property.tag, 'timeauth-sensitive');
  h.advance(29999);
  assert.equal(h.state.text, 'generated-secret');
  h.advance(1);
  assert.equal(h.state.text, '');
  assert.equal(h.state.clearCalls, 1);
});

test('later copies get their own full deadline and stale callbacks are ignored', async () => {
  const h = harness();
  await h.api.copySensitiveText({}, 'first');
  const staleCallback = [...h.timers.values()][0].callback;
  h.advance(20000);
  await h.api.copySensitiveText({}, 'second');
  staleCallback();
  h.advance(10000);
  assert.equal(h.state.text, 'second');
  h.advance(20000);
  assert.equal(h.state.text, '');
  assert.equal(h.state.clearCalls, 1);
});

test('concurrent callers serialize writes and only clear the final copy', async () => {
  const h = harness();
  assert.deepEqual(await Promise.all([
    h.api.copySensitiveText({}, 'first'), h.api.copySensitiveText({}, 'second')
  ]), [true, true]);
  assert.equal(h.timers.size, 1);
  assert.equal(h.state.text, 'second');
  h.advance(30000);
  assert.equal(h.state.clearCalls, 1);
});

for (const app of ['Other App', 'TimeAuth']) {
  test(`does not clear a newer clipboard value copied by ${app}`, async () => {
    const h = harness();
    await h.api.copySensitiveText({}, 'generated-secret');
    h.replace('newer-user-value', app);
    h.advance(30000);
    h.api.resumeSensitiveClipboardClear();
    h.api.disposeSensitiveClipboard();
    assert.equal(h.state.text, 'newer-user-value');
    assert.equal(h.state.clearCalls, 0);
  });
}

test('an identical newer copy is still a distinct revision', async () => {
  const h = harness();
  await h.api.copySensitiveText({}, 'same-text');
  h.replace('same-text', 'TimeAuth');
  h.advance(30000);
  assert.equal(h.state.text, 'same-text');
  assert.equal(h.state.clearCalls, 0);
});

test('external write during ownership capture prevents arming cleanup', async () => {
  const h = harness();
  h.state.afterWrite = () => h.replace('newer-user-value');
  assert.equal(await h.api.copySensitiveText({}, 'generated-secret'), true);
  assert.equal(h.timers.size, 0);
  h.api.disposeSensitiveClipboard();
  assert.equal(h.state.text, 'newer-user-value');
});

test('changed data source blocks cleanup even if revision was reset', async () => {
  const h = harness();
  await h.api.copySensitiveText({}, 'generated-secret');
  h.state.source = 'Other App';
  h.state.text = 'newer-user-value';
  h.advance(30000);
  assert.equal(h.state.clearCalls, 0);
  assert.equal(h.state.text, 'newer-user-value');
});

test('failed and empty copy attempts retain the previous cleanup', async () => {
  const h = harness();
  await h.api.copySensitiveText({}, 'first');
  assert.equal(await h.api.copySensitiveText({}, ''), false);
  h.state.failWrite = true;
  assert.equal(await h.api.copySensitiveText({}, 'DO-NOT-LOG-secret-payload'), false);
  assert.equal(h.timers.size, 1);
  assert.equal(h.logs.length, 1);
  assert.match(h.logs[0], /12900005/);
  assert.doesNotMatch(h.logs.join('\n'), /DO-NOT-LOG|secret-payload/);
  h.advance(30000);
  assert.equal(h.state.text, '');
});

test('disabled automatic cleanup respects copied data and teardown', async () => {
  const h = harness();
  h.state.autoClear = false;
  await h.api.copySensitiveText({}, 'generated-secret');
  assert.equal(h.timers.size, 0);
  h.api.resumeSensitiveClipboardClear();
  h.api.disposeSensitiveClipboard();
  assert.equal(h.state.text, 'generated-secret');
});

test('disabling cleanup cancels an already scheduled clear', async () => {
  const h = harness();
  await h.api.copySensitiveText({}, 'generated-secret');
  h.state.autoClear = false;
  h.api.cancelPendingSensitiveClipboardClear();
  h.advance(60000);
  h.api.disposeSensitiveClipboard();
  assert.equal(h.state.text, 'generated-secret');
});

for (const metadataFailure of ['failMetadata', 'failSource', 'metadataZero']) {
  test(`${metadataFailure} skips cleanup without reporting a successful copy as failed`, async () => {
    const h = harness();
    h.state[metadataFailure] = true;
    assert.equal(await h.api.copySensitiveText({}, 'generated-secret'), true);
    assert.equal(h.state.text, 'generated-secret');
    assert.equal(h.timers.size, 0);
    h.api.disposeSensitiveClipboard();
    assert.equal(h.state.clearCalls, 0);
    assert.doesNotMatch(h.logs.join('\n'), /DO-NOT-LOG|secret-payload/);
  });
}

test('foreground return uses the original deadline after suspended timers', async () => {
  const h = harness();
  await h.api.copySensitiveText({}, 'generated-secret');
  h.advance(10000, false);
  h.api.resumeSensitiveClipboardClear();
  h.advance(19999);
  assert.equal(h.state.text, 'generated-secret');
  h.advance(1, false);
  h.api.resumeSensitiveClipboardClear();
  assert.equal(h.state.text, '');
  assert.equal(h.timers.size, 0);
});

test('expired foreground retry leaves a newer clipboard intact', async () => {
  const h = harness();
  await h.api.copySensitiveText({}, 'generated-secret');
  h.advance(45000, false);
  h.replace('newer-user-value', 'TimeAuth');
  h.api.resumeSensitiveClipboardClear();
  assert.equal(h.state.text, 'newer-user-value');
  assert.equal(h.state.clearCalls, 0);
});

for (const transientFailure of ['failClear', 'failMetadata', 'metadataZero']) {
  test(`${transientFailure} at deadline can retry on foreground`, async () => {
    const h = harness();
    await h.api.copySensitiveText({}, 'generated-secret');
    h.state[transientFailure] = true;
    h.advance(30000);
    assert.equal(h.state.text, 'generated-secret');
    h.state[transientFailure] = false;
    h.api.resumeSensitiveClipboardClear();
    assert.equal(h.state.text, '');
    assert.equal(h.state.clearCalls, 1);
    assert.doesNotMatch(h.logs.join('\n'), /DO-NOT-LOG|secret-payload/);
  });
}

test('teardown clears only pending owned data and cancels all timers', async () => {
  const h = harness();
  await h.api.copySensitiveText({}, 'generated-secret');
  h.api.disposeSensitiveClipboard();
  assert.equal(h.state.text, '');
  assert.equal(h.timers.size, 0);
  h.advance(60000);
  assert.equal(h.state.clearCalls, 1);
});

for (const errorValue of [null, undefined, 'DO-NOT-LOG-secret-payload']) {
  test(`copy failure logging handles ${typeof errorValue} thrown values`, async () => {
    const h = harness();
    h.state.failWrite = true;
    h.state.failureValue = errorValue;
    assert.equal(await h.api.copySensitiveText({}, 'generated-secret'), false);
    assert.equal(h.logs.length, 1);
    assert.match(h.logs[0], /code=-1/);
    assert.doesNotMatch(h.logs.join('\n'), /DO-NOT-LOG|secret-payload/);
  });
}
