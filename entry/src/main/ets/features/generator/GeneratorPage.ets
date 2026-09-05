import { PageHeader } from '../../components/PageHeader';
import { AppLayout, AppSpacing, AppTypography } from '../../design/Tokens';
import { GeneratorMode } from './GeneratorCore';
import { GeneratorPanel } from './GeneratorPanel';
import { readGeneratorMode, saveGeneratorMode } from './GeneratorSettings';
import { getSelectedGeneratorMode, setSelectedGeneratorMode } from './GeneratorSession';

@Component
export struct GeneratorPage {
  @State private selectedIndex: number = 0;
  @State private preferencesFailed: boolean = false;
  private active: boolean = false;
  private selectionRequest: number = 0;

  aboutToAppear(): void {
    this.active = true;
    let mode: GeneratorMode | undefined = getSelectedGeneratorMode();
    if (mode === undefined) {
      const context = this.getUIContext().getHostContext();
      if (context !== undefined) {
        const saved = readGeneratorMode(context);
        mode = saved.mode;
        this.preferencesFailed = !saved.succeeded;
      } else {
        mode = GeneratorMode.PASSWORD;
        this.preferencesFailed = true;
      }
      setSelectedGeneratorMode(mode);
    }
    this.selectedIndex = mode === GeneratorMode.PASSPHRASE ? 1 : 0;
  }

  aboutToDisappear(): void {
    this.active = false;
    this.selectionRequest++;
  }

  private selectTab(index: number): void {
    if (index === this.selectedIndex) {
      return;
    }
    this.selectedIndex = index;
    const mode: GeneratorMode = index === 1 ? GeneratorMode.PASSPHRASE : GeneratorMode.PASSWORD;
    setSelectedGeneratorMode(mode);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.preferencesFailed = true;
      return;
    }
    const request: number = ++this.selectionRequest;
    saveGeneratorMode(context, mode).then((success: boolean) => {
      if (this.active && request === this.selectionRequest) {
        this.preferencesFailed = !success;
      }
    });
  }

  build() {
    Column() {
      Column({ space: AppSpacing.sm }) {
        PageHeader({ title: $r('app.string.generator_title'), subtitle: $r('app.string.generator_subtitle') })
        if (this.preferencesFailed) {
          Text($r('app.string.generator_preferences_failed'))
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.warning'))
            .width('100%')
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: AppLayout.pageMaxWidth })
      .padding({ left: AppLayout.compactPadding, right: AppLayout.compactPadding,
        top: AppSpacing.xl, bottom: AppSpacing.sm })

      Tabs({ barPosition: BarPosition.Start, index: this.selectedIndex }) {
        TabContent() {
          GeneratorPanel({ mode: GeneratorMode.PASSWORD, tabActive: this.selectedIndex === 0 })
        }
        .tabBar(SubTabBarStyle.of($r('app.string.generator_mode_password'))
          .indicator({ color: $r('app.color.brand') })
          .labelStyle({ selectedColor: $r('app.color.brand'), unselectedColor: $r('app.color.text_secondary') }))
        TabContent() {
          GeneratorPanel({ mode: GeneratorMode.PASSPHRASE, tabActive: this.selectedIndex === 1 })
        }
        .tabBar(SubTabBarStyle.of($r('app.string.generator_mode_passphrase'))
          .indicator({ color: $r('app.color.brand') })
          .labelStyle({ selectedColor: $r('app.color.brand'), unselectedColor: $r('app.color.text_secondary') }))
      }
      .barMode(BarMode.Fixed)
      .barHeight(56)
      .scrollable(false)
      .animationDuration(0)
      .onChange((index: number) => { this.selectTab(index); })
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
