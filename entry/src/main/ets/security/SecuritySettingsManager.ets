import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';

const PREFERENCES_NAME: string = 'timeauth_preferences';
const HIDE_TASK_PREVIEW_KEY: string = 'timeauth.hideTaskPreview';
const CLEAR_CLIPBOARD_KEY: string = 'timeauth.clearClipboard';

export interface SecuritySettings {
  hideTaskPreview: boolean;
  clearClipboard: boolean;
}

export function readSecuritySettings(context: common.Context): SecuritySettings {
  try {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
    return {
      hideTaskPreview: store.getSync(HIDE_TASK_PREVIEW_KEY, true) as boolean,
      clearClipboard: store.getSync(CLEAR_CLIPBOARD_KEY, true) as boolean
    };
  } catch (error) {
    console.error(`Failed to read TimeAuth security settings: ${JSON.stringify(error)}`);
    return {
      hideTaskPreview: true,
      clearClipboard: true
    };
  }
}

function saveBoolean(context: common.Context, key: string, value: boolean): void {
  try {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
    store.putSync(key, value);
    store.flush((error: BusinessError) => {
      if (error) {
        console.error(`Failed to persist TimeAuth security setting ${key}: ${JSON.stringify(error)}`);
      }
    });
  } catch (error) {
    console.error(`Failed to save TimeAuth security setting ${key}: ${JSON.stringify(error)}`);
  }
}

export function saveHideTaskPreview(context: common.Context, value: boolean): void {
  saveBoolean(context, HIDE_TASK_PREVIEW_KEY, value);
}

export function saveClearClipboard(context: common.Context, value: boolean): void {
  saveBoolean(context, CLEAR_CLIPBOARD_KEY, value);
}
