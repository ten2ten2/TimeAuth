import { common } from '@kit.AbilityKit';
import { SelectDialog } from '@kit.ArkUI';
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
  onOpenAbout: () => void = () => {};
  @StorageLink('timeauth.themePreference') private themePreference: ThemePreference = ThemePreference.SYSTEM;
  @State private hideTaskPreview: boolean = true;
  @State private clearClipboard: boolean = true;
  @State private themeDialogIndex: number = 0;
  @State private languageDialogIndex: number = 0;
  @StorageLink('timeauth.languagePreference') private languagePreference: LanguagePreference =
    LanguagePreference.SYSTEM;

  private themeDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectDialog({
      title: $r('app.string.settings_appearance'),
      selectedIndex: this.themeDialogIndex,
      radioContent: [
        {
          title: $r('app.string.theme_system'),
          action: () => {
            this.themeDialogIndex = 0;
            this.themeDialogController.close();
            this.setTheme(ThemePreference.SYSTEM);
          }
        },
        {
          title: $r('app.string.theme_light'),
          action: () => {
            this.themeDialogIndex = 1;
            this.themeDialogController.close();
            this.setTheme(ThemePreference.LIGHT);
          }
        },
        {
          title: $r('app.string.theme_dark'),
          action: () => {
            this.themeDialogIndex = 2;
            this.themeDialogController.close();
            this.setTheme(ThemePreference.DARK);
          }
        }
      ]
    }),
    autoCancel: true
  });

  private languageDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectDialog({
      title: $r('app.string.settings_language'),
      selectedIndex: this.languageDialogIndex,
      radioContent: [
        {
          title: $r('app.string.language_system'),
          action: () => {
            this.languageDialogIndex = 0;
            this.languageDialogController.close();
            this.setLanguage(LanguagePreference.SYSTEM);
          }
        },
        {
          title: $r('app.string.language_simplified_chinese'),
          action: () => {
            this.languageDialogIndex = 1;
            this.languageDialogController.close();
            this.setLanguage(LanguagePreference.SIMPLIFIED_CHINESE);
          }
        },
        {
          title: $r('app.string.language_traditional_chinese'),
          action: () => {
            this.languageDialogIndex = 2;
            this.languageDialogController.close();
            this.setLanguage(LanguagePreference.TRADITIONAL_CHINESE);
          }
        },
        {
          title: $r('app.string.language_english'),
          action: () => {
            this.languageDialogIndex = 3;
            this.languageDialogController.close();
            this.setLanguage(LanguagePreference.ENGLISH);
          }
        }
      ]
    }),
    autoCancel: true
  });

  aboutToAppear(): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      const settings: SecuritySettings = readSecuritySettings(context);
      this.hideTaskPreview = settings.hideTaskPreview;
      this.clearClipboard = settings.clearClipboard;
    }
    this.syncDialogSelections();
  }

  private themePreferenceIndex(): number {
    if (this.themePreference === ThemePreference.LIGHT) {
      return 1;
    }
    if (this.themePreference === ThemePreference.DARK) {
      return 2;
    }
    return 0;
  }

  private languagePreferenceIndex(): number {
    if (this.languagePreference === LanguagePreference.SIMPLIFIED_CHINESE) {
      return 1;
    }
    if (this.languagePreference === LanguagePreference.TRADITIONAL_CHINESE) {
      return 2;
    }
    if (this.languagePreference === LanguagePreference.ENGLISH) {
      return 3;
    }
    return 0;
  }

  private syncDialogSelections(): void {
    this.themeDialogIndex = this.themePreferenceIndex();
    this.languageDialogIndex = this.languagePreferenceIndex();
  }

  private openThemeDialog(): void {
    this.themeDialogIndex = this.themePreferenceIndex();
    this.themeDialogController.open();
  }

  private openLanguageDialog(): void {
    this.languageDialogIndex = this.languagePreferenceIndex();
    this.languageDialogController.open();
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
  PreferenceSelectionRow(title: ResourceStr, value: ResourceStr, onClick: () => void) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: AppSpacing.sm }) {
        Text(title)
          .fontSize(AppTypography.body)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(22)
          .layoutWeight(1)
          .textAlign(TextAlign.Start)

        Row({ space: AppSpacing.xs }) {
          Text(value)
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(20)
            .textAlign(TextAlign.End)
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
      .height(56)
      .padding({ left: AppSpacing.md, right: AppSpacing.sm })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(56)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .onClick(onClick)
  }

  @Builder
  SettingToggle(title: ResourceStr, description: ResourceStr, value: boolean,
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

      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor($r('app.color.brand'))
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
  StatusRow(title: ResourceStr, description: ResourceStr, badge: ResourceStr) {
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

      if (badge !== '') {
        Text(badge)
          .fontSize(AppTypography.caption)
          .fontColor($r('app.color.brand'))
          .lineHeight(18)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 58 })
    .padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.xs, bottom: AppSpacing.xs })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  NavigationRow(title: ResourceStr, description: ResourceStr, onClick: () => void) {
    Button({ type: ButtonType.Normal }) {
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

        Text('›')
          .fontSize(22)
          .fontColor($r('app.color.text_secondary'))
          .width(20)
          .height(24)
          .lineHeight(24)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .constraintSize({ minHeight: 58 })
      .padding({ left: AppSpacing.md, right: AppSpacing.sm, top: AppSpacing.xs, bottom: AppSpacing.xs })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(0)
    .backgroundColor(Color.Transparent)
    .onClick(onClick)
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
          subtitle: $r('app.string.settings_subtitle')
        })

        Column() {
          this.PreferenceSelectionRow($r('app.string.settings_appearance'), this.currentThemeLabel(), () => {
            this.openThemeDialog();
          })
          Divider()
            .color($r('app.color.border'))
            .margin({ left: AppSpacing.md, right: AppSpacing.md })
          this.PreferenceSelectionRow($r('app.string.settings_language'), this.currentLanguageLabel(), () => {
            this.openLanguageDialog();
          })
        }
        .width('100%')
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column() {
          this.SectionTitle($r('app.string.settings_security'))
          this.StatusRow($r('app.string.settings_biometric'),
            $r('app.string.settings_biometric_detail'), $r('app.string.common_preview'))
          Divider()
            .color($r('app.color.border'))
            .margin({ left: AppSpacing.md, right: AppSpacing.md })
          this.SettingToggle($r('app.string.settings_hide_preview'),
            $r('app.string.settings_hide_preview_detail'), this.hideTaskPreview, (value: boolean) => {
              this.setHideTaskPreview(value);
            })
          Divider()
            .color($r('app.color.border'))
            .margin({ left: AppSpacing.md, right: AppSpacing.md })
          this.SettingToggle($r('app.string.settings_clear_clipboard'),
            $r('app.string.settings_clear_clipboard_detail'), this.clearClipboard, (value: boolean) => {
              this.setClearClipboard(value);
            })
        }
        .width('100%')
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column() {
          this.SectionTitle($r('app.string.settings_data'))
          this.StatusRow($r('app.string.settings_backup'), $r('app.string.settings_backup_detail'),
            $r('app.string.common_free'))
          Divider()
            .color($r('app.color.border'))
            .margin({ left: AppSpacing.md, right: AppSpacing.md })
          this.StatusRow($r('app.string.settings_import_codes'),
            $r('app.string.settings_import_codes_detail'), $r('app.string.common_preview'))
          Divider()
            .color($r('app.color.border'))
            .margin({ left: AppSpacing.md, right: AppSpacing.md })
          this.StatusRow($r('app.string.settings_local_data'), $r('app.string.settings_local_data_detail'),
            $r('app.string.common_preview'))
        }
        .width('100%')
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column() {
          this.NavigationRow($r('app.string.settings_about'), $r('app.string.settings_about_detail'), () => {
            this.onOpenAbout();
          })
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
