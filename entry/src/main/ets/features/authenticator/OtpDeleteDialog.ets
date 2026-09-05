import { AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';

@CustomDialog
export struct OtpDeleteDialog {
  controller?: CustomDialogController;
  message: ResourceStr = '';
  onDelete: () => void = () => {};
  onCancel: () => void = () => {};

  build() {
    Column({ space: AppSpacing.lg }) {
      Text($r('app.string.auth_delete_title'))
        .fontSize(AppTypography.section)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(this.message)
        .fontSize(AppTypography.body)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(24)
        .width('100%')
      Row({ space: AppSpacing.sm }) {
        Button($r('app.string.auth_cancel'))
          .layoutWeight(1)
          .height(48)
          .defaultFocus(true)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => { this.onCancel(); })
        Button($r('app.string.auth_delete'))
          .layoutWeight(1)
          .height(48)
          .backgroundColor($r('app.color.danger'))
          .fontColor(Color.White)
          .onClick(() => { this.onDelete(); })
      }
      .width('100%')
    }
    .padding(AppSpacing.xl)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(AppRadius.large)
    .clip(true)
  }
}
