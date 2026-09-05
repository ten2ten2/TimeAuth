import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { applyThemePreference, readThemePreference } from '../design/ThemeManager';
import { applyLanguagePreference, readLanguagePreference } from '../localization/LanguageManager';
import { handleWindowStageLifecycle, refreshScreenSecurity } from '../security/ScreenSecurityManager';

export default class EntryAbility extends UIAbility {
  private windowStage: window.WindowStage | undefined = undefined;
  private lifecycleListener: ((event: window.WindowStageLifecycleEventType) => void) | undefined = undefined;

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

    try {
      windowStage.on('windowStageLifecycleEvent', this.lifecycleListener);
    } catch (error) {
      hilog.error(0x0000, 'TimeAuth', 'Failed to register WindowStage lifecycle listener: %{public}s',
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
    if (this.windowStage !== undefined && this.lifecycleListener !== undefined) {
      try {
        this.windowStage.off('windowStageLifecycleEvent', this.lifecycleListener);
      } catch (error) {
        hilog.error(0x0000, 'TimeAuth', 'Failed to unregister WindowStage lifecycle listener: %{public}s',
          JSON.stringify(error));
      }
    }
    this.lifecycleListener = undefined;
    this.windowStage = undefined;
  }
}
