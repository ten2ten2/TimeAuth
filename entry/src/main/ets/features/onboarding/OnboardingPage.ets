import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';

@Component
export struct OnboardingPage {
  @State private pageIndex: number = 0;
  onComplete: () => void = () => {};

  private title(): ResourceStr {
    if (this.pageIndex === 0) {
      return $r('app.string.onboarding_title_local');
    }
    if (this.pageIndex === 1) {
      return $r('app.string.onboarding_title_separate');
    }
    return $r('app.string.onboarding_title_control');
  }

  private message(): ResourceStr {
    if (this.pageIndex === 0) {
      return $r('app.string.onboarding_message_local');
    }
    if (this.pageIndex === 1) {
      return $r('app.string.onboarding_message_separate');
    }
    return $r('app.string.onboarding_message_control');
  }

  private symbol(): string {
    if (this.pageIndex === 0) {
      return '◈';
    }
    if (this.pageIndex === 1) {
      return '⇄';
    }
    return '◆';
  }

  build() {
    Column() {
      Row() {
        Text('TimeAuth')
          .fontSize(AppTypography.section)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text($r('app.string.preview_badge'))
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
          Button($r('app.string.onboarding_previous'))
            .type(ButtonType.Capsule)
            .height(52)
            .fontColor($r('app.color.brand'))
            .backgroundColor($r('app.color.brand_soft'))
            .layoutWeight(1)
            .onClick(() => {
              this.pageIndex -= 1;
            })
        }

        Button(this.pageIndex === 2 ? $r('app.string.onboarding_get_started') :
          $r('app.string.onboarding_continue'))
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
