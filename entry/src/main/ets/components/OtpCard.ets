import { AppRadius, AppSpacing, AppTypography } from '../design/Tokens';
import {
  resolveServiceIcon, ServiceIconKey, ServiceIconMatch, serviceInitial
} from '../features/authenticator/ServiceIconRegistry';
import { OtpItem, OtpKind } from '../models/AppModels';

@Component
export struct OtpCard {
  @Prop item: OtpItem;
  onCopy: (code: string, issuer: string) => void = () => {};

  private serviceIconMatch(): ServiceIconMatch | undefined {
    return resolveServiceIcon(this.item.issuer);
  }

  private serviceIconBackground(): string {
    const match: ServiceIconMatch | undefined = this.serviceIconMatch();
    return match === undefined ? '#626A76' : match.backgroundColor;
  }

  private serviceIconOffsetY(): number {
    const match: ServiceIconMatch | undefined = this.serviceIconMatch();
    return match !== undefined && match.key === ServiceIconKey.APPLE ? -1 : 0;
  }

  private serviceIconResource(): Resource {
    const match: ServiceIconMatch | undefined = this.serviceIconMatch();
    if (match === undefined) {
      return $r('app.media.nav_authenticator');
    }
    switch (match.key) {
      case ServiceIconKey.ALIBABA_CLOUD: return $r('app.media.service_alibaba_cloud');
      case ServiceIconKey.TENCENT_CLOUD: return $r('app.media.service_tencent_cloud');
      case ServiceIconKey.HUAWEI_CLOUD: return $r('app.media.service_huawei_cloud');
      case ServiceIconKey.BAIDU_AI_CLOUD: return $r('app.media.service_baidu_ai_cloud');
      case ServiceIconKey.VOLCANO_ENGINE: return $r('app.media.service_volcano_engine');
      case ServiceIconKey.GOOGLE: return $r('app.media.service_google');
      case ServiceIconKey.MICROSOFT: return $r('app.media.service_microsoft');
      case ServiceIconKey.GITHUB: return $r('app.media.service_github');
      case ServiceIconKey.APPLE: return $r('app.media.service_apple');
      case ServiceIconKey.AWS: return $r('app.media.service_aws');
      case ServiceIconKey.CLOUDFLARE: return $r('app.media.service_cloudflare');
      case ServiceIconKey.STEAM: return $r('app.media.service_steam');
      case ServiceIconKey.DISCORD: return $r('app.media.service_discord');
      case ServiceIconKey.DROPBOX: return $r('app.media.service_dropbox');
      case ServiceIconKey.SLACK: return $r('app.media.service_slack');
      case ServiceIconKey.BITWARDEN: return $r('app.media.service_bitwarden');
      case ServiceIconKey.ONE_PASSWORD: return $r('app.media.service_1password');
      case ServiceIconKey.GITLAB: return $r('app.media.service_gitlab');
      case ServiceIconKey.PROTON: return $r('app.media.service_proton');
      case ServiceIconKey.OPENAI: return $r('app.media.service_openai');
      default: return $r('app.media.nav_authenticator');
    }
  }

  @Builder
  ServiceBadge() {
    if (this.serviceIconMatch() !== undefined) {
      Stack({ alignContent: Alignment.Center }) {
        Image(this.serviceIconResource())
          .width(28)
          .height(28)
          .objectFit(ImageFit.Contain)
          .fillColor(Color.White)
          .translate({ y: this.serviceIconOffsetY() })
          .draggable(false)
          .accessibilityLevel('no')
      }
      .width(48)
      .height(48)
      .backgroundColor(this.serviceIconBackground())
      .borderRadius(AppRadius.medium)
      .accessibilityLevel('no')
    } else {
      Text(serviceInitial(this.item.issuer))
        .fontSize(AppTypography.section)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .width(48)
        .height(48)
        .backgroundColor($r('app.color.surface_secondary'))
        .borderRadius(AppRadius.medium)
        .accessibilityLevel('no')
    }
  }

  @Builder
  Countdown() {
    Stack({ alignContent: Alignment.Center }) {
      Progress({
        value: this.item.remainingSeconds,
        total: this.item.periodSeconds,
        type: ProgressType.Ring
      })
        .width(42)
        .height(42)
        .color(this.item.remainingSeconds <= 5 ? $r('app.color.warning') : $r('app.color.brand'))
        .backgroundColor($r('app.color.surface_secondary'))

      Text(`${this.item.remainingSeconds}`)
        .fontSize(AppTypography.caption)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.item.remainingSeconds <= 5 ? $r('app.color.warning') : $r('app.color.text_secondary'))
    }
    .accessibilityLevel('no')
  }

  build() {
    // The outer container owns the visual card shape so native Button rendering cannot flatten the corners.
    Column() {
      // Keep a single full-card button for copy semantics, pressed feedback and accessibility.
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Column({ space: AppSpacing.md }) {
          Row({ space: AppSpacing.sm }) {
            this.ServiceBadge()

            Column({ space: AppSpacing.xxs }) {
              Row({ space: AppSpacing.xs }) {
                Text(this.item.issuer)
                  .fontSize(AppTypography.body)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)

                if (this.item.kind === OtpKind.STEAM) {
                  Text('STEAM')
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.brand'))
                    .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                    .backgroundColor($r('app.color.brand_soft'))
                    .borderRadius(AppRadius.pill)
                }
              }
              .width('100%')

              Text(this.item.account)
                .fontSize(AppTypography.label)
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            this.Countdown()
          }
          .width('100%')

          Text(this.item.code)
            .fontSize(AppTypography.otp)
            .fontFamily('monospace')
            .fontWeight(FontWeight.Medium)
            .letterSpacing(1.5)
            .fontColor(this.item.remainingSeconds <= 5 ? $r('app.color.warning') : $r('app.color.brand'))
            .width('100%')
            .maxLines(1)
            .textAlign(TextAlign.Start)
        }
        .width('100%')
      }
      .width('100%')
      .padding(AppSpacing.md)
      .backgroundColor(Color.Transparent)
      .accessibilityGroup(true)
      .accessibilityText($r('app.string.auth_card_accessibility',
        this.item.issuer, this.item.account, this.item.code))
      .accessibilityDescription($r('app.string.auth_card_hint'))
      .onClick(() => {
        this.onCopy(this.item.code, this.item.issuer);
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius(AppRadius.large)
    .border({ width: 1, color: $r('app.color.border') })
    .clip(true)
  }
}
