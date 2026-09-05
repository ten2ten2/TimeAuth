import { bundleManager, common, OpenLinkOptions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { BrandMark } from '../../components/BrandMark';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';

enum AboutDetailMode {
  NONE = 0,
  PRIVACY = 1,
  OPEN_SOURCE = 2
}

@Component
export struct AboutPage {
  onBack: () => void = () => {};
  @State private versionName: string = '1.0.0';
  @State private versionCode: string = '—';
  @State private detailMode: AboutDetailMode = AboutDetailMode.NONE;
  @State private linkFailed: boolean = false;

  aboutToAppear(): void {
    try {
      bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
        .then((info: bundleManager.BundleInfo) => {
          this.versionName = info.versionName;
          this.versionCode = `${info.versionCode}`;
        })
        .catch((error: BusinessError) => {
          console.error(`Failed to read TimeAuth bundle info: ${JSON.stringify(error)}`);
        });
    } catch (error) {
      console.error(`Failed to request TimeAuth bundle info: ${JSON.stringify(error)}`);
    }
  }

  private openSourceRepository(): void {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.showLinkFailure();
      return;
    }
    const context: common.UIAbilityContext = hostContext as common.UIAbilityContext;
    const options: OpenLinkOptions = { appLinkingOnly: false };
    try {
      context.openLink('https://github.com/ten2ten2/TimeAuth', options)
        .catch((error: BusinessError) => {
          console.error(`Failed to open TimeAuth source repository: ${JSON.stringify(error)}`);
          this.showLinkFailure();
        });
    } catch (error) {
      console.error(`Failed to request TimeAuth source repository: ${JSON.stringify(error)}`);
      this.showLinkFailure();
    }
  }

  private showLinkFailure(): void {
    this.linkFailed = true;
    setTimeout(() => {
      this.linkFailed = false;
    }, 2200);
  }

  @Builder
  AboutRow(title: ResourceStr, detail: ResourceStr, onClick: () => void) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: AppSpacing.md }) {
        Column({ space: 2 }) {
          Text(title)
            .fontSize(AppTypography.body)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(22)
          Text(detail)
            .fontSize(AppTypography.caption)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(17)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('›')
          .fontSize(22)
          .fontColor($r('app.color.text_secondary'))
          .width(20)
          .height(24)
          .lineHeight(24)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .constraintSize({ minHeight: 60 })
      .padding({ left: AppSpacing.md, right: AppSpacing.sm, top: AppSpacing.xs, bottom: AppSpacing.xs })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(0)
    .backgroundColor(Color.Transparent)
    .onClick(onClick)
  }

  @Builder
  DetailSheet() {
    Column() {
      Blank()
        .layoutWeight(1)
        .width('100%')
        .onClick(() => {
          this.detailMode = AboutDetailMode.NONE;
        })

      Column({ space: AppSpacing.md }) {
        Row() {
          Text(this.detailMode === AboutDetailMode.PRIVACY ?
            $r('app.string.about_privacy_title') : $r('app.string.about_open_source_title'))
            .fontSize(AppTypography.section)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Button($r('app.string.common_close'))
            .type(ButtonType.Normal)
            .height(40)
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.brand'))
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.detailMode = AboutDetailMode.NONE;
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Scroll() {
          Text(this.detailMode === AboutDetailMode.PRIVACY ?
            $r('app.string.about_privacy_body') : $r('app.string.about_open_source_body'))
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(22)
            .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: 420 })
      }
      .width('100%')
      .padding(AppSpacing.lg)
      .backgroundColor($r('app.color.surface_elevated'))
      .borderRadius({ topLeft: AppRadius.large, topRight: AppRadius.large })
      .border({ width: { top: 1, left: 1, right: 1 }, color: $r('app.color.border') })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.scrim'))
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: AppSpacing.md }) {
          Row({ space: AppSpacing.sm }) {
            Button('←')
              .type(ButtonType.Circle)
              .width(44)
              .height(44)
              .fontSize(20)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.surface'))
              .accessibilityText($r('app.string.about_back'))
              .onClick(() => {
                this.onBack();
              })
            Text($r('app.string.settings_about'))
              .fontSize(AppTypography.title)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Column({ space: AppSpacing.sm }) {
            BrandMark({ markSize: 72 })
            Text($r('app.string.brand_name'))
              .fontSize(AppTypography.title)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.about_tagline'))
              .fontSize(AppTypography.label)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(21)
              .textAlign(TextAlign.Center)
              .constraintSize({ maxWidth: 520 })
            Row({ space: AppSpacing.xs }) {
              Text($r('app.string.about_version_label'))
                .fontSize(AppTypography.caption)
                .fontColor($r('app.color.text_secondary'))
              Text(`${this.versionName} (${this.versionCode})`)
                .fontSize(AppTypography.caption)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
            }
          }
          .width('100%')
          .padding({ top: AppSpacing.xl, bottom: AppSpacing.xl, left: AppSpacing.lg, right: AppSpacing.lg })
          .backgroundColor($r('app.color.surface'))
          .borderRadius(AppRadius.large)
          .border({ width: 1, color: $r('app.color.border') })
          .alignItems(HorizontalAlign.Center)

          Column() {
            this.AboutRow($r('app.string.about_privacy_title'), $r('app.string.about_privacy_summary'), () => {
              this.detailMode = AboutDetailMode.PRIVACY;
            })
            Divider()
              .color($r('app.color.border'))
              .margin({ left: AppSpacing.md, right: AppSpacing.md })
            this.AboutRow($r('app.string.about_open_source_title'), $r('app.string.about_open_source_summary'), () => {
              this.detailMode = AboutDetailMode.OPEN_SOURCE;
            })
            Divider()
              .color($r('app.color.border'))
              .margin({ left: AppSpacing.md, right: AppSpacing.md })
            this.AboutRow($r('app.string.about_source_title'), $r('app.string.about_source_summary'), () => {
              this.openSourceRepository();
            })
          }
          .width('100%')
          .backgroundColor($r('app.color.surface'))
          .borderRadius(AppRadius.large)
          .border({ width: 1, color: $r('app.color.border') })

          Column({ space: AppSpacing.xs }) {
            Row() {
              Text($r('app.string.about_platform_title'))
                .fontSize(AppTypography.label)
                .fontColor($r('app.color.text_secondary'))
              Blank()
              Text($r('app.string.about_platform_value'))
                .fontSize(AppTypography.label)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
            }
            .width('100%')
            Text($r('app.string.about_local_first_note'))
              .fontSize(AppTypography.caption)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(18)
              .width('100%')
          }
          .width('100%')
          .padding(AppSpacing.md)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(AppRadius.large)
          .border({ width: 1, color: $r('app.color.border') })

          Text($r('app.string.about_copyright'))
            .fontSize(AppTypography.caption)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: AppSpacing.sm, bottom: 72 })
        }
        .width('100%')
        .constraintSize({ maxWidth: AppLayout.pageMaxWidth })
        .padding({
          left: AppLayout.compactPadding,
          right: AppLayout.compactPadding,
          top: AppSpacing.xl,
          bottom: AppSpacing.xl
        })
      }
      .width('100%')
      .height('100%')

      if (this.detailMode !== AboutDetailMode.NONE) {
        this.DetailSheet()
      }

      if (this.linkFailed) {
        Text($r('app.string.about_open_link_failed'))
          .fontSize(AppTypography.label)
          .fontColor(Color.White)
          .padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.sm, bottom: AppSpacing.sm })
          .backgroundColor('#CC17191D')
          .borderRadius(AppRadius.pill)
          .margin({ bottom: AppSpacing.lg })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
