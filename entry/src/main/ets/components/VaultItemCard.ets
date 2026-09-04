import { AppRadius, AppSpacing, AppTypography } from '../design/Tokens';
import { VaultItem, VaultItemKind } from '../models/AppModels';

@Component
export struct VaultItemCard {
  @Prop item: VaultItem;
  @State isRevealed: boolean = false;
  onCopyPreview: (title: string) => void = () => {};

  build() {
    Column({ space: AppSpacing.sm }) {
      Row({ space: AppSpacing.sm }) {
        Text(this.item.title.substring(0, 1).toUpperCase())
          .fontSize(AppTypography.section)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .width(48)
          .height(48)
          .backgroundColor(this.item.accentColor)
          .borderRadius(AppRadius.medium)

        Column({ space: AppSpacing.xxs }) {
          Row({ space: AppSpacing.xs }) {
            Text(this.item.title)
              .fontSize(AppTypography.body)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (this.item.linkedOtpIssuer !== undefined) {
              Text($r('app.string.vault_linked_code'))
                .fontSize(10)
                .fontColor($r('app.color.success'))
            }
          }

          Text(this.item.username)
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('›')
          .fontSize(26)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      if (this.item.kind === VaultItemKind.LOGIN) {
        Divider().color($r('app.color.border'))

        Row({ space: AppSpacing.sm }) {
          Text(this.isRevealed ? this.item.passwordPreview : '••••••••••••')
            .fontSize(AppTypography.label)
            .fontFamily('monospace')
            .fontColor($r('app.color.text_secondary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Button(this.isRevealed ? $r('app.string.common_hide') : $r('app.string.common_show'))
            .type(ButtonType.Normal)
            .height(36)
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.brand'))
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.isRevealed = !this.isRevealed;
            })

          Button($r('app.string.common_copy'))
            .type(ButtonType.Capsule)
            .height(36)
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.brand'))
            .backgroundColor($r('app.color.brand_soft'))
            .onClick(() => {
              this.onCopyPreview(this.item.title);
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(AppSpacing.md)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(AppRadius.large)
    .border({ width: 1, color: $r('app.color.border') })
  }
}
