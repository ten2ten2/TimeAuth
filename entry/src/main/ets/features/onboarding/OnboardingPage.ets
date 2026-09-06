import { BrandMark } from '../../components/BrandMark';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';

@Component
export struct OnboardingPage {
  @State private pageIndex: number = 0;
  @Prop saving: boolean = false;
  @Prop saveFailed: boolean = false;
  private swiperController: SwiperController = new SwiperController();
  onComplete: () => void = () => {};

  private title(index: number): ResourceStr {
    if (index === 0) { return $r('app.string.onboarding_title_local'); }
    if (index === 1) { return $r('app.string.onboarding_title_separate'); }
    return $r('app.string.onboarding_title_control');
  }

  private message(index: number): ResourceStr {
    if (index === 0) { return $r('app.string.auth_live_onboarding_local_v2'); }
    if (index === 1) { return $r('app.string.auth_live_onboarding_separate'); }
    return $r('app.string.auth_live_onboarding_control');
  }

  private symbol(index: number): string {
    if (index === 0) { return '◈'; }
    if (index === 1) { return '⇄'; }
    return '◆';
  }

  @Builder
  OnboardingSlide(index: number) {
    Column() {
      Blank()
      Column({ space: AppSpacing.xl }) {
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(172).height(172).backgroundColor($r('app.color.brand_soft')).borderRadius(86)
          Row()
            .width(116).height(116).backgroundColor($r('app.color.brand')).borderRadius(58)
          Text(this.symbol(index))
            .fontSize(40).fontWeight(FontWeight.Bold).fontColor(Color.White)
        }
        .width(180).height(180)
        Column({ space: AppSpacing.sm }) {
          Text(this.title(index))
            .fontSize(AppTypography.hero).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary')).textAlign(TextAlign.Center)
          Text(this.message(index))
            .fontSize(AppTypography.body).fontColor($r('app.color.text_secondary'))
            .lineHeight(25).textAlign(TextAlign.Center)
        }
        .width('100%')
      }
      .width('100%').constraintSize({ maxWidth: 560 }).alignItems(HorizontalAlign.Center)
      Blank()
    }
    .width('100%').height('100%').alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      Row() {
        Row({ space: AppSpacing.xs }) {
          BrandMark({ markSize: 28 })
          Text($r('app.string.brand_name'))
            .fontSize(AppTypography.section).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        }
        Blank()
      }
      .width('100%')
      Swiper(this.swiperController) {
        this.OnboardingSlide(0)
        this.OnboardingSlide(1)
        this.OnboardingSlide(2)
      }
      .layoutWeight(1).width('100%').indicator(false).loop(false).duration(220).curve(Curve.EaseOut)
      .onChange((index: number) => { this.pageIndex = index; })
      Row({ space: AppSpacing.xs }) {
        ForEach([0, 1, 2], (index: number) => {
          Row()
            .width(this.pageIndex === index ? 24 : 8).height(8)
            .backgroundColor(this.pageIndex === index ? $r('app.color.brand') : $r('app.color.border'))
            .borderRadius(AppRadius.pill).animation({ duration: 180, curve: Curve.EaseOut })
        })
      }
      if (this.saveFailed) {
        Text($r('app.string.onboarding_save_failed'))
          .fontSize(AppTypography.caption).fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center).width('100%').padding({ top: AppSpacing.sm })
      }
      Row({ space: AppSpacing.sm }) {
        if (this.pageIndex > 0) {
          Button($r('app.string.onboarding_previous'))
            .type(ButtonType.Capsule).height(52).fontColor($r('app.color.brand'))
            .backgroundColor($r('app.color.brand_soft')).layoutWeight(1)
            .onClick(() => { this.swiperController.showPrevious(); })
        }
        Button(this.pageIndex === 2 ? $r('app.string.onboarding_get_started') : $r('app.string.onboarding_continue'))
          .enabled(!this.saving).type(ButtonType.Capsule).height(52).fontColor(Color.White)
          .backgroundColor($r('app.color.brand')).layoutWeight(1)
          .onClick(() => {
            if (this.pageIndex < 2) { this.swiperController.showNext(); return; }
            this.onComplete();
          })
      }
      .width('100%').constraintSize({ maxWidth: 560 }).padding({ top: AppSpacing.xl })
    }
    .width('100%').height('100%')
    .padding({ left: AppLayout.contentPadding, right: AppLayout.contentPadding,
      top: AppSpacing.xl, bottom: AppSpacing.xl })
    .backgroundColor($r('app.color.background'))
  }
}
