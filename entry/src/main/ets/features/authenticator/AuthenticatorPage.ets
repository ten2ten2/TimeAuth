import { EmptyState } from '../../components/EmptyState';
import { OtpCard } from '../../components/OtpCard';
import { PageHeader } from '../../components/PageHeader';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';
import { OtpItem } from '../../models/AppModels';
import { copySensitiveText } from '../../security/SecureClipboard';
import {
  authenticatorPreviewStore, OTP_ACCOUNT_MAX_LENGTH, OTP_ISSUER_MAX_LENGTH,
  otpClipboardValue, otpPreviewRenderKey, validOtpPreviewLabels
} from './AuthenticatorPreviewStore';

@Component
export struct AuthenticatorPage {
  @State private items: OtpItem[] = authenticatorPreviewStore.readItems();
  @State private feedbackVisible: boolean = false;
  @State private feedbackText: ResourceStr = '';
  @State private showEditor: boolean = false;
  @State private editIssuer: string = '';
  @State private editAccount: string = '';
  @State private editKind: string = '';
  @State private editPeriod: number = 30;
  private editId: string = '';
  private listScroller: ListScroller = new ListScroller();
  private swipedItemId: string = '';
  private feedbackTimer: number = -1;
  private active: boolean = false;
  private copyRevision: number = 0;
  private deleteDialogOpen: boolean = false;

  aboutToAppear(): void {
    this.active = true;
    this.items = authenticatorPreviewStore.readItems();
  }

  aboutToDisappear(): void {
    this.active = false;
    this.copyRevision += 1;
    if (this.feedbackTimer >= 0) {
      clearTimeout(this.feedbackTimer);
      this.feedbackTimer = -1;
    }
    this.feedbackVisible = false;
    this.showEditor = false;
    this.deleteDialogOpen = false;
  }

  private showFeedback(message: ResourceStr): void {
    if (!this.active) {
      return;
    }
    if (this.feedbackTimer >= 0) {
      clearTimeout(this.feedbackTimer);
    }
    this.feedbackText = message;
    this.feedbackVisible = true;
    this.feedbackTimer = setTimeout(() => {
      this.feedbackVisible = false;
      this.feedbackTimer = -1;
    }, 2200);
  }

  private closeSwipeActions(): void {
    this.listScroller.closeAllSwipeActions();
    this.swipedItemId = '';
  }

  private copyItem(id: string): void {
    // Tapping an exposed/sliding card first dismisses its actions, not a hidden code.
    if (this.swipedItemId.length > 0) {
      this.closeSwipeActions();
      return;
    }
    const revision: number = ++this.copyRevision;
    const item: OtpItem | undefined = authenticatorPreviewStore.findItem(id);
    const context = this.getUIContext().getHostContext();
    if (item === undefined || context === undefined) {
      this.showFeedback($r('app.string.security_copy_failed'));
      return;
    }
    copySensitiveText(context, otpClipboardValue(item.code)).then((success: boolean) => {
      if (this.active && revision === this.copyRevision) {
        this.showFeedback(success ? $r('app.string.security_copy_success') :
          $r('app.string.security_copy_failed'));
      }
    }).catch(() => {
      if (this.active && revision === this.copyRevision) {
        this.showFeedback($r('app.string.security_copy_failed'));
      }
    });
  }

  private openEditor(id: string): void {
    const item: OtpItem | undefined = authenticatorPreviewStore.findItem(id);
    if (item === undefined) {
      return;
    }
    this.closeSwipeActions();
    // Draft fields are separate from the store; dismissing never changes the item.
    this.editId = item.id;
    this.editIssuer = item.issuer;
    this.editAccount = item.account;
    this.editKind = item.kind;
    this.editPeriod = item.periodSeconds;
    this.showEditor = true;
  }

  private saveEdit(): void {
    if (!authenticatorPreviewStore.updateLabels(this.editId, this.editIssuer, this.editAccount)) {
      this.showFeedback($r('app.string.auth_edit_failed'));
      return;
    }
    this.items = authenticatorPreviewStore.readItems();
    this.showEditor = false;
    this.showFeedback($r('app.string.auth_edit_saved'));
  }

  private confirmDelete(id: string): void {
    const item: OtpItem | undefined = authenticatorPreviewStore.findItem(id);
    if (item === undefined || this.deleteDialogOpen) {
      return;
    }
    this.closeSwipeActions();
    this.deleteDialogOpen = true;
    try {
      this.getUIContext().showAlertDialog({
        title: $r('app.string.auth_delete_title'),
        message: $r('app.string.auth_delete_message', item.issuer, item.account),
        autoCancel: true,
        primaryButton: {
          value: $r('app.string.auth_cancel'),
          defaultFocus: true,
          action: () => {
            this.deleteDialogOpen = false;
          }
        },
        secondaryButton: {
          value: $r('app.string.auth_delete'),
          fontColor: $r('app.color.danger'),
          action: () => {
            this.deleteDialogOpen = false;
            if (this.active && authenticatorPreviewStore.removeItem(id)) {
              this.items = authenticatorPreviewStore.readItems();
              this.showFeedback($r('app.string.auth_deleted'));
            }
          }
        },
        cancel: () => {
          this.deleteDialogOpen = false;
        }
      });
    } catch {
      this.deleteDialogOpen = false;
      this.showFeedback($r('app.string.auth_action_failed'));
    }
  }

  @Builder
  AddMenu() {
    Menu() {
      MenuItem({ startIcon: $r('app.media.menu_scan_qr'), content: $r('app.string.auth_scan_qr') })
        .onClick(() => {
          this.closeSwipeActions();
          this.showFeedback($r('app.string.auth_feature_later_feedback'));
        })
      MenuItem({ startIcon: $r('app.media.menu_manual_entry'), content: $r('app.string.auth_manual_entry') })
        .onClick(() => {
          this.closeSwipeActions();
          this.showFeedback($r('app.string.auth_feature_later_feedback'));
        })
    }
  }

  @Builder
  SwipeActions(item: OtpItem) {
    Row({ space: AppSpacing.xs }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Image($r('app.media.action_edit'))
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.brand'))
          .draggable(false)
          .accessibilityLevel('no')
      }
      .width(68)
      .height('100%')
      .padding(0)
      .backgroundColor($r('app.color.brand_soft'))
      .borderRadius(AppRadius.medium)
      .accessibilityText($r('app.string.auth_edit_accessibility', item.issuer, item.account))
      .onClick(() => {
        this.openEditor(item.id);
      })
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Image($r('app.media.action_delete'))
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
          .fillColor(Color.White)
          .draggable(false)
          .accessibilityLevel('no')
      }
      .width(68)
      .height('100%')
      .padding(0)
      .backgroundColor($r('app.color.danger'))
      .borderRadius(AppRadius.medium)
      .accessibilityText($r('app.string.auth_delete_accessibility', item.issuer, item.account))
      .onClick(() => {
        this.confirmDelete(item.id);
      })
    }
    .height('100%')
    .width(152)
    .padding({ left: AppSpacing.xs })
  }

  @Builder
  EditorSheet() {
    Column({ space: AppSpacing.lg }) {
      Row({ space: AppSpacing.sm }) {
        Button($r('app.string.auth_cancel'))
          .type(ButtonType.Normal)
          .height(AppLayout.minimumTouchTarget)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.brand'))
          .onClick(() => {
            this.showEditor = false;
          })
        Text($r('app.string.auth_edit_title'))
          .fontSize(AppTypography.section)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
        Button($r('app.string.auth_save'))
          .type(ButtonType.Normal)
          .height(AppLayout.minimumTouchTarget)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.brand'))
          .enabled(validOtpPreviewLabels(this.editIssuer, this.editAccount))
          .onClick(() => {
            this.saveEdit();
          })
      }
      .width('100%')

      Scroll() {
        Column({ space: AppSpacing.md }) {
          Text($r('app.string.auth_issuer_label'))
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.text_secondary'))
          TextInput({ text: this.editIssuer, placeholder: $r('app.string.auth_issuer_label') })
            .maxLength(OTP_ISSUER_MAX_LENGTH)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_secondary'))
            .accessibilityText($r('app.string.auth_issuer_label'))
            .onChange((value: string) => {
              this.editIssuer = value;
            })
          Text($r('app.string.auth_account_label'))
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.text_secondary'))
          TextInput({ text: this.editAccount, placeholder: $r('app.string.auth_account_label') })
            .maxLength(OTP_ACCOUNT_MAX_LENGTH)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_secondary'))
            .accessibilityText($r('app.string.auth_account_label'))
            .onChange((value: string) => {
              this.editAccount = value;
            })
          this.DetailRow($r('app.string.auth_type_label'), this.editKind)
          this.DetailRow($r('app.string.auth_period_label'),
            $r('app.string.auth_period_value', `${this.editPeriod}`))
          Text($r('app.string.auth_edit_preview_notice'))
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(22)
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ bottom: AppSpacing.xxl })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding(AppSpacing.lg)
    .backgroundColor($r('app.color.surface'))
  }

  @Builder
  DetailRow(label: ResourceStr, value: ResourceStr) {
    Row({ space: AppSpacing.sm }) {
      Text(label)
        .fontSize(AppTypography.label)
        .fontColor($r('app.color.text_secondary'))
        .layoutWeight(1)
      Text(value)
        .fontSize(AppTypography.body)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .constraintSize({ minHeight: AppLayout.minimumTouchTarget })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: AppSpacing.md }) {
        Row({ space: AppSpacing.md }) {
          // Keep the original mock header, including its explicit preview subtitle.
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
            .bindMenu(this.AddMenu, { placement: Placement.BottomRight })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Text($r('app.string.auth_card_hint'))
          .fontSize(AppTypography.caption)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        if (this.items.length === 0) {
          Column() {
            EmptyState({
              symbol: '+',
              title: $r('app.string.auth_no_items_title'),
              message: $r('app.string.auth_no_items_message')
            })
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          List({ space: AppSpacing.sm, scroller: this.listScroller }) {
            ForEach(this.items, (item: OtpItem) => {
              ListItem() {
                OtpCard({
                  item: item,
                  onCopy: () => {
                    this.copyItem(item.id);
                  }
                })
              }
              .swipeAction({
                end: {
                  builder: () => { this.SwipeActions(item); },
                  // Reveal buttons only. Never delete at a swipe threshold.
                  actionAreaDistance: 0
                },
                edgeEffect: SwipeEdgeEffect.None,
                onOffsetChange: (offset: number) => {
                  if (Math.abs(offset) > 1) {
                    this.swipedItemId = item.id;
                  } else if (this.swipedItemId === item.id) {
                    this.swipedItemId = '';
                  }
                }
              })
            }, (item: OtpItem) => otpPreviewRenderKey(item))
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
        }
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: AppLayout.pageMaxWidth })
      .padding({
        left: AppLayout.compactPadding,
        right: AppLayout.compactPadding,
        top: AppSpacing.xl,
        bottom: AppSpacing.lg
      })

      if (this.feedbackVisible) {
        Text(this.feedbackText)
          .fontSize(AppTypography.label)
          .fontColor(Color.White)
          .padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.sm, bottom: AppSpacing.sm })
          .backgroundColor('#CC17191D')
          .borderRadius(AppRadius.pill)
          .margin({ bottom: AppSpacing.lg })
          .hitTestBehavior(HitTestMode.None)
          .transition(TransitionEffect.OPACITY)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
    .bindSheet($$this.showEditor, this.EditorSheet(), {
      height: SheetSize.LARGE,
      showClose: false,
      dragBar: false,
      backgroundColor: $r('app.color.surface')
    })
  }
}
