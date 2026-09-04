import { BrandMark } from '../../components/BrandMark';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';

@Component
export struct UnlockPage {
  @State private showFallback: boolean = false;
  onUnlock: () => void = () => {};

  build() {
    Column() {
      Row() {
        Row({ space: AppSpacing.xs }) {
          BrandMark({ size: 28 })
          Text($r('app.string.brand_name'))
            .fontSize(AppTypography.section)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
        Blank()
        Text($r('app.string.preview_mode'))
          .fontSize(AppTypography.caption)
          .fontColor($r('app.color.warning'))
      }
      .width('100%')

      Blank()

      Column({ space: AppSpacing.lg }) {
        BrandMark({ size: 88 })

        Column({ space: AppSpacing.xs }) {
          Text($r('app.string.unlock_title'))
            .fontSize(AppTypography.title)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.unlock_description'))
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(21)
            .textAlign(TextAlign.Center)
        }
        .width('100%')

        if (this.showFallback) {
          TextInput({ placeholder: $r('app.string.unlock_password_placeholder') })
            .type(InputType.Password)
            .height(52)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.surface'))
            .borderRadius(AppRadius.medium)
            .border({ width: 1, color: $r('app.color.border') })
            .padding({ left: AppSpacing.md, right: AppSpacing.md })
        }

        Button(this.showFallback ? $r('app.string.unlock_mock_password') :
          $r('app.string.unlock_mock_biometric'))
          .type(ButtonType.Capsule)
          .width('100%')
          .height(52)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.brand'))
          .onClick(() => {
            this.onUnlock();
          })

        Button(this.showFallback ? $r('app.string.unlock_use_biometric') :
          $r('app.string.unlock_use_password'))
          .type(ButtonType.Normal)
          .height(48)
          .fontColor($r('app.color.brand'))
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showFallback = !this.showFallback;
          })
      }
      .width('100%')
      .constraintSize({ maxWidth: 440 })
      .padding(AppSpacing.xl)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(AppRadius.large)
      .border({ width: 1, color: $r('app.color.border') })

      Blank()

      Text($r('app.string.unlock_no_real_auth'))
        .fontSize(AppTypography.caption)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height('100%')
    .padding({
      left: AppLayout.contentPadding,
      right: AppLayout.contentPadding,
      top: AppSpacing.xl,
      bottom: AppSpacing.xl
    })
    .backgroundColor($r('app.color.background'))
  }
}
