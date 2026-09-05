import { PageHeader } from '../../components/PageHeader';
import { AppLayout, AppSpacing } from '../../design/Tokens';
import { GeneratorMode } from './GeneratorCore';
import { GeneratorPanel } from './GeneratorPanel';
import { getSelectedGeneratorMode, setSelectedGeneratorMode } from './GeneratorSession';

@Component
export struct GeneratorPage {
  @State private selectedIndex: number = 0;
  private active: boolean = false;

  aboutToAppear(): void {
    this.active = true;
    // Only this process remembers the last tab. A fresh app session starts on Password.
    const mode: GeneratorMode = getSelectedGeneratorMode();
    this.selectedIndex = mode === GeneratorMode.PIN ? 2 : mode === GeneratorMode.PASSPHRASE ? 1 : 0;
  }

  aboutToDisappear(): void {
    this.active = false;
  }

  private selectTab(index: number): void {
    if (!this.active || index < 0 || index > 2 || index === this.selectedIndex) {
      return;
    }
    this.selectedIndex = index;
    const mode: GeneratorMode = index === 2 ? GeneratorMode.PIN :
      index === 1 ? GeneratorMode.PASSPHRASE : GeneratorMode.PASSWORD;
    setSelectedGeneratorMode(mode);
  }

  build() {
    Column() {
      Column({ space: AppSpacing.sm }) {
        PageHeader({ title: $r('app.string.generator_title'), subtitle: $r('app.string.generator_subtitle') })
      }
      .width('100%')
      .constraintSize({ maxWidth: AppLayout.pageMaxWidth })
      .padding({ left: AppLayout.compactPadding, right: AppLayout.compactPadding,
        top: AppSpacing.xl, bottom: AppSpacing.sm })

      Tabs({ barPosition: BarPosition.Start, index: this.selectedIndex }) {
        TabContent() {
          GeneratorPanel({ mode: GeneratorMode.PASSWORD, selectedIndex: $selectedIndex })
        }
        .tabBar(SubTabBarStyle.of($r('app.string.generator_mode_password'))
          .indicator({ color: $r('app.color.brand') })
          .labelStyle({ selectedColor: $r('app.color.brand'), unselectedColor: $r('app.color.text_secondary') }))
        TabContent() {
          GeneratorPanel({ mode: GeneratorMode.PASSPHRASE, selectedIndex: $selectedIndex })
        }
        .tabBar(SubTabBarStyle.of($r('app.string.generator_mode_passphrase'))
          .indicator({ color: $r('app.color.brand') })
          .labelStyle({ selectedColor: $r('app.color.brand'), unselectedColor: $r('app.color.text_secondary') }))
        TabContent() {
          GeneratorPanel({ mode: GeneratorMode.PIN, selectedIndex: $selectedIndex })
        }
        .tabBar(SubTabBarStyle.of($r('app.string.generator_mode_pin'))
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
