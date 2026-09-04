import { AppRadius, AppSpacing, AppTypography } from '../design/Tokens';

@Component
export struct SearchField {
  @Link value: string;
  @Prop placeholder: ResourceStr = $r('app.string.common_search');

  build() {
    Row({ space: AppSpacing.sm }) {
      Text('⌕')
        .fontSize(22)
        .fontColor($r('app.color.text_secondary'))
        .accessibilityText($r('app.string.common_search'))

      TextInput({ text: this.value, placeholder: this.placeholder })
        .layoutWeight(1)
        .height(48)
        .fontSize(AppTypography.body)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_secondary'))
        .backgroundColor(Color.Transparent)
        .padding(0)
        .onChange((value: string) => {
          this.value = value;
        })

      if (this.value.length > 0) {
        Button('×')
          .type(ButtonType.Circle)
          .width(32)
          .height(32)
          .fontSize(20)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.surface_secondary'))
          .accessibilityText($r('app.string.common_clear_search'))
          .onClick(() => {
            this.value = '';
          })
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: AppSpacing.md, right: AppSpacing.sm })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(AppRadius.medium)
    .border({ width: 1, color: $r('app.color.border') })
  }
}
