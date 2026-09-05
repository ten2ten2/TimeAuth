import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ThemePreference } from '../models/AppModels';

const THEME_PREFERENCE_STORAGE_KEY: string = 'timeauth.themePreference';
const THEME_PREFERENCES_NAME: string = 'timeauth_preferences';

export function readThemePreference(context: common.Context): ThemePreference {
  try {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, {
      name: THEME_PREFERENCES_NAME
    });
    const value: string = store.getSync(THEME_PREFERENCE_STORAGE_KEY, ThemePreference.SYSTEM) as string;
    if (value === ThemePreference.LIGHT || value === ThemePreference.DARK) {
      return value as ThemePreference;
    }
  } catch (error) {
    console.error(`Failed to read TimeAuth theme preference: ${JSON.stringify(error)}`);
  }
  return ThemePreference.SYSTEM;
}

export async function saveThemePreference(context: common.Context, preference: ThemePreference): Promise<boolean> {
  let store: preferences.Preferences | undefined = undefined;
  const previous: ThemePreference = readThemePreference(context);
  try {
    store = preferences.getPreferencesSync(context, { name: THEME_PREFERENCES_NAME });
    store.putSync(THEME_PREFERENCE_STORAGE_KEY, preference);
    await store.flush();
    return true;
  } catch (error) {
    if (store !== undefined) {
      try {
        store.putSync(THEME_PREFERENCE_STORAGE_KEY, previous);
        await store.flush();
      } catch (rollbackError) {
        console.error(`Failed to roll back theme preference: ${JSON.stringify(rollbackError)}`);
      }
    }
    console.error(`Failed to save TimeAuth theme preference: ${JSON.stringify(error)}`);
    return false;
  }
}

// Requires a created window with loaded page content.
export function applyThemePreference(context: common.Context, preference: ThemePreference): boolean {
  try {
    context.getApplicationContext().setColorMode(colorModeForTheme(preference));
    return true;
  } catch (error) {
    console.error(`Failed to apply TimeAuth theme preference: ${JSON.stringify(error)}`);
    return false;
  }
}

function colorModeForTheme(preference: ThemePreference): ConfigurationConstant.ColorMode {
  if (preference === ThemePreference.LIGHT) {
    return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  }
  if (preference === ThemePreference.DARK) {
    return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }
  return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
}
