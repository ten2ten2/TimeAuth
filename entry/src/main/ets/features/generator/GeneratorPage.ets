import { PageHeader } from '../../components/PageHeader';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';
import { GeneratorMode } from '../../models/AppModels';

@Component
export struct GeneratorPage {
  @State private mode: GeneratorMode = GeneratorMode.PASSWORD;
  @State private length: number = 20;
  @State private includeUppercase: boolean = true;
  @State private includeNumbers: boolean = true;
  @State private includeSymbols: boolean = true;
  @State private avoidAmbiguous: boolean = true;
  @State private previewIndex: number = 0;
  @State private feedbackVisible: boolean = false;

  private previewValue(): string {
    if (this.mode === GeneratorMode.PASSPHRASE) {
      return this.previewIndex % 2 === 0 ? 'river-amber-orbit-canvas-maple' : 'velvet-lantern-forest-comet-silver';
    }
    if (this.mode === GeneratorMode.PIN) {
      return this.previewIndex % 2 === 0 ? '482 907' : '731 054';
    }
    return this.previewIndex % 2 === 0 ? 'N7!qL2@vP9#sT4$xW8%m' : 'C4@rK8!nQ2#yM7%pZ6&w';
  }

  private showFeedback(): void {
    this.feedbackVisible = true;
    setTimeout(() => {
      this.feedbackVisible = false;
    }, 2200);
  }

  @Builder
  ModeButton(value: GeneratorMode, label: Resource) {
    Button(label)
      .type(ButtonType.Normal)
      .height(44)
      .fontSize(AppTypography.label)
      .fontWeight(this.mode === value ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.mode === value ? $r('app.color.brand') : $r('app.color.text_secondary'))
      .backgroundColor(this.mode === value ? $r('app.color.brand_soft') : Color.Transparent)
      .borderRadius(AppRadius.medium)
      .layoutWeight(1)
      .onClick(() => {
        this.mode = value;
      })
  }

  @Builder
  OptionToggle(title: ResourceStr, description: ResourceStr, value: boolean,
    onChange: (value: boolean) => void) {
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

      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor($r('app.color.brand'))
        .onChange((isOn: boolean) => {
          onChange(isOn);
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: AppSpacing.md }) {
          PageHeader({
            title: $r('app.string.generator_title'),
            subtitle: $r('app.string.generator_subtitle')
          })

          Row({ space: AppSpacing.xs }) {
            this.ModeButton(GeneratorMode.PASSWORD, $r('app.string.generator_mode_password'))
            this.ModeButton(GeneratorMode.PASSPHRASE, $r('app.string.generator_mode_passphrase'))
            this.ModeButton(GeneratorMode.PIN, $r('app.string.generator_mode_pin'))
          }
          .width('100%')
          .padding(AppSpacing.xs)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(AppRadius.large)
          .border({ width: 1, color: $r('app.color.border') })

          Column({ space: AppSpacing.md }) {
            Row() {
              Text($r('app.string.generator_dev_preview'))
                .fontSize(AppTypography.caption)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.warning'))
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor($r('app.color.surface_secondary'))
                .borderRadius(AppRadius.pill)
              Blank()
              Text(this.mode === GeneratorMode.PASSWORD ?
                $r('app.string.generator_character_count', `${this.length}`) :
                this.mode === GeneratorMode.PASSPHRASE ? $r('app.string.generator_five_words') :
                  $r('app.string.generator_six_digits'))
                .fontSize(AppTypography.label)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')

            Text(this.previewValue())
              .fontSize(this.mode === GeneratorMode.PASSPHRASE ? 20 : AppTypography.otp)
              .fontFamily('monospace')
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .maxLines(3)

            Row({ space: AppSpacing.sm }) {
              Button($r('app.string.generator_regenerate'))
                .type(ButtonType.Capsule)
                .height(44)
                .fontColor($r('app.color.brand'))
                .backgroundColor($r('app.color.brand_soft'))
                .layoutWeight(1)
                .onClick(() => {
                  this.previewIndex += 1;
                })
              Button($r('app.string.generator_mock_copy'))
                .type(ButtonType.Capsule)
                .height(44)
                .fontColor(Color.White)
                .backgroundColor($r('app.color.brand'))
                .layoutWeight(1)
                .onClick(() => {
                  this.showFeedback();
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(AppSpacing.lg)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(AppRadius.large)
          .border({ width: 1, color: $r('app.color.border') })

          if (this.mode === GeneratorMode.PASSWORD) {
            Column({ space: AppSpacing.md }) {
              Row() {
                Text($r('app.string.generator_length'))
                  .fontSize(AppTypography.body)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Blank()
                Text(`${this.length}`)
                  .fontSize(AppTypography.body)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.brand'))
              }
              .width('100%')

              Slider({ value: this.length, min: 8, max: 64, step: 1, style: SliderStyle.OutSet })
                .selectedColor($r('app.color.brand'))
                .blockColor($r('app.color.brand'))
                .trackColor($r('app.color.surface_secondary'))
                .onChange((value: number) => {
                  this.length = Math.round(value);
                })

              Divider().color($r('app.color.border'))
              this.OptionToggle($r('app.string.generator_uppercase'),
                $r('app.string.generator_uppercase_detail'), this.includeUppercase, (value: boolean) => {
                this.includeUppercase = value;
              })
              this.OptionToggle($r('app.string.generator_numbers'),
                $r('app.string.generator_numbers_detail'), this.includeNumbers, (value: boolean) => {
                this.includeNumbers = value;
              })
              this.OptionToggle($r('app.string.generator_symbols'),
                $r('app.string.generator_symbols_detail'), this.includeSymbols, (value: boolean) => {
                this.includeSymbols = value;
              })
              this.OptionToggle($r('app.string.generator_avoid_ambiguous'),
                $r('app.string.generator_avoid_ambiguous_detail'), this.avoidAmbiguous, (value: boolean) => {
                this.avoidAmbiguous = value;
              })
            }
            .width('100%')
            .padding(AppSpacing.lg)
            .backgroundColor($r('app.color.surface'))
            .borderRadius(AppRadius.large)
            .border({ width: 1, color: $r('app.color.border') })
          } else {
            Column({ space: AppSpacing.sm }) {
              Text(this.mode === GeneratorMode.PASSPHRASE ?
                $r('app.string.generator_passphrase_options') : $r('app.string.generator_pin_options'))
                .fontSize(AppTypography.section)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
              Text(this.mode === GeneratorMode.PASSPHRASE ?
                $r('app.string.generator_passphrase_options_detail') :
                $r('app.string.generator_pin_options_detail'))
                .fontSize(AppTypography.label)
                .fontColor($r('app.color.text_secondary'))
                .lineHeight(21)
            }
            .width('100%')
            .padding(AppSpacing.lg)
            .backgroundColor($r('app.color.surface'))
            .borderRadius(AppRadius.large)
            .border({ width: 1, color: $r('app.color.border') })
          }

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

      if (this.feedbackVisible) {
        Text($r('app.string.generator_copy_feedback'))
          .fontSize(AppTypography.label)
          .fontColor(Color.White)
          .padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.sm, bottom: AppSpacing.sm })
          .backgroundColor('#CC17191D')
          .borderRadius(AppRadius.pill)
          .margin({ bottom: AppSpacing.lg })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
