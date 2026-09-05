import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { readSecuritySettings, SecuritySettings } from './SecuritySettingsManager';

export enum ScreenSecurityPage {
  ONBOARDING = 'ONBOARDING',
  ABOUT = 'ABOUT',
  SETTINGS = 'SETTINGS',
  UNLOCK = 'UNLOCK',
  AUTHENTICATOR = 'AUTHENTICATOR',
  VAULT = 'VAULT',
  GENERATOR = 'GENERATOR'
}

let currentPage: ScreenSecurityPage = ScreenSecurityPage.ONBOARDING;
let isWindowResumed: boolean = false;

function pageAllowsCapture(page: ScreenSecurityPage): boolean {
  return page === ScreenSecurityPage.ONBOARDING ||
    page === ScreenSecurityPage.ABOUT ||
    page === ScreenSecurityPage.SETTINGS;
}

function shouldUsePrivacyMode(context: common.Context): boolean {
  if (!pageAllowsCapture(currentPage)) {
    return true;
  }

  if (isWindowResumed) {
    return false;
  }

  const settings: SecuritySettings = readSecuritySettings(context);
  return settings.hideTaskPreview;
}

function applyPrivacyMode(context: common.Context): void {
  try {
    const abilityContext: common.UIAbilityContext = context as common.UIAbilityContext;
    if (abilityContext.windowStage === undefined) {
      return;
    }
    const mainWindow: window.Window = abilityContext.windowStage.getMainWindowSync();
    mainWindow.setWindowPrivacyMode(shouldUsePrivacyMode(context)).catch((error: BusinessError) => {
      console.error(`Failed to set TimeAuth screen privacy mode: ${JSON.stringify(error)}`);
    });
  } catch (error) {
    console.error(`Failed to apply TimeAuth screen privacy mode: ${JSON.stringify(error)}`);
  }
}

export function setCurrentScreen(context: common.Context, page: ScreenSecurityPage): void {
  currentPage = page;
  applyPrivacyMode(context);
}

export function handleWindowStageLifecycle(context: common.Context,
  event: window.WindowStageLifecycleEventType): void {
  isWindowResumed = event === window.WindowStageLifecycleEventType.RESUMED;
  applyPrivacyMode(context);
}

export function refreshScreenSecurity(context: common.Context): void {
  applyPrivacyMode(context);
}
