import { i18n } from '@kit.LocalizationKit';
import { LanguagePreference } from '../models/AppModels';

export const LANGUAGE_PREFERENCE_STORAGE_KEY: string = 'timeauth.languagePreference';

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
