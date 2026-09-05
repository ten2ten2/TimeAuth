import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';
import { copySensitiveText } from '../../security/SecureClipboard';
import {
  GeneratorFailure, GeneratorMode, GeneratorOptions, GeneratorValidation, PasswordGenerationError, PasswordResult,
  validateGeneratorOptions
} from './GeneratorCore';
import { generatePassword } from './PasswordGenerator';
import { copyGeneratorOptions, readGeneratorOptions, saveGeneratorOptions } from './GeneratorSettings';
import { GeneratorSession, getGeneratorSession } from './GeneratorSession';
import { GeneratorOptionToggle } from './GeneratorOptionToggle';

@Component
export struct GeneratorPanel {
  mode: GeneratorMode = GeneratorMode.PASSWORD;
  @Link @Watch('onSelectedIndexChanged') selectedIndex: number;
  @State private options: GeneratorOptions = new GeneratorOptions();
  @State private lengthInput: string = '16';
  @State private value: string = '';
  @State private entropyBits: number = 0;
  @State private generatedFor: string = '';
  @State private generationFailure: GeneratorFailure = GeneratorFailure.NONE;
  @State private revealed: boolean = true;
  @State private advanced: boolean = false;
  @State private preferencesFailed: boolean = false;
  @State private copying: boolean = false;
  @State private resultPressed: boolean = false;
  private resultPointerId: number = -1;
  private resultPressX: number = 0;
  private resultPressY: number = 0;
  private resultWidth: number = 0;
  private resultHeight: number = 0;
  @State private feedback: Resource | undefined = undefined;
  private feedbackTimer: number = -1;
  private preferenceTimer: number = -1;
  @State private active: boolean = false;
  private appeared: boolean = false;
  private restored: boolean = false;
  private copyRequest: number = 0;

  aboutToAppear(): void {
    this.appeared = true;
    // Restore the fixed mode before the first render, including inactive/lazy tab instances.
    this.restoreSession();
    if (this.isSelectedTab()) {
      this.activateTab();
    }
  }

  private isSelectedTab(): boolean {
    const index: number = this.mode === GeneratorMode.PIN ? 2 : this.mode === GeneratorMode.PASSPHRASE ? 1 : 0;
    return this.selectedIndex === index;
  }

  private onSelectedIndexChanged(): void {
    if (!this.appeared) {
      return;
    }
    if (this.isSelectedTab()) {
      this.activateTab();
    } else {
      this.deactivateTab();
    }
  }

  private restoreSession(): void {
    const session: GeneratorSession = getGeneratorSession(this.mode);
    this.preferencesFailed = session.preferencesFailed;
    if (this.restored) {
      return;
    }
    this.restored = true;
    if (!session.initialized) {
      const context = this.getUIContext().getHostContext();
      if (context !== undefined) {
        const saved = readGeneratorOptions(context, this.mode);
        session.options = saved.options;
        session.preferencesFailed = !saved.succeeded;
      } else {
        session.preferencesFailed = true;
      }
      session.initialized = true;
    }
    this.preferencesFailed = session.preferencesFailed;
    this.options = copyGeneratorOptions(session.options);
    this.lengthInput = this.options.length > 0 ? `${this.options.length}` : '';
    this.value = session.value;
    this.entropyBits = session.entropyBits;
    this.generatedFor = session.generatedFor;
    this.generationFailure = session.generationFailure;
    // Native navigation can recreate the component. Do not overwrite an existing result.
    this.revealed = session.value.length === 0;
  }

  private activateTab(): void {
    this.restoreSession();
    this.active = true;
    if (this.value.length === 0 && this.generationFailure === GeneratorFailure.NONE &&
      this.validation() === GeneratorValidation.VALID) {
      this.regenerate(false);
    }
  }

  aboutToDisappear(): void {
    this.deactivateTab();
    this.revealed = false;
    this.appeared = false;
    this.restored = false;
  }

  private deactivateTab(): void {
    this.cancelResultPress();
    this.active = false;
    // An earlier clipboard completion must not show feedback after leaving/re-entering this tab.
    this.copyRequest++;
    this.copying = false;
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
  }

  private validation(): GeneratorValidation {
    return validateGeneratorOptions(this.options);
  }

  private optionsSignature(): string {
    return JSON.stringify(copyGeneratorOptions(this.options));
  }

  private sliderValue(): number {
    return Math.max(8, Math.min(128, this.options.length));
  }

  private rulesChanged(): boolean {
    return this.value.length > 0 && this.generatedFor !== this.optionsSignature();
  }

  private hasCopyableResult(): boolean {
    return this.active && this.isSelectedTab() && this.value.length > 0 &&
      this.generationFailure === GeneratorFailure.NONE && !this.rulesChanged() &&
      this.validation() === GeneratorValidation.VALID;
  }

  private canCopy(): boolean {
    return this.hasCopyableResult() && !this.copying;
  }

  private characterTypeCount(): number {
    return (this.options.includeLowercase ? 1 : 0) + (this.options.includeUppercase ? 1 : 0) +
      (this.options.includeNumbers ? 1 : 0) + (this.options.includeSymbols ? 1 : 0);
  }

  private optionsChanged(): void {
    this.cancelResultPress();
    getGeneratorSession(this.mode).options = copyGeneratorOptions(this.options);
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
    const session: GeneratorSession = getGeneratorSession(this.mode);
    const revision: number = ++session.preferenceRevision;
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      session.preferencesFailed = true;
      if (this.active) {
        this.preferencesFailed = true;
      }
      return;
    }
    saveGeneratorOptions(context, copyGeneratorOptions(this.options)).then((success: boolean) => {
      if (session.preferenceRevision === revision && session === getGeneratorSession(this.mode)) {
        // Retain a failed flush even when it completes while this tab is hidden.
        session.preferencesFailed = !success;
        if (this.active) {
          this.preferencesFailed = !success;
        }
      }
    });
  }

  private regenerate(notify: boolean = true): void {
    this.cancelResultPress();
    if (this.validation() !== GeneratorValidation.VALID) {
      return;
    }
    const session: GeneratorSession = getGeneratorSession(this.mode);
    try {
      const result: PasswordResult = generatePassword(this.options);
      this.value = result.value;
      this.entropyBits = result.entropyBits;
      this.generatedFor = this.optionsSignature();
      this.generationFailure = GeneratorFailure.NONE;
      session.value = result.value;
      session.entropyBits = result.entropyBits;
      session.generatedFor = this.generatedFor;
      session.generationFailure = GeneratorFailure.NONE;
      session.options = copyGeneratorOptions(this.options);
      this.persistOptions();
      if (notify) {
        this.showFeedback(this.mode === GeneratorMode.PIN ?
          $r('app.string.generator_pin_generated') : $r('app.string.generator_generated'));
      }
    } catch (error) {
      // Never fall back to predictable demo values or log a password/error payload.
      this.value = '';
      this.entropyBits = 0;
      this.generatedFor = '';
      this.generationFailure = error instanceof PasswordGenerationError ? error.failure : GeneratorFailure.UNAVAILABLE;
      session.value = '';
      session.entropyBits = 0;
      session.generatedFor = '';
      session.generationFailure = this.generationFailure;
      this.feedback = undefined;
    }
  }

  private cancelResultPress(): void {
    this.resultPressed = false;
    this.resultPointerId = -1;
  }

  private onResultTouch(event: TouchEvent): void {
    // Touch samples drive animation only. They may be empty or resampled independently
    // of native click recognition, so they must never disable a recognized click.
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.cancelResultPress();
      return;
    }
    if (event.type === TouchType.Down) {
      if (!this.canCopy() || event.touches.length !== 1) {
        this.cancelResultPress();
        return;
      }
      const point: TouchObject = event.changedTouches[0] ?? event.touches[0];
      this.resultPointerId = point.id;
      this.resultPressX = point.windowX;
      this.resultPressY = point.windowY;
      this.resultPressed = true;
      return;
    }
    if (this.resultPointerId < 0) {
      return;
    }
    const point: TouchObject | undefined = event.changedTouches.find((touch: TouchObject) =>
      touch.id === this.resultPointerId);
    if (point === undefined || event.touches.length > 1 || !this.canCopy()) {
      this.cancelResultPress();
      return;
    }
    // Regeneration can resize/reposition the result; use window coordinates for movement.
    const moved: boolean = Math.abs(point.windowX - this.resultPressX) > 8 ||
      Math.abs(point.windowY - this.resultPressY) > 8;
    const outside: boolean = point.x < 0 || point.y < 0 ||
      (this.resultWidth > 0 && point.x > this.resultWidth) ||
      (this.resultHeight > 0 && point.y > this.resultHeight);
    if (moved || outside) {
      this.cancelResultPress();
      return;
    }
  }

  private onResultClick(): void {
    this.cancelResultPress();
    this.copyValue();
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
    const request: number = ++this.copyRequest;
    copySensitiveText(context, this.value).then((success: boolean) => {
      if (this.active && request === this.copyRequest) {
        this.copying = false;
        this.showFeedback(success ? $r('app.string.security_copy_success') : $r('app.string.security_copy_failed'));
      }
    }).catch(() => {
      if (this.active && request === this.copyRequest) {
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
    if (this.validation() === GeneratorValidation.INVALID_PIN_LENGTH) {
      return $r('app.string.generator_invalid_pin_length');
    }
    if (this.validation() === GeneratorValidation.INVALID_WORD_COUNT) {
      return $r('app.string.generator_invalid_word_count');
    }
    if (this.validation() === GeneratorValidation.INVALID_SEPARATOR ||
      this.validation() === GeneratorValidation.INVALID_MODE) {
      return $r('app.string.generator_invalid_phrase_options');
    }
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

  private resultPlaceholder(): Resource {
    if (this.generationFailure === GeneratorFailure.UNSUPPORTED) {
      return $r('app.string.generator_device_unsupported');
    }
    if (this.generationFailure === GeneratorFailure.UNAVAILABLE) {
      return $r('app.string.generator_generate_failed');
    }
    return this.mode === GeneratorMode.PIN ? $r('app.string.generator_pin_empty') : $r('app.string.generator_empty');
  }

  private visibilityLabel(): Resource {
    if (this.mode === GeneratorMode.PIN) {
      return this.revealed ? $r('app.string.generator_pin_hide') : $r('app.string.generator_pin_show');
    }
    return this.revealed ? $r('app.string.generator_hide') : $r('app.string.generator_show');
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
  ResultValue() {
    if (this.mode === GeneratorMode.PIN) {
      Text(this.revealed ? this.value : '•'.repeat(this.value.length))
        .fontSize(28)
        .minFontSize(18)
        .maxFontSize(28)
        .maxLines(1)
        .fontFamily('monospace')
        .fontWeight(FontWeight.Medium)
        .fontColor(this.revealed ? $r('app.color.brand') : $r('app.color.text_primary'))
        .letterSpacing(6)
        .textAlign(TextAlign.Center)
        .width('100%')
        .copyOption(CopyOptions.None)
    } else if (this.revealed) {
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
        .maxLines(1)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .copyOption(CopyOptions.None)
    }
  }

  @Builder
  ResultCard() {
    Column({ space: AppSpacing.md }) {
      if (this.value.length === 0) {
        Text(this.resultPlaceholder())
          .fontSize(AppTypography.body)
          .fontColor(this.generationFailure !== GeneratorFailure.NONE ?
            $r('app.color.danger') : $r('app.color.text_secondary'))
          .width('100%')
      } else {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Column({ space: AppSpacing.xs }) {
            this.ResultValue()
            if (!this.rulesChanged() && this.validation() === GeneratorValidation.VALID) {
              Text($r('app.string.generator_tap_to_copy'))
                .fontSize(AppTypography.caption)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
                .width('100%')
            }
          }
          .width('100%')
        }
        .width('100%')
        .constraintSize({ minHeight: AppLayout.minimumTouchTarget })
        .padding({ left: AppSpacing.xs, right: AppSpacing.xs, top: AppSpacing.sm, bottom: AppSpacing.sm })
        .borderRadius(AppRadius.small)
        .backgroundColor(this.resultPressed ? $r('app.color.surface_secondary') : $r('app.color.surface'))
        .animation({ duration: this.resultPressed ? 80 : 120, curve: Curve.EaseOut })
        .enabled(this.hasCopyableResult())
        .accessibilityText($r('app.string.generator_tap_to_copy'))
        .onAreaChange((_oldArea: Area, area: Area) => {
          this.resultWidth = Number(area.width);
          this.resultHeight = Number(area.height);
        })
        .onTouch((event: TouchEvent) => { this.onResultTouch(event); })
        // The native recognizer owns movement/scroll cancellation and non-touch activation.
        .onClick(() => { this.onResultClick(); }, 8)
        if (this.mode !== GeneratorMode.PIN) {
          Text() {
            Span($r('app.string.generator_strength_prefix'))
            Span(this.strengthLabel())
              .fontColor(this.strengthColor())
            Span($r('app.string.generator_strength_detail', `${Math.floor(this.entropyBits)}`))
          }
          .fontSize(AppTypography.caption)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        }
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
          .fontColor($r('app.color.background'))
          .backgroundColor($r('app.color.brand'))
          .layoutWeight(1)
          .enabled(this.validation() === GeneratorValidation.VALID)
          .onClick(() => {
            this.regenerate();
          })
        Button(this.visibilityLabel())
          .type(ButtonType.Capsule)
          .height(AppLayout.minimumTouchTarget)
          .fontSize(AppTypography.label)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_soft'))
          .layoutWeight(1)
          .enabled(this.value.length > 0)
          .onClick(() => {
            this.cancelResultPress();
            this.revealed = !this.revealed;
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
  PinLengthButton(length: number) {
    Button($r('app.string.generator_pin_digits', `${length}`))
      .constraintSize({ minHeight: AppLayout.minimumTouchTarget })
      .layoutWeight(1)
      .fontSize(AppTypography.label)
      .fontColor(this.options.pinLength === length ? Color.White : $r('app.color.brand'))
      .backgroundColor(this.options.pinLength === length ? $r('app.color.brand') : $r('app.color.brand_soft'))
      .onClick(() => {
        this.options.pinLength = length;
        this.optionsChanged();
      })
  }

  @Builder
  PinOptionsCard() {
    Column({ space: AppSpacing.md }) {
      Text($r('app.string.generator_pin_length'))
        .fontSize(AppTypography.body)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Row({ space: AppSpacing.sm }) {
        this.PinLengthButton(4)
        this.PinLengthButton(6)
        this.PinLengthButton(8)
      }
      .width('100%')
      Text($r('app.string.generator_pin_length_hint'))
        .fontSize(AppTypography.caption)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      Text($r('app.string.generator_pin_notice'))
        .fontSize(AppTypography.caption)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
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

  @Builder
  SeparatorButton(separator: string, title: Resource) {
    Button(title)
      .constraintSize({ minHeight: AppLayout.minimumTouchTarget })
      .layoutWeight(1)
      .fontSize(AppTypography.label)
      .fontColor(this.options.separator === separator ? Color.White : $r('app.color.brand'))
      .backgroundColor(this.options.separator === separator ? $r('app.color.brand') : $r('app.color.brand_soft'))
      .onClick(() => {
        this.options.separator = separator;
        this.optionsChanged();
      })
  }

  @Builder
  PassphraseOptionsCard() {
    Column({ space: AppSpacing.md }) {
      Row({ space: AppSpacing.sm }) {
        Text($r('app.string.generator_word_count'))
          .fontSize(AppTypography.body)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Button('−')
          .width(AppLayout.minimumTouchTarget)
          .height(AppLayout.minimumTouchTarget)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_soft'))
          .enabled(this.options.wordCount > 4)
          .accessibilityText($r('app.string.generator_fewer_words'))
          .onClick(() => {
            this.options.wordCount = Math.max(4, this.options.wordCount - 1);
            this.optionsChanged();
          })
        Text(`${this.options.wordCount}`)
          .width(32)
          .textAlign(TextAlign.Center)
          .fontSize(AppTypography.body)
          .fontColor($r('app.color.text_primary'))
        Button('+')
          .width(AppLayout.minimumTouchTarget)
          .height(AppLayout.minimumTouchTarget)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_soft'))
          .enabled(this.options.wordCount < 10)
          .accessibilityText($r('app.string.generator_more_words'))
          .onClick(() => {
            this.options.wordCount = Math.min(10, this.options.wordCount + 1);
            this.optionsChanged();
          })
      }
      .width('100%')
      Text($r('app.string.generator_word_count_hint'))
        .fontSize(AppTypography.caption)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      Text($r('app.string.generator_separator'))
        .fontSize(AppTypography.body)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Row({ space: AppSpacing.sm }) {
        this.SeparatorButton('-', $r('app.string.generator_separator_hyphen'))
        this.SeparatorButton(' ', $r('app.string.generator_separator_space'))
      }
      .width('100%')
      Row({ space: AppSpacing.sm }) {
        this.SeparatorButton('_', $r('app.string.generator_separator_underscore'))
        this.SeparatorButton('.', $r('app.string.generator_separator_dot'))
      }
      .width('100%')
      GeneratorOptionToggle({
        title: $r('app.string.generator_capitalize'),
        description: $r('app.string.generator_capitalize_detail'),
        value: this.options.capitalize,
        onValueChange: (value: boolean) => {
          this.options.capitalize = value;
          this.optionsChanged();
        }
      })
      GeneratorOptionToggle({
        title: $r('app.string.generator_append_number'),
        description: $r('app.string.generator_append_number_detail'),
        value: this.options.appendNumber,
        onValueChange: (value: boolean) => {
          this.options.appendNumber = value;
          this.optionsChanged();
        }
      })
      Text($r('app.string.generator_wordlist_notice'))
        .fontSize(AppTypography.caption)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
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

      Slider({ value: this.sliderValue(), min: 8, max: 128,
        step: 1, style: SliderStyle.OutSet })
        // Start on the thumb's native touch target; touching the track must not change length.
        .sliderInteractionMode(SliderInteraction.SLIDE_ONLY)
        .selectedColor($r('app.color.brand'))
        .blockColor($r('app.color.brand'))
        .trackColor($r('app.color.surface_secondary'))
        .accessibilityText($r('app.string.generator_length'))
        .onChange((value: number) => {
          const nextLength: number = Math.round(value);
          // Begin/End can fire without movement. Preserve the draft and feedback on a mere touch.
          if (nextLength === this.sliderValue()) {
            return;
          }
          this.options.length = nextLength;
          this.lengthInput = `${this.options.length}`;
          this.optionsChanged();
        })
      Row({ space: AppSpacing.sm }) {
        Text($r('app.string.generator_length_hint'))
          .fontSize(AppTypography.caption)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
        Button($r('app.string.generator_reset_length'))
          .height(AppLayout.minimumTouchTarget)
          .fontSize(AppTypography.label)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_soft'))
          .onClick(() => {
            this.options.length = new GeneratorOptions().length;
            this.lengthInput = `${this.options.length}`;
            this.optionsChanged();
          })
      }
      .width('100%')
      Divider().color($r('app.color.border'))

      GeneratorOptionToggle({
        title: $r('app.string.generator_lowercase'),
        description: $r('app.string.generator_lowercase_detail'),
        value: this.options.includeLowercase, optionEnabled: !this.options.includeLowercase || this.characterTypeCount() > 1,
        onValueChange: (value: boolean) => {
          this.options.includeLowercase = value;
          this.optionsChanged();
        }
      })
      GeneratorOptionToggle({
        title: $r('app.string.generator_uppercase'),
        description: $r('app.string.generator_uppercase_detail'),
        value: this.options.includeUppercase, optionEnabled: !this.options.includeUppercase || this.characterTypeCount() > 1,
        onValueChange: (value: boolean) => {
          this.options.includeUppercase = value;
          this.optionsChanged();
        }
      })
      GeneratorOptionToggle({
        title: $r('app.string.generator_numbers'),
        description: $r('app.string.generator_numbers_detail'),
        value: this.options.includeNumbers, optionEnabled: !this.options.includeNumbers || this.characterTypeCount() > 1,
        onValueChange: (value: boolean) => {
          this.options.includeNumbers = value;
          this.optionsChanged();
        }
      })
      GeneratorOptionToggle({
        title: $r('app.string.generator_symbols'),
        description: $r('app.string.generator_symbols_detail'),
        value: this.options.includeSymbols, optionEnabled: !this.options.includeSymbols || this.characterTypeCount() > 1,
        onValueChange: (value: boolean) => {
          this.options.includeSymbols = value;
          this.optionsChanged();
        }
      })
      GeneratorOptionToggle({
        title: $r('app.string.generator_avoid_ambiguous'),
        description: $r('app.string.generator_avoid_ambiguous_detail'),
        value: this.options.avoidAmbiguous, optionEnabled: true,
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
          this.ResultCard()
          if (this.mode === GeneratorMode.PASSPHRASE) {
            this.PassphraseOptionsCard()
          } else if (this.mode === GeneratorMode.PIN) {
            this.PinOptionsCard()
          } else {
            this.OptionsCard()
          }
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
          top: AppSpacing.md, bottom: AppSpacing.xl })
      }
      .width('100%')
      .height('100%')
      .onScrollStart(() => { this.cancelResultPress(); })

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
