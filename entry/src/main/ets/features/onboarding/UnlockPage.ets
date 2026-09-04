import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';

@Component
export struct UnlockPage {
  @State private showFallback: boolean = false;
  onUnlock: () => void = () => {};

  build() {
    Column() {
      Row() {
        Text('TimeAuth')
          .fontSize(AppTypography.section)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('预览模式')
          .fontSize(AppTypography.caption)
          .fontColor($r('app.color.warning'))
      }
      .width('100%')

      Blank()

      Column({ space: AppSpacing.lg }) {
        Text('锁')
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .width(88)
          .height(88)
          .backgroundColor($r('app.color.brand'))
          .borderRadius(28)

        Column({ space: AppSpacing.xs }) {
          Text('解锁 TimeAuth')
            .fontSize(AppTypography.title)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('真实生物识别将在安全实现阶段接入。当前按钮只用于验证解锁流程。')
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(21)
            .textAlign(TextAlign.Center)
        }
        .width('100%')

        if (this.showFallback) {
          TextInput({ placeholder: '输入备用解锁密码' })
            .type(InputType.Password)
            .height(52)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.surface'))
            .borderRadius(AppRadius.medium)
            .border({ width: 1, color: $r('app.color.border') })
            .padding({ left: AppSpacing.md, right: AppSpacing.md })
        }

        Button(this.showFallback ? '模拟密码解锁' : '模拟生物识别解锁')
          .type(ButtonType.Capsule)
          .width('100%')
          .height(52)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.brand'))
          .onClick(() => {
            this.onUnlock();
          })

        Button(this.showFallback ? '使用生物识别' : '使用备用密码')
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

      Text('没有真实认证或密码校验发生')
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

