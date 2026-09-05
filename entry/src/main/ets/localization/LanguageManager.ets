import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { i18n } from '@kit.LocalizationKit';
import { LanguagePreference } from '../models/AppModels';

const LANGUAGE_PREFERENCE_STORAGE_KEY: string = 'timeauth.languagePreference';
const PREFERENCES_NAME: string = 'timeauth_preferences';

function getStore(context: common.Context): preferences.Preferences {
  return preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
}

export function readLanguagePreference(context: common.Context): LanguagePreference {
  try {
    const storedValue: string = getStore(context).getSync(
      LANGUAGE_PREFERENCE_STORAGE_KEY,
      LanguagePreference.SYSTEM
    ) as string;
    if (storedValue === LanguagePreference.SIMPLIFIED_CHINESE) {
      return LanguagePreference.SIMPLIFIED_CHINESE;
    }
    if (storedValue === LanguagePreference.TRADITIONAL_CHINESE) {
      return LanguagePreference.TRADITIONAL_CHINESE;
    }
    if (storedValue === LanguagePreference.ENGLISH) {
      return LanguagePreference.ENGLISH;
    }
  } catch (error) {
    console.error(`Failed to read TimeAuth language preference: ${JSON.stringify(error)}`);
  }
  return LanguagePreference.SYSTEM;
}

export async function saveLanguagePreference(context: common.Context,
  preference: LanguagePreference): Promise<boolean> {
  try {
    const store: preferences.Preferences = getStore(context);
    store.putSync(LANGUAGE_PREFERENCE_STORAGE_KEY, preference);
    await store.flush();
    return true;
  } catch (error) {
    console.error(`Failed to save TimeAuth language preference: ${JSON.stringify(error)}`);
    return false;
  }
}

export function applyLanguagePreference(preference: LanguagePreference): void {
  let languageTag: string = 'default';
  if (preference === LanguagePreference.SIMPLIFIED_CHINESE) {
    languageTag = 'zh-Hans';
  } else if (preference === LanguagePreference.TRADITIONAL_CHINESE) {
    languageTag = 'zh-Hant';
  } else if (preference === LanguagePreference.ENGLISH) {
    languageTag = 'en';
  }

  try {
    i18n.System.setAppPreferredLanguage(languageTag);
  } catch (error) {
    console.error(`Failed to set TimeAuth language preference: ${JSON.stringify(error)}`);
  }
}
