const assert = require('node:assert/strict');
const { before, beforeEach, test } = require('node:test');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const directory = join(__dirname, '../entry/src/main/ets/features/generator');
let core, adapter, platformSource, capability = true, capabilityThrows = false, randomCalls = 0;
function url(source) {
  return `data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(source, { mode: 'transform' })).toString('base64')}`;
}
function bytes(sequence) {
  let offset = 0;
  return length => Uint8Array.from({ length }, () => sequence[offset++ % sequence.length]);
}
function options(extra = {}) {
  return Object.assign(new core.GeneratorOptions(), { mode: core.GeneratorMode.PIN }, extra);
}
before(async () => {
  const coreUrl = url(readFileSync(join(directory, 'GeneratorCore.ets'), 'utf8'));
  const wordsUrl = url(readFileSync(join(directory, 'PassphraseWords.ets'), 'utf8'));
  core = await import(coreUrl);
  globalThis.__pinPlatform = {
    createRandom: () => { randomCalls++; return { generateRandomSync: length => ({ data: platformSource(length) }) }; }
  };
  globalThis.__pinCapability = () => {
    if (capabilityThrows) throw new Error('PRIVATE_CAPABILITY_DETAIL');
    return capability;
  };
  const kitUrl = url('export const cryptoFramework = globalThis.__pinPlatform;');
  const source = 'const canIUse = globalThis.__pinCapability;\n' +
    readFileSync(join(directory, 'PasswordGenerator.ets'), 'utf8')
      .replace("'@kit.CryptoArchitectureKit'", JSON.stringify(kitUrl))
      .replace("'./GeneratorCore'", JSON.stringify(coreUrl))
      .replace("'./PassphraseWords'", JSON.stringify(wordsUrl));
  adapter = await import(url(source));
  delete globalThis.__pinPlatform; delete globalThis.__pinCapability;
});
beforeEach(() => { capability = true; capabilityThrows = false; randomCalls = 0; platformSource = bytes([0, 1, 2, 3, 4, 5, 6, 7]); });

test('PIN defaults to six digits and all supported lengths preserve leading zeros and exact entropy', () => {
  assert.equal(options().pinLength, 6);
  for (const pinLength of [4, 6, 8]) {
    const configuration = options({ pinLength });
    const result = core.generatePinFromSource(configuration, bytes([0, 1, 2, 3, 4, 5, 6, 7]));
    assert.equal(result.value, '01234567'.slice(0, pinLength));
    assert.equal(typeof result.value, 'string');
    assert.equal(result.entropyBits, pinLength * Math.log2(10));
    assert.equal(core.estimatePasswordEntropy(configuration), result.entropyBits);
  }
});

test('every digit has exactly 25 accepted byte values and bytes 250–255 are rejected', () => {
  const counts = new Array(10).fill(0);
  for (let byte = 0; byte < 250; byte++) {
    const result = core.generatePinFromSource(options({ pinLength: 4 }), bytes([byte]));
    assert.equal(result.value, String(byte % 10).repeat(4));
    counts[Number(result.value[0])]++;
  }
  assert.deepEqual(counts, new Array(10).fill(25));
  assert.equal(core.generatePinFromSource(options({ pinLength: 4 }),
    bytes([250, 251, 252, 253, 254, 255, 0, 1, 8, 9])).value, '0189');
});

test('all-zero and repeated PINs remain eligible, regardless of password or phrase rules', () => {
  const configuration = options({ length: 0, includeLowercase: false, includeUppercase: false,
    includeNumbers: false, includeSymbols: false, symbols: '', avoidAmbiguous: true, requireEach: true,
    wordCount: 0, separator: '', appendNumber: true, capitalize: true });
  assert.equal(core.validateGeneratorOptions(configuration), core.GeneratorValidation.VALID);
  assert.equal(core.generatePinFromSource(configuration, bytes([0])).value, '000000');
  assert.equal(core.generatePinFromSource(configuration, bytes([1])).value, '111111');
  assert.equal(core.generatePinFromSource(configuration, bytes([9])).value, '999999');
});

test('unsupported lengths and other modes fail before drawing randomness', () => {
  for (const pinLength of [0, 3, 5, 7, 9, 128, 6.5, NaN, Infinity, '6', null, undefined]) {
    const configuration = options({ pinLength });
    assert.equal(core.validateGeneratorOptions(configuration), core.GeneratorValidation.INVALID_PIN_LENGTH);
    assert.throws(() => core.generatePinFromSource(configuration, () => assert.fail('must not draw')));
    assert.throws(() => core.estimatePasswordEntropy(configuration));
  }
  for (const mode of [core.GeneratorMode.PASSWORD, core.GeneratorMode.PASSPHRASE, 'unknown']) {
    assert.throws(() => core.generatePinFromSource(options({ mode }), () => assert.fail('must not draw')));
  }
  assert.throws(() => core.generatePasswordFromSource(options(), () => assert.fail('must not draw')));
});

test('buffers are erased on success, invalid provider output and provider exceptions', () => {
  let buffer;
  assert.equal(core.generatePinFromSource(options(), length => {
    buffer = new Uint8Array(length).fill(9); return buffer;
  }).value, '999999');
  assert.ok(buffer.every(value => value === 0));
  const short = new Uint8Array(3).fill(99);
  assert.throws(() => core.generatePinFromSource(options(), () => short), { message: 'Secure password generation failed.' });
  assert.ok(short.every(value => value === 0));
  let calls = 0;
  assert.throws(() => core.generatePinFromSource(options(), length => {
    if (++calls > 1) throw new Error('PRIVATE_RANDOM_DETAIL');
    buffer = new Uint8Array(length).fill(255); return buffer;
  }), { message: 'Secure password generation failed.' });
  assert.ok(buffer.every(value => value === 0));
});

test('a broken source that never yields an acceptable byte terminates with a sanitized failure', () => {
  let calls = 0, buffer;
  assert.throws(() => core.generatePinFromSource(options(), length => {
    assert.ok(++calls <= 1024);
    buffer = new Uint8Array(length).fill(255); return buffer;
  }), { message: 'Secure password generation failed.' });
  assert.ok(buffer.every(value => value === 0));
});

test('production adapter generates PINs and distinguishes unsupported capability from retryable failures', () => {
  assert.equal(adapter.generatePassword(options()).value, '012345');
  capability = false;
  const calls = randomCalls;
  assert.throws(() => adapter.generatePassword(options()), { failure: core.GeneratorFailure.UNSUPPORTED });
  assert.equal(randomCalls, calls);
  capability = true; capabilityThrows = true;
  assert.throws(() => adapter.generatePassword(options()), {
    failure: core.GeneratorFailure.UNAVAILABLE, message: 'Secure password generation failed.'
  });
  capabilityThrows = false;
  platformSource = () => { throw new Error('PRIVATE_PROVIDER_DETAIL'); };
  assert.throws(() => adapter.generatePassword(options()), {
    failure: core.GeneratorFailure.UNAVAILABLE, message: 'Secure password generation failed.'
  });
  platformSource = bytes([0]);
  assert.equal(adapter.generatePassword(options()).value, '000000');
});
