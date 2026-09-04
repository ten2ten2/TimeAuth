import { AppRadius, AppSpacing, AppTypography } from '../design/Tokens';
import { OtpItem, OtpKind } from '../models/AppModels';

@Component
export struct OtpCard {
  @Prop item: OtpItem;
  onCopy: (code: string, issuer: string) => void = () => {};

  @Builder
  ServiceBadge() {
    Text(this.item.issuer.substring(0, 1).toUpperCase())
      .fontSize(AppTypography.section)
      .fontWeight(FontWeight.Bold)
      .fontColor(Color.White)
      .textAlign(TextAlign.Center)
      .width(48)
      .height(48)
      .backgroundColor(this.item.accentColor)
      .borderRadius(AppRadius.medium)
      .accessibilityText($r('app.string.otp_icon_accessibility', this.item.issuer))
  }

  @Builder
  Countdown() {
    Stack({ alignContent: Alignment.Center }) {
      Progress({
        value: this.item.remainingSeconds,
        total: this.item.periodSeconds,
        type: ProgressType.Ring
      })
        .width(42)
        .height(42)
        .color(this.item.remainingSeconds <= 5 ? $r('app.color.warning') : $r('app.color.brand'))
        .backgroundColor($r('app.color.surface_secondary'))

      Text(`${this.item.remainingSeconds}`)
        .fontSize(AppTypography.caption)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.item.remainingSeconds <= 5 ? $r('app.color.warning') : $r('app.color.text_secondary'))
    }
    .accessibilityText($r('app.string.otp_remaining_seconds', `${this.item.remainingSeconds}`))
  }

  build() {
    Column({ space: AppSpacing.md }) {
      Row({ space: AppSpacing.sm }) {
        this.ServiceBadge()

        Column({ space: AppSpacing.xxs }) {
          Row({ space: AppSpacing.xs }) {
            Text(this.item.issuer)
              .fontSize(AppTypography.body)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (this.item.kind === OtpKind.STEAM) {
              Text('STEAM')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.brand'))
                .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                .backgroundColor($r('app.color.brand_soft'))
                .borderRadius(AppRadius.pill)
            }
          }
          .width('100%')

          Text(this.item.account)
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        this.Countdown()
      }
      .width('100%')

      Row() {
        Text(this.item.code)
          .fontSize(AppTypography.otp)
          .fontFamily('monospace')
          .fontWeight(FontWeight.Medium)
          .letterSpacing(1.5)
          .fontColor(this.item.remainingSeconds <= 5 ? $r('app.color.warning') : $r('app.color.text_primary'))
          .layoutWeight(1)
          .accessibilityText($r('app.string.otp_code_accessibility', this.item.issuer, this.item.code))

        Button($r('app.string.common_copy'))
          .type(ButtonType.Capsule)
          .height(40)
          .fontSize(AppTypography.label)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_soft'))
          .accessibilityText($r('app.string.otp_copy_accessibility', this.item.issuer))
          .onClick(() => {
            this.onCopy(this.item.code, this.item.issuer);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(AppSpacing.md)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(AppRadius.large)
    .border({ width: 1, color: $r('app.color.border') })
  }
}
