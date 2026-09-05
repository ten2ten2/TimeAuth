import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { GeneratorOptions, GeneratorValidation, validateGeneratorOptions } from './GeneratorCore';

const PREFERENCES_NAME: string = 'timeauth_preferences';
const OPTIONS_KEY: string = 'timeauth.generator.options.v1';

export class GeneratorPreferencesResult {
  options: GeneratorOptions = new GeneratorOptions();
  succeeded: boolean = true;
}

// Keep a whitelist: a password/result must never enter the preferences payload.
export function copyGeneratorOptions(source: GeneratorOptions): GeneratorOptions {
  const options: GeneratorOptions = new GeneratorOptions();
  options.length = source.length;
  options.includeLowercase = source.includeLowercase;
  options.includeUppercase = source.includeUppercase;
  options.includeNumbers = source.includeNumbers;
  options.includeSymbols = source.includeSymbols;
  options.avoidAmbiguous = source.avoidAmbiguous;
  options.requireEach = source.requireEach;
  options.symbols = source.symbols;
  return options;
}

export function readGeneratorOptions(context: common.Context): GeneratorPreferencesResult {
  const result: GeneratorPreferencesResult = new GeneratorPreferencesResult();
  try {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
    const raw: preferences.ValueType = store.getSync(OPTIONS_KEY, '');
    if (raw === '') {
      return result;
    }
    if (typeof raw !== 'string') {
      result.succeeded = false;
      return result;
    }
    const saved: GeneratorOptions = JSON.parse(raw) as GeneratorOptions;
    if (saved === null || typeof saved !== 'object' || typeof saved.length !== 'number' ||
      typeof saved.includeLowercase !== 'boolean' || typeof saved.includeUppercase !== 'boolean' ||
      typeof saved.includeNumbers !== 'boolean' || typeof saved.includeSymbols !== 'boolean' ||
      typeof saved.avoidAmbiguous !== 'boolean' || typeof saved.requireEach !== 'boolean' ||
      typeof saved.symbols !== 'string' || validateGeneratorOptions(saved) !== GeneratorValidation.VALID) {
      result.succeeded = false;
      return result;
    }
    result.options = copyGeneratorOptions(saved);
  } catch (_) {
    // Do not log persisted contents or exception payloads.
    result.succeeded = false;
  }
  return result;
}

export async function saveGeneratorOptions(context: common.Context, options: GeneratorOptions): Promise<boolean> {
  if (validateGeneratorOptions(options) !== GeneratorValidation.VALID) {
    return false;
  }
  try {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
    store.putSync(OPTIONS_KEY, JSON.stringify(copyGeneratorOptions(options)));
    await store.flush();
    return true;
  } catch (_) {
    return false;
  }
}
