import { PageHeader } from '../../components/PageHeader';
import { colorModeForTheme, saveThemePreference } from '../../design/ThemeManager';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';
import { applyLanguagePreference } from '../../localization/LanguageManager';
import { LanguagePreference, ThemePreference } from '../../models/AppModels';

@Component
export struct SettingsPage {
  @StorageLink('timeauth.themePreference') private themePreference: ThemePreference = ThemePreference.SYSTEM;
  @State private biometricLock: boolean = true;
  @State private hideTaskPreview: boolean = true;
  @State private blockScreenshots: boolean = true;
  @State private clearClipboard: boolean = true;
  @StorageLink('timeauth.languagePreference') private languagePreference: LanguagePreference =
    LanguagePreference.SYSTEM;

  private setTheme(preference: ThemePreference): void {
    this.themePreference = preference;
    saveThemePreference(getContext(this), preference);
    getContext(this).getApplicationContext().setColorMode(colorModeForTheme(preference));
  }

  private setLanguage(preference: LanguagePreference): void {
    this.languagePreference = preference;
    applyLanguagePreference(preference);
  }

  @Builder
  ThemeButton(value: ThemePreference, label: ResourceStr, symbol: string) {
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
  LanguageButton(value: LanguagePreference, label: ResourceStr) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: AppSpacing.sm }) {
        Text(label)
          .fontSize(AppTypography.label)
          .fontWeight(this.languagePreference === value ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.languagePreference === value ? $r('app.color.brand') :
            $r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
        Text(this.languagePreference === value ? '✓' : '')
          .fontSize(AppTypography.body)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand'))
          .width(22)
      }
      .width('100%')
      .padding({ left: AppSpacing.md, right: AppSpacing.sm })
    }
    .width('100%')
    .height(52)
    .padding(0)
    .backgroundColor(this.languagePreference === value ? $r('app.color.brand_soft') :
      $r('app.color.surface_secondary'))
    .borderRadius(AppRadius.medium)
    .border({ width: this.languagePreference === value ? 2 : 0, color: $r('app.color.brand') })
    .onClick(() => {
      this.setLanguage(value);
    })
  }

  @Builder
  SettingToggle(title: ResourceStr, description: ResourceStr, value: boolean,
    onChange: (value: boolean) => void) {
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
  NavigationRow(title: ResourceStr, description: ResourceStr, badge: ResourceStr) {
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
      if (badge !== '') {
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
          title: $r('app.string.settings_title'),
          subtitle: $r('app.string.settings_subtitle')
        })

        Column({ space: AppSpacing.sm }) {
          Text($r('app.string.settings_appearance'))
            .fontSize(AppTypography.section)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Row({ space: AppSpacing.xs }) {
            this.ThemeButton(ThemePreference.SYSTEM, $r('app.string.theme_system'), '◐')
            this.ThemeButton(ThemePreference.LIGHT, $r('app.string.theme_light'), '○')
            this.ThemeButton(ThemePreference.DARK, $r('app.string.theme_dark'), '●')
          }
          .width('100%')
        }
        .width('100%')
        .padding(AppSpacing.lg)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column({ space: AppSpacing.sm }) {
          Text($r('app.string.settings_language'))
            .fontSize(AppTypography.section)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Text($r('app.string.settings_language_description'))
            .fontSize(AppTypography.caption)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          Column({ space: AppSpacing.xs }) {
            this.LanguageButton(LanguagePreference.SYSTEM, $r('app.string.language_system'))
            this.LanguageButton(LanguagePreference.ENGLISH, $r('app.string.language_english'))
            this.LanguageButton(LanguagePreference.SIMPLIFIED_CHINESE,
              $r('app.string.language_simplified_chinese'))
            this.LanguageButton(LanguagePreference.TRADITIONAL_CHINESE,
              $r('app.string.language_traditional_chinese'))
          }
          .width('100%')
        }
        .width('100%')
        .padding(AppSpacing.lg)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column() {
          Text($r('app.string.settings_security'))
            .fontSize(AppTypography.section)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .margin({ bottom: AppSpacing.sm })
          this.SettingToggle($r('app.string.settings_biometric'), $r('app.string.settings_biometric_detail'),
            this.biometricLock, (value: boolean) => {
            this.biometricLock = value;
          })
          Divider().color($r('app.color.border'))
          this.SettingToggle($r('app.string.settings_hide_preview'),
            $r('app.string.settings_hide_preview_detail'), this.hideTaskPreview, (value: boolean) => {
            this.hideTaskPreview = value;
          })
          Divider().color($r('app.color.border'))
          this.SettingToggle($r('app.string.settings_block_screenshots'),
            $r('app.string.settings_block_screenshots_detail'), this.blockScreenshots, (value: boolean) => {
            this.blockScreenshots = value;
          })
          Divider().color($r('app.color.border'))
          this.SettingToggle($r('app.string.settings_clear_clipboard'),
            $r('app.string.settings_clear_clipboard_detail'), this.clearClipboard, (value: boolean) => {
            this.clearClipboard = value;
          })
        }
        .width('100%')
        .padding(AppSpacing.lg)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column() {
          Text($r('app.string.settings_data'))
            .fontSize(AppTypography.section)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .margin({ bottom: AppSpacing.sm })
          this.NavigationRow($r('app.string.settings_backup'), $r('app.string.settings_backup_detail'),
            $r('app.string.common_free'))
          Divider().color($r('app.color.border'))
          this.NavigationRow($r('app.string.settings_import_codes'),
            $r('app.string.settings_import_codes_detail'), '')
          Divider().color($r('app.color.border'))
          this.NavigationRow($r('app.string.settings_local_data'), $r('app.string.settings_local_data_detail'),
            $r('app.string.common_preview'))
        }
        .width('100%')
        .padding(AppSpacing.lg)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column() {
          this.NavigationRow($r('app.string.settings_about'), $r('app.string.settings_about_detail'),
            '1.0.0-preview')
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
