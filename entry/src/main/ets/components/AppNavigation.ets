import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../design/Tokens';

@Component
export struct BottomNavigation {
  @Prop selectedIndex: number = 0;
  onSelect: (index: number) => void = () => {};

  @Builder
  NavItem(index: number, symbol: string, label: string) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: AppSpacing.xxs }) {
        Text(symbol)
          .fontSize(20)
          .fontWeight(this.selectedIndex === index ? FontWeight.Bold : FontWeight.Regular)
          .fontColor(this.selectedIndex === index ? $r('app.color.brand') : $r('app.color.text_secondary'))
        Text(label)
          .fontSize(AppTypography.caption)
          .fontWeight(this.selectedIndex === index ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.selectedIndex === index ? $r('app.color.brand') : $r('app.color.text_secondary'))
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .height(56)
    }
    .layoutWeight(1)
    .height(64)
    .padding(0)
    .backgroundColor(this.selectedIndex === index ? $r('app.color.brand_soft') : Color.Transparent)
    .borderRadius(AppRadius.medium)
    .accessibilityText(label)
    .onClick(() => {
      this.onSelect(index);
    })
  }

  build() {
    Row({ space: AppSpacing.xs }) {
      this.NavItem(0, '码', '验证器')
      this.NavItem(1, '钥', '密码库')
      this.NavItem(2, '生', '生成器')
      this.NavItem(3, '设', '设置')
    }
    .width('100%')
    .height(80)
    .padding({ left: AppSpacing.sm, right: AppSpacing.sm, top: AppSpacing.xs, bottom: AppSpacing.xs })
    .backgroundColor($r('app.color.surface'))
    .border({ width: { top: 1 }, color: $r('app.color.border') })
  }
}

@Component
export struct NavigationRail {
  @Prop selectedIndex: number = 0;
  onSelect: (index: number) => void = () => {};

  @Builder
  RailItem(index: number, symbol: string, label: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: AppSpacing.sm }) {
        Text(symbol)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.selectedIndex === index ? $r('app.color.brand') : $r('app.color.text_secondary'))
          .width(28)
        Text(label)
          .fontSize(AppTypography.body)
          .fontWeight(this.selectedIndex === index ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.selectedIndex === index ? $r('app.color.brand') : $r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
      }
      .width('100%')
      .height(52)
      .padding({ left: AppSpacing.md, right: AppSpacing.md })
    }
    .width('100%')
    .height(52)
    .padding(0)
    .backgroundColor(this.selectedIndex === index ? $r('app.color.brand_soft') : Color.Transparent)
    .borderRadius(AppRadius.medium)
    .onClick(() => {
      this.onSelect(index);
    })
  }

  build() {
    Column({ space: AppSpacing.xs }) {
      Row({ space: AppSpacing.sm }) {
        Text('T')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .width(42)
          .height(42)
          .backgroundColor($r('app.color.brand'))
          .borderRadius(AppRadius.medium)
        Text('TimeAuth')
          .fontSize(AppTypography.section)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .padding({ bottom: AppSpacing.lg })

      this.RailItem(0, '码', '验证器')
      this.RailItem(1, '钥', '密码库')
      this.RailItem(2, '生', '生成器')
      this.RailItem(3, '设', '设置')

      Blank()

      Text('UI/UX PREVIEW')
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_secondary'))
        .padding({ left: AppSpacing.md })
        .width('100%')
    }
    .width(AppLayout.railWidth)
    .height('100%')
    .padding(AppSpacing.md)
    .backgroundColor($r('app.color.surface'))
    .border({ width: { right: 1 }, color: $r('app.color.border') })
    .alignItems(HorizontalAlign.Start)
  }
}

