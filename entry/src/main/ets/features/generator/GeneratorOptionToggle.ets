import { AppSpacing, AppTypography } from '../../design/Tokens';

@Component
export struct GeneratorOptionToggle {
  title: Resource = $r('app.string.generator_lowercase');
  description: Resource = $r('app.string.generator_lowercase_detail');
  @Prop value: boolean = false;
  @Prop enabled: boolean = true;
  onValueChange: (value: boolean) => void = () => {};

  build() {
    Row({ space: AppSpacing.md }) {
      Column({ space: 3 }) {
        Text(this.title)
          .fontSize(AppTypography.body)
          .fontColor($r('app.color.text_primary'))
        Text(this.description)
          .fontSize(AppTypography.caption)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: this.value })
        .selectedColor($r('app.color.brand'))
        .enabled(this.enabled)
        .accessibilityText(this.title)
        .onChange((isOn: boolean) => {
          this.onValueChange(isOn);
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
  }
}
