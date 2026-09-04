import { EmptyState } from '../../components/EmptyState';
import { OtpCard } from '../../components/OtpCard';
import { PageHeader } from '../../components/PageHeader';
import { SearchField } from '../../components/SearchField';
import { mockRepository } from '../../data/MockRepository';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';
import { OtpItem } from '../../models/AppModels';

@Component
export struct AuthenticatorPage {
  @State private searchText: string = '';
  @State private showAddMenu: boolean = false;
  @State private feedbackMessage: string = '';
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

  private showFeedback(message: string): void {
    this.feedbackMessage = message;
    setTimeout(() => {
      this.feedbackMessage = '';
    }, 2200);
  }

  @Builder
  AddMenu() {
    Column({ space: AppSpacing.xs }) {
      Row() {
        Text('添加验证码')
          .fontSize(AppTypography.section)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Button('关闭')
          .type(ButtonType.Normal)
          .height(40)
          .fontColor($r('app.color.brand'))
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showAddMenu = false;
          })
      }
      .width('100%')

      this.AddMenuRow('▣', '扫描二维码', '在需要时申请相机权限')
      this.AddMenuRow('图', '从相册识别', '选择二维码图片')
      this.AddMenuRow('文', '手动输入', '输入服务名称和密钥')
      this.AddMenuRow('S', 'Steam 验证码', '导入已有共享密钥')
    }
    .width('100%')
    .padding(AppSpacing.md)
    .backgroundColor($r('app.color.surface_elevated'))
    .borderRadius(AppRadius.large)
    .border({ width: 1, color: $r('app.color.border') })
  }

  @Builder
  AddMenuRow(symbol: string, title: string, detail: string) {
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
      this.showFeedback(`${title}：将在后续功能阶段接入`);
      this.showAddMenu = false;
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: AppSpacing.md }) {
          Row({ space: AppSpacing.md }) {
            PageHeader({
              title: '验证器',
              subtitle: '所有内容均为 UI 预览数据，当前不会生成或保存真实验证码。'
            })
              .layoutWeight(1)

            Button('+')
              .type(ButtonType.Circle)
              .width(AppLayout.minimumTouchTarget)
              .height(AppLayout.minimumTouchTarget)
              .fontSize(28)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.brand'))
              .accessibilityText('添加验证码')
              .onClick(() => {
                this.showAddMenu = !this.showAddMenu;
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          SearchField({ value: $searchText, placeholder: '搜索服务或账号' })

          if (this.showAddMenu) {
            this.AddMenu()
          }

          if (this.filteredItems().length === 0) {
            EmptyState({
              symbol: '⌕',
              title: '没有匹配的验证码',
              message: '尝试搜索其他服务名称或账号。'
            })
          } else {
            ForEach(this.filteredItems(), (item: OtpItem) => {
              OtpCard({
                item: item,
                onCopy: (code: string, issuer: string) => {
                  this.showFeedback(`${issuer}：模拟复制成功，未写入系统剪贴板`);
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

      if (this.feedbackMessage.length > 0) {
        Text(this.feedbackMessage)
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

