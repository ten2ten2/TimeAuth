import { common } from '@kit.AbilityKit';
import { SelectDialog } from '@kit.ArkUI';
import { PageHeader } from '../../components/PageHeader';
import { applyThemePreference, readThemePreference, saveThemePreference } from '../../design/ThemeManager';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';
import { applyLanguagePreference, readLanguagePreference, saveLanguagePreference } from '../../localization/LanguageManager';
import { LanguagePreference, ThemePreference } from '../../models/AppModels';
import { cancelPendingSensitiveClipboardClear } from '../../security/SecureClipboard';
import { refreshScreenSecurity } from '../../security/ScreenSecurityManager';
import { readSecuritySettings, saveClearClipboard, saveHideTaskPreview, SecuritySettings } from '../../security/SecuritySettingsManager';

@Component
export struct SettingsPage {
  onOpenAbout: () => void = () => {};
  @State private themePreference: ThemePreference = ThemePreference.SYSTEM;
  @State private languagePreference: LanguagePreference = LanguagePreference.SYSTEM;
  @State private hideTaskPreview: boolean = true;
  @State private clearClipboard: boolean = true;
  @State private preferencePending: boolean = false;
  @State private preferenceFailed: boolean = false;
  @StorageLink('timeauth.screenCovered') @Watch('onScreenCoverChanged') private screenCovered: boolean = false;
  @StorageLink('timeauth.screenProtectionFailed') private protectionFailed: boolean = false;

  private themeDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectDialog({
      title: $r('app.string.settings_appearance'),
      selectedIndex: this.themePreferenceIndex(),
      radioContent: [
        { title: $r('app.string.theme_system'), action: () => { this.selectTheme(ThemePreference.SYSTEM); } },
        { title: $r('app.string.theme_light'), action: () => { this.selectTheme(ThemePreference.LIGHT); } },
        { title: $r('app.string.theme_dark'), action: () => { this.selectTheme(ThemePreference.DARK); } }
      ]
    }),
    autoCancel: true
  });

  private languageDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectDialog({
      title: $r('app.string.settings_language'),
      selectedIndex: this.languagePreferenceIndex(),
      radioContent: [
        { title: $r('app.string.language_system'), action: () => { this.selectLanguage(LanguagePreference.SYSTEM); } },
        { title: $r('app.string.language_simplified_chinese'), action: () => { this.selectLanguage(LanguagePreference.SIMPLIFIED_CHINESE); } },
        { title: $r('app.string.language_traditional_chinese_taiwan'), action: () => { this.selectLanguage(LanguagePreference.TRADITIONAL_CHINESE_TAIWAN); } },
        { title: $r('app.string.language_traditional_chinese_hong_kong'), action: () => { this.selectLanguage(LanguagePreference.TRADITIONAL_CHINESE_HONG_KONG); } },
        { title: $r('app.string.language_english'), action: () => { this.selectLanguage(LanguagePreference.ENGLISH); } }
      ]
    }),
    autoCancel: true
  });

  aboutToAppear(): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      this.themePreference = readThemePreference(context);
      this.languagePreference = readLanguagePreference(context);
      const settings: SecuritySettings = readSecuritySettings(context);
      this.hideTaskPreview = settings.hideTaskPreview;
      this.clearClipboard = settings.clearClipboard;
    }
  }

  aboutToDisappear(): void {
    this.closePreferenceDialogs();
  }

  private onScreenCoverChanged(): void {
    if (this.screenCovered) {
      this.closePreferenceDialogs();
    }
  }

  private closePreferenceDialogs(): void {
    this.themeDialogController.close();
    this.languageDialogController.close();
  }

  private themePreferenceIndex(): number {
    return this.themePreference === ThemePreference.LIGHT ? 1 : this.themePreference === ThemePreference.DARK ? 2 : 0;
  }

  private languagePreferenceIndex(): number {
    if (this.languagePreference === LanguagePreference.SIMPLIFIED_CHINESE) {
      return 1;
    }
    if (this.languagePreference === LanguagePreference.TRADITIONAL_CHINESE_TAIWAN) {
      return 2;
    }
    if (this.languagePreference === LanguagePreference.TRADITIONAL_CHINESE_HONG_KONG) {
      return 3;
    }
    return this.languagePreference === LanguagePreference.ENGLISH ? 4 : 0;
  }

  private async selectTheme(preference: ThemePreference): Promise<void> {
    if (this.preferencePending) {
      return;
    }
    const previous: ThemePreference = this.themePreference;
    this.preferencePending = true;
    this.preferenceFailed = false;
    this.themePreference = preference;
    this.themeDialogController.close();
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.preferenceFailed = true;
      this.preferencePending = false;
      return;
    }
    const saved: boolean = await saveThemePreference(context, preference);
    if (!saved) {
      this.themePreference = previous;
      this.preferenceFailed = true;
    } else if (!applyThemePreference(context, preference)) {
      await saveThemePreference(context, previous);
      applyThemePreference(context, previous);
      this.themePreference = previous;
      this.preferenceFailed = true;
    }
    this.preferencePending = false;
  }

  private async selectLanguage(preference: LanguagePreference): Promise<void> {
    if (this.preferencePending) {
      return;
    }
    const previous: LanguagePreference = this.languagePreference;
    this.preferencePending = true;
    this.preferenceFailed = false;
    this.languagePreference = preference;
    this.languageDialogController.close();
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.preferenceFailed = true;
      this.preferencePending = false;
      return;
    }
    const saved: boolean = await saveLanguagePreference(context, preference);
    if (!saved) {
      this.languagePreference = previous;
      this.preferenceFailed = true;
    } else if (!applyLanguagePreference(context, preference)) {
      await saveLanguagePreference(context, previous);
      applyLanguagePreference(context, previous);
      this.languagePreference = previous;
      this.preferenceFailed = true;
    }
    this.preferencePending = false;
  }

  private setHideTaskPreview(value: boolean): void {
    this.hideTaskPreview = value;
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      saveHideTaskPreview(context, value);
      refreshScreenSecurity(context);
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

  private themeLabel(preference: ThemePreference): ResourceStr {
    if (preference === ThemePreference.LIGHT) {
      return $r('app.string.theme_light');
    }
    return preference === ThemePreference.DARK ? $r('app.string.theme_dark') : $r('app.string.theme_system');
  }

  private languageLabel(preference: LanguagePreference): ResourceStr {
    if (preference === LanguagePreference.ENGLISH) {
      return $r('app.string.language_english');
    }
    if (preference === LanguagePreference.SIMPLIFIED_CHINESE) {
      return $r('app.string.language_simplified_chinese');
    }
    if (preference === LanguagePreference.TRADITIONAL_CHINESE_TAIWAN) {
      return $r('app.string.language_traditional_chinese_taiwan');
    }
    return preference === LanguagePreference.TRADITIONAL_CHINESE_HONG_KONG ?
      $r('app.string.language_traditional_chinese_hong_kong') : $r('app.string.language_system');
  }

  @Builder
  PreferenceSelectionRow(isAppearance: boolean) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: AppSpacing.sm }) {
        Text(isAppearance ? $r('app.string.settings_appearance') : $r('app.string.settings_language'))
          .fontSize(AppTypography.body)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(22)
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
        Row({ space: AppSpacing.xs }) {
          Text(isAppearance ? this.themeLabel(this.themePreference) : this.languageLabel(this.languagePreference))
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(20)
            .width(isAppearance ? 92 : 132)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.End)
            .id(isAppearance ? 'settings-appearance-value' : 'settings-language-value')
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
      .constraintSize({ minHeight: 56 })
      .padding({ left: AppSpacing.md, right: AppSpacing.sm, top: AppSpacing.xs, bottom: AppSpacing.xs })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(0)
    .backgroundColor(Color.Transparent)
    .enabled(!this.preferencePending)
    .onClick(() => {
      if (isAppearance) {
        this.themeDialogController.open();
      } else {
        this.languageDialogController.open();
      }
    })
  }

  @Builder
  SettingToggle(isTaskPreview: boolean) {
    Row({ space: AppSpacing.md }) {
      Column({ space: 2 }) {
        Text(isTaskPreview ? $r('app.string.settings_hide_preview') : $r('app.string.settings_clear_clipboard'))
          .fontSize(AppTypography.body)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(22)
        Text(isTaskPreview ? $r('app.string.settings_hide_preview_detail') : $r('app.string.settings_clear_clipboard_detail'))
          .fontSize(AppTypography.caption)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(16)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: isTaskPreview ? this.hideTaskPreview : this.clearClipboard })
        .selectedColor($r('app.color.brand'))
        .id(isTaskPreview ? 'settings-hide-preview' : 'settings-clear-clipboard')
        .onChange((isOn: boolean) => {
          if (isTaskPreview) {
            this.setHideTaskPreview(isOn);
          } else {
            this.setClearClipboard(isOn);
          }
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
      Text(badge)
        .fontSize(AppTypography.caption)
        .fontColor($r('app.color.brand'))
        .lineHeight(18)
    }
    .width('100%')
    .constraintSize({ minHeight: 58 })
    .padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.xs, bottom: AppSpacing.xs })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  AboutRow() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: AppSpacing.md }) {
        Column({ space: 2 }) {
          Text($r('app.string.settings_about'))
            .fontSize(AppTypography.body)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(22)
          Text($r('app.string.settings_about_detail'))
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
    .onClick(() => { this.onOpenAbout(); })
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

  @Builder
  SectionDivider() {
    Divider().color($r('app.color.border')).margin({ left: AppSpacing.md, right: AppSpacing.md })
  }

  build() {
    Scroll() {
      Column({ space: AppSpacing.sm }) {
        PageHeader({ title: $r('app.string.settings_title'), subtitle: $r('app.string.settings_options_summary') })
        if (this.preferenceFailed) {
          Text($r('app.string.settings_apply_failed'))
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.danger'))
            .width('100%')
        }
        if (this.protectionFailed) {
          Text($r('app.string.screen_protection_error'))
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.danger'))
            .width('100%')
        }
        Column() {
          this.PreferenceSelectionRow(true)
          this.SectionDivider()
          this.PreferenceSelectionRow(false)
        }
        .width('100%')
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column() {
          this.SectionTitle($r('app.string.settings_security'))
          this.StatusRow($r('app.string.settings_biometric'),
            $r('app.string.settings_biometric_detail'), $r('app.string.common_preview'))
          this.SectionDivider()
          this.SettingToggle(true)
          this.SectionDivider()
          this.SettingToggle(false)
        }
        .width('100%')
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column() {
          this.SectionTitle($r('app.string.settings_data'))
          this.StatusRow($r('app.string.settings_backup'), $r('app.string.settings_backup_detail'),
            $r('app.string.common_preview'))
          this.SectionDivider()
          this.StatusRow($r('app.string.settings_import_codes'),
            $r('app.string.settings_import_codes_detail'), $r('app.string.common_preview'))
          this.SectionDivider()
          this.StatusRow($r('app.string.settings_local_data'), $r('app.string.settings_local_data_detail'),
            $r('app.string.common_preview'))
        }
        .width('100%')
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Column() { this.AboutRow() }
          .width('100%')
          .backgroundColor($r('app.color.surface'))
          .borderRadius(AppRadius.large)
          .border({ width: 1, color: $r('app.color.border') })
        Blank().height(72)
      }
      .width('100%')
      .constraintSize({ maxWidth: AppLayout.pageMaxWidth })
      .padding({ left: AppLayout.compactPadding, right: AppLayout.compactPadding,
        top: AppSpacing.xl, bottom: AppSpacing.xl })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}