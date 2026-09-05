import { EmptyState } from '../../components/EmptyState';
import { PageHeader } from '../../components/PageHeader';
import { SearchField } from '../../components/SearchField';
import { VaultItemCard } from '../../components/VaultItemCard';
import { mockRepository } from '../../data/MockRepository';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';
import { VaultItem } from '../../models/AppModels';
import { copySensitiveText } from '../../security/SecureClipboard';

@Component
export struct PasswordVaultPage {
  @State private searchText: string = '';
  @State private showAddMenu: boolean = false;
  @State private feedbackVisible: boolean = false;
  @State private copyFeedback: boolean = false;
  @State private copySucceeded: boolean = true;
  private items: VaultItem[] = mockRepository.getVaultItems();

  private filteredItems(): VaultItem[] {
    const normalizedQuery: string = this.searchText.trim().toLowerCase();
    if (normalizedQuery.length === 0) {
      return this.items;
    }
    return this.items.filter((item: VaultItem) =>
      item.title.toLowerCase().includes(normalizedQuery) ||
      item.username.toLowerCase().includes(normalizedQuery));
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
    Row({ space: AppSpacing.sm }) {
      Button($r('app.string.vault_add_login'))
        .type(ButtonType.Capsule)
        .height(48)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.brand'))
        .layoutWeight(1)
        .onClick(() => {
          this.showFeedback(false);
          this.showAddMenu = false;
        })
      Button($r('app.string.vault_add_note'))
        .type(ButtonType.Capsule)
        .height(48)
        .fontColor($r('app.color.brand'))
        .backgroundColor($r('app.color.brand_soft'))
        .layoutWeight(1)
        .onClick(() => {
          this.showFeedback(false);
          this.showAddMenu = false;
        })
    }
    .width('100%')
    .padding(AppSpacing.sm)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(AppRadius.large)
    .border({ width: 1, color: $r('app.color.border') })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: AppSpacing.md }) {
          Row({ space: AppSpacing.md }) {
            PageHeader({
              title: $r('app.string.vault_title'),
              subtitle: $r('app.string.vault_subtitle')
            })
              .layoutWeight(1)

            Button('+')
              .type(ButtonType.Circle)
              .width(AppLayout.minimumTouchTarget)
              .height(AppLayout.minimumTouchTarget)
              .fontSize(28)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.brand'))
              .accessibilityText($r('app.string.vault_new_item_accessibility'))
              .onClick(() => {
                this.showAddMenu = !this.showAddMenu;
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          SearchField({ value: $searchText, placeholder: $r('app.string.vault_search_placeholder') })

          if (this.showAddMenu) {
            this.AddMenu()
          }

          Row({ space: AppSpacing.sm }) {
            Text($r('app.string.vault_filter_all'))
              .fontSize(AppTypography.label)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.brand'))
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor($r('app.color.brand_soft'))
              .borderRadius(AppRadius.pill)
            Text($r('app.string.vault_filter_favorites'))
              .fontSize(AppTypography.label)
              .fontColor($r('app.color.text_secondary'))
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            Text($r('app.string.vault_filter_notes'))
              .fontSize(AppTypography.label)
              .fontColor($r('app.color.text_secondary'))
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          }
          .width('100%')

          if (this.filteredItems().length === 0) {
            EmptyState({
              symbol: '⌕',
              title: $r('app.string.vault_empty_title'),
              message: $r('app.string.vault_empty_message')
            })
          } else {
            ForEach(this.filteredItems(), (item: VaultItem) => {
              VaultItemCard({
                item: item,
                onCopyPassword: (password: string, title: string) => {
                  const context = this.getUIContext().getHostContext();
                  if (context === undefined) {
                    this.showFeedback(true, false);
                    return;
                  }
                  copySensitiveText(context, password).then((success: boolean) => {
                    this.showFeedback(true, success);
                  });
                }
              })
            }, (item: VaultItem) => item.id)
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

      if (this.feedbackVisible) {
        Text(this.copyFeedback ?
          (this.copySucceeded ? $r('app.string.security_copy_success') : $r('app.string.security_copy_failed')) :
          $r('app.string.vault_feature_later_feedback'))
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
