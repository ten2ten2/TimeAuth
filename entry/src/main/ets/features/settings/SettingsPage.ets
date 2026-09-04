import { ConfigurationConstant } from '@kit.AbilityKit';
import { PageHeader } from '../../components/PageHeader';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';
import { ThemePreference } from '../../models/AppModels';

@Component
export struct SettingsPage {
  @State private themePreference: ThemePreference = ThemePreference.SYSTEM;
  @State private biometricLock: boolean = true;
  @State private hideTaskPreview: boolean = true;
  @State private blockScreenshots: boolean = true;
  @State private clearClipboard: boolean = true;

  private setTheme(preference: ThemePreference): void {
    this.themePreference = preference;
    if (preference === ThemePreference.LIGHT) {
      getContext(this).getApplicationContext()
        .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      return;
    }
    if (preference === ThemePreference.DARK) {
      getContext(this).getApplicationContext()
        .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      return;
    }
    getContext(this).getApplicationContext()
      .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
  }

  @Builder
  ThemeButton(value: ThemePreference, label: string, symbol: string) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: AppSpacing.xs }) {
        Text(symbol)
          .fontSize(22)
          .fontColor(this.themePreference === value ? $r('app.color.brand') : $r('app.color.text_secondary'))
        Text(label)
          .fontSize(AppTypography.label)
          .fontWeight(this.themePreference === value ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.themePreference === value ? $r('app.color.brand') : $r('app.color.text_primary'))
      }
      .width('100%')
      .height(72)
      .justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1)
    .height(80)
    .padding(0)
    .backgroundColor(this.themePreference === value ? $r('app.color.brand_soft') : $r('app.color.surface_secondary'))
    .borderRadius(AppRadius.medium)
    .border({ width: this.themePreference === value ? 2 : 0, color: $r('app.color.brand') })
    .onClick(() => {
      this.setTheme(value);
    })
  }

  @Builder
  SettingToggle(title: string, description: string, value: boolean, onChange: (value: boolean) => void) {
    Row({ space: AppSpacing.md }) {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(AppTypography.body)
          .fontColor($r('app.color.text_primary'))
        Text(description)
          .fontSize(AppTypography.caption)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(18)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor($r('app.color.brand'))
        .onChange((isOn: boolean) => {
          onChange(isOn);
        })
    }
    .width('100%')
    .minHeight(64)
  }

  @Builder
  NavigationRow(title: string, description: string, badge: string) {
    Row({ space: AppSpacing.md }) {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(AppTypography.body)
          .fontColor($r('app.color.text_primary'))
        Text(description)
          .fontSize(AppTypography.caption)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (badge.length > 0) {
        Text(badge)
          .fontSize(AppTypography.caption)
          .fontColor($r('app.color.brand'))
      }
      Text('›')
        .fontSize(24)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .minHeight(58)
  }

  build() {
    Scroll() {
      Column({ space: AppSpacing.md }) {
        PageHeader({
          title: '设置',
          subtitle: '安全开关为交互预览；主题切换已连接系统颜色模式。'
        })

        Column({ space: AppSpacing.sm }) {
          Text('外观')
            .fontSize(AppTypography.section)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Row({ space: AppSpacing.xs }) {
            this.ThemeButton(ThemePreference.SYSTEM, '跟随系统', '◐')
            this.ThemeButton(ThemePreference.LIGHT, '浅色', '○')
            this.ThemeButton(ThemePreference.DARK, '深色', '●')
          }
          .width('100%')
        }
        .width('100%')
        .padding(AppSpacing.lg)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column() {
          Text('安全')
            .fontSize(AppTypography.section)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .margin({ bottom: AppSpacing.sm })
          this.SettingToggle('生物识别解锁', '进入应用时验证设备所有者', this.biometricLock, (value: boolean) => {
            this.biometricLock = value;
          })
          Divider().color($r('app.color.border'))
          this.SettingToggle('隐藏后台预览', '切换应用后遮挡敏感内容', this.hideTaskPreview, (value: boolean) => {
            this.hideTaskPreview = value;
          })
          Divider().color($r('app.color.border'))
          this.SettingToggle('阻止敏感页面截屏', '真实能力将在安全阶段接入', this.blockScreenshots, (value: boolean) => {
            this.blockScreenshots = value;
          })
          Divider().color($r('app.color.border'))
          this.SettingToggle('自动清理剪贴板', '复制30秒后清除', this.clearClipboard, (value: boolean) => {
            this.clearClipboard = value;
          })
        }
        .width('100%')
        .padding(AppSpacing.lg)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column() {
          Text('数据')
            .fontSize(AppTypography.section)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .margin({ bottom: AppSpacing.sm })
          this.NavigationRow('备份与恢复', '创建或导入加密备份', '免费')
          Divider().color($r('app.color.border'))
          this.NavigationRow('导入验证码', '从兼容格式迁移', '')
          Divider().color($r('app.color.border'))
          this.NavigationRow('本地数据', '当前仅使用 Mock 数据', '预览')
        }
        .width('100%')
        .padding(AppSpacing.lg)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column() {
          this.NavigationRow('关于 TimeAuth', '版本、隐私与开源许可', '1.0.0-preview')
        }
        .width('100%')
        .padding({ left: AppSpacing.lg, right: AppSpacing.lg })
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Blank().height(72)
      }
      .width('100%')
      .constraintSize({ maxWidth: AppLayout.pageMaxWidth })
      .padding({
        left: AppLayout.compactPadding,
        right: AppLayout.compactPadding,
        top: AppSpacing.xl,
        bottom: AppSpacing.xl
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}

