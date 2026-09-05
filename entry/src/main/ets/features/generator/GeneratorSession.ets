import { GeneratorFailure, GeneratorMode, GeneratorOptions } from './GeneratorCore';

export class GeneratorSession {
  initialized: boolean = false;
  options: GeneratorOptions = new GeneratorOptions();
  value: string = '';
  entropyBits: number = 0;
  generatedFor: string = '';
  generationFailure: GeneratorFailure = GeneratorFailure.NONE;
  preferencesFailed: boolean = false;
  preferenceRevision: number = 0;

  constructor(mode: GeneratorMode = GeneratorMode.PASSWORD) {
    this.options.mode = mode;
  }
}

// Memory only. Survives page recreation and language/theme changes, never process restart.
let passwordSession: GeneratorSession = new GeneratorSession(GeneratorMode.PASSWORD);
let passphraseSession: GeneratorSession = new GeneratorSession(GeneratorMode.PASSPHRASE);
let pinSession: GeneratorSession = new GeneratorSession(GeneratorMode.PIN);
let selectedMode: GeneratorMode | undefined = undefined;

export function getGeneratorSession(mode: GeneratorMode = GeneratorMode.PASSWORD): GeneratorSession {
  if (mode === GeneratorMode.PIN) {
    return pinSession;
  }
  return mode === GeneratorMode.PASSPHRASE ? passphraseSession : passwordSession;
}

export function getSelectedGeneratorMode(): GeneratorMode | undefined {
  return selectedMode;
}

export function setSelectedGeneratorMode(mode: GeneratorMode): void {
  selectedMode = mode;
}

export function clearGeneratorSession(): void {
  for (const session of [passwordSession, passphraseSession, pinSession]) {
    session.value = '';
    session.generatedFor = '';
    session.entropyBits = 0;
  }
  passwordSession = new GeneratorSession(GeneratorMode.PASSWORD);
  passphraseSession = new GeneratorSession(GeneratorMode.PASSPHRASE);
  pinSession = new GeneratorSession(GeneratorMode.PIN);
  selectedMode = undefined;
}
