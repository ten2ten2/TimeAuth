import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { applyThemePreference, readThemePreference } from '../design/ThemeManager';
import { clearGeneratorSession } from '../features/generator/GeneratorSession';
import {
  applyLanguagePreference, readLanguagePreference, refreshSystemLanguage
} from '../localization/LanguageManager';
import {
  attachScreenSecurity, detachScreenSecurity, handleWindowEvent,
  handleWindowStageLifecycle, markScreenContentReady, reportScreenSecuritySetupFailure, setScreenAbilityForeground
} from '../security/ScreenSecurityManager';
import { disposeSensitiveClipboard, resumeSensitiveClipboardClear } from '../security/SecureClipboard';
import { configureAppUnlock, lockAppSession, setAppSessionForeground } from '../security/AppSession';
import { readSecuritySettings } from '../security/SecuritySettingsManager';

export default class EntryAbility extends UIAbility {
  private windowStage: window.WindowStage | undefined = undefined;
  private mainWindow: window.Window | undefined = undefined;
  private lifecycleListener: ((event: window.WindowStageLifecycleEventType) => void) | undefined = undefined;
  private windowListener: ((event: window.WindowEventType) => void) | undefined = undefined;
  private localeSubscriber: commonEventManager.CommonEventSubscriber | undefined = undefined;
  private contentLoaded: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // App unlock is opt-in. Screen privacy and encrypted storage are independent of this preference.
    configureAppUnlock(readSecuritySettings(this.context).appUnlockEnabled);
    hilog.info(0x0000, 'TimeAuth', 'EntryAbility created');
    try {
      const subscriber: commonEventManager.CommonEventSubscriber = commonEventManager.createSubscriberSync({
        events: [commonEventManager.Support.COMMON_EVENT_LOCALE_CHANGED]
      });
      this.localeSubscriber = subscriber;
      commonEventManager.subscribe(subscriber, (error: BusinessError, data: commonEventManager.CommonEventData) => {
        if (this.localeSubscriber !== subscriber) { return; }
        if (error) {
          hilog.error(0x0000, 'TimeAuth', 'Locale subscription failed: %{public}s', JSON.stringify(error));
          return;
        }
        if (this.contentLoaded && data.event === commonEventManager.Support.COMMON_EVENT_LOCALE_CHANGED) {
          refreshSystemLanguage(this.context);
        }
      });
    } catch (error) {
      hilog.error(0x0000, 'TimeAuth', 'Locale listener unavailable: %{public}s', JSON.stringify(error));
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.windowStage = windowStage;
    this.contentLoaded = false;
    try {
      this.mainWindow = windowStage.getMainWindowSync();
      attachScreenSecurity(this.context, this.mainWindow);
      this.windowListener = (event: window.WindowEventType): void => {
        handleWindowEvent(event);
      };
      this.mainWindow.on('windowEvent', this.windowListener);
    } catch (error) {
      reportScreenSecuritySetupFailure();
      hilog.error(0x0000, 'TimeAuth', 'Main window security setup failed: %{public}s', JSON.stringify(error));
    }
    this.lifecycleListener = (event: window.WindowStageLifecycleEventType): void => {
      handleWindowStageLifecycle(event);
    };
    try {
      windowStage.on('windowStageLifecycleEvent', this.lifecycleListener);
    } catch (error) {
      reportScreenSecuritySetupFailure();
      hilog.error(0x0000, 'TimeAuth', 'Stage lifecycle subscription failed: %{public}s', JSON.stringify(error));
    }

    windowStage.loadContent('pages/Index', (error) => {
      if (this.windowStage !== windowStage) { return; }
      if (error.code) {
        hilog.error(0x0000, 'TimeAuth', 'Failed to load content: %{public}s', JSON.stringify(error));
        return;
      }
      this.contentLoaded = true;
      applyLanguagePreference(this.context, readLanguagePreference(this.context));
      applyThemePreference(this.context, readThemePreference(this.context));
      if (this.mainWindow !== undefined) {
        markScreenContentReady(this.context, this.mainWindow.getUIContext());
      }
    });
  }

  onForeground(): void {
    // When app unlock is disabled this restores the transient session automatically; when enabled it remains locked.
    setAppSessionForeground(true);
    resumeSensitiveClipboardClear();
    if (this.contentLoaded) {
      refreshSystemLanguage(this.context);
    }
    setScreenAbilityForeground(true);
  }

  onBackground(): void {
    setScreenAbilityForeground(false);
    // Always close the transient session so decrypted authenticator material is released on backgrounding.
    setAppSessionForeground(false);
  }

  onWindowStageDestroy(): void {
    lockAppSession();
    this.contentLoaded = false;
    if (this.mainWindow !== undefined && this.windowListener !== undefined) {
      try {
        this.mainWindow.off('windowEvent', this.windowListener);
      } catch (error) {
        hilog.error(0x0000, 'TimeAuth', 'Failed to remove window listener: %{public}s', JSON.stringify(error));
      }
    }
    if (this.windowStage !== undefined && this.lifecycleListener !== undefined) {
      try {
        this.windowStage.off('windowStageLifecycleEvent', this.lifecycleListener);
      } catch (error) {
        hilog.error(0x0000, 'TimeAuth', 'Failed to remove stage listener: %{public}s', JSON.stringify(error));
      }
    }
    detachScreenSecurity();
    this.windowListener = undefined;
    this.lifecycleListener = undefined;
    this.mainWindow = undefined;
    this.windowStage = undefined;
  }

  onDestroy(): void {
    lockAppSession();
    disposeSensitiveClipboard();
    clearGeneratorSession();
    const subscriber: commonEventManager.CommonEventSubscriber | undefined = this.localeSubscriber;
    this.localeSubscriber = undefined;
    if (subscriber !== undefined) {
      try {
        commonEventManager.unsubscribe(subscriber, (error: BusinessError) => {
          if (error) {
            hilog.error(0x0000, 'TimeAuth', 'Locale unsubscribe failed: %{public}s', JSON.stringify(error));
          }
        });
      } catch (error) {
        hilog.error(0x0000, 'TimeAuth', 'Locale cleanup failed: %{public}s', JSON.stringify(error));
      }
    }
  }
}
