import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { applyThemePreference, readThemePreference } from '../design/ThemeManager';
import { applyLanguagePreference, readLanguagePreference } from '../localization/LanguageManager';
import {
  handleWindowFocus,
  handleWindowStageLifecycle,
  refreshScreenSecurity
} from '../security/ScreenSecurityManager';

export default class EntryAbility extends UIAbility {
  private windowStage: window.WindowStage | undefined = undefined;
  private lifecycleListener: ((event: window.WindowStageLifecycleEventType) => void) | undefined = undefined;
  private focusListener: ((event: window.WindowStageEventType) => void) | undefined = undefined;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'TimeAuth', 'EntryAbility created');
    applyLanguagePreference(readLanguagePreference(this.context));
    applyThemePreference(this.context, readThemePreference(this.context));
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.windowStage = windowStage;
    this.lifecycleListener = (event: window.WindowStageLifecycleEventType): void => {
      handleWindowStageLifecycle(this.context, event);
    };
    this.focusListener = (event: window.WindowStageEventType): void => {
      handleWindowFocus(this.context, event);
    };

    try {
      windowStage.on('windowStageLifecycleEvent', this.lifecycleListener);
      windowStage.on('windowStageEvent', this.focusListener);
    } catch (error) {
      hilog.error(0x0000, 'TimeAuth', 'Failed to register WindowStage security listeners: %{public}s',
        JSON.stringify(error));
    }

    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        hilog.error(0x0000, 'TimeAuth', 'Failed to load content: %{public}s', JSON.stringify(error));
        return;
      }
      refreshScreenSecurity(this.context);
      hilog.info(0x0000, 'TimeAuth', 'UI loaded');
    });
  }

  onWindowStageDestroy(): void {
    if (this.windowStage !== undefined) {
      if (this.lifecycleListener !== undefined) {
        try {
          this.windowStage.off('windowStageLifecycleEvent', this.lifecycleListener);
        } catch (error) {
          hilog.error(0x0000, 'TimeAuth', 'Failed to unregister WindowStage lifecycle listener: %{public}s',
            JSON.stringify(error));
        }
      }
      if (this.focusListener !== undefined) {
        try {
          this.windowStage.off('windowStageEvent', this.focusListener);
        } catch (error) {
          hilog.error(0x0000, 'TimeAuth', 'Failed to unregister WindowStage focus listener: %{public}s',
            JSON.stringify(error));
        }
      }
    }
    this.lifecycleListener = undefined;
    this.focusListener = undefined;
    this.windowStage = undefined;
  }
}
