// Exercise the actual component lifecycle/event methods with mocked platform services.
// Decorators/builders are excluded: this is not an ArkUI renderer or an ArkTS build check.
const assert = require('node:assert/strict');
const { before, beforeEach, afterEach, test } = require('node:test');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const directory = join(__dirname, '../entry/src/main/ets/features/generator');
const storage = new Map();
const panels = [];
const copies = [];
let core, sessions, settings, Panel, Page, generated = [], failureMode, failFlush = false;
function url(source) {
  return `data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(source, { mode: 'transform' })).toString('base64')}`;
}
function read(name) { return readFileSync(join(directory, name), 'utf8'); }
function replaceImports(source, modules) {
  for (const [name, target] of Object.entries(modules)) source = source.replaceAll(`'${name}'`, JSON.stringify(target));
  return source;
}
function componentMethods(source, name) {
  return source.slice(0, source.indexOf('  @Builder') >= 0 ? source.indexOf('  @Builder') : source.indexOf('  build()'))
    .replace(/import .* from '..\/..\/[^']+';\n/g, '')
    .replace(/import .* from '.\/GeneratorOptionToggle';\n/g, '')
    .replace(/import .* from '.\/GeneratorPanel';\n/g, '')
    .replace('@Component\n', '').replace(`export struct ${name}`, `export class ${name}`)
    .replace(/@Watch\('[^']+'\)\s*/g, '').replace(/@(Prop|State|Link)\s*/g, '') + '\n}';
}
function indexFor(mode) { return mode === core.GeneratorMode.PIN ? 2 : mode === core.GeneratorMode.PASSPHRASE ? 1 : 0; }
function activate(panel, value) {
  panel.selectedIndex = value ? indexFor(panel.mode) : (indexFor(panel.mode) + 1) % 3;
  panel.onSelectedIndexChanged();
}
function panel(mode, active = true) {
  const value = new Panel();
  value.mode = mode; value.selectedIndex = active ? indexFor(mode) : (indexFor(mode) + 1) % 3;
  panels.push(value); value.aboutToAppear();
  return value;
}
async function settle() { await Promise.resolve(); await Promise.resolve(); }

before(async () => {
  const coreUrl = url(read('GeneratorCore.ets'));
  core = await import(coreUrl);
  globalThis.__generatorTabsMock = {
    generate(options) {
      generated.push({ mode: options.mode, length: options.length, words: options.wordCount, pinLength: options.pinLength });
      if (options.mode === failureMode) throw new core.PasswordGenerationError(core.GeneratorFailure.UNAVAILABLE);
      if (options.mode === core.GeneratorMode.PIN) {
        return new core.PasswordResult('0' + String(generated.length).padStart(options.pinLength - 1, '1'),
          options.pinLength * Math.log2(10));
      }
      return new core.PasswordResult(`${options.mode}-result-${generated.length}`, options.mode === 'password' ? 100 : 77.55);
    },
    copy(_context, value) { return new Promise(resolve => copies.push({ value, resolve })); },
    preferences: {
      getPreferencesSync() {
        return {
          getSync: (key, fallback) => storage.has(key) ? storage.get(key) : fallback,
          putSync: (key, value) => storage.set(key, value),
          flush: async () => { if (failFlush) throw new Error('flush failed'); }
        };
      }
    }
  };
  const prefUrl = url('export const preferences = globalThis.__generatorTabsMock.preferences;');
  const settingsUrl = url(replaceImports(read('GeneratorSettings.ets'), {
    './GeneratorCore': coreUrl, '@kit.ArkData': prefUrl, '@kit.AbilityKit': url('export const common = {};')
  }));
  settings = await import(settingsUrl);
  const sessionUrl = url(replaceImports(read('GeneratorSession.ets'), { './GeneratorCore': coreUrl }));
  sessions = await import(sessionUrl);
  const generatorUrl = url('export const generatePassword = globalThis.__generatorTabsMock.generate;');
  const deps = { './GeneratorCore': coreUrl, './GeneratorSettings': settingsUrl,
    './GeneratorSession': sessionUrl, './PasswordGenerator': generatorUrl };
  Panel = (await import(url(replaceImports(componentMethods(read('GeneratorPanel.ets'), 'GeneratorPanel'), deps) +
    '\nconst copySensitiveText = globalThis.__generatorTabsMock.copy;\nconst $r = name => name;'))).GeneratorPanel;
  Page = (await import(url(replaceImports(componentMethods(read('GeneratorPage.ets'), 'GeneratorPage'), deps)))).GeneratorPage;
  Panel.prototype.getUIContext = Page.prototype.getUIContext = () => ({ getHostContext: () => ({}) });
  delete globalThis.__generatorTabsMock;
});
beforeEach(() => { sessions.clearGeneratorSession(); storage.clear(); generated = []; failureMode = undefined; failFlush = false; copies.length = 0; });
afterEach(() => { for (const value of panels.splice(0)) value.aboutToDisappear(); });

test('only the first visible visit generates; both tabs retain their own result and reveal state', () => {
  const password = panel(core.GeneratorMode.PASSWORD);
  const phrase = panel(core.GeneratorMode.PASSPHRASE, false);
  assert.equal(generated.length, 1);
  assert.equal(phrase.value, '');
  const original = password.value;
  password.revealed = false;
  activate(password, false); activate(phrase, true);
  assert.equal(generated.length, 2);
  assert.equal(phrase.options.mode, core.GeneratorMode.PASSPHRASE);
  const originalPhrase = phrase.value;
  for (let n = 0; n < 3; n++) {
    activate(phrase, false); activate(password, true);
    assert.equal(password.value, original);
    assert.equal(password.revealed, false);
    assert.equal(password.canCopy(), true);
    activate(password, false); activate(phrase, true);
    assert.equal(phrase.value, originalPhrase);
    assert.equal(phrase.canCopy(), true);
  }
  assert.equal(generated.length, 2);
});

test('draft changes stay within their tab and require explicit regeneration', async () => {
  const password = panel(core.GeneratorMode.PASSWORD);
  const original = password.value;
  password.options.length = 64; password.optionsChanged();
  assert.equal(password.value, original);
  assert.equal(password.canCopy(), false);
  // Leaving before the debounce deadline still persists this tab's valid settings.
  activate(password, false);
  const phrase = panel(core.GeneratorMode.PASSPHRASE);
  const phraseValue = phrase.value;
  phrase.options.wordCount = 8; phrase.optionsChanged();
  assert.equal(phrase.value, phraseValue);
  activate(phrase, false); activate(password, true);
  await settle();
  assert.equal(settings.readGeneratorOptions({}, core.GeneratorMode.PASSWORD).options.length, 64);
  assert.equal(settings.readGeneratorOptions({}, core.GeneratorMode.PASSPHRASE).options.wordCount, 8);
  assert.equal(password.value, original);
  assert.equal(password.canCopy(), false);
  password.regenerate(false);
  assert.notEqual(password.value, original);
  assert.equal(password.canCopy(), true);
  assert.equal(phrase.value, phraseValue);
  assert.equal(phrase.canCopy(), false);
  assert.equal(generated.at(-1).length, 64);
});

test('page recreation retains both results; process reset restores only saved rules', async () => {
  const password = panel(core.GeneratorMode.PASSWORD);
  password.options.length = 32; password.optionsChanged(); password.regenerate(false);
  const phrase = panel(core.GeneratorMode.PASSPHRASE);
  phrase.options.wordCount = 9; phrase.optionsChanged(); phrase.regenerate(false);
  const oldPassword = password.value, oldPhrase = phrase.value;
  password.aboutToDisappear(); phrase.aboutToDisappear();
  const count = generated.length;
  const restoredPassword = panel(core.GeneratorMode.PASSWORD);
  const restoredPhrase = panel(core.GeneratorMode.PASSPHRASE);
  assert.equal(restoredPassword.value, oldPassword);
  assert.equal(restoredPhrase.value, oldPhrase);
  assert.equal(generated.length, count);
  assert.equal(restoredPassword.revealed, false);
  assert.equal(restoredPhrase.revealed, false);
  for (const value of panels.splice(0)) value.aboutToDisappear();
  await settle(); sessions.clearGeneratorSession();
  const freshPassword = panel(core.GeneratorMode.PASSWORD);
  const freshPhrase = panel(core.GeneratorMode.PASSPHRASE);
  assert.notEqual(freshPassword.value, oldPassword);
  assert.notEqual(freshPhrase.value, oldPhrase);
  assert.equal(freshPassword.options.length, 32);
  assert.equal(freshPhrase.options.wordCount, 9);
  assert.equal([...storage.values()].some(value => value.includes('-result-')), false);
});

test('a failed tab does not clear the other result or silently retry on return', () => {
  const password = panel(core.GeneratorMode.PASSWORD);
  const original = password.value;
  activate(password, false);
  failureMode = core.GeneratorMode.PASSPHRASE;
  const phrase = panel(core.GeneratorMode.PASSPHRASE);
  assert.equal(phrase.generationFailure, core.GeneratorFailure.UNAVAILABLE);
  assert.equal(phrase.canCopy(), false);
  activate(phrase, false); activate(password, true);
  assert.equal(password.value, original);
  assert.equal(password.canCopy(), true);
  activate(password, false); activate(phrase, true);
  assert.equal(generated.length, 2);
  phrase.aboutToDisappear();
  const recreated = panel(core.GeneratorMode.PASSPHRASE);
  assert.equal(generated.length, 2);
  assert.equal(recreated.generationFailure, core.GeneratorFailure.UNAVAILABLE);
  failureMode = undefined;
  recreated.regenerate(false);
  assert.equal(recreated.canCopy(), true);
  assert.equal(password.value, original);
});

test('late clipboard completion cannot announce success or clear a newer copy after tab switching', async () => {
  const password = panel(core.GeneratorMode.PASSWORD);
  password.copyValue();
  activate(password, false);
  const phrase = panel(core.GeneratorMode.PASSPHRASE);
  phrase.copyValue();
  assert.equal(copies[0].value, password.value);
  assert.equal(copies[1].value, phrase.value);
  activate(phrase, false); activate(password, true);
  password.copyValue();
  copies[0].resolve(true); copies[1].resolve(true);
  await settle();
  assert.equal(password.feedback, undefined);
  assert.equal(phrase.feedback, undefined);
  assert.equal(password.copying, true);
  copies[2].resolve(true); await settle();
  assert.equal(password.copying, false);
  assert.equal(password.feedback, 'app.string.security_copy_success');
});

test('cold launch ignores old saved tab selections while page recreation keeps the in-session tab', () => {
  storage.set('timeauth.generator.options.v1', JSON.stringify({ ...new core.GeneratorOptions(), mode: 'passphrase' }));
  storage.set('timeauth.generator.mode.v1', 'pin');
  const first = new Page(); first.aboutToAppear();
  assert.equal(first.selectedIndex, 0);
  first.selectTab(2); first.aboutToDisappear();
  // A delayed native onChange during teardown must not change the remembered selection.
  first.selectTab(0);
  const second = new Page(); second.aboutToAppear();
  assert.equal(second.selectedIndex, 2);
  second.aboutToDisappear(); sessions.clearGeneratorSession();
  const third = new Page(); third.aboutToAppear();
  assert.equal(third.selectedIndex, 0);
  assert.equal(storage.get('timeauth.generator.mode.v1'), 'pin');
  third.aboutToDisappear();
});

test('a settings flush failure while hidden is shown on return and remains isolated to that tab', async () => {
  const password = panel(core.GeneratorMode.PASSWORD);
  await settle();
  failFlush = true;
  password.options.length = 40; password.optionsChanged();
  activate(password, false);
  await settle();
  failFlush = false;
  const phrase = panel(core.GeneratorMode.PASSPHRASE);
  await settle();
  assert.equal(phrase.preferencesFailed, false);
  activate(phrase, false); activate(password, true);
  assert.equal(password.preferencesFailed, true);
  password.persistOptions(); await settle();
  assert.equal(password.preferencesFailed, false);
});

test('PIN first visit generates once; leading zeros, copying and draft rules stay with the PIN tab', async () => {
  const password = panel(core.GeneratorMode.PASSWORD);
  const phrase = panel(core.GeneratorMode.PASSPHRASE);
  const pin = panel(core.GeneratorMode.PIN, false);
  const passwordValue = password.value, phraseValue = phrase.value;
  assert.equal(generated.length, 2);
  activate(password, false); activate(phrase, false); activate(pin, true);
  const originalPin = pin.value;
  assert.match(originalPin, /^0\d{5}$/);
  assert.equal(pin.options.pinLength, 6);
  assert.equal(pin.visibilityLabel(), 'app.string.generator_pin_hide');
  pin.revealed = false;
  assert.equal(pin.visibilityLabel(), 'app.string.generator_pin_show');
  pin.copyValue();
  assert.equal(copies[0].value, originalPin);
  copies[0].resolve(true); await settle();
  pin.options.pinLength = 8; pin.optionsChanged();
  assert.equal(pin.value, originalPin);
  assert.equal(pin.canCopy(), false);
  activate(pin, false); activate(password, true);
  assert.equal(password.value, passwordValue);
  assert.equal(password.canCopy(), true);
  activate(password, false); activate(phrase, true);
  assert.equal(phrase.value, phraseValue);
  assert.equal(phrase.canCopy(), true);
  activate(phrase, false); activate(pin, true);
  assert.equal(pin.value, originalPin);
  assert.equal(generated.length, 3);
  pin.regenerate();
  assert.equal(pin.feedback, 'app.string.generator_pin_generated');
  assert.match(pin.value, /^0\d{7}$/);
  assert.equal(pin.canCopy(), true);
  assert.equal(generated.at(-1).pinLength, 8);
});

test('PIN selection survives navigation; restart opens Password and later restores only PIN settings', async () => {
  const first = new Page(); first.aboutToAppear(); first.selectTab(2);
  assert.equal(sessions.getSelectedGeneratorMode(), core.GeneratorMode.PIN);
  const pin = panel(core.GeneratorMode.PIN);
  pin.options.pinLength = 4; pin.optionsChanged(); pin.regenerate(false);
  const original = pin.value;
  pin.aboutToDisappear(); first.aboutToDisappear();
  const second = new Page(); second.aboutToAppear();
  assert.equal(second.selectedIndex, 2);
  const restored = panel(core.GeneratorMode.PIN);
  assert.equal(restored.value, original);
  assert.equal(restored.options.pinLength, 4);
  for (const value of panels.splice(0)) value.aboutToDisappear();
  second.aboutToDisappear(); await settle(); sessions.clearGeneratorSession();
  const restarted = new Page(); restarted.aboutToAppear();
  assert.equal(restarted.selectedIndex, 0);
  restarted.selectTab(2);
  const fresh = panel(core.GeneratorMode.PIN);
  assert.equal(fresh.options.pinLength, 4);
  assert.notEqual(fresh.value, original);
  restarted.aboutToDisappear();
});

test('PIN failures stay in their tab and require explicit retry without altering other results', () => {
  const password = panel(core.GeneratorMode.PASSWORD);
  const phrase = panel(core.GeneratorMode.PASSPHRASE);
  const originalPassword = password.value, originalPhrase = phrase.value;
  failureMode = core.GeneratorMode.PIN;
  const pin = panel(core.GeneratorMode.PIN);
  assert.equal(pin.value, '');
  assert.equal(pin.generationFailure, core.GeneratorFailure.UNAVAILABLE);
  assert.equal(pin.canCopy(), false);
  const count = generated.length;
  activate(pin, false); activate(pin, true);
  assert.equal(generated.length, count);
  assert.equal(password.value, originalPassword);
  assert.equal(phrase.value, originalPhrase);
  failureMode = undefined; pin.regenerate(false);
  assert.equal(pin.canCopy(), true);
});


test('inactive tab instances restore their own mode and retained result before first render', () => {
  for (const mode of [core.GeneratorMode.PASSPHRASE, core.GeneratorMode.PIN]) {
    const first = panel(mode);
    const original = first.value;
    first.aboutToDisappear();
    const count = generated.length;
    const restored = panel(mode, false);
    assert.equal(restored.options.mode, mode);
    assert.equal(restored.value, original);
    assert.equal(restored.active, false);
    assert.equal(generated.length, count);
    activate(restored, true);
    assert.equal(restored.value, original);
    assert.equal(restored.active, true);
    assert.equal(generated.length, count);
  }
});

test('PIN → Password → Authenticator → Generator → PIN restores the PIN result and clipboard value', async () => {
  const first = new Page(); first.aboutToAppear();
  const password = panel(core.GeneratorMode.PASSWORD);
  first.selectTab(2); activate(password, false);
  const pin = panel(core.GeneratorMode.PIN);
  const originalPassword = password.value, originalPin = pin.value;
  first.selectTab(0); activate(pin, false); activate(password, true);
  first.aboutToDisappear(); password.aboutToDisappear(); pin.aboutToDisappear();
  // Returning from Authenticator recreates Generator and its cached/lazy contents.
  const second = new Page(); second.aboutToAppear();
  assert.equal(second.selectedIndex, 0);
  const restoredPassword = panel(core.GeneratorMode.PASSWORD);
  const restoredPin = panel(core.GeneratorMode.PIN, false);
  assert.equal(restoredPin.options.mode, core.GeneratorMode.PIN);
  assert.equal(restoredPin.value, originalPin);
  const count = generated.length;
  second.selectTab(2);
  activate(restoredPassword, false); activate(restoredPin, true);
  assert.equal(second.selectedIndex, 2);
  assert.equal(restoredPin.isSelectedTab(), true);
  assert.equal(restoredPassword.isSelectedTab(), false);
  assert.equal(restoredPin.value, originalPin);
  assert.equal(restoredPassword.value, originalPassword);
  assert.equal(generated.length, count);
  restoredPin.copyValue();
  assert.equal(copies.at(-1).value, originalPin);
  copies.at(-1).resolve(true); await settle();
  assert.equal(restoredPin.feedback, 'app.string.security_copy_success');
  second.aboutToDisappear();
});

test('selection notifications before lazy child appearance use the current index and generate exactly once', () => {
  const pin = new Panel(); pin.mode = core.GeneratorMode.PIN; panels.push(pin);
  pin.selectedIndex = 0;
  pin.onSelectedIndexChanged();
  assert.equal(generated.length, 0);
  pin.selectedIndex = 2;
  pin.onSelectedIndexChanged();
  assert.equal(generated.length, 0);
  pin.aboutToAppear();
  assert.equal(pin.options.mode, core.GeneratorMode.PIN);
  assert.match(pin.value, /^0\d{5}$/);
  assert.equal(generated.length, 1);
  pin.onSelectedIndexChanged();
  assert.equal(generated.length, 1);
});
