import { common } from '@kit.AbilityKit';
import { PageHeader } from '../../components/PageHeader';
import { applyThemePreference, saveThemePreference } from '../../design/ThemeManager';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';
import { applyLanguagePreference } from '../../localization/LanguageManager';
import { LanguagePreference, ThemePreference } from '../../models/AppModels';
import { cancelPendingSensitiveClipboardClear } from '../../security/SecureClipboard';
import {
  readSecuritySettings,
  saveClearClipboard,
  saveHideTaskPreview,
  SecuritySettings
} from '../../security/SecuritySettingsManager';

@Component
export struct SettingsPage {
  @StorageLink('timeauth.themePreference') private themePreference: ThemePreference = ThemePreference.SYSTEM;
  @State private biometricLock: boolean = true;
  @State private hideTaskPreview: boolean = true;
  @State private clearClipboard: boolean = true;
  @StorageLink('timeauth.languagePreference') private languagePreference: LanguagePreference =
    LanguagePreference.SYSTEM;

  aboutToAppear(): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    const settings: SecuritySettings = readSecuritySettings(context);
    this.hideTaskPreview = settings.hideTaskPreview;
    this.clearClipboard = settings.clearClipboard;
  }

  private setTheme(preference: ThemePreference): void {
    this.themePreference = preference;
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    saveThemePreference(context, preference);
    applyThemePreference(context, preference);
  }

  private setLanguage(preference: LanguagePreference): void {
    this.languagePreference = preference;
    applyLanguagePreference(preference);
  }

  private setHideTaskPreview(value: boolean): void {
    this.hideTaskPreview = value;
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      saveHideTaskPreview(context, value);
    }
  }

  private setClearClipboard(value: boolean): void {
    this.clearClipboard = value;
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      saveClearClipboard(context, value);
    }
    if (!value) {
      cancelPendingSensitiveClipboardClear();
    }
  }

  private currentThemeLabel(): ResourceStr {
    switch (this.themePreference) {
      case ThemePreference.LIGHT:
        return $r('app.string.theme_light');
      case ThemePreference.DARK:
        return $r('app.string.theme_dark');
      case ThemePreference.SYSTEM:
      default:
        return $r('app.string.theme_system');
    }
  }

  private currentLanguageLabel(): ResourceStr {
    switch (this.languagePreference) {
      case LanguagePreference.ENGLISH:
        return $r('app.string.language_english');
      case LanguagePreference.SIMPLIFIED_CHINESE:
        return $r('app.string.language_simplified_chinese');
      case LanguagePreference.TRADITIONAL_CHINESE:
        return $r('app.string.language_traditional_chinese');
      case LanguagePreference.SYSTEM:
      default:
        return $r('app.string.language_system');
    }
  }

  @Builder
  ThemeSelectionRow() {
    Row({ space: AppSpacing.sm }) {
      Text($r('app.string.settings_appearance'))
        .fontSize(AppTypography.body)
        .fontColor($r('app.color.text_primary'))
        .lineHeight(22)
        .layoutWeight(1)

      Row({ space: AppSpacing.xs }) {
        Text(this.currentThemeLabel())
          .fontSize(AppTypography.label)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)
          .textAlign(TextAlign.End)
        Text('⌄')
          .fontSize(18)
          .fontColor($r('app.color.text_secondary'))
          .width(20)
          .height(20)
          .lineHeight(20)
          .textAlign(TextAlign.Center)
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(56)
    .padding({ left: AppSpacing.md, right: AppSpacing.sm })
    .alignItems(VerticalAlign.Center)
    .bindMenu([
      {
        value: $r('app.string.theme_system'),
        action: () => {
          this.setTheme(ThemePreference.SYSTEM);
        }
      },
      {
        value: $r('app.string.theme_light'),
        action: () => {
          this.setTheme(ThemePreference.LIGHT);
        }
      },
      {
        value: $r('app.string.theme_dark'),
        action: () => {
          this.setTheme(ThemePreference.DARK);
        }
      }
    ])
  }

  @Builder
  LanguageSelectionRow() {
    Row({ space: AppSpacing.sm }) {
      Text($r('app.string.settings_language'))
        .fontSize(AppTypography.body)
        .fontColor($r('app.color.text_primary'))
        .lineHeight(22)
        .layoutWeight(1)

      Row({ space: AppSpacing.xs }) {
        Text(this.currentLanguageLabel())
          .fontSize(AppTypography.label)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)
          .textAlign(TextAlign.End)
        Text('⌄')
          .fontSize(18)
          .fontColor($r('app.color.text_secondary'))
          .width(20)
          .height(20)
          .lineHeight(20)
          .textAlign(TextAlign.Center)
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(56)
    .padding({ left: AppSpacing.md, right: AppSpacing.sm })
    .alignItems(VerticalAlign.Center)
    .bindMenu([
      {
        value: $r('app.string.language_system'),
        action: () => {
          this.setLanguage(LanguagePreference.SYSTEM);
        }
      },
      {
        value: $r('app.string.language_english'),
        action: () => {
          this.setLanguage(LanguagePreference.ENGLISH);
        }
      },
      {
        value: $r('app.string.language_simplified_chinese'),
        action: () => {
          this.setLanguage(LanguagePreference.SIMPLIFIED_CHINESE);
        }
      },
      {
        value: $r('app.string.language_traditional_chinese'),
        action: () => {
          this.setLanguage(LanguagePreference.TRADITIONAL_CHINESE);
        }
      }
    ])
  }

  @Builder
  SettingToggle(title: ResourceStr, description: ResourceStr, value: boolean, enabled: boolean,
    onChange: (value: boolean) => void) {
    Row({ space: AppSpacing.md }) {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(AppTypography.body)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(22)
        Text(description)
          .fontSize(AppTypography.caption)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(16)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .opacity(enabled ? 1 : 0.65)

      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor($r('app.color.brand'))
        .enabled(enabled)
        .opacity(enabled ? 1 : 0.45)
        .onChange((isOn: boolean) => {
          onChange(isOn);
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 60 })
    .padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.xs, bottom: AppSpacing.xs })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  NavigationRow(title: ResourceStr, description: ResourceStr, badge: ResourceStr) {
    Row({ space: AppSpacing.md }) {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(AppTypography.body)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(22)
        Text(description)
          .fontSize(AppTypography.caption)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(16)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row({ space: AppSpacing.xs }) {
        if (badge !== '') {
          Text(badge)
            .fontSize(AppTypography.caption)
            .fontColor($r('app.color.brand'))
            .lineHeight(18)
        }
        Text('›')
          .fontSize(22)
          .fontColor($r('app.color.text_secondary'))
          .width(20)
          .height(24)
          .lineHeight(24)
          .textAlign(TextAlign.Center)
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .constraintSize({ minHeight: 58 })
    .padding({ left: AppSpacing.md, right: AppSpacing.sm, top: AppSpacing.xs, bottom: AppSpacing.xs })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  SectionTitle(title: ResourceStr) {
    Text(title)
      .fontSize(AppTypography.section)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_primary'))
      .lineHeight(24)
      .width('100%')
      .padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.md, bottom: AppSpacing.xs })
  }

  build() {
    Scroll() {
      Column({ space: AppSpacing.sm }) {
        PageHeader({
          title: $r('app.string.settings_title'),
          subtitle: $r('app.string.settings_subtitle_security_active')
        })

        Column() {
          this.ThemeSelectionRow()
          Divider()
            .color($r('app.color.border'))
            .margin({ left: AppSpacing.md, right: AppSpacing.md })
          this.LanguageSelectionRow()
        }
        .width('100%')
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column() {
          this.SectionTitle($r('app.string.settings_security'))
          this.SettingToggle($r('app.string.settings_biometric'),
            $r('app.string.settings_biometric_preview_detail'), this.biometricLock, false, (value: boolean) => {
            this.biometricLock = value;
          })
          Divider()
            .color($r('app.color.border'))
            .margin({ left: AppSpacing.md, right: AppSpacing.md })
          this.SettingToggle($r('app.string.settings_hide_preview'),
            $r('app.string.settings_hide_preview_active_detail'), this.hideTaskPreview, true, (value: boolean) => {
            this.setHideTaskPreview(value);
          })
          Divider()
            .color($r('app.color.border'))
            .margin({ left: AppSpacing.md, right: AppSpacing.md })
          this.SettingToggle($r('app.string.settings_clear_clipboard'),
            $r('app.string.settings_clear_clipboard_active_detail'), this.clearClipboard, true, (value: boolean) => {
            this.setClearClipboard(value);
          })
        }
        .width('100%')
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column() {
          this.SectionTitle($r('app.string.settings_data'))
          this.NavigationRow($r('app.string.settings_backup'), $r('app.string.settings_backup_detail'),
            $r('app.string.common_free'))
          Divider()
            .color($r('app.color.border'))
            .margin({ left: AppSpacing.md, right: AppSpacing.md })
          this.NavigationRow($r('app.string.settings_import_codes'),
            $r('app.string.settings_import_codes_detail'), '')
          Divider()
            .color($r('app.color.border'))
            .margin({ left: AppSpacing.md, right: AppSpacing.md })
          this.NavigationRow($r('app.string.settings_local_data'), $r('app.string.settings_local_data_detail'),
            $r('app.string.common_preview'))
        }
        .width('100%')
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column() {
          this.NavigationRow($r('app.string.settings_about'), $r('app.string.settings_about_detail'),
            '1.0.0-preview')
        }
        .width('100%')
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
