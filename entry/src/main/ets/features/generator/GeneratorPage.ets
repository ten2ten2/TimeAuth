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
  @State private feedbackMessage: string = '';

  private previewValue(): string {
    if (this.mode === GeneratorMode.PASSPHRASE) {
      return this.previewIndex % 2 === 0 ? 'river-amber-orbit-canvas-maple' : 'velvet-lantern-forest-comet-silver';
    }
    if (this.mode === GeneratorMode.PIN) {
      return this.previewIndex % 2 === 0 ? '482 907' : '731 054';
    }
    return this.previewIndex % 2 === 0 ? 'N7!qL2@vP9#sT4$xW8%m' : 'C4@rK8!nQ2#yM7%pZ6&w';
  }

  private showFeedback(message: string): void {
    this.feedbackMessage = message;
    setTimeout(() => {
      this.feedbackMessage = '';
    }, 2200);
  }

  @Builder
  ModeButton(value: GeneratorMode, label: string) {
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
  OptionToggle(title: string, description: string, value: boolean, onChange: (value: boolean) => void) {
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
    .minHeight(56)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: AppSpacing.md }) {
          PageHeader({
            title: '密码生成器',
            subtitle: '调整参数并预览交互；当前展示值不是密码学安全随机结果。'
          })

          Row({ space: AppSpacing.xs }) {
            this.ModeButton(GeneratorMode.PASSWORD, '随机密码')
            this.ModeButton(GeneratorMode.PASSPHRASE, '密码短语')
            this.ModeButton(GeneratorMode.PIN, 'PIN')
          }
          .width('100%')
          .padding(AppSpacing.xs)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(AppRadius.large)
          .border({ width: 1, color: $r('app.color.border') })

          Column({ space: AppSpacing.md }) {
            Row() {
              Text('开发预览')
                .fontSize(AppTypography.caption)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.warning'))
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor($r('app.color.surface_secondary'))
                .borderRadius(AppRadius.pill)
              Blank()
              Text(this.mode === GeneratorMode.PASSWORD ? `${this.length} 位` :
                this.mode === GeneratorMode.PASSPHRASE ? '5 个单词' : '6 位')
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
              Button('重新生成')
                .type(ButtonType.Capsule)
                .height(44)
                .fontColor($r('app.color.brand'))
                .backgroundColor($r('app.color.brand_soft'))
                .layoutWeight(1)
                .onClick(() => {
                  this.previewIndex += 1;
                })
              Button('模拟复制')
                .type(ButtonType.Capsule)
                .height(44)
                .fontColor(Color.White)
                .backgroundColor($r('app.color.brand'))
                .layoutWeight(1)
                .onClick(() => {
                  this.showFeedback('原型阶段不会把预览值写入剪贴板');
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
                Text('长度')
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
              this.OptionToggle('大写字母', '包含 A–Z', this.includeUppercase, (value: boolean) => {
                this.includeUppercase = value;
              })
              this.OptionToggle('数字', '包含 0–9', this.includeNumbers, (value: boolean) => {
                this.includeNumbers = value;
              })
              this.OptionToggle('特殊字符', '包含常用符号', this.includeSymbols, (value: boolean) => {
                this.includeSymbols = value;
              })
              this.OptionToggle('排除易混淆字符', '例如 0、O、1、l、I', this.avoidAmbiguous, (value: boolean) => {
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
              Text(this.mode === GeneratorMode.PASSPHRASE ? '密码短语选项' : 'PIN 选项')
                .fontSize(AppTypography.section)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
              Text(this.mode === GeneratorMode.PASSPHRASE ?
                '单词数量、分隔符、大小写与随机数字将在生成器功能阶段接入。' :
                '位数、排除连续数字和排除重复数字将在生成器功能阶段接入。')
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

      if (this.feedbackMessage.length > 0) {
        Text(this.feedbackMessage)
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

