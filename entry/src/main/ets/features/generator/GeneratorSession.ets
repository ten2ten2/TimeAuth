import { GeneratorFailure, GeneratorOptions } from './GeneratorCore';

export class GeneratorSession {
  initialized: boolean = false;
  options: GeneratorOptions = new GeneratorOptions();
  value: string = '';
  entropyBits: number = 0;
  generatedFor: string = '';
  generationFailure: GeneratorFailure = GeneratorFailure.NONE;
}

// Memory only. Survives page recreation and language/theme changes, never process restart.
let session: GeneratorSession = new GeneratorSession();

export function getGeneratorSession(): GeneratorSession {
  return session;
}

export function clearGeneratorSession(): void {
  session.value = '';
  session.generatedFor = '';
  session = new GeneratorSession();
}
