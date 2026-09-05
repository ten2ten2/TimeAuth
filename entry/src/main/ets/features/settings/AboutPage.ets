import { bundleManager } from '@kit.AbilityKit';
import { CustomContentDialog } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { BrandMark } from '../../components/BrandMark';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';

@Component
export struct AboutPage {
  onBack: () => void = () => {};
  @State private versionName: string = '0.1.0';

  private privacyDialogController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: $r('app.string.about_privacy_title'),
      contentBuilder: () => {
        this.DialogBody($r('app.string.about_privacy_body'));
      },
      buttons: [
        {
          value: $r('app.string.common_close'),
          action: () => {
            this.privacyDialogController.close();
          }
        }
      ]
    }),
    autoCancel: true
  });

  private licenseDialogController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: $r('app.string.about_license_title'),
      contentBuilder: () => {
        this.DialogBody($r('app.string.about_license_body'));
      },
      buttons: [
        {
          value: $r('app.string.common_close'),
          action: () => {
            this.licenseDialogController.close();
          }
        }
      ]
    }),
    autoCancel: true
  });

  aboutToAppear(): void {
    try {
      bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
        .then((info: bundleManager.BundleInfo) => {
          this.versionName = info.versionName;
        })
        .catch((error: BusinessError) => {
          console.error(`Failed to read TimeAuth bundle info: ${JSON.stringify(error)}`);
        });
    } catch (error) {
      console.error(`Failed to request TimeAuth bundle info: ${JSON.stringify(error)}`);
    }
  }

  aboutToDisappear(): void {
    this.privacyDialogController.close();
    this.licenseDialogController.close();
  }

  @Builder
  DialogBody(body: ResourceStr) {
    Scroll() {
      Text(body)
        .fontSize(AppTypography.label)
        .fontColor($r('app.color.text_primary'))
        .lineHeight(22)
        .width('100%')
    }
    .width('100%')
    .constraintSize({ maxHeight: 420 })
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

  build() {
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
            Text(this.versionName)
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
            this.privacyDialogController.open();
          })
          Divider()
            .color($r('app.color.border'))
            .margin({ left: AppSpacing.md, right: AppSpacing.md })
          this.AboutRow($r('app.string.about_license_title'), $r('app.string.about_license_summary'), () => {
            this.licenseDialogController.open();
          })
        }
        .width('100%')
        .backgroundColor($r('app.color.surface'))
        .borderRadius(AppRadius.large)
        .border({ width: 1, color: $r('app.color.border') })

        Text($r('app.string.about_copyright_private'))
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
    .backgroundColor($r('app.color.background'))
  }
}
