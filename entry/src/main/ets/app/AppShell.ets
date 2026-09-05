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
    this.showAbout = false;
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      setCurrentScreen(context, this.securityPageForIndex(index));
    }
    this.selectedIndex = index;
  }

  private openAbout(): void {
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
      AuthenticatorPage()
    } else if (this.selectedIndex === 1) {
      PasswordVaultPage()
    } else if (this.selectedIndex === 2) {
      GeneratorPage()
    } else if (this.showAbout) {
      AboutPage({
        onBack: () => {
          this.closeAbout();
        }
      })
    } else {
      SettingsPage({
        onOpenAbout: () => {
          this.openAbout();
        }
      })
    }
  }

  @Builder
  CompactLayout() {
    Column() {
      Column() {
        this.CurrentPage()
      }
      .layoutWeight(1)
      .width('100%')

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

      Column() {
        this.CurrentPage()
      }
      .layoutWeight(1)
      .height('100%')
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
