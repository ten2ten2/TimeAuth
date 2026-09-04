import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { ThemePreference } from '../models/AppModels';

export const THEME_PREFERENCE_STORAGE_KEY: string = 'timeauth.themePreference';
const THEME_PREFERENCES_NAME: string = 'timeauth_preferences';

export function readThemePreference(context: common.Context): ThemePreference {
  try {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, {
      name: THEME_PREFERENCES_NAME
    });
    const storedValue: string = store.getSync(THEME_PREFERENCE_STORAGE_KEY,
      ThemePreference.SYSTEM) as string;
    if (storedValue === ThemePreference.LIGHT) {
      return ThemePreference.LIGHT;
    }
    if (storedValue === ThemePreference.DARK) {
      return ThemePreference.DARK;
    }
  } catch (error) {
    console.error(`Failed to read TimeAuth theme preference: ${JSON.stringify(error)}`);
  }
  return ThemePreference.SYSTEM;
}

export function saveThemePreference(context: common.Context, preference: ThemePreference): void {
  try {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, {
      name: THEME_PREFERENCES_NAME
    });
    store.putSync(THEME_PREFERENCE_STORAGE_KEY, preference);
    store.flush((error: BusinessError) => {
      if (error) {
        console.error(`Failed to persist TimeAuth theme preference: ${JSON.stringify(error)}`);
      }
    });
  } catch (error) {
    console.error(`Failed to save TimeAuth theme preference: ${JSON.stringify(error)}`);
  }
}

export function colorModeForTheme(preference: ThemePreference): ConfigurationConstant.ColorMode {
  if (preference === ThemePreference.LIGHT) {
    return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  }
  if (preference === ThemePreference.DARK) {
    return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }
  return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
}
