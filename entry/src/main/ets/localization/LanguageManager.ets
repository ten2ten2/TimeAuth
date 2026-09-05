import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { i18n } from '@kit.LocalizationKit';
import { LanguagePreference } from '../models/AppModels';

const LANGUAGE_PREFERENCE_STORAGE_KEY: string = 'timeauth.languagePreference';
const PREFERENCES_NAME: string = 'timeauth_preferences';
let lastAppliedTag: string = '';
let lastAppliedPreference: LanguagePreference = LanguagePreference.SYSTEM;

export function readLanguagePreference(context: common.Context): LanguagePreference {
  try {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
    const value: string = store.getSync(
      LANGUAGE_PREFERENCE_STORAGE_KEY, LanguagePreference.SYSTEM) as string;
    if (value === LanguagePreference.SIMPLIFIED_CHINESE ||
      value === LanguagePreference.TRADITIONAL_CHINESE_TAIWAN ||
      value === LanguagePreference.TRADITIONAL_CHINESE_HONG_KONG ||
      value === LanguagePreference.ENGLISH) {
      return value as LanguagePreference;
    }
  } catch (error) {
    console.error(`Failed to read TimeAuth language preference: ${JSON.stringify(error)}`);
  }
  return LanguagePreference.SYSTEM;
}

export async function saveLanguagePreference(context: common.Context,
  preference: LanguagePreference): Promise<boolean> {
  let store: preferences.Preferences | undefined = undefined;
  const previous: LanguagePreference = readLanguagePreference(context);
  try {
    store = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
    store.putSync(LANGUAGE_PREFERENCE_STORAGE_KEY, preference);
    await store.flush();
    return true;
  } catch (error) {
    if (store !== undefined) {
      try {
        store.putSync(LANGUAGE_PREFERENCE_STORAGE_KEY, previous);
        await store.flush();
      } catch (rollbackError) {
        console.error(`Failed to roll back language preference: ${JSON.stringify(rollbackError)}`);
      }
    }
    console.error(`Failed to save TimeAuth language preference: ${JSON.stringify(error)}`);
    return false;
  }
}

export function resolveLanguageTag(preference: LanguagePreference, systemLanguage: string): string {
  if (preference === LanguagePreference.SIMPLIFIED_CHINESE) {
    return 'zh-Hans';
  }
  if (preference === LanguagePreference.TRADITIONAL_CHINESE_TAIWAN) {
    return 'zh-Hant-TW';
  }
  if (preference === LanguagePreference.TRADITIONAL_CHINESE_HONG_KONG) {
    return 'zh-Hant-HK';
  }
  if (preference === LanguagePreference.ENGLISH) {
    return 'en';
  }

  const tag: string = systemLanguage.replace(/_/g, '-').toLowerCase();
  const parts: string[] = tag.split('-');
  if (parts[0] !== 'zh') {
    return 'en';
  }
  if (parts.includes('hans')) {
    return 'zh-Hans';
  }
  if (parts.includes('hant')) {
    return parts.includes('hk') || parts.includes('mo') ? 'zh-Hant-HK' : 'zh-Hant-TW';
  }
  if (parts.includes('tw')) {
    return 'zh-Hant-TW';
  }
  if (parts.includes('hk') || parts.includes('mo')) {
    return 'zh-Hant-HK';
  }
  return 'zh-Hans';
}

// SYSTEM follows the current OS language. Region only chooses the Chinese variant.
export function applyLanguagePreference(context: common.Context,
  preference: LanguagePreference, force: boolean = true): boolean {
  try {
    const systemLanguage: string = preference === LanguagePreference.SYSTEM ?
      i18n.System.getSystemLanguage() : '';
    const tag: string = resolveLanguageTag(preference, systemLanguage);
    if (!force && tag === lastAppliedTag && preference === lastAppliedPreference) {
      return true;
    }
    i18n.System.setAppPreferredLanguage(tag);
    context.getApplicationContext().setLanguage(tag);
    lastAppliedTag = tag;
    lastAppliedPreference = preference;
    return true;
  } catch (error) {
    console.error(`Failed to apply TimeAuth language: ${JSON.stringify(error)}`);
    return false;
  }
}

export function refreshSystemLanguage(context: common.Context): void {
  if (readLanguagePreference(context) === LanguagePreference.SYSTEM) {
    applyLanguagePreference(context, LanguagePreference.SYSTEM, false);
  }
}
