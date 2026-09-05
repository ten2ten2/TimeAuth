// Pure generation rules. The platform adapter is the only production source of random bytes.
export enum GeneratorMode {
  PASSWORD = 'password',
  PASSPHRASE = 'passphrase',
  PIN = 'pin'
}

export class GeneratorOptions {
  mode: GeneratorMode = GeneratorMode.PASSWORD;
  pinLength: number = 6;
  wordCount: number = 6;
  separator: string = '-';
  capitalize: boolean = false;
  appendNumber: boolean = false;
  length: number = 16;
  includeLowercase: boolean = true;
  includeUppercase: boolean = true;
  includeNumbers: boolean = true;
  includeSymbols: boolean = true;
  avoidAmbiguous: boolean = true;
  requireEach: boolean = true;
  symbols: string = '!@#$%^&*()-_=+[]{};:,.?';
}

export enum GeneratorValidation {
  VALID = 'valid',
  INVALID_MODE = 'invalid_mode',
  INVALID_PIN_LENGTH = 'invalid_pin_length',
  INVALID_WORD_COUNT = 'invalid_word_count',
  INVALID_SEPARATOR = 'invalid_separator',
  INVALID_LENGTH = 'invalid_length',
  NO_CHARACTERS = 'no_characters',
  INVALID_SYMBOLS = 'invalid_symbols',
  EMPTY_SYMBOLS = 'empty_symbols'
}

export enum GeneratorFailure {
  NONE = 'none',
  UNSUPPORTED = 'unsupported',
  UNAVAILABLE = 'unavailable'
}

// Only a sanitized category crosses the platform adapter boundary.
export class PasswordGenerationError extends Error {
  readonly failure: GeneratorFailure;

  constructor(failure: GeneratorFailure) {
    super('Secure password generation failed.');
    this.failure = failure;
  }
}

export class PasswordResult {
  value: string;
  entropyBits: number;

  constructor(value: string, entropyBits: number) {
    this.value = value;
    this.entropyBits = entropyBits;
  }
}

const RANDOM_CHUNK_SIZE: number = 256;
const MAX_BYTE_DRAWS: number = 262144;
const MAX_PASSWORD_ATTEMPTS: number = 1024;
const GENERATION_FAILURE: string = 'Secure password generation failed.';

export function validateGeneratorOptions(options: GeneratorOptions): GeneratorValidation {
  if (options.mode === GeneratorMode.PIN) {
    return [4, 6, 8].indexOf(options.pinLength) >= 0 ?
      GeneratorValidation.VALID : GeneratorValidation.INVALID_PIN_LENGTH;
  }
  if (options.mode === GeneratorMode.PASSPHRASE) {
    if (!Number.isInteger(options.wordCount) || options.wordCount < 4 || options.wordCount > 10) {
      return GeneratorValidation.INVALID_WORD_COUNT;
    }
    if (['-', ' ', '_', '.'].indexOf(options.separator) < 0) {
      return GeneratorValidation.INVALID_SEPARATOR;
    }
    return GeneratorValidation.VALID;
  }
  if (options.mode !== GeneratorMode.PASSWORD) {
    return GeneratorValidation.INVALID_MODE;
  }
  if (!Number.isInteger(options.length) || options.length < 8 || options.length > 128) {
    return GeneratorValidation.INVALID_LENGTH;
  }
  if (!options.includeLowercase && !options.includeUppercase &&
    !options.includeNumbers && !options.includeSymbols) {
    return GeneratorValidation.NO_CHARACTERS;
  }
  // An unused custom symbol setting must not block letters-only generation.
  if (options.includeSymbols) {
    if (options.symbols.length === 0) {
      return GeneratorValidation.EMPTY_SYMBOLS;
    }
    for (let index: number = 0; index < options.symbols.length; index++) {
      const code: number = options.symbols.charCodeAt(index);
      const punctuation: boolean = (code >= 33 && code <= 47) || (code >= 58 && code <= 64) ||
        (code >= 91 && code <= 96) || (code >= 123 && code <= 126);
      if (!punctuation) {
        return GeneratorValidation.INVALID_SYMBOLS;
      }
    }
  }
  return GeneratorValidation.VALID;
}

function uniqueCharacters(value: string, avoidAmbiguous: boolean): string {
  let result: string = '';
  for (let index: number = 0; index < value.length; index++) {
    const character: string = value.charAt(index);
    if (result.indexOf(character) >= 0 || (avoidAmbiguous && '0O1Il'.indexOf(character) >= 0)) {
      continue;
    }
    result += character;
  }
  return result;
}

function characterGroups(options: GeneratorOptions): string[] {
  const groups: string[] = [];
  if (options.includeLowercase) {
    groups.push(uniqueCharacters('abcdefghijklmnopqrstuvwxyz', options.avoidAmbiguous));
  }
  if (options.includeUppercase) {
    groups.push(uniqueCharacters('ABCDEFGHIJKLMNOPQRSTUVWXYZ', options.avoidAmbiguous));
  }
  if (options.includeNumbers) {
    groups.push(uniqueCharacters('0123456789', options.avoidAmbiguous));
  }
  if (options.includeSymbols) {
    groups.push(uniqueCharacters(options.symbols, options.avoidAmbiguous));
  }
  return groups;
}

function entropyForGroups(length: number, groups: string[], requireEach: boolean): number {
  let alphabetSize: number = 0;
  for (let group: number = 0; group < groups.length; group++) {
    alphabetSize += groups[group].length;
  }
  const unrestrictedBits: number = length * Math.log2(alphabetSize);
  if (!requireEach || groups.length === 1) {
    return unrestrictedBits;
  }

  // Probability DP counts category coverage without overflowing at 128 characters.
  // Every accepted string is equally likely, so entropy = log2(number of legal strings).
  const stateCount: number = 1 << groups.length;
  let probabilities: number[] = new Array<number>(stateCount).fill(0);
  probabilities[0] = 1;
  for (let position: number = 0; position < length; position++) {
    const next: number[] = new Array<number>(stateCount).fill(0);
    for (let mask: number = 0; mask < stateCount; mask++) {
      for (let group: number = 0; group < groups.length; group++) {
        next[mask | (1 << group)] += probabilities[mask] * groups[group].length / alphabetSize;
      }
    }
    probabilities = next;
  }
  return unrestrictedBits + Math.log2(Math.min(1, probabilities[stateCount - 1]));
}

export function estimatePasswordEntropy(options: GeneratorOptions): number {
  if (validateGeneratorOptions(options) !== GeneratorValidation.VALID) {
    throw new Error('Invalid password generator options.');
  }
  if (options.mode === GeneratorMode.PIN) {
    return options.pinLength * Math.log2(10);
  }
  if (options.mode === GeneratorMode.PASSPHRASE) {
    return options.wordCount * Math.log2(7776) + (options.appendNumber ? Math.log2(10) : 0);
  }
  return entropyForGroups(options.length, characterGroups(options), options.requireEach);
}

// PINs are strings: all ten digits are eligible at every position, including a leading zero.
export function generatePinFromSource(options: GeneratorOptions,
  randomBytes: (length: number) => Uint8Array): PasswordResult {
  if (options.mode !== GeneratorMode.PIN || validateGeneratorOptions(options) !== GeneratorValidation.VALID) {
    throw new Error('Invalid PIN generator options.');
  }
  const reader: RandomByteReader = new RandomByteReader(randomBytes);
  try {
    let value: string = '';
    for (let index: number = 0; index < options.pinLength; index++) {
      value += `${reader.uniformIndex(10)}`;
    }
    return new PasswordResult(value, options.pinLength * Math.log2(10));
  } catch (_) {
    throw new Error(GENERATION_FAILURE);
  } finally {
    reader.clear();
  }
}

class RandomByteReader {
  private randomBytes: (length: number) => Uint8Array;
  private bytes: Uint8Array = new Uint8Array(0);
  private offset: number = 0;
  private draws: number = 0;

  constructor(randomBytes: (length: number) => Uint8Array) {
    this.randomBytes = randomBytes;
  }

  uniformIndex(size: number): number {
    if (!Number.isInteger(size) || size < 1 || size > 65536) {
      throw new Error(GENERATION_FAILURE);
    }
    const range: number = size > 256 ? 65536 : 256;
    const acceptanceLimit: number = Math.floor(range / size) * size;
    while (this.draws < MAX_BYTE_DRAWS) {
      const value: number = size > 256 ? this.nextByte() * 256 + this.nextByte() : this.nextByte();
      // Discard the incomplete range rather than biasing characters or words with modulo.
      if (value < acceptanceLimit) {
        return value % size;
      }
    }
    throw new Error(GENERATION_FAILURE);
  }

  private nextByte(): number {
    if (this.draws >= MAX_BYTE_DRAWS) {
      throw new Error(GENERATION_FAILURE);
    }
    if (this.offset >= this.bytes.length) {
      this.clear();
      const bytes: Uint8Array = this.randomBytes(RANDOM_CHUNK_SIZE);
      if (!(bytes instanceof Uint8Array) || bytes.length !== RANDOM_CHUNK_SIZE) {
        if (bytes instanceof Uint8Array) {
          bytes.fill(0);
        }
        throw new Error(GENERATION_FAILURE);
      }
      this.bytes = bytes;
    }
    this.draws++;
    return this.bytes[this.offset++];
  }

  clear(): void {
    this.bytes.fill(0);
    this.offset = 0;
  }
}

// randomBytes must supply fresh cryptographically secure bytes. Buffers are owned and cleared here.
export function generatePasswordFromSource(options: GeneratorOptions,
  randomBytes: (length: number) => Uint8Array): PasswordResult {
  if (options.mode !== GeneratorMode.PASSWORD || validateGeneratorOptions(options) !== GeneratorValidation.VALID) {
    throw new Error('Invalid password generator options.');
  }
  const groups: string[] = characterGroups(options);
  const alphabet: string = groups.join('');
  const allGroups: number = (1 << groups.length) - 1;
  const reader: RandomByteReader = new RandomByteReader(randomBytes);
  try {
    // Whole-string rejection preserves a uniform distribution over every valid password.
    // Inserting mandatory characters and shuffling would give some strings higher probability.
    for (let attempt: number = 0; attempt < MAX_PASSWORD_ATTEMPTS; attempt++) {
      let value: string = '';
      let seenGroups: number = 0;
      for (let position: number = 0; position < options.length; position++) {
        const character: string = alphabet.charAt(reader.uniformIndex(alphabet.length));
        value += character;
        for (let group: number = 0; group < groups.length; group++) {
          if (groups[group].indexOf(character) >= 0) {
            seenGroups |= 1 << group;
            break;
          }
        }
      }
      if (!options.requireEach || seenGroups === allGroups) {
        return new PasswordResult(value, entropyForGroups(options.length, groups, options.requireEach));
      }
    }
    throw new Error(GENERATION_FAILURE);
  } catch (error) {
    // Never propagate provider messages, which could contain sensitive diagnostic data.
    throw new Error(GENERATION_FAILURE);
  } finally {
    reader.clear();
  }
}

// The bundled list contains 7,776 unique lowercase words. Sampling is with replacement.
export function generatePassphraseFromSource(options: GeneratorOptions,
  randomBytes: (length: number) => Uint8Array, words: string[]): PasswordResult {
  if (options.mode !== GeneratorMode.PASSPHRASE ||
    validateGeneratorOptions(options) !== GeneratorValidation.VALID || words.length !== 7776) {
    throw new Error('Invalid passphrase generator options.');
  }
  const reader: RandomByteReader = new RandomByteReader(randomBytes);
  try {
    const selected: string[] = [];
    for (let index: number = 0; index < options.wordCount; index++) {
      const word: string = words[reader.uniformIndex(words.length)];
      selected.push(options.capitalize ? word.charAt(0).toUpperCase() + word.slice(1) : word);
    }
    let value: string = selected.join(options.separator);
    if (options.appendNumber) {
      value += `${reader.uniformIndex(10)}`;
    }
    // Separators and fixed capitalization add no entropy. A fresh appended digit adds log2(10).
    return new PasswordResult(value,
      options.wordCount * Math.log2(words.length) + (options.appendNumber ? Math.log2(10) : 0));
  } catch (_) {
    throw new Error(GENERATION_FAILURE);
  } finally {
    reader.clear();
  }
}
