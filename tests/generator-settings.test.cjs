// Node 22.13+; run actual ArkTS modules with only ArkData/AbilityKit substituted.
const assert = require('node:assert/strict');
const { before, test } = require('node:test');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const directory = join(__dirname, '../entry/src/main/ets/features/generator');
let core, settings, session;
let stored = '';
let writes = [];
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
          assert.equal(key, 'timeauth.generator.options.v1');
          return stored === undefined ? fallback : stored;
        },
        putSync(key, value) {
          if (failWrite) throw new Error('write failed');
          writes.push({ key, value });
          stored = value;
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
  const result = settings.readGeneratorOptions({});
  assert.equal(result.succeeded, true);
  assert.equal(result.options.mode, core.GeneratorMode.PASSPHRASE);
  assert.equal(result.options.wordCount, 10);
  assert.equal(result.options.separator, '_');
  assert.equal(result.options.capitalize, true);
  assert.equal(result.options.appendNumber, true);
  assert.equal(stored.includes('DO_NOT_PERSIST'), false);
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
