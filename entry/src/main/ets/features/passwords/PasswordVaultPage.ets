import { EmptyState } from '../../components/EmptyState';
import { PageHeader } from '../../components/PageHeader';
import { SearchField } from '../../components/SearchField';
import { VaultItemCard } from '../../components/VaultItemCard';
import { mockRepository } from '../../data/MockRepository';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';
import { VaultItem } from '../../models/AppModels';

@Component
export struct PasswordVaultPage {
  @State private searchText: string = '';
  @State private showAddMenu: boolean = false;
  @State private feedbackMessage: string = '';
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

  private showFeedback(message: string): void {
    this.feedbackMessage = message;
    setTimeout(() => {
      this.feedbackMessage = '';
    }, 2200);
  }

  @Builder
  AddMenu() {
    Row({ space: AppSpacing.sm }) {
      Button('＋ 登录账号')
        .type(ButtonType.Capsule)
        .height(48)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.brand'))
        .layoutWeight(1)
        .onClick(() => {
          this.showFeedback('新建登录账号：将在本地密码库阶段接入');
          this.showAddMenu = false;
        })
      Button('＋ 安全笔记')
        .type(ButtonType.Capsule)
        .height(48)
        .fontColor($r('app.color.brand'))
        .backgroundColor($r('app.color.brand_soft'))
        .layoutWeight(1)
        .onClick(() => {
          this.showFeedback('新建安全笔记：将在本地密码库阶段接入');
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
              title: '密码库',
              subtitle: '独立于验证码保险库；显示内容为 Mock 数据。'
            })
              .layoutWeight(1)

            Button('+')
              .type(ButtonType.Circle)
              .width(AppLayout.minimumTouchTarget)
              .height(AppLayout.minimumTouchTarget)
              .fontSize(28)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.brand'))
              .accessibilityText('新建密码项目')
              .onClick(() => {
                this.showAddMenu = !this.showAddMenu;
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          SearchField({ value: $searchText, placeholder: '搜索登录账号或安全笔记' })

          if (this.showAddMenu) {
            this.AddMenu()
          }

          Row({ space: AppSpacing.sm }) {
            Text('全部')
              .fontSize(AppTypography.label)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.brand'))
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor($r('app.color.brand_soft'))
              .borderRadius(AppRadius.pill)
            Text('收藏')
              .fontSize(AppTypography.label)
              .fontColor($r('app.color.text_secondary'))
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            Text('安全笔记')
              .fontSize(AppTypography.label)
              .fontColor($r('app.color.text_secondary'))
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          }
          .width('100%')

          if (this.filteredItems().length === 0) {
            EmptyState({
              symbol: '⌕',
              title: '没有匹配的项目',
              message: '尝试搜索其他名称或用户名。'
            })
          } else {
            ForEach(this.filteredItems(), (item: VaultItem) => {
              VaultItemCard({
                item: item,
                onCopyPreview: (title: string) => {
                  this.showFeedback(`${title}：模拟复制成功，未写入系统剪贴板`);
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

      if (this.feedbackMessage.length > 0) {
        Text(this.feedbackMessage)
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

