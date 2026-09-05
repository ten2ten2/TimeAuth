import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { applyThemePreference, readThemePreference } from '../design/ThemeManager';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'TimeAuth', 'EntryAbility created');
    applyThemePreference(this.context, readThemePreference(this.context));
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        hilog.error(0x0000, 'TimeAuth', 'Failed to load content: %{public}s', JSON.stringify(error));
        return;
      }
      hilog.info(0x0000, 'TimeAuth', 'UI/UX preview loaded');
    });
  }
}
