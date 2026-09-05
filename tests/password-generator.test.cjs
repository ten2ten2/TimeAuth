// Run with Node 22.13+ (or Node 24): node --test tests/password-generator.test.cjs
// Execute the actual pure ArkTS core through Node's TypeScript transform, without package installs.
const assert = require('node:assert/strict');
const { before, test } = require('node:test');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { createHash } = require('node:crypto');
const { stripTypeScriptTypes } = require('node:module');

if (typeof stripTypeScriptTypes !== 'function') {
  throw new Error('Password generator tests require Node 22.13+ or Node 24.');
}

const generatorDirectory = join(__dirname, '../entry/src/main/ets/features/generator');
let core;
let adapter;
let adapterSource;
let adapterCalls;
let factoryFailure = false;
let factoryCalls = 0;
let capabilityAvailable = true;
let capabilityFailure = false;

function moduleUrl(source) {
  const javascript = stripTypeScriptTypes(source, { mode: 'transform' });
  return `data:text/javascript;base64,${Buffer.from(javascript).toString('base64')}`;
}

before(async () => {
  const coreUrl = moduleUrl(readFileSync(join(generatorDirectory, 'GeneratorCore.ets'), 'utf8'));
  core = await import(coreUrl);
  // Only the platform API is substituted. The production wrapper itself is loaded unchanged otherwise.
  globalThis.__timeAuthTestCrypto = {
    createRandom() {
      factoryCalls++;
      if (factoryFailure) throw new Error('SENSITIVE_PROVIDER_DETAIL');
      return {
        generateRandomSync(length) {
          adapterCalls.push(length);
          return { data: adapterSource(length) };
        }
      };
    }
  };
  globalThis.__timeAuthTestCanIUse = (capability) => {
    assert.equal(capability, 'SystemCapability.Security.CryptoFramework.Rand');
    if (capabilityFailure) throw new Error('SENSITIVE_CAPABILITY_DETAIL');
    return capabilityAvailable;
  };
  const kitUrl = moduleUrl('export const cryptoFramework = globalThis.__timeAuthTestCrypto;');
  const adapterSourceCode = 'const canIUse = globalThis.__timeAuthTestCanIUse;\n' +
    readFileSync(join(generatorDirectory, 'PasswordGenerator.ets'), 'utf8')
    .replace("'@kit.CryptoArchitectureKit'", JSON.stringify(kitUrl))
    .replace("'./GeneratorCore'", JSON.stringify(coreUrl));
  adapter = await import(moduleUrl(adapterSourceCode));
  delete globalThis.__timeAuthTestCrypto;
  delete globalThis.__timeAuthTestCanIUse;
});

function options(overrides = {}) {
  return Object.assign(new core.GeneratorOptions(), overrides);
}

function sequence(values) {
  let offset = 0;
  return (length) => Uint8Array.from({ length }, () => values[offset++ % values.length]);
}

// A deterministic source for tests only; production uses HarmonyOS's system CSPRNG.
function deterministicSource(seed) {
  let counter = 0;
  return (length) => {
    const bytes = new Uint8Array(length);
    for (let offset = 0; offset < length; offset += 32) {
      const digest = createHash('sha256').update(`${seed}:${counter++}`).digest();
      bytes.set(digest.subarray(0, Math.min(32, length - offset)), offset);
    }
    return bytes;
  };
}

function alphabetGroups(configuration) {
  return [
    configuration.includeLowercase ? 'abcdefghijklmnopqrstuvwxyz' : '',
    configuration.includeUppercase ? 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' : '',
    configuration.includeNumbers ? '0123456789' : '',
    configuration.includeSymbols ? [...new Set(configuration.symbols)].join('') : ''
  ].map((value) => configuration.avoidAmbiguous ? value.replace(/[0O1Il]/g, '') : value).filter(Boolean);
}

// Independent exact-integer inclusion/exclusion check for the probability-DP implementation.
function legalOutputCount(length, groups, requireEach) {
  if (!requireEach) return BigInt(groups.join('').length) ** BigInt(length);
  let count = 0n;
  for (let removed = 0; removed < (1 << groups.length); removed++) {
    let alphabetSize = 0;
    let removedCount = 0;
    groups.forEach((group, index) => {
      if (removed & (1 << index)) removedCount++;
      else alphabetSize += group.length;
    });
    const combinations = BigInt(alphabetSize) ** BigInt(length);
    count += removedCount % 2 ? -combinations : combinations;
  }
  return count;
}

function near(actual, expected) {
  assert.ok(Math.abs(actual - expected) < 1e-10, `Expected ${actual} to equal ${expected}`);
}

test('default settings are valid and generate a 20-character result', () => {
  const configuration = options();
  assert.equal(configuration.length, 20);
  assert.equal(configuration.requireEach, true);
  assert.equal(configuration.avoidAmbiguous, true);
  assert.equal(core.validateGeneratorOptions(configuration), core.GeneratorValidation.VALID);
  const result = core.generatePasswordFromSource(configuration, deterministicSource('defaults'));
  assert.equal(result.value.length, 20);
  assert.ok(result.entropyBits > 120);
});

test('length boundaries reject invalid values before requesting randomness', () => {
  for (const length of [7, 129, -1, 8.5, NaN, Infinity, -Infinity]) {
    const configuration = options({ length });
    assert.equal(core.validateGeneratorOptions(configuration), core.GeneratorValidation.INVALID_LENGTH);
    assert.throws(() => core.generatePasswordFromSource(configuration, () => {
      assert.fail('Invalid configuration must not read the random source');
    }), /Invalid password generator options/);
  }
  for (const length of [8, 128]) {
    assert.equal(core.validateGeneratorOptions(options({ length })), core.GeneratorValidation.VALID);
  }
});

test('empty character selections and unsafe custom symbols fail validation', () => {
  const empty = options({
    includeLowercase: false, includeUppercase: false, includeNumbers: false, includeSymbols: false
  });
  assert.equal(core.validateGeneratorOptions(empty), core.GeneratorValidation.NO_CHARACTERS);
  assert.equal(core.validateGeneratorOptions(options({ symbols: '' })), core.GeneratorValidation.EMPTY_SYMBOLS);
  for (const symbols of ['hello', '123', '! ', '\t', '\n', '\u0000', '\u007f', '中文', '🙂', '！', '\u00a0']) {
    assert.equal(core.validateGeneratorOptions(options({ symbols })), core.GeneratorValidation.INVALID_SYMBOLS);
  }
  const allPunctuation = '!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~';
  assert.equal(core.validateGeneratorOptions(options({ symbols: allPunctuation })), core.GeneratorValidation.VALID);
  assert.equal(core.validateGeneratorOptions(options({ includeSymbols: false, symbols: 'unused invalid' })),
    core.GeneratorValidation.VALID);
});

test('every category combination respects length, exclusions, selected groups and exact entropy', () => {
  for (let selected = 1; selected < 16; selected++) {
    for (const avoidAmbiguous of [false, true]) {
      for (const requireEach of [false, true]) {
        for (const length of [8, 128]) {
          const configuration = options({
            includeLowercase: Boolean(selected & 1), includeUppercase: Boolean(selected & 2),
            includeNumbers: Boolean(selected & 4), includeSymbols: Boolean(selected & 8),
            avoidAmbiguous, requireEach, length, symbols: '!'
          });
          const groups = alphabetGroups(configuration);
          const result = core.generatePasswordFromSource(configuration,
            deterministicSource(`${selected}:${avoidAmbiguous}:${requireEach}:${length}`));
          assert.equal(result.value.length, length);
          assert.ok([...result.value].every((character) => groups.join('').includes(character)));
          if (requireEach) {
            for (const group of groups) {
              assert.ok([...result.value].some((character) => group.includes(character)));
            }
          }
          if (avoidAmbiguous) assert.doesNotMatch(result.value, /[0O1Il]/);
          const expectedEntropy = Math.log2(Number(legalOutputCount(length, groups, requireEach)));
          near(result.entropyBits, expectedEntropy);
          near(core.estimatePasswordEntropy(configuration), expectedEntropy);
        }
      }
    }
  }
});

test('duplicate custom symbols never weight the alphabet or inflate entropy', () => {
  const configuration = options({
    includeLowercase: false, includeUppercase: false, includeNumbers: false, length: 8, symbols: '!??!!'
  });
  const deduplicated = options({ ...configuration, symbols: '!?' });
  const first = core.generatePasswordFromSource(configuration, sequence([0, 1]));
  const second = core.generatePasswordFromSource(deduplicated, sequence([0, 1]));
  assert.equal(first.value, '!?!?!?!?');
  assert.equal(first.value, second.value);
  assert.equal(first.entropyBits, 8);
  assert.equal(first.entropyBits, second.entropyBits);
});

test('a one-character alphabet has zero entropy regardless of length', () => {
  const configuration = options({
    includeLowercase: false, includeUppercase: false, includeNumbers: false, symbols: '!!!', length: 128
  });
  const result = core.generatePasswordFromSource(configuration, sequence([255]));
  assert.equal(result.value, '!'.repeat(128));
  assert.equal(result.entropyBits, 0);
});

test('byte rejection discards the incomplete range instead of introducing modulo bias', () => {
  const configuration = options({
    includeLowercase: false, includeUppercase: false, includeSymbols: false, avoidAmbiguous: false, length: 8
  });
  const result = core.generatePasswordFromSource(configuration,
    sequence([250, 251, 252, 253, 254, 255, 0, 1, 2, 3, 4, 5, 6, 7]));
  assert.equal(result.value, '01234567');
  near(result.entropyBits, 8 * Math.log2(10));
});

test('require-each discards an entire invalid candidate, while disabling it allows that candidate', () => {
  const configuration = options({ includeUppercase: false, includeSymbols: false, avoidAmbiguous: false, length: 8 });
  const bytes = [0, 0, 0, 0, 0, 0, 0, 0, 0, 26, 1, 27, 2, 28, 3, 29];
  const required = core.generatePasswordFromSource(configuration, sequence(bytes));
  const optional = core.generatePasswordFromSource(options({ ...configuration, requireEach: false }), sequence(bytes));
  assert.equal(required.value, 'a0b1c2d3');
  assert.equal(optional.value, 'aaaaaaaa');
  assert.ok(required.entropyBits < optional.entropyBits);
});

test('broken random providers fail closed with sanitized errors and bounded work', () => {
  const configuration = options({ length: 8 });
  for (const source of [
    () => { throw new Error('SENSITIVE_PROVIDER_DETAIL'); },
    () => new Uint8Array(0),
    (length) => new Uint8Array(length - 1),
    (length) => new Uint8Array(length + 1),
    () => undefined,
    () => []
  ]) {
    assert.throws(() => core.generatePasswordFromSource(configuration, source),
      { message: 'Secure password generation failed.' });
  }
  for (const byte of [0, 255]) {
    let calls = 0;
    assert.throws(() => core.generatePasswordFromSource(configuration, (length) => {
      calls++;
      if (calls > 4096) assert.fail('Random-source failure must terminate promptly');
      return new Uint8Array(length).fill(byte);
    }), { message: 'Secure password generation failed.' });
    assert.ok(calls > 0 && calls <= 4096);
  }
});

test('temporary random byte buffers are cleared after success and failure', () => {
  let supplied;
  core.generatePasswordFromSource(options({ requireEach: false }), (length) => {
    supplied = new Uint8Array(length).fill(7);
    return supplied;
  });
  assert.ok(supplied.every((byte) => byte === 0));
  const short = new Uint8Array(12).fill(7);
  assert.throws(() => core.generatePasswordFromSource(options(), () => short));
  assert.ok(short.every((byte) => byte === 0));
});

test('production adapter reads system synchronous random bytes and sanitizes platform failures', () => {
  adapterCalls = [];
  adapterSource = deterministicSource('platform-adapter');
  const result = adapter.generatePassword(options());
  assert.equal(result.value.length, 20);
  assert.ok(adapterCalls.length > 0);
  assert.ok(adapterCalls.every((length) => Number.isInteger(length) && length > 0));
  adapterSource = () => { throw new Error('SENSITIVE_PROVIDER_DETAIL'); };
  assert.throws(() => adapter.generatePassword(options()), { message: 'Secure password generation failed.' });
  factoryFailure = true;
  try {
    assert.throws(() => adapter.generatePassword(options()), { message: 'Secure password generation failed.' });
  } finally {
    factoryFailure = false;
  }
});

test('unsupported or failing system capability checks stop before creating a random source', () => {
  const beforeCalls = factoryCalls;
  capabilityAvailable = false;
  try {
    assert.throws(() => adapter.generatePassword(options()), { message: 'Secure password generation failed.' });
    assert.equal(factoryCalls, beforeCalls);
    capabilityAvailable = true;
    capabilityFailure = true;
    assert.throws(() => adapter.generatePassword(options()), { message: 'Secure password generation failed.' });
    assert.equal(factoryCalls, beforeCalls);
  } finally {
    capabilityAvailable = true;
    capabilityFailure = false;
  }
});
