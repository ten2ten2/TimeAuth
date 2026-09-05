import { BrandMark } from '../../components/BrandMark';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';
import { appSessionEpoch, unlockAppSession } from '../../security/AppSession';
import { DeviceUnlock } from '../../security/DeviceUnlock';

@Component
export struct UnlockPage {
  @State private busy: boolean = false;
  @State private failed: boolean = false;
  private active: boolean = false;
  private request: DeviceUnlock = new DeviceUnlock();

  aboutToAppear(): void { this.active = true; }
  aboutToDisappear(): void { this.active = false; this.request.cancel(); }

  private async unlock(): Promise<void> {
    if (this.busy || !this.active) { return; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.failed = true; return; }
    this.busy = true;
    this.failed = false;
    const epoch: number = appSessionEpoch();
    try {
      const title: string = context.resourceManager.getStringSync($r('app.string.auth_live_unlock_title').id);
      const success: boolean = await this.request.verify(title);
      if (!this.active) { return; }
      this.failed = !success || !unlockAppSession(epoch);
    } catch {
      if (this.active) { this.failed = true; }
    } finally {
      if (this.active) { this.busy = false; }
    }
  }

  build() {
    Column() {
      Row({ space: AppSpacing.xs }) {
        BrandMark({ markSize: 28 })
        Text($r('app.string.brand_name'))
          .fontSize(AppTypography.section).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      Blank()
      Column({ space: AppSpacing.lg }) {
        BrandMark({ markSize: 88 })
        Text($r('app.string.auth_live_unlock_title'))
          .fontSize(AppTypography.title).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        Text($r('app.string.auth_live_unlock_description'))
          .fontSize(AppTypography.body).fontColor($r('app.color.text_secondary'))
          .lineHeight(24).textAlign(TextAlign.Center)
        if (this.failed) {
          Text($r('app.string.auth_live_unlock_failed'))
            .fontSize(AppTypography.label).fontColor($r('app.color.danger'))
            .lineHeight(22).textAlign(TextAlign.Center)
        }
        Button(this.busy ? $r('app.string.auth_live_unlock_pending') : $r('app.string.auth_live_unlock_button'))
          .type(ButtonType.Capsule).width('100%').height(52).enabled(!this.busy)
          .fontColor(Color.White).backgroundColor($r('app.color.brand'))
          .onClick(() => { this.unlock(); })
      }
      .width('100%').constraintSize({ maxWidth: 440 }).padding(AppSpacing.xl)
      .backgroundColor($r('app.color.surface')).borderRadius(AppRadius.large)
      .border({ width: 1, color: $r('app.color.border'), radius: AppRadius.large })
      Blank()
      Text($r('app.string.auth_live_unlock_privacy'))
        .fontSize(AppTypography.caption).fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center)
    }
    .width('100%').height('100%')
    .padding({ left: AppLayout.contentPadding, right: AppLayout.contentPadding,
      top: AppSpacing.xl, bottom: AppSpacing.xl })
    .backgroundColor($r('app.color.background'))
  }
}
