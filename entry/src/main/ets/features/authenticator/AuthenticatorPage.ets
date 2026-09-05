import { EmptyState } from '../../components/EmptyState';
import { OtpCard } from '../../components/OtpCard';
import { PageHeader } from '../../components/PageHeader';
import { SearchField } from '../../components/SearchField';
import { mockRepository } from '../../data/MockRepository';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';
import { OtpItem } from '../../models/AppModels';
import { copySensitiveText } from '../../security/SecureClipboard';

@Component
export struct AuthenticatorPage {
  @State private searchText: string = '';
  @State private showAddMenu: boolean = false;
  @State private feedbackVisible: boolean = false;
  @State private copyFeedback: boolean = false;
  @State private copySucceeded: boolean = true;
  private items: OtpItem[] = mockRepository.getOtpItems();

  private filteredItems(): OtpItem[] {
    const normalizedQuery: string = this.searchText.trim().toLowerCase();
    if (normalizedQuery.length === 0) {
      return this.items;
    }
    return this.items.filter((item: OtpItem) =>
      item.issuer.toLowerCase().includes(normalizedQuery) ||
      item.account.toLowerCase().includes(normalizedQuery));
  }

  private showFeedback(isCopy: boolean, copySucceeded: boolean = true): void {
    this.copyFeedback = isCopy;
    this.copySucceeded = copySucceeded;
    this.feedbackVisible = true;
    setTimeout(() => {
      this.feedbackVisible = false;
    }, 2200);
  }

  @Builder
  AddMenu() {
    Column({ space: AppSpacing.xs }) {
      Row() {
        Text($r('app.string.auth_add_code'))
          .fontSize(AppTypography.section)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Button($r('app.string.common_close'))
          .type(ButtonType.Normal)
          .height(40)
          .fontColor($r('app.color.brand'))
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showAddMenu = false;
          })
      }
      .width('100%')

      this.AddMenuRow('▣', $r('app.string.auth_scan_qr'), $r('app.string.auth_scan_qr_detail'))
      this.AddMenuRow('▧', $r('app.string.auth_import_photo'), $r('app.string.auth_import_photo_detail'))
      this.AddMenuRow('⌨', $r('app.string.auth_manual_entry'), $r('app.string.auth_manual_entry_detail'))
      this.AddMenuRow('S', $r('app.string.auth_steam_code'), $r('app.string.auth_steam_code_detail'))
    }
    .width('100%')
    .padding(AppSpacing.md)
    .backgroundColor($r('app.color.surface_elevated'))
    .borderRadius(AppRadius.large)
    .border({ width: 1, color: $r('app.color.border') })
  }

  @Builder
  AddMenuRow(symbol: string, title: ResourceStr, detail: ResourceStr) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: AppSpacing.sm }) {
        Text(symbol)
          .fontSize(AppTypography.body)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand'))
          .textAlign(TextAlign.Center)
          .width(40)
          .height(40)
          .backgroundColor($r('app.color.brand_soft'))
          .borderRadius(AppRadius.small)
        Column({ space: 2 }) {
          Text(title)
            .fontSize(AppTypography.body)
            .fontColor($r('app.color.text_primary'))
          Text(detail)
            .fontSize(AppTypography.caption)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('›')
          .fontSize(24)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ top: AppSpacing.xs, bottom: AppSpacing.xs })
    }
    .width('100%')
    .padding(0)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.showFeedback(false);
      this.showAddMenu = false;
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: AppSpacing.md }) {
          Row({ space: AppSpacing.md }) {
            PageHeader({
              title: $r('app.string.auth_title'),
              subtitle: $r('app.string.auth_subtitle')
            })
              .layoutWeight(1)

            Button('+')
              .type(ButtonType.Circle)
              .width(AppLayout.minimumTouchTarget)
              .height(AppLayout.minimumTouchTarget)
              .fontSize(28)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.brand'))
              .accessibilityText($r('app.string.auth_add_code'))
              .onClick(() => {
                this.showAddMenu = !this.showAddMenu;
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          SearchField({ value: $searchText, placeholder: $r('app.string.auth_search_placeholder') })

          if (this.showAddMenu) {
            this.AddMenu()
          }

          if (this.filteredItems().length === 0) {
            EmptyState({
              symbol: '⌕',
              title: $r('app.string.auth_empty_title'),
              message: $r('app.string.auth_empty_message')
            })
          } else {
            ForEach(this.filteredItems(), (item: OtpItem) => {
              OtpCard({
                item: item,
                onCopy: (code: string, issuer: string) => {
                  const context = this.getUIContext().getHostContext();
                  if (context === undefined) {
                    this.showFeedback(true, false);
                    return;
                  }
                  copySensitiveText(context, code).then((success: boolean) => {
                    this.showFeedback(true, success);
                  });
                }
              })
            }, (item: OtpItem) => item.id)
          }

          Blank().height(72)
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
      .align(Alignment.Top)

      if (this.feedbackVisible) {
        Text(this.copyFeedback ?
          (this.copySucceeded ? $r('app.string.security_copy_success') : $r('app.string.security_copy_failed')) :
          $r('app.string.auth_feature_later_feedback'))
          .fontSize(AppTypography.label)
          .fontColor(Color.White)
          .padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.sm, bottom: AppSpacing.sm })
          .backgroundColor('#CC17191D')
          .borderRadius(AppRadius.pill)
          .margin({ bottom: AppSpacing.lg })
          .transition(TransitionEffect.OPACITY)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
