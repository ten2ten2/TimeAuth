import { BottomNavigation, NavigationRail } from '../components/AppNavigation';
import { AuthenticatorPage } from '../features/authenticator/AuthenticatorPage';
import { GeneratorPage } from '../features/generator/GeneratorPage';
import { PasswordVaultPage } from '../features/passwords/PasswordVaultPage';
import { AboutPage } from '../features/settings/AboutPage';
import { SettingsPage } from '../features/settings/SettingsPage';
import { ScreenSecurityPage, setCurrentScreen } from '../security/ScreenSecurityManager';

@Component
export struct AppShell {
  @State private selectedIndex: number = 0;
  @State private currentBreakpoint: string = 'xs';
  @State private showAbout: boolean = false;
  private contentTransitionEffect: TransitionEffect = TransitionEffect.OPACITY
    .animation({ duration: 160, curve: Curve.EaseOut })
    .combine(TransitionEffect.translate({ y: 6 }));

  private isExpanded(): boolean {
    return this.currentBreakpoint === 'md' ||
      this.currentBreakpoint === 'lg' ||
      this.currentBreakpoint === 'xl' ||
      this.currentBreakpoint === 'xxl';
  }

  private securityPageForIndex(index: number): ScreenSecurityPage {
    if (index === 0) {
      return ScreenSecurityPage.AUTHENTICATOR;
    }
    if (index === 1) {
      return ScreenSecurityPage.VAULT;
    }
    if (index === 2) {
      return ScreenSecurityPage.GENERATOR;
    }
    return ScreenSecurityPage.SETTINGS;
  }

  private selectPage(index: number): void {
    if (index === this.selectedIndex && !this.showAbout) {
      return;
    }
    this.showAbout = false;
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      setCurrentScreen(context, this.securityPageForIndex(index));
    }
    this.selectedIndex = index;
  }

  private openAbout(): void {
    if (this.showAbout) {
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      setCurrentScreen(context, ScreenSecurityPage.ABOUT);
    }
    this.showAbout = true;
  }

  private closeAbout(): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      setCurrentScreen(context, ScreenSecurityPage.SETTINGS);
    }
    this.showAbout = false;
  }

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      setCurrentScreen(context, this.securityPageForIndex(this.selectedIndex));
    }
  }

  @Builder
  CurrentPage() {
    if (this.selectedIndex === 0) {
      Column() {
        AuthenticatorPage()
      }
      .width('100%')
      .height('100%')
      .transition(this.contentTransitionEffect)
    } else if (this.selectedIndex === 1) {
      Column() {
        PasswordVaultPage()
      }
      .width('100%')
      .height('100%')
      .transition(this.contentTransitionEffect)
    } else if (this.selectedIndex === 2) {
      Column() {
        GeneratorPage()
      }
      .width('100%')
      .height('100%')
      .transition(this.contentTransitionEffect)
    } else if (this.showAbout) {
      Column() {
        AboutPage({
          onBack: () => {
            this.closeAbout();
          }
        })
      }
      .width('100%')
      .height('100%')
      .transition(this.contentTransitionEffect)
    } else {
      Column() {
        SettingsPage({
          onOpenAbout: () => {
            this.openAbout();
          }
        })
      }
      .width('100%')
      .height('100%')
      .transition(this.contentTransitionEffect)
    }
  }

  @Builder
  CompactLayout() {
    Column() {
      Stack() {
        this.CurrentPage()
      }
      .layoutWeight(1)
      .width('100%')
      .clip(true)

      BottomNavigation({
        selectedIndex: this.selectedIndex,
        onSelect: (index: number) => {
          this.selectPage(index);
        }
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  ExpandedLayout() {
    Row() {
      NavigationRail({
        selectedIndex: this.selectedIndex,
        onSelect: (index: number) => {
          this.selectPage(index);
        }
      })

      Stack() {
        this.CurrentPage()
      }
      .layoutWeight(1)
      .height('100%')
      .clip(true)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    GridRow({
      columns: 12,
      breakpoints: {
        value: ['600vp', '840vp'],
        reference: BreakpointsReference.WindowSize
      }
    }) {
      GridCol({ span: 12 }) {
        if (this.isExpanded()) {
          this.ExpandedLayout()
        } else {
          this.CompactLayout()
        }
      }
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .onBreakpointChange((breakpoint: string) => {
      this.currentBreakpoint = breakpoint;
    })
  }
}
