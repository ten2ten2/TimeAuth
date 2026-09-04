import { AppSpacing, AppTypography } from '../design/Tokens';

@Component
export struct PageHeader {
  @Prop title: ResourceStr = '';
  @Prop subtitle: ResourceStr = '';

  build() {
    Column({ space: AppSpacing.xs }) {
      Text(this.title)
        .fontSize(AppTypography.title)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      if (this.subtitle !== '') {
        Text(this.subtitle)
          .fontSize(AppTypography.label)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(21)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
