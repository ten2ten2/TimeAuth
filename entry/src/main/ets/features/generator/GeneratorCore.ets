// Pure generation rules. The platform adapter is the only production source of random bytes.
export class GeneratorOptions {
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
  return entropyForGroups(options.length, characterGroups(options), options.requireEach);
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
    const acceptanceLimit: number = Math.floor(256 / size) * size;
    while (this.draws < MAX_BYTE_DRAWS) {
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
      const value: number = this.bytes[this.offset++];
      this.draws++;
      // Discard the incomplete range; directly taking byte % size would bias characters.
      if (value < acceptanceLimit) {
        return value % size;
      }
    }
    throw new Error(GENERATION_FAILURE);
  }

  clear(): void {
    this.bytes.fill(0);
    this.offset = 0;
  }
}

// randomBytes must supply fresh cryptographically secure bytes. Buffers are owned and cleared here.
export function generatePasswordFromSource(options: GeneratorOptions,
  randomBytes: (length: number) => Uint8Array): PasswordResult {
  if (validateGeneratorOptions(options) !== GeneratorValidation.VALID) {
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
