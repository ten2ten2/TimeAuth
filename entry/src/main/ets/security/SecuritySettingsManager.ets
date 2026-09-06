import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';

const PREFERENCES_NAME: string = 'timeauth_preferences';
const HIDE_TASK_PREVIEW_KEY: string = 'timeauth.hideTaskPreview';
const CLEAR_CLIPBOARD_KEY: string = 'timeauth.clearClipboard';
const APP_UNLOCK_KEY: string = 'timeauth.appUnlockEnabled';

export interface SecuritySettings {
  hideTaskPreview: boolean;
  clearClipboard: boolean;
  appUnlockEnabled: boolean;
}

export function readSecuritySettings(context: common.Context): SecuritySettings {
  try {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
    return {
      hideTaskPreview: store.getSync(HIDE_TASK_PREVIEW_KEY, true) as boolean,
      clearClipboard: store.getSync(CLEAR_CLIPBOARD_KEY, true) as boolean,
      appUnlockEnabled: store.getSync(APP_UNLOCK_KEY, false) as boolean
    };
  } catch (error) {
    console.error(`Failed to read TimeAuth security settings: ${JSON.stringify(error)}`);
    // Missing preference => off by default. A storage/read exception is different: fail closed so an existing opt-in cannot be bypassed.
    return {
      hideTaskPreview: true,
      clearClipboard: true,
      appUnlockEnabled: true
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

export async function saveAppUnlockEnabled(context: common.Context, value: boolean): Promise<boolean> {
  try {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
    const previous: boolean = store.getSync(APP_UNLOCK_KEY, false) as boolean;
    store.putSync(APP_UNLOCK_KEY, value);
    try {
      await store.flush();
      return true;
    } catch (error) {
      store.putSync(APP_UNLOCK_KEY, previous);
      try { await store.flush(); } catch {}
      console.error(`Failed to persist TimeAuth app unlock setting: ${JSON.stringify(error)}`);
      return false;
    }
  } catch (error) {
    console.error(`Failed to save TimeAuth app unlock setting: ${JSON.stringify(error)}`);
    return false;
  }
}
