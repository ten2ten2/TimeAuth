'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const base = 'entry/src/main/ets/features/authenticator/';
const storeSource = read(base + 'AuthenticatorPreviewStore.ets');
const pageSource = read(base + 'AuthenticatorPage.ets');
const cardSource = read('entry/src/main/ets/components/OtpCard.ets');
const plain = value => JSON.parse(JSON.stringify(value));

function fixture() {
  return [
    { id: 'a', issuer: 'GitHub', account: 'one@example.com', code: '001 234', remainingSeconds: 20,
      periodSeconds: 30, kind: 'TOTP', accentColor: '#24292F', isFavorite: true },
    { id: 'b', issuer: 'GitHub', account: 'two@example.com', code: '567 890', remainingSeconds: 20,
      periodSeconds: 30, kind: 'TOTP', accentColor: '#24292F', isFavorite: false },
    { id: 'c', issuer: 'Steam', account: 'Demo', code: 'R5K2P', remainingSeconds: 20,
      periodSeconds: 30, kind: 'STEAM', accentColor: '#1B2838', isFavorite: false }
  ];
}

function load() {
  const env = { writes: [], alerts: [], timers: new Map(), closedSwipes: 0, context: {}, nextTimer: 0 };
  const uiContext = {
    getHostContext: () => env.context,
    showAlertDialog: options => { if (env.dialogFails) throw new Error('native unavailable'); env.alerts.push(options); }
  };
  const sandbox = {
    mockRepository: { getOtpItems: fixture }, uiContext,
    $r: (key, ...args) => ({ key, args }),
    ListScroller: class { closeAllSwipeActions() { env.closedSwipes++; } },
    copySensitiveText: (_context, text) => {
      env.writes.push(text);
      return env.copyHook ? env.copyHook(text) : Promise.resolve(true);
    },
    setTimeout: fn => { const id = ++env.nextTimer; env.timers.set(id, fn); return id; },
    clearTimeout: id => env.timers.delete(id)
  };
  const context = vm.createContext(sandbox);
  const removeImports = text => text.replace(/^import[\s\S]*?;\r?\n/gm, '');
  const storeTs = removeImports(storeSource).replace(/\bexport /g, '');
  // Execute actual lifecycle/controller code, but deliberately exclude ArkUI builders.
  const prefix = pageSource.slice(0, pageSource.indexOf('  @Builder'));
  const pageTs = removeImports(prefix).replace('@Component\n', '')
    .replace('export struct AuthenticatorPage', 'class AuthenticatorPage')
    .replace(/@State\s+/g, '') + '\n getUIContext() { return uiContext; }\n}\n';
  const code = storeTs + '\n' + pageTs + '\nglobalThis.loaded = { AuthenticatorPreviewStore, authenticatorPreviewStore,' +
    ' AuthenticatorPage, otpClipboardValue, otpPreviewRenderKey, validOtpPreviewLabels };';
  vm.runInContext(stripTypeScriptTypes(code, { mode: 'transform' }), context);
  const api = sandbox.loaded;
  env.store = api.authenticatorPreviewStore;
  env.page = new api.AuthenticatorPage();
  env.page.aboutToAppear();
  return Object.assign(env, api);
}
const settle = () => new Promise(resolve => setImmediate(resolve));

test('store owns its seed and returns detached snapshots', () => {
  const e = load(), seed = fixture(), store = new e.AuthenticatorPreviewStore(seed);
  seed[0].issuer = 'outside';
  const items = store.readItems(); items[0].account = 'outside'; items.pop();
  const found = store.findItem('a'); found.code = 'outside';
  assert.deepEqual(plain(store.readItems()), fixture());
});
test('editing trims labels and preserves IDs, OTP values, kind, timing and order', () => {
  const e = load(); assert.equal(e.store.updateLabels('a', '  Work  ', '  user@example.com  '), true);
  const expected = fixture(); expected[0].issuer = 'Work'; expected[0].account = 'user@example.com';
  assert.deepEqual(plain(e.store.readItems()), expected);
});
test('empty and oversized labels are rejected without mutation', () => {
  const e = load();
  for (const [issuer, account] of [[' ', 'x'], ['x'.repeat(129), 'x'], ['x', 'x'.repeat(257)]]) {
    assert.equal(e.store.updateLabels('a', issuer, account), false);
  }
  assert.deepEqual(plain(e.store.readItems()), fixture());
  assert.equal(e.validOtpPreviewLabels('x'.repeat(128), 'x'.repeat(256)), true);
});
test('account is optional and blank accounts are trimmed', () => {
  const e = load(); assert.equal(e.store.updateLabels('a', 'Service', '  '), true);
  assert.equal(e.store.findItem('a').account, '');
});
test('unknown IDs cannot edit, delete or resurrect an entry', () => {
  const e = load(); assert.equal(e.store.findItem('missing'), undefined);
  assert.equal(e.store.updateLabels('missing', 'x', ''), false);
  assert.equal(e.store.removeItem('missing'), false);
  assert.equal(e.store.removeItem('a'), true);
  assert.equal(e.store.updateLabels('a', 'x', ''), false);
});
test('delete targets ID rather than duplicate issuer names or positions', () => {
  const e = load(); e.store.removeItem('a');
  assert.deepEqual(plain(e.store.readItems()).map(x => x.id), ['b', 'c']);
});
test('clipboard formatting preserves leading zeroes, 8 digits and Steam characters', () => {
  const e = load();
  assert.equal(e.otpClipboardValue('001 234'), '001234');
  assert.equal(e.otpClipboardValue('00 123 456'), '00123456');
  assert.equal(e.otpClipboardValue('R5K2P'), 'R5K2P');
  assert.equal(e.otpClipboardValue(' 001\t234\n'), '001234');
});
test('content-based render keys change after edits and remain stable for unchanged entries', () => {
  const e = load(), a = e.otpPreviewRenderKey(e.store.findItem('a')),
    b = e.otpPreviewRenderKey(e.store.findItem('b'));
  e.store.updateLabels('a', 'Changed', '');
  assert.notEqual(e.otpPreviewRenderKey(e.store.findItem('a')), a);
  assert.equal(e.otpPreviewRenderKey(e.store.findItem('b')), b);
  assert.match(pageSource, /\(item: OtpItem\) => otpPreviewRenderKey\(item\)/);
});
test('opening Delete shows account identity but does not remove it', () => {
  const e = load(); e.page.confirmDelete('b');
  assert.equal(e.alerts.length, 1);
  assert.deepEqual(plain(e.alerts[0].message.args), ['GitHub', 'two@example.com']);
  assert.equal(e.alerts[0].primaryButton.defaultFocus, true);
  assert.equal(e.store.readItems().length, 3);
  assert.equal(e.writes.length, 0);
});
test('Cancel and system dismissal do not delete and allow another dialog', () => {
  const e = load(); e.page.confirmDelete('a'); e.alerts[0].primaryButton.action();
  e.page.confirmDelete('a'); e.alerts[1].cancel();
  assert.equal(e.page.deleteDialogOpen, false);
  assert.deepEqual(plain(e.store.readItems()), fixture());
});
test('only affirmative Delete removes the captured stable ID', () => {
  const e = load(); e.page.confirmDelete('b');
  e.store.removeItem('a'); // Index changed after confirmation was opened.
  e.alerts[0].secondaryButton.action();
  assert.deepEqual(plain(e.page.items).map(x => x.id), ['c']);
  assert.equal(e.writes.length, 0);
});
test('repeated Delete taps cannot stack dialogs', () => {
  const e = load(); e.page.confirmDelete('a'); e.page.confirmDelete('b');
  assert.equal(e.alerts.length, 1);
});
test('a stale dialog callback cannot delete after page disposal', () => {
  const e = load(); e.page.confirmDelete('a'); e.page.aboutToDisappear();
  e.alerts[0].secondaryButton.action();
  assert.equal(e.store.readItems().length, 3);
});
test('native dialog failure unlocks the guard and reports failure without deleting', () => {
  const e = load(); e.dialogFails = true; e.page.confirmDelete('a');
  assert.equal(e.page.deleteDialogOpen, false);
  assert.equal(e.page.feedbackText.key, 'app.string.auth_action_failed');
  assert.equal(e.store.readItems().length, 3);
});
test('edit drafts do not mutate the store until Save', () => {
  const e = load(); e.page.openEditor('a'); e.page.editIssuer = 'Work';
  assert.equal(e.store.findItem('a').issuer, 'GitHub');
  e.page.saveEdit();
  assert.equal(e.store.findItem('a').issuer, 'Work');
  assert.equal(e.page.items[0].issuer, 'Work');
  assert.equal(e.page.showEditor, false);
  assert.equal(e.writes.length, 0);
});
test('cancelled drafts are discarded and another editor loads the correct account', () => {
  const e = load(); e.page.openEditor('a'); e.page.editIssuer = 'Unsaved'; e.page.showEditor = false;
  e.page.openEditor('b');
  assert.equal(e.page.editIssuer, 'GitHub'); assert.equal(e.page.editAccount, 'two@example.com');
  assert.equal(e.store.findItem('a').issuer, 'GitHub');
});
test('invalid edit keeps the editor open without changing the store', () => {
  const e = load(); e.page.openEditor('a'); e.page.editIssuer = '  '; e.page.saveEdit();
  assert.equal(e.page.showEditor, true);
  assert.equal(e.page.feedbackText.key, 'app.string.auth_edit_failed');
  assert.equal(e.store.findItem('a').issuer, 'GitHub');
});
test('mock edits and removals survive tab/page reconstruction in the current process', () => {
  const e = load(); e.page.openEditor('a'); e.page.editIssuer = 'Work'; e.page.saveEdit();
  e.page.confirmDelete('b'); e.alerts[0].secondaryButton.action(); e.page.aboutToDisappear();
  const next = new e.AuthenticatorPage(); next.aboutToAppear();
  assert.deepEqual(plain(next.items).map(x => [x.id, x.issuer]), [['a', 'Work'], ['c', 'Steam']]);
});
test('empty preview state survives reconstruction and a new store resets demo fixtures', () => {
  const e = load(); fixture().forEach(x => e.store.removeItem(x.id));
  const next = new e.AuthenticatorPage(); next.aboutToAppear(); assert.equal(next.items.length, 0);
  assert.equal(new e.AuthenticatorPreviewStore(fixture()).readItems().length, 3);
});
test('card controller copies the current store value without display spacing', async () => {
  const e = load(); e.page.copyItem('a'); await settle();
  assert.deepEqual(e.writes, ['001234']);
  assert.equal(e.page.feedbackText.key, 'app.string.security_copy_success');
});
test('tapping an exposed card dismisses actions without copying', () => {
  const e = load(); e.page.swipedItemId = 'a'; e.page.copyItem('a');
  assert.equal(e.closedSwipes, 1); assert.equal(e.writes.length, 0);
});
test('missing clipboard context and rejected writes produce failure feedback', async () => {
  const e = load(); e.context = undefined; e.page.copyItem('a');
  assert.equal(e.page.feedbackText.key, 'app.string.security_copy_failed');
  assert.equal(e.writes.length, 0);
  e.context = {}; e.copyHook = () => Promise.reject(new Error('native failed'));
  e.page.copyItem('a'); await settle();
  assert.equal(e.page.feedbackText.key, 'app.string.security_copy_failed');
});
test('out-of-order clipboard completions do not overwrite newer feedback', async () => {
  const e = load(), completions = [];
  e.copyHook = () => new Promise(resolve => completions.push(resolve));
  e.page.copyItem('a'); e.page.copyItem('c');
  completions[1](true); await settle(); completions[0](false); await settle();
  assert.equal(e.page.feedbackText.key, 'app.string.security_copy_success');
});
test('page disposal clears feedback timers and ignores late clipboard callbacks', async () => {
  const e = load(); e.page.showFeedback({ key: 'first' }); e.page.showFeedback({ key: 'second' });
  assert.equal(e.timers.size, 1);
  let complete; e.copyHook = () => new Promise(resolve => { complete = resolve; });
  e.page.copyItem('a'); e.page.aboutToDisappear(); complete(true); await settle();
  assert.equal(e.timers.size, 0); assert.equal(e.page.feedbackVisible, false);
});
test('UI contract preserves header, removes search/theme controls and limits add menu to two entries', () => {
  assert.match(pageSource, /title: \$r\('app.string.auth_title'\)/);
  assert.match(pageSource, /subtitle: \$r\('app.string.auth_subtitle'\)/);
  assert.doesNotMatch(pageSource, /SearchField|searchText|ThemePreference|theme_light|theme_dark/);
  const menu = pageSource.slice(pageSource.indexOf('  AddMenu()'), pageSource.indexOf('  SwipeActions('));
  assert.equal((menu.match(/MenuItem\(/g) || []).length, 2);
  assert.match(menu, /auth_scan_qr/); assert.match(menu, /auth_manual_entry/);
  assert.doesNotMatch(menu, /auth_import_photo|auth_steam_code/);
  assert.match(pageSource, /\.bindMenu\(this.AddMenu,/);
});
test('UI contract uses one native whole-card button and reveal-only swipe actions', () => {
  assert.equal((cardSource.match(/Button\(/g) || []).length, 1);
  assert.match(cardSource, /stateEffect: true/);
  assert.match(cardSource, /this.onCopy\(this.item.code, this.item.issuer\)/);
  assert.doesNotMatch(cardSource, /common_copy|Text\('›'\)|openEditor|bindContextMenu/);
  assert.match(pageSource, /actionAreaDistance: 0/);
  assert.match(pageSource, /edgeEffect: SwipeEdgeEffect.None/);
  assert.doesNotMatch(pageSource, /onAction\s*:/);
  assert.equal((pageSource.match(/authenticatorPreviewStore.removeItem\(/g) || []).length, 1);
  assert.match(pageSource, /\.hitTestBehavior\(HitTestMode.None\)/);
  assert.match(pageSource, /\.bindSheet\(\$\$this.showEditor/);
});
test('all new strings have matching keys and placeholders in every supported locale', () => {
  const locales = ['base', 'zh_Hans', 'zh_Hant_TW', 'zh_Hant_HK'];
  let expected;
  for (const locale of locales) {
    const entries = JSON.parse(read(`entry/src/main/resources/${locale}/element/authenticator.json`)).string;
    const keys = entries.map(x => x.name);
    assert.equal(new Set(keys).size, keys.length);
    const signatures = entries.map(x => [x.name, (x.value.match(/%s/g) || []).length]);
    if (!expected) expected = signatures; else assert.deepEqual(signatures, expected);
    entries.forEach(x => assert.ok(x.value.trim().length));
  }
});
test('preview never introduces secret fields, persistent storage or permission requests', () => {
  assert.doesNotMatch(storeSource, /@kit\.|preferences|relationalStore|fileIo|console\./);
  assert.doesNotMatch(pageSource, /requestPermissionsFromUser|editSecret|secret:\s|console\./);
});
