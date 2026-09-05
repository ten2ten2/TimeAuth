import { AppRoot } from '../app/AppRoot';
import { BrandMark } from '../components/BrandMark';
import { AppSpacing, AppTypography } from '../design/Tokens';
import { refreshScreenSecurity } from '../security/ScreenSecurityManager';

@Entry
@Component
struct Index {
  @StorageLink('timeauth.screenCovered') private screenCovered: boolean = false;
  @StorageLink('timeauth.screenProtectionFailed') private protectionFailed: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        AppRoot()
          .width('100%')
          .height('100%')
      }
      .width('100%')
      .height('100%')
      // Keep the route/component state mounted, but remove its pixels and accessibility tree.
      .visibility(this.screenCovered ? Visibility.Hidden : Visibility.Visible)
      .accessibilityLevel(this.screenCovered ? 'no-hide-descendants' : 'auto')

      if (this.screenCovered) {
        Column({ space: AppSpacing.md }) {
          BrandMark({ markSize: 64 })
          Text($r('app.string.brand_name'))
            .fontSize(AppTypography.title)
            .fontColor($r('app.color.text_primary'))
          Text(this.protectionFailed ? $r('app.string.screen_protection_error') :
            $r('app.string.screen_content_covered'))
            .fontSize(AppTypography.body)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
          if (this.protectionFailed) {
            Button($r('app.string.settings_retry'))
              .onClick(() => {
                const context = this.getUIContext().getHostContext();
                if (context !== undefined) {
                  refreshScreenSecurity(context);
                }
              })
          }
        }
        .width('100%')
        .height('100%')
        .padding(AppSpacing.xl)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        // An opaque cover, not a blur/scrim; no fade animation during loss of focus.
        .backgroundColor($r('app.color.background'))
        .id('privacy-cover')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
