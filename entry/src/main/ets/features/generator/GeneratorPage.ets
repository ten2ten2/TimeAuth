import { PageHeader } from '../../components/PageHeader';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';
import { copySensitiveText } from '../../security/SecureClipboard';
import { GeneratorOptions, GeneratorValidation, PasswordResult, validateGeneratorOptions } from './GeneratorCore';
import { generatePassword } from './PasswordGenerator';
import { copyGeneratorOptions, readGeneratorOptions, saveGeneratorOptions } from './GeneratorSettings';
import { GeneratorSession, getGeneratorSession } from './GeneratorSession';
import { GeneratorOptionToggle } from './GeneratorOptionToggle';

@Component
export struct GeneratorPage {
  @State private options: GeneratorOptions = new GeneratorOptions();
  @State private lengthInput: string = '20';
  @State private value: string = '';
  @State private entropyBits: number = 0;
  @State private generatedFor: string = '';
  @State private generationFailed: boolean = false;
  @State private revealed: boolean = true;
  @State private advanced: boolean = false;
  @State private preferencesFailed: boolean = false;
  @State private copying: boolean = false;
  @State private feedback: Resource | undefined = undefined;
  private feedbackTimer: number = -1;
  private preferenceTimer: number = -1;
  private active: boolean = false;

  aboutToAppear(): void {
    this.active = true;
    const session: GeneratorSession = getGeneratorSession();
    if (!session.initialized) {
      const context = this.getUIContext().getHostContext();
      if (context !== undefined) {
        const saved = readGeneratorOptions(context);
        session.options = saved.options;
        this.preferencesFailed = !saved.succeeded;
      } else {
        this.preferencesFailed = true;
      }
      session.initialized = true;
    }
    this.options = copyGeneratorOptions(session.options);
    this.lengthInput = this.options.length > 0 ? `${this.options.length}` : '';
    this.value = session.value;
    this.entropyBits = session.entropyBits;
    this.generatedFor = session.generatedFor;
    this.generationFailed = session.generationFailed;
    // Native navigation can recreate the component. Do not overwrite an existing result.
    this.revealed = session.value.length === 0;
    if (this.value.length === 0 && !this.generationFailed && this.validation() === GeneratorValidation.VALID) {
      this.regenerate(false);
    }
  }

  aboutToDisappear(): void {
    this.active = false;
    if (this.preferenceTimer >= 0) {
      clearTimeout(this.preferenceTimer);
      this.preferenceTimer = -1;
      this.persistOptions();
    }
    if (this.feedbackTimer >= 0) {
      clearTimeout(this.feedbackTimer);
      this.feedbackTimer = -1;
    }
    this.feedback = undefined;
    this.revealed = false;
  }

  private validation(): GeneratorValidation {
    return validateGeneratorOptions(this.options);
  }

  private optionsSignature(): string {
    return JSON.stringify(copyGeneratorOptions(this.options));
  }

  private rulesChanged(): boolean {
    return this.value.length > 0 && this.generatedFor !== this.optionsSignature();
  }

  private canCopy(): boolean {
    return this.value.length > 0 && !this.generationFailed && !this.rulesChanged() &&
      this.validation() === GeneratorValidation.VALID && !this.copying;
  }

  private characterTypeCount(): number {
    return (this.options.includeLowercase ? 1 : 0) + (this.options.includeUppercase ? 1 : 0) +
      (this.options.includeNumbers ? 1 : 0) + (this.options.includeSymbols ? 1 : 0);
  }

  private optionsChanged(): void {
    getGeneratorSession().options = copyGeneratorOptions(this.options);
    this.feedback = undefined;
    if (this.preferenceTimer >= 0) {
      clearTimeout(this.preferenceTimer);
      this.preferenceTimer = -1;
    }
    // Debounce slider/input edits; invalid drafts never replace saved valid preferences.
    if (this.validation() === GeneratorValidation.VALID) {
      this.preferenceTimer = setTimeout(() => {
        this.preferenceTimer = -1;
        this.persistOptions();
      }, 250);
    }
  }

  private persistOptions(): void {
    if (this.validation() !== GeneratorValidation.VALID) {
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      if (this.active) {
        this.preferencesFailed = true;
      }
      return;
    }
    saveGeneratorOptions(context, copyGeneratorOptions(this.options)).then((success: boolean) => {
      if (this.active) {
        this.preferencesFailed = !success;
      }
    });
  }

  private regenerate(notify: boolean = true): void {
    if (this.validation() !== GeneratorValidation.VALID) {
      return;
    }
    const session: GeneratorSession = getGeneratorSession();
    try {
      const result: PasswordResult = generatePassword(this.options);
      this.value = result.value;
      this.entropyBits = result.entropyBits;
      this.generatedFor = this.optionsSignature();
      this.generationFailed = false;
      session.value = result.value;
      session.entropyBits = result.entropyBits;
      session.generatedFor = this.generatedFor;
      session.generationFailed = false;
      session.options = copyGeneratorOptions(this.options);
      this.persistOptions();
      if (notify) {
        this.showFeedback($r('app.string.generator_generated'));
      }
    } catch (_) {
      // Never fall back to predictable demo values or log a password/error payload.
      this.value = '';
      this.entropyBits = 0;
      this.generatedFor = '';
      this.generationFailed = true;
      session.value = '';
      session.entropyBits = 0;
      session.generatedFor = '';
      session.generationFailed = true;
      this.feedback = undefined;
    }
  }

  private copyValue(): void {
    if (!this.canCopy()) {
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showFeedback($r('app.string.security_copy_failed'));
      return;
    }
    this.copying = true;
    copySensitiveText(context, this.value).then((success: boolean) => {
      if (this.active) {
        this.copying = false;
        this.showFeedback(success ? $r('app.string.security_copy_success') : $r('app.string.security_copy_failed'));
      }
    }).catch(() => {
      if (this.active) {
        this.copying = false;
        this.showFeedback($r('app.string.security_copy_failed'));
      }
    });
  }

  private showFeedback(message: Resource): void {
    if (this.feedbackTimer >= 0) {
      clearTimeout(this.feedbackTimer);
    }
    this.feedback = message;
    this.feedbackTimer = setTimeout(() => {
      this.feedback = undefined;
      this.feedbackTimer = -1;
    }, 2200);
  }

  private validationMessage(): Resource {
    if (this.validation() === GeneratorValidation.INVALID_LENGTH) {
      return $r('app.string.generator_invalid_length');
    }
    if (this.validation() === GeneratorValidation.NO_CHARACTERS) {
      return $r('app.string.generator_no_characters');
    }
    if (this.validation() === GeneratorValidation.EMPTY_SYMBOLS) {
      return $r('app.string.generator_empty_symbols');
    }
    return $r('app.string.generator_invalid_symbols');
  }

  private strengthLabel(): Resource {
    if (this.entropyBits < 40) {
      return $r('app.string.generator_strength_weak');
    }
    if (this.entropyBits < 60) {
      return $r('app.string.generator_strength_fair');
    }
    if (this.entropyBits < 80) {
      return $r('app.string.generator_strength_strong');
    }
    return $r('app.string.generator_strength_very_strong');
  }

  private strengthColor(): Resource {
    return this.entropyBits < 40 ? $r('app.color.danger') :
      this.entropyBits < 60 ? $r('app.color.warning') : $r('app.color.success');
  }

  private characterColor(character: string): Resource {
    if (character >= '0' && character <= '9') {
      return $r('app.color.brand');
    }
    if ((character >= 'A' && character <= 'Z') || (character >= 'a' && character <= 'z')) {
      return $r('app.color.text_primary');
    }
    return $r('app.color.warning');
  }

  @Builder
  ResultCard() {
    Column({ space: AppSpacing.md }) {
      Row({ space: AppSpacing.sm }) {
        Text($r('app.string.generator_offline'))
          .fontSize(AppTypography.caption)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.success'))
          .layoutWeight(1)
        if (this.value.length > 0) {
          Text($r('app.string.generator_character_count', `${this.value.length}`))
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')

      if (this.value.length === 0) {
        Text(this.generationFailed ? $r('app.string.generator_generate_failed') : $r('app.string.generator_empty'))
          .fontSize(AppTypography.body)
          .fontColor(this.generationFailed ? $r('app.color.danger') : $r('app.color.text_secondary'))
          .width('100%')
      } else {
        if (this.revealed) {
          Text() {
            ForEach(this.value.split(''), (character: string) => {
              Span(character).fontColor(this.characterColor(character))
            }, (character: string, index: number) => `${index}:${character}`)
          }
          .fontSize(24)
          .fontFamily('monospace')
          .fontWeight(FontWeight.Medium)
          .wordBreak(WordBreak.BREAK_ALL)
          .width('100%')
          .copyOption(CopyOptions.None)
        } else {
          Text('••••••••••••')
            .fontSize(24)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
        }
        Row({ space: AppSpacing.sm }) {
          Text(this.strengthLabel())
            .fontSize(AppTypography.label)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.strengthColor())
            .layoutWeight(1)
          Button(this.revealed ? $r('app.string.generator_hide') : $r('app.string.generator_show'))
            .height(AppLayout.minimumTouchTarget)
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.brand'))
            .backgroundColor($r('app.color.brand_soft'))
            .onClick(() => {
              this.revealed = !this.revealed;
            })
        }
        .width('100%')
        Text($r('app.string.generator_strength_detail', `${Math.floor(this.entropyBits)}`))
          .fontSize(AppTypography.caption)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }

      if (this.rulesChanged()) {
        Text($r('app.string.generator_options_changed'))
          .fontSize(AppTypography.label)
          .fontColor($r('app.color.warning'))
          .width('100%')
      }

      Row({ space: AppSpacing.sm }) {
        Button($r('app.string.generator_regenerate'))
          .type(ButtonType.Capsule)
          .height(AppLayout.minimumTouchTarget)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_soft'))
          .layoutWeight(1)
          .enabled(this.validation() === GeneratorValidation.VALID)
          .onClick(() => {
            this.regenerate();
          })
        Button($r('app.string.common_copy'))
          .type(ButtonType.Capsule)
          .height(AppLayout.minimumTouchTarget)
          .fontColor($r('app.color.background'))
          .backgroundColor($r('app.color.brand'))
          .layoutWeight(1)
          .enabled(this.canCopy())
          .onClick(() => {
            this.copyValue();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(AppSpacing.lg)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(AppRadius.large)
    .border({ width: 1, color: $r('app.color.border') })
  }

  @Builder
  OptionsCard() {
    Column({ space: AppSpacing.md }) {
      Row({ space: AppSpacing.md }) {
        Text($r('app.string.generator_length'))
          .fontSize(AppTypography.body)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        TextInput({ text: this.lengthInput })
          .type(InputType.Number)
          .inputFilter('[0-9]*')
          .maxLength(3)
          .width(88)
          .height(AppLayout.minimumTouchTarget)
          .fontSize(AppTypography.body)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_secondary'))
          .textAlign(TextAlign.Center)
          .accessibilityText($r('app.string.generator_length'))
          .onChange((text: string) => {
            this.lengthInput = text;
            this.options.length = text.length > 0 ? Number(text) : 0;
            this.optionsChanged();
          })
      }
      .width('100%')

      Slider({ value: Math.max(8, Math.min(128, this.options.length)), min: 8, max: 128,
        step: 1, style: SliderStyle.OutSet })
        .selectedColor($r('app.color.brand'))
        .blockColor($r('app.color.brand'))
        .trackColor($r('app.color.surface_secondary'))
        .accessibilityText($r('app.string.generator_length'))
        .onChange((value: number) => {
          this.options.length = Math.round(value);
          this.lengthInput = `${this.options.length}`;
          this.optionsChanged();
        })
      Text($r('app.string.generator_length_hint'))
        .fontSize(AppTypography.caption)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      Divider().color($r('app.color.border'))

      GeneratorOptionToggle({
        title: $r('app.string.generator_lowercase'),
        description: $r('app.string.generator_lowercase_detail'),
        value: this.options.includeLowercase, enabled: !this.options.includeLowercase || this.characterTypeCount() > 1,
        onValueChange: (value: boolean) => {
          this.options.includeLowercase = value;
          this.optionsChanged();
        }
      })
      GeneratorOptionToggle({
        title: $r('app.string.generator_uppercase'),
        description: $r('app.string.generator_uppercase_detail'),
        value: this.options.includeUppercase, enabled: !this.options.includeUppercase || this.characterTypeCount() > 1,
        onValueChange: (value: boolean) => {
          this.options.includeUppercase = value;
          this.optionsChanged();
        }
      })
      GeneratorOptionToggle({
        title: $r('app.string.generator_numbers'),
        description: $r('app.string.generator_numbers_detail'),
        value: this.options.includeNumbers, enabled: !this.options.includeNumbers || this.characterTypeCount() > 1,
        onValueChange: (value: boolean) => {
          this.options.includeNumbers = value;
          this.optionsChanged();
        }
      })
      GeneratorOptionToggle({
        title: $r('app.string.generator_symbols'),
        description: $r('app.string.generator_symbols_detail'),
        value: this.options.includeSymbols, enabled: !this.options.includeSymbols || this.characterTypeCount() > 1,
        onValueChange: (value: boolean) => {
          this.options.includeSymbols = value;
          this.optionsChanged();
        }
      })
      GeneratorOptionToggle({
        title: $r('app.string.generator_avoid_ambiguous'),
        description: $r('app.string.generator_avoid_ambiguous_detail'),
        value: this.options.avoidAmbiguous, enabled: true,
        onValueChange: (value: boolean) => {
          this.options.avoidAmbiguous = value;
          this.optionsChanged();
        }
      })
      Button($r('app.string.generator_advanced'))
        .height(AppLayout.minimumTouchTarget)
        .width('100%')
        .fontColor($r('app.color.brand'))
        .backgroundColor($r('app.color.brand_soft'))
        .onClick(() => { this.advanced = !this.advanced; })

      if (this.advanced) {
        GeneratorOptionToggle({
          title: $r('app.string.generator_require_each'),
          description: $r('app.string.generator_require_each_detail'),
          value: this.options.requireEach,
          onValueChange: (value: boolean) => {
            this.options.requireEach = value;
            this.optionsChanged();
          }
        })
        Text($r('app.string.generator_custom_symbols'))
          .fontSize(AppTypography.body)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        TextInput({ text: this.options.symbols })
          .height(AppLayout.minimumTouchTarget)
          .fontFamily('monospace')
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_secondary'))
          .maxLength(128)
          .enabled(this.options.includeSymbols)
          .accessibilityText($r('app.string.generator_custom_symbols'))
          .onChange((text: string) => {
            this.options.symbols = text;
            this.optionsChanged();
          })
        Text($r('app.string.generator_custom_symbols_detail'))
          .fontSize(AppTypography.caption)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Button($r('app.string.generator_reset_symbols'))
          .height(AppLayout.minimumTouchTarget)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_soft'))
          .onClick(() => {
            this.options.symbols = new GeneratorOptions().symbols;
            this.optionsChanged();
          })
      }

      if (this.validation() !== GeneratorValidation.VALID) {
        Text(this.validationMessage())
          .fontSize(AppTypography.label)
          .fontColor($r('app.color.danger'))
          .width('100%')
      }
      if (this.preferencesFailed) {
        Text($r('app.string.generator_preferences_failed'))
          .fontSize(AppTypography.label)
          .fontColor($r('app.color.warning'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(AppSpacing.lg)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(AppRadius.large)
    .border({ width: 1, color: $r('app.color.border') })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: AppSpacing.md }) {
          PageHeader({ title: $r('app.string.generator_title'), subtitle: $r('app.string.generator_subtitle') })
          this.ResultCard()
          this.OptionsCard()
          Text($r('app.string.generator_local_notice'))
            .fontSize(AppTypography.caption)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .lineHeight(20)
          Blank().height(56)
        }
        .width('100%')
        .constraintSize({ maxWidth: AppLayout.pageMaxWidth })
        .padding({ left: AppLayout.compactPadding, right: AppLayout.compactPadding,
          top: AppSpacing.xl, bottom: AppSpacing.xl })
      }
      .width('100%')
      .height('100%')

      if (this.feedback !== undefined) {
        Text(this.feedback)
          .fontSize(AppTypography.label)
          .fontColor(Color.White)
          .padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.sm, bottom: AppSpacing.sm })
          .backgroundColor('#CC17191D')
          .borderRadius(AppRadius.pill)
          .margin({ bottom: AppSpacing.lg, left: AppSpacing.md, right: AppSpacing.md })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
