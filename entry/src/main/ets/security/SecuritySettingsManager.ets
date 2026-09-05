import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';

const PREFERENCES_NAME: string = 'timeauth_preferences';
const HIDE_TASK_PREVIEW_KEY: string = 'timeauth.hideTaskPreview';
const BLOCK_SCREENSHOTS_KEY: string = 'timeauth.blockScreenshots';
const CLEAR_CLIPBOARD_KEY: string = 'timeauth.clearClipboard';

export interface SecuritySettings {
  hideTaskPreview: boolean;
  blockScreenshots: boolean;
  clearClipboard: boolean;
}

function getStore(context: common.Context): preferences.Preferences {
  return preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
}

export function readSecuritySettings(context: common.Context): SecuritySettings {
  try {
    const store: preferences.Preferences = getStore(context);
    return {
      hideTaskPreview: store.getSync(HIDE_TASK_PREVIEW_KEY, true) as boolean,
      blockScreenshots: store.getSync(BLOCK_SCREENSHOTS_KEY, true) as boolean,
      clearClipboard: store.getSync(CLEAR_CLIPBOARD_KEY, true) as boolean
    };
  } catch (error) {
    console.error(`Failed to read TimeAuth security settings: ${JSON.stringify(error)}`);
    return {
      hideTaskPreview: true,
      blockScreenshots: true,
      clearClipboard: true
    };
  }
}

function saveBoolean(context: common.Context, key: string, value: boolean): void {
  try {
    const store: preferences.Preferences = getStore(context);
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

export function saveBlockScreenshots(context: common.Context, value: boolean): void {
  saveBoolean(context, BLOCK_SCREENSHOTS_KEY, value);
}

export function saveClearClipboard(context: common.Context, value: boolean): void {
  saveBoolean(context, CLEAR_CLIPBOARD_KEY, value);
}

export function applyWindowPrivacyMode(context: common.Context, isPrivate: boolean): void {
  try {
    const abilityContext: common.UIAbilityContext = context as common.UIAbilityContext;
    if (abilityContext.windowStage === undefined) {
      return;
    }
    const mainWindow: window.Window = abilityContext.windowStage.getMainWindowSync();
    mainWindow.setWindowPrivacyMode(isPrivate).catch((error: BusinessError) => {
      console.error(`Failed to set TimeAuth window privacy mode: ${JSON.stringify(error)}`);
    });
  } catch (error) {
    console.error(`Failed to apply TimeAuth window privacy mode: ${JSON.stringify(error)}`);
  }
}
