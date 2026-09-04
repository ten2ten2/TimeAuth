import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';

@Component
export struct OnboardingPage {
  @State private pageIndex: number = 0;
  onComplete: () => void = () => {};

  private title(): string {
    if (this.pageIndex === 0) {
      return '安全，从本地开始';
    }
    if (this.pageIndex === 1) {
      return '验证与密码，彼此隔离';
    }
    return '你始终掌控自己的数据';
  }

  private message(): string {
    if (this.pageIndex === 0) {
      return 'TimeAuth 默认离线工作，不需要注册账号。UI 预览阶段不会保存任何敏感信息。';
    }
    if (this.pageIndex === 1) {
      return '验证码保险库和密码保险库将使用不同的密钥，并允许你分别控制解锁和备份。';
    }
    return '基础导入、加密导出与恢复不会成为付费墙，后续接入真实数据时仍遵循这一原则。';
  }

  private symbol(): string {
    if (this.pageIndex === 0) {
      return '盾';
    }
    if (this.pageIndex === 1) {
      return '双';
    }
    return '钥';
  }

  build() {
    Column() {
      Row() {
        Text('TimeAuth')
          .fontSize(AppTypography.section)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('UI/UX PREVIEW')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.warning'))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.pill)
      }
      .width('100%')

      Blank()

      Column({ space: AppSpacing.xl }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(172)
            .height(172)
            .fill($r('app.color.brand_soft'))
          Circle()
            .width(116)
            .height(116)
            .fill($r('app.color.brand'))
          Text(this.symbol())
            .fontSize(40)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(180)
        .height(180)

        Column({ space: AppSpacing.sm }) {
          Text(this.title())
            .fontSize(AppTypography.hero)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .textAlign(TextAlign.Center)
          Text(this.message())
            .fontSize(AppTypography.body)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(25)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxWidth: 560 })

      Blank()

      Row({ space: AppSpacing.xs }) {
        ForEach([0, 1, 2], (index: number) => {
          Circle()
            .width(this.pageIndex === index ? 24 : 8)
            .height(8)
            .fill(this.pageIndex === index ? $r('app.color.brand') : $r('app.color.border'))
            .animation({ duration: 180, curve: Curve.EaseOut })
        })
      }

      Row({ space: AppSpacing.sm }) {
        if (this.pageIndex > 0) {
          Button('上一步')
            .type(ButtonType.Capsule)
            .height(52)
            .fontColor($r('app.color.brand'))
            .backgroundColor($r('app.color.brand_soft'))
            .layoutWeight(1)
            .onClick(() => {
              this.pageIndex -= 1;
            })
        }

        Button(this.pageIndex === 2 ? '开始使用' : '继续')
          .type(ButtonType.Capsule)
          .height(52)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.brand'))
          .layoutWeight(1)
          .onClick(() => {
            if (this.pageIndex < 2) {
              this.pageIndex += 1;
              return;
            }
            this.onComplete();
          })
      }
      .width('100%')
      .constraintSize({ maxWidth: 560 })
      .padding({ top: AppSpacing.xl })
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

