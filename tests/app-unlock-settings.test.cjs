'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function clean(source) {
  return source.replace(/^import[\s\S]*?;\r?\n/gm, '').replace(/\bexport /g, '');
}

function loadSession() {
  const storage = new Map();
  const sandbox = { AppStorage: { setOrCreate: (key, value) => storage.set(key, value) } };
  const source = clean(read('entry/src/main/ets/security/AppSession.ets')) +
    '\nglobalThis.api={configureAppUnlock,isAppUnlockRequired,isAppSessionUnlocked,appSessionEpoch,' +
    'lockAppSession,setAppSessionForeground,unlockAppSession};';
  vm.runInNewContext(stripTypeScriptTypes(source, { mode: 'transform' }), sandbox);
  return { ...sandbox.api, storage };
}

function loadSettings() {
  const values = new Map();
  let flushFails = false;
  const store = {
    getSync(key, fallback) { return values.has(key) ? values.get(key) : fallback; },
    putSync(key, value) { values.set(key, value); },
    flush(callback) {
      if (typeof callback === 'function') {
        callback(flushFails ? { code: 1 } : undefined);
        return;
      }
      return flushFails ? Promise.reject(new Error('disk')) : Promise.resolve();
    }
  };
  const sandbox = {
    preferences: { getPreferencesSync(_context, options) { assert.equal(options.name, 'timeauth_preferences'); return store; } },
    console: { error() {} }
  };
  const source = clean(read('entry/src/main/ets/security/SecuritySettingsManager.ets')) +
    '\nglobalThis.api={readSecuritySettings,saveAppUnlockEnabled};';
  vm.runInNewContext(stripTypeScriptTypes(source, { mode: 'transform' }), sandbox);
  return { ...sandbox.api, values, setFlushFailure: value => { flushFails = value; } };
}

test('App unlock preference defaults off while other security defaults stay on', () => {
  const e = loadSettings();
  assert.deepEqual(JSON.parse(JSON.stringify(e.readSecuritySettings({}))), {
    hideTaskPreview: true, clearClipboard: true, appUnlockEnabled: false
  });
});

test('App unlock preference persists and a failed flush reports failure', async () => {
  const e = loadSettings();
  assert.equal(await e.saveAppUnlockEnabled({}, true), true);
  assert.equal(e.readSecuritySettings({}).appUnlockEnabled, true);
  e.setFlushFailure(true);
  assert.equal(await e.saveAppUnlockEnabled({}, false), false);
  assert.equal(e.readSecuritySettings({}).appUnlockEnabled, true);
});

test('session fails closed before preference load, then auto-opens only when App unlock is disabled', () => {
  const e = loadSession();
  assert.equal(e.isAppUnlockRequired(), true);
  assert.equal(e.isAppSessionUnlocked(), false);
  e.configureAppUnlock(false);
  assert.equal(e.isAppUnlockRequired(), false);
  assert.equal(e.isAppSessionUnlocked(), true);
  e.setAppSessionForeground(false);
  assert.equal(e.isAppSessionUnlocked(), false);
  e.setAppSessionForeground(true);
  assert.equal(e.isAppSessionUnlocked(), true);
});

test('enabled App unlock remains locked after background until explicit system-auth success', () => {
  const e = loadSession();
  e.configureAppUnlock(true, true);
  assert.equal(e.isAppSessionUnlocked(), true);
  e.setAppSessionForeground(false);
  e.setAppSessionForeground(true);
  assert.equal(e.isAppSessionUnlocked(), false);
  const epoch = e.appSessionEpoch();
  assert.equal(e.unlockAppSession(epoch), true);
  assert.equal(e.isAppSessionUnlocked(), true);
});

test('settings UI verifies before persisting an enable and exposes a dedicated toggle', () => {
  const source = read('entry/src/main/ets/features/settings/SettingsPage.ets');
  assert.match(source, /id\('settings-app-unlock'\)/);
  const method = source.slice(source.indexOf('private async setAppUnlock'), source.indexOf('private themeLabel'));
  assert.ok(method.indexOf('this.appUnlockRequest.verify') >= 0);
  assert.ok(method.indexOf('saveAppUnlockEnabled') > method.indexOf('this.appUnlockRequest.verify'));
  assert.match(method, /configureAppUnlock\(value, value\)/);
});

test('ability loads the persisted preference and AppRoot bypasses UnlockPage when the transient session is open', () => {
  const ability = read('entry/src/main/ets/entryability/EntryAbility.ets');
  const rootSource = read('entry/src/main/ets/app/AppRoot.ets');
  assert.match(ability, /configureAppUnlock\(readSecuritySettings\(this\.context\)\.appUnlockEnabled\)/);
  assert.match(rootSource, /this\.unlocked \? ScreenSecurityPage\.AUTHENTICATOR : ScreenSecurityPage\.UNLOCK/);
  assert.match(rootSource, /if \(!this\.unlocked\) \{\s*UnlockPage\(\)/);
});

test('all four locale files expose identical App-unlock keys', () => {
  const locales = ['base', 'zh_Hans', 'zh_Hant_TW', 'zh_Hant_HK'];
  let expected;
  for (const locale of locales) {
    const entries = JSON.parse(read(`entry/src/main/resources/${locale}/element/authenticator_live.json`)).string;
    const keys = entries.map(item => item.name);
    assert.ok(keys.includes('auth_live_unlock_setting_detail'));
    assert.ok(keys.includes('auth_live_unlock_setting_failed'));
    if (expected === undefined) expected = keys;
    else assert.deepEqual(keys, expected);
  }
});
