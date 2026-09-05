import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { i18n } from '@kit.LocalizationKit';
import { LanguagePreference } from '../models/AppModels';

const LANGUAGE_PREFERENCE_STORAGE_KEY: string = 'timeauth.languagePreference';
const PREFERENCES_NAME: string = 'timeauth_preferences';
let lastAppliedTag: string = '';
let lastAppliedPreference: LanguagePreference = LanguagePreference.SYSTEM;

function getStore(context: common.Context): preferences.Preferences {
  return preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
}

export function readLanguagePreference(context: common.Context): LanguagePreference {
  try {
    const value: string = getStore(context).getSync(
      LANGUAGE_PREFERENCE_STORAGE_KEY, LanguagePreference.SYSTEM) as string;
    if (value === LanguagePreference.SIMPLIFIED_CHINESE ||
      value === LanguagePreference.TRADITIONAL_CHINESE || value === LanguagePreference.ENGLISH) {
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
    store = getStore(context);
    store.putSync(LANGUAGE_PREFERENCE_STORAGE_KEY, preference);
    await store.flush();
    return true;
  } catch (error) {
    // putSync also changes the in-memory Preferences cache. Restore it on failure.
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
  if (preference === LanguagePreference.TRADITIONAL_CHINESE) {
    return 'zh-Hant';
  }
  if (preference === LanguagePreference.ENGLISH) {
    return 'en';
  }
  const tag: string = systemLanguage.replace(/_/g, '-').toLowerCase();
  const parts: string[] = tag.split('-');
  if (parts[0] !== 'zh') {
    return 'en';
  }
  if (parts.includes('hant')) {
    return 'zh-Hant';
  }
  if (parts.includes('hans')) {
    return 'zh-Hans';
  }
  return parts.includes('tw') || parts.includes('hk') || parts.includes('mo') ? 'zh-Hant' : 'zh-Hans';
}

// Call after loadContent. The native 'default' preference takes effect on cold start,
// so SYSTEM is resolved now and re-evaluated on locale events, foreground and launch.
// Only the user's SYSTEM choice is persisted in our Preferences, never this resolved tag.
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
