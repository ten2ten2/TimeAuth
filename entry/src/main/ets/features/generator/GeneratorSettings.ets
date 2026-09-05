import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { GeneratorMode, GeneratorOptions, GeneratorValidation, validateGeneratorOptions } from './GeneratorCore';

const PREFERENCES_NAME: string = 'timeauth_preferences';
const OPTIONS_KEY: string = 'timeauth.generator.options.v1';

function tabOptionsKey(mode: GeneratorMode): string {
  return `timeauth.generator.options.${mode}.v2`;
}

export class GeneratorPreferencesResult {
  options: GeneratorOptions = new GeneratorOptions();
  succeeded: boolean = true;
}

// Keep a whitelist: a password/result must never enter the preferences payload.
export function copyGeneratorOptions(source: GeneratorOptions): GeneratorOptions {
  const options: GeneratorOptions = new GeneratorOptions();
  // Missing fields belong to the original password-only v1 settings format.
  if (source.mode !== undefined) { options.mode = source.mode; }
  if (source.pinLength !== undefined) { options.pinLength = source.pinLength; }
  if (source.wordCount !== undefined) { options.wordCount = source.wordCount; }
  if (source.separator !== undefined) { options.separator = source.separator; }
  if (source.capitalize !== undefined) { options.capitalize = source.capitalize; }
  if (source.appendNumber !== undefined) { options.appendNumber = source.appendNumber; }
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

export function readGeneratorOptions(context: common.Context,
  mode: GeneratorMode = GeneratorMode.PASSWORD): GeneratorPreferencesResult {
  const result: GeneratorPreferencesResult = new GeneratorPreferencesResult();
  result.options.mode = mode;
  try {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
    // Migrate each tab lazily, so saving one tab cannot erase the other tab's legacy rules.
    let raw: preferences.ValueType = store.getSync(tabOptionsKey(mode), '');
    if (raw === '' && mode !== GeneratorMode.PIN) {
      raw = store.getSync(OPTIONS_KEY, '');
    }
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
      typeof saved.symbols !== 'string' ||
      (saved.mode !== undefined && saved.mode !== GeneratorMode.PASSWORD &&
        saved.mode !== GeneratorMode.PASSPHRASE && saved.mode !== GeneratorMode.PIN) ||
      (saved.pinLength !== undefined && [4, 6, 8].indexOf(saved.pinLength) < 0) ||
      (saved.wordCount !== undefined && (typeof saved.wordCount !== 'number' ||
        !Number.isInteger(saved.wordCount) || saved.wordCount < 4 || saved.wordCount > 10)) ||
      (saved.separator !== undefined && ['-', ' ', '_', '.'].indexOf(saved.separator) < 0) ||
      (saved.capitalize !== undefined && typeof saved.capitalize !== 'boolean') ||
      (saved.appendNumber !== undefined && typeof saved.appendNumber !== 'boolean')) {
      result.succeeded = false;
      return result;
    }
    result.options = copyGeneratorOptions(saved);
    result.options.mode = mode;
    if (validateGeneratorOptions(result.options) !== GeneratorValidation.VALID) {
      result.options = new GeneratorOptions();
      result.options.mode = mode;
      result.succeeded = false;
    }
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
    store.putSync(tabOptionsKey(options.mode), JSON.stringify(copyGeneratorOptions(options)));
    await store.flush();
    return true;
  } catch (_) {
    return false;
  }
}
