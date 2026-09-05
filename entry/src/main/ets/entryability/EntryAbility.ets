import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { applyThemePreference, readThemePreference } from '../design/ThemeManager';
import { readSecuritySettings, SecuritySettings } from '../security/SecuritySettingsManager';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | undefined = undefined;
  private windowStage: window.WindowStage | undefined = undefined;
  private stageEventListener: ((event: window.WindowStageEventType) => void) | undefined = undefined;

  private applyPrivacyMode(isPrivate: boolean): void {
    if (this.mainWindow === undefined) {
      return;
    }
    this.mainWindow.setWindowPrivacyMode(isPrivate).catch((error: BusinessError) => {
      hilog.error(0x0000, 'TimeAuth', 'Failed to update window privacy mode: %{public}s', JSON.stringify(error));
    });
  }

  private applyForegroundPrivacy(): void {
    const settings: SecuritySettings = readSecuritySettings(this.context);
    this.applyPrivacyMode(settings.blockScreenshots);
  }

  private applyBackgroundPrivacy(): void {
    const settings: SecuritySettings = readSecuritySettings(this.context);
    this.applyPrivacyMode(settings.blockScreenshots || settings.hideTaskPreview);
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'TimeAuth', 'EntryAbility created');
    applyThemePreference(this.context, readThemePreference(this.context));
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.windowStage = windowStage;
    this.stageEventListener = (event: window.WindowStageEventType): void => {
      switch (event) {
        case window.WindowStageEventType.INACTIVE:
        case window.WindowStageEventType.HIDDEN:
          this.applyBackgroundPrivacy();
          break;
        case window.WindowStageEventType.SHOWN:
        case window.WindowStageEventType.ACTIVE:
          this.applyForegroundPrivacy();
          break;
        default:
          break;
      }
    };

    try {
      windowStage.on('windowStageEvent', this.stageEventListener);
    } catch (error) {
      hilog.error(0x0000, 'TimeAuth', 'Failed to register window-stage privacy listener: %{public}s',
        JSON.stringify(error));
    }

    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        hilog.error(0x0000, 'TimeAuth', 'Failed to load content: %{public}s', JSON.stringify(error));
        return;
      }
      try {
        this.mainWindow = windowStage.getMainWindowSync();
        this.applyForegroundPrivacy();
      } catch (windowError) {
        hilog.error(0x0000, 'TimeAuth', 'Failed to initialize secure main window: %{public}s',
          JSON.stringify(windowError));
      }
      hilog.info(0x0000, 'TimeAuth', 'UI/UX preview loaded');
    });
  }

  onForeground(): void {
    this.applyForegroundPrivacy();
  }

  onBackground(): void {
    this.applyBackgroundPrivacy();
  }

  onWindowStageDestroy(): void {
    if (this.windowStage !== undefined && this.stageEventListener !== undefined) {
      try {
        this.windowStage.off('windowStageEvent', this.stageEventListener);
      } catch (error) {
        hilog.error(0x0000, 'TimeAuth', 'Failed to unregister window-stage privacy listener: %{public}s',
          JSON.stringify(error));
      }
    }
    this.stageEventListener = undefined;
    this.mainWindow = undefined;
    this.windowStage = undefined;
  }
}
