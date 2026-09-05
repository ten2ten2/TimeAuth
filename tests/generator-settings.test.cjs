// Node 22.13+; run actual ArkTS modules with only ArkData/AbilityKit substituted.
const assert = require('node:assert/strict');
const { before, beforeEach, test } = require('node:test');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const directory = join(__dirname, '../entry/src/main/ets/features/generator');
let core, settings, session;
let stored = '';
let writes = [];
const tabStorage = new Map();
let failRead = false;
let failWrite = false;
let failFlush = false;

function url(source) {
  return `data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(source, { mode: 'transform' })).toString('base64')}`;
}

before(async () => {
  const coreUrl = url(readFileSync(join(directory, 'GeneratorCore.ets'), 'utf8'));
  core = await import(coreUrl);
  globalThis.__generatorPreferencesMock = {
    getPreferencesSync(_context, options) {
      assert.equal(options.name, 'timeauth_preferences');
      if (failRead) throw new Error('private data must not be logged');
      return {
        getSync(key, fallback) {
          if (key === 'timeauth.generator.options.v1') return stored === undefined ? fallback : stored;
          return tabStorage.has(key) ? tabStorage.get(key) : fallback;
        },
        putSync(key, value) {
          if (failWrite) throw new Error('write failed');
          writes.push({ key, value });
          tabStorage.set(key, value);
        },
        async flush() {
          if (failFlush) throw new Error('flush failed');
        }
      };
    }
  };
  const preferencesUrl = url('export const preferences = globalThis.__generatorPreferencesMock;');
  const abilityUrl = url('export const common = {};');
  const source = readFileSync(join(directory, 'GeneratorSettings.ets'), 'utf8')
    .replace("'@kit.AbilityKit'", JSON.stringify(abilityUrl))
    .replace("'@kit.ArkData'", JSON.stringify(preferencesUrl))
    .replace("'./GeneratorCore'", JSON.stringify(coreUrl));
  settings = await import(url(source));
  session = await import(url(readFileSync(join(directory, 'GeneratorSession.ets'), 'utf8')
    .replace("'./GeneratorCore'", JSON.stringify(coreUrl))));
  delete globalThis.__generatorPreferencesMock;
});

beforeEach(() => { stored = undefined; writes = []; tabStorage.clear(); session.clearGeneratorSession(); });

test('missing preferences use valid defaults', () => {
  stored = undefined;
  const result = settings.readGeneratorOptions({});
  assert.equal(result.succeeded, true);
  assert.equal(result.options.length, 16);
  assert.equal(core.validateGeneratorOptions(result.options), core.GeneratorValidation.VALID);
});

test('saved rules round-trip; output and unexpected fields never enter storage', async () => {
  const options = new core.GeneratorOptions();
  Object.assign(options, { length: 128, symbols: '!@', avoidAmbiguous: false, requireEach: false,
    value: 'DO_NOT_PERSIST', password: 'DO_NOT_PERSIST', nested: { secret: 'DO_NOT_PERSIST' } });
  writes = [];
  assert.equal(await settings.saveGeneratorOptions({}, options), true);
  assert.equal(writes.length, 1);
  assert.equal(writes[0].value.includes('DO_NOT_PERSIST'), false);
  assert.deepEqual(Object.keys(JSON.parse(writes[0].value)).sort(), [
    'length', 'includeLowercase', 'includeUppercase', 'includeNumbers', 'includeSymbols',
    'avoidAmbiguous', 'requireEach', 'symbols', 'mode', 'wordCount', 'separator', 'capitalize', 'appendNumber'
  ].sort());
  const read = settings.readGeneratorOptions({});
  assert.equal(read.succeeded, true);
  assert.equal(read.options.length, 128);
  assert.equal(read.options.symbols, '!@');
  assert.equal(read.options.avoidAmbiguous, false);
  assert.equal(read.options.requireEach, false);
  assert.equal(read.options.value, undefined);
});

test('the new default preserves an existing saved 20-character preference', () => {
  stored = JSON.stringify({ ...new core.GeneratorOptions(), length: 20 });
  const result = settings.readGeneratorOptions({});
  assert.equal(result.succeeded, true);
  assert.equal(result.options.length, 20);
});

test('legacy password-only settings acquire passphrase defaults without changing old rules', () => {
  const legacy = { ...new core.GeneratorOptions(), length: 17, symbols: '!@' };
  for (const key of ['mode', 'wordCount', 'separator', 'capitalize', 'appendNumber']) delete legacy[key];
  stored = JSON.stringify(legacy);
  const result = settings.readGeneratorOptions({});
  assert.equal(result.succeeded, true);
  assert.equal(result.options.length, 17);
  assert.equal(result.options.symbols, '!@');
  assert.equal(result.options.mode, core.GeneratorMode.PASSWORD);
  assert.equal(result.options.wordCount, 6);
});

test('passphrase mode and rules persist while generated values remain excluded', async () => {
  const configuration = Object.assign(new core.GeneratorOptions(), { mode: core.GeneratorMode.PASSPHRASE,
    wordCount: 10, separator: '_', capitalize: true, appendNumber: true, value: 'DO_NOT_PERSIST' });
  assert.equal(await settings.saveGeneratorOptions({}, configuration), true);
  const result = settings.readGeneratorOptions({}, core.GeneratorMode.PASSPHRASE);
  assert.equal(result.succeeded, true);
  assert.equal(result.options.mode, core.GeneratorMode.PASSPHRASE);
  assert.equal(result.options.wordCount, 10);
  assert.equal(result.options.separator, '_');
  assert.equal(result.options.capitalize, true);
  assert.equal(result.options.appendNumber, true);
  assert.equal(writes.at(-1).value.includes('DO_NOT_PERSIST'), false);
});

test('malformed passphrase settings do not become active preferences', () => {
  for (const bad of [{ mode: 'pin' }, { wordCount: 3 }, { wordCount: 11 }, { wordCount: '6' },
    { separator: '' }, { separator: null }, { capitalize: 1 }, { appendNumber: 'false' }]) {
    stored = JSON.stringify({ ...new core.GeneratorOptions(), ...bad });
    assert.equal(settings.readGeneratorOptions({}).succeeded, false);
  }
});

test('malformed and invalid persisted rules recover to defaults without throwing', () => {
  const valid = new core.GeneratorOptions();
  for (const raw of [null, 55, 'null', '[]', '{', '{}', 'true', JSON.stringify({ ...valid, length: 129 }),
    JSON.stringify({ ...valid, includeNumbers: 'true' }), JSON.stringify({ ...valid, symbols: 'a!' }),
    JSON.stringify({ ...valid, includeLowercase: false, includeUppercase: false,
      includeNumbers: false, includeSymbols: false })]) {
    stored = raw;
    const read = settings.readGeneratorOptions({});
    assert.equal(read.succeeded, false);
    assert.equal(read.options.length, 16);
    assert.equal(core.validateGeneratorOptions(read.options), core.GeneratorValidation.VALID);
  }
});

test('invalid drafts cannot overwrite saved options', async () => {
  stored = JSON.stringify(new core.GeneratorOptions());
  const prior = stored;
  writes = [];
  const options = new core.GeneratorOptions();
  options.length = 0;
  assert.equal(await settings.saveGeneratorOptions({}, options), false);
  assert.equal(stored, prior);
  assert.equal(writes.length, 0);
});

test('preference read, write and flush errors are reported without throwing', async () => {
  failRead = true;
  assert.equal(settings.readGeneratorOptions({}).succeeded, false);
  assert.equal(await settings.saveGeneratorOptions({}, new core.GeneratorOptions()), false);
  failRead = false;
  failWrite = true;
  assert.equal(await settings.saveGeneratorOptions({}, new core.GeneratorOptions()), false);
  failWrite = false;
  failFlush = true;
  assert.equal(await settings.saveGeneratorOptions({}, new core.GeneratorOptions()), false);
  failFlush = false;
});

test('session survives repeated page access and explicit teardown discards the password', () => {
  const first = session.getGeneratorSession();
  first.initialized = true;
  first.value = 'SESSION_ONLY';
  first.generatedFor = 'rules';
  first.options.length = 64;
  first.generationFailure = core.GeneratorFailure.UNSUPPORTED;
  assert.equal(session.getGeneratorSession(), first);
  assert.equal(session.getGeneratorSession().value, 'SESSION_ONLY');
  assert.equal(session.getGeneratorSession().generationFailure, core.GeneratorFailure.UNSUPPORTED);
  session.clearGeneratorSession();
  assert.equal(first.value, '');
  const fresh = session.getGeneratorSession();
  assert.notEqual(fresh, first);
  assert.equal(fresh.initialized, false);
  assert.equal(fresh.value, '');
  assert.equal(fresh.options.length, 16);
  assert.equal(fresh.generationFailure, core.GeneratorFailure.NONE);
});


test('each tab migrates legacy settings independently even after the other tab has saved', async () => {
  stored = JSON.stringify({ ...new core.GeneratorOptions(), mode: core.GeneratorMode.PASSPHRASE,
    length: 31, symbols: '!@', wordCount: 8, separator: '_', capitalize: true });
  const password = settings.readGeneratorOptions({}, core.GeneratorMode.PASSWORD).options;
  assert.equal(password.mode, core.GeneratorMode.PASSWORD);
  assert.equal(password.length, 31);
  password.length = 64;
  assert.equal(await settings.saveGeneratorOptions({}, password), true);
  const phrase = settings.readGeneratorOptions({}, core.GeneratorMode.PASSPHRASE).options;
  assert.equal(phrase.wordCount, 8);
  assert.equal(phrase.separator, '_');
  assert.equal(phrase.capitalize, true);
  phrase.wordCount = 10;
  await settings.saveGeneratorOptions({}, phrase);
  assert.equal(settings.readGeneratorOptions({}, core.GeneratorMode.PASSWORD).options.length, 64);
  assert.equal(settings.readGeneratorOptions({}, core.GeneratorMode.PASSPHRASE).options.wordCount, 10);
  assert.equal(JSON.parse(stored).length, 31);
});

test('interleaved saves from stale tab snapshots never overwrite the other tab or selected mode', async () => {
  const password = settings.readGeneratorOptions({}, core.GeneratorMode.PASSWORD).options;
  const phrase = settings.readGeneratorOptions({}, core.GeneratorMode.PASSPHRASE).options;
  password.length = 48;
  phrase.wordCount = 9;
  await Promise.all([settings.saveGeneratorOptions({}, password), settings.saveGeneratorOptions({}, phrase),
    settings.saveGeneratorMode({}, core.GeneratorMode.PASSPHRASE)]);
  password.length = 96;
  await settings.saveGeneratorOptions({}, password);
  assert.equal(settings.readGeneratorOptions({}, core.GeneratorMode.PASSWORD).options.length, 96);
  assert.equal(settings.readGeneratorOptions({}, core.GeneratorMode.PASSPHRASE).options.wordCount, 9);
  assert.equal(settings.readGeneratorMode({}).mode, core.GeneratorMode.PASSPHRASE);
});

test('invalid password drafts and damaged password storage do not block the phrase tab', async () => {
  const phrase = Object.assign(new core.GeneratorOptions(), { mode: core.GeneratorMode.PASSPHRASE, wordCount: 7 });
  await settings.saveGeneratorOptions({}, phrase);
  const bad = Object.assign(new core.GeneratorOptions(), { length: 0 });
  assert.equal(await settings.saveGeneratorOptions({}, bad), false);
  tabStorage.set('timeauth.generator.options.password.v2', '{');
  assert.equal(settings.readGeneratorOptions({}, core.GeneratorMode.PASSWORD).succeeded, false);
  const read = settings.readGeneratorOptions({}, core.GeneratorMode.PASSPHRASE);
  assert.equal(read.succeeded, true);
  assert.equal(read.options.wordCount, 7);
  tabStorage.set('timeauth.generator.options.passphrase.v2', '{');
  const failed = settings.readGeneratorOptions({}, core.GeneratorMode.PASSPHRASE);
  assert.equal(failed.succeeded, false);
  assert.equal(failed.options.mode, core.GeneratorMode.PASSPHRASE);
});

test('selected tab migrates, persists separately and handles storage failures', async () => {
  assert.equal(settings.readGeneratorMode({}).mode, core.GeneratorMode.PASSWORD);
  stored = JSON.stringify({ ...new core.GeneratorOptions(), mode: core.GeneratorMode.PASSPHRASE });
  assert.equal(settings.readGeneratorMode({}).mode, core.GeneratorMode.PASSPHRASE);
  await settings.saveGeneratorMode({}, core.GeneratorMode.PASSWORD);
  assert.equal(settings.readGeneratorMode({}).mode, core.GeneratorMode.PASSWORD);
  assert.equal(await settings.saveGeneratorMode({}, 'pin'), false);
  tabStorage.set('timeauth.generator.mode.v1', 42);
  assert.equal(settings.readGeneratorMode({}).succeeded, false);
  failRead = true;
  assert.equal(settings.readGeneratorMode({}).succeeded, false);
  assert.equal(await settings.saveGeneratorMode({}, core.GeneratorMode.PASSWORD), false);
  failRead = false;
  failFlush = true;
  assert.equal(await settings.saveGeneratorMode({}, core.GeneratorMode.PASSPHRASE), false);
  failFlush = false;
});

test('sessions isolate results, drafts and errors; teardown clears both retained result references', () => {
  const password = session.getGeneratorSession(core.GeneratorMode.PASSWORD);
  const phrase = session.getGeneratorSession(core.GeneratorMode.PASSPHRASE);
  assert.notEqual(password, phrase);
  assert.notEqual(password.options, phrase.options);
  password.value = 'PASSWORD_ONLY';
  password.options.length = 0;
  password.generationFailure = core.GeneratorFailure.UNAVAILABLE;
  phrase.value = 'PHRASE_ONLY';
  phrase.generatedFor = 'phrase-rules';
  phrase.entropyBits = 77.55;
  assert.equal(phrase.options.mode, core.GeneratorMode.PASSPHRASE);
  assert.equal(phrase.options.wordCount, 6);
  assert.equal(phrase.generationFailure, core.GeneratorFailure.NONE);
  session.setSelectedGeneratorMode(core.GeneratorMode.PASSPHRASE);
  assert.equal(session.getSelectedGeneratorMode(), core.GeneratorMode.PASSPHRASE);
  assert.equal(session.getGeneratorSession(core.GeneratorMode.PASSWORD).value, 'PASSWORD_ONLY');
  session.clearGeneratorSession();
  assert.equal(password.value, '');
  assert.equal(phrase.value, '');
  assert.equal(phrase.generatedFor, '');
  assert.equal(phrase.entropyBits, 0);
  assert.equal(session.getSelectedGeneratorMode(), undefined);
  assert.notEqual(session.getGeneratorSession(core.GeneratorMode.PASSPHRASE), phrase);
});
