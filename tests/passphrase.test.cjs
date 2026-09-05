const assert = require('node:assert/strict');
const { before, test } = require('node:test');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { createHash } = require('node:crypto');
const { stripTypeScriptTypes } = require('node:module');
const directory = join(__dirname, '../entry/src/main/ets/features/generator');
let core, words, adapter, platformSource, capability = true;
function url(source) {
  return `data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(source, { mode: 'transform' })).toString('base64')}`;
}
before(async () => {
  const coreUrl = url(readFileSync(join(directory, 'GeneratorCore.ets'), 'utf8'));
  const wordsUrl = url(readFileSync(join(directory, 'PassphraseWords.ets'), 'utf8'));
  core = await import(coreUrl);
  words = (await import(wordsUrl)).PASSPHRASE_WORDS;
  globalThis.__phrasePlatform = {
    createRandom: () => ({ generateRandomSync: length => ({ data: platformSource(length) }) })
  };
  globalThis.__phraseCapability = () => capability;
  const kitUrl = url('export const cryptoFramework = globalThis.__phrasePlatform;');
  const source = 'const canIUse = globalThis.__phraseCapability;\n' +
    readFileSync(join(directory, 'PasswordGenerator.ets'), 'utf8')
      .replace("'@kit.CryptoArchitectureKit'", JSON.stringify(kitUrl))
      .replace("'./GeneratorCore'", JSON.stringify(coreUrl))
      .replace("'./PassphraseWords'", JSON.stringify(wordsUrl));
  adapter = await import(url(source));
  delete globalThis.__phrasePlatform;
  delete globalThis.__phraseCapability;
});
function options(extra = {}) {
  return Object.assign(new core.GeneratorOptions(), { mode: core.GeneratorMode.PASSPHRASE }, extra);
}
function bytes(sequence) {
  let offset = 0;
  return length => Uint8Array.from({ length }, () => sequence[offset++ % sequence.length]);
}
function indices(values) {
  return bytes(values.flatMap(value => [Math.floor(value / 256), value % 256]));
}
test('the bundled list exactly matches the pinned EFF source and preserves all 7,776 words', () => {
  const raw = readFileSync(join(__dirname, '../third_party/eff/eff_large_wordlist.txt'));
  assert.equal(createHash('sha256').update(raw).digest('hex'),
    'addd35536511597a02fa0a9ff1e5284677b8883b83e986e43f15a3db996b903e');
  assert.deepEqual(words, raw.toString().trim().split('\n').map(line => line.trim().split(/\s+/)[1]));
  assert.equal(words.length, 7776);
  assert.equal(new Set(words).size, 7776);
  assert.ok(words.every(word => /^[a-z]+(?:-[a-z]+)?$/.test(word)));
  // The four hyphenated words cannot be confused with two separate list entries.
  // Thus word + delimiter is a prefix-free code for every supported delimiter.
  for (const word of words.filter(word => word.includes('-'))) {
    assert.equal(words.includes(word.split('-')[0]), false);
  }
});
test('default passphrases contain six independently selected words and about 77.55 bits', () => {
  const result = core.generatePassphraseFromSource(options(), indices([0, 1, 2, 3, 4, 7775]), words);
  assert.equal(result.value, [0, 1, 2, 3, 4, 7775].map(i => words[i]).join('-'));
  assert.ok(Math.abs(result.entropyBits - 6 * Math.log2(7776)) < 1e-10);
  assert.equal(result.entropyBits, core.estimatePasswordEntropy(options()));
});
test('word count boundaries work and invalid options fail before reading randomness', () => {
  for (const count of [4, 10]) {
    const result = core.generatePassphraseFromSource(options({ wordCount: count, separator: ' ' }), indices([0]), words);
    assert.equal(result.value.split(' ').length, count);
  }
  for (const extra of [{ wordCount: 3 }, { wordCount: 11 }, { wordCount: 6.5 }, { wordCount: NaN },
    { separator: '' }, { separator: 'a' }, { separator: '\n' }, { mode: 'pin' }]) {
    assert.throws(() => core.generatePassphraseFromSource(options(extra), () => assert.fail('must not read'), words));
  }
  assert.throws(() => core.generatePassphraseFromSource(options(), () => assert.fail('must not read'), words.slice(1)));
});
test('16-bit rejection sampling discards 62208 and reaches the first and last words without bias', () => {
  const result = core.generatePassphraseFromSource(options({ wordCount: 4 }),
    indices([62208, 0, 7775, 7776, 62207]), words);
  assert.equal(result.value, [0, 7775, 0, 7775].map(i => words[i]).join('-'));
});
test('every word index is reachable, including indices beyond one byte', () => {
  for (let start = 0; start < 7776; start += 4) {
    const chosen = [start, start + 1, start + 2, start + 3];
    const result = core.generatePassphraseFromSource(options({ wordCount: 4, separator: ' ' }), indices(chosen), words);
    assert.equal(result.value, chosen.map(i => words[i]).join(' '));
  }
});
test('all separator and capitalization combinations preserve entropy and the selected words', () => {
  for (const separator of ['-', ' ', '_', '.']) {
    for (const capitalize of [false, true]) {
      const configuration = options({ separator, capitalize });
      const result = core.generatePassphraseFromSource(configuration, indices([0]), words);
      assert.equal(result.value, new Array(6).fill(capitalize ? 'Abacus' : 'abacus').join(separator));
      assert.equal(result.entropyBits, 6 * Math.log2(7776));
    }
  }
});
test('appended digits use independent unbiased sampling, including zero', () => {
  for (const digit of [0, 9]) {
    // Six word draws, rejected digit 250, then the accepted digit.
    const result = core.generatePassphraseFromSource(options({ appendNumber: true }),
      bytes([...new Array(12).fill(0), 250, digit]), words);
    assert.equal(result.value, new Array(6).fill('abacus').join('-') + digit);
    assert.equal(result.entropyBits, 6 * Math.log2(7776) + Math.log2(10));
  }
});
test('inactive password rules do not block passphrases', () => {
  const configuration = options({ length: 0, includeLowercase: false, includeUppercase: false,
    includeNumbers: false, includeSymbols: false, symbols: '' });
  assert.equal(core.validateGeneratorOptions(configuration), core.GeneratorValidation.VALID);
  assert.ok(core.generatePassphraseFromSource(configuration, indices([0]), words).value.length > 0);
  assert.throws(() => core.generatePasswordFromSource(configuration, indices([0])));
});
test('provider failures are bounded and temporary buffers are erased', () => {
  let supplied;
  core.generatePassphraseFromSource(options(), length => { supplied = new Uint8Array(length); return supplied; }, words);
  assert.ok(supplied.every(value => value === 0));
  let calls = 0;
  assert.throws(() => core.generatePassphraseFromSource(options(), length => {
    assert.ok(++calls <= 1024);
    supplied = new Uint8Array(length).fill(255);
    return supplied;
  }, words), { message: 'Secure password generation failed.' });
  assert.ok(supplied.every(value => value === 0));
  const short = new Uint8Array(3).fill(99);
  assert.throws(() => core.generatePassphraseFromSource(options(), () => short, words));
  assert.ok(short.every(value => value === 0));
});
test('the production adapter dispatches passphrases and retains capability and failure protections', () => {
  platformSource = indices([0]);
  assert.equal(adapter.generatePassword(options()).value, new Array(6).fill('abacus').join('-'));
  capability = false;
  assert.throws(() => adapter.generatePassword(options()), { failure: core.GeneratorFailure.UNSUPPORTED });
  capability = true;
  platformSource = () => { throw new Error('PRIVATE_PLATFORM_DETAIL'); };
  assert.throws(() => adapter.generatePassword(options()), {
    failure: core.GeneratorFailure.UNAVAILABLE, message: 'Secure password generation failed.'
  });
});
