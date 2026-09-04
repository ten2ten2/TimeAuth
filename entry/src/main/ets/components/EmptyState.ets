import { AppRadius, AppSpacing, AppTypography } from '../design/Tokens';

@Component
export struct EmptyState {
  @Prop symbol: string = '＋';
  @Prop title: string = '';
  @Prop message: string = '';

  build() {
    Column({ space: AppSpacing.sm }) {
      Text(this.symbol)
        .fontSize(32)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.brand'))
        .width(64)
        .height(64)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.brand_soft'))
        .borderRadius(AppRadius.large)

      Text(this.title)
        .fontSize(AppTypography.section)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))

      Text(this.message)
        .fontSize(AppTypography.label)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .lineHeight(21)
    }
    .width('100%')
    .padding({ top: 48, bottom: 48, left: 32, right: 32 })
  }
}

