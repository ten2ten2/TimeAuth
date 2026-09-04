import { BottomNavigation, NavigationRail } from '../components/AppNavigation';
import { AuthenticatorPage } from '../features/authenticator/AuthenticatorPage';
import { GeneratorPage } from '../features/generator/GeneratorPage';
import { PasswordVaultPage } from '../features/passwords/PasswordVaultPage';
import { SettingsPage } from '../features/settings/SettingsPage';

@Component
export struct AppShell {
  @State private selectedIndex: number = 0;
  @State private currentBreakpoint: string = 'xs';

  private isExpanded(): boolean {
    return this.currentBreakpoint === 'md' ||
      this.currentBreakpoint === 'lg' ||
      this.currentBreakpoint === 'xl' ||
      this.currentBreakpoint === 'xxl';
  }

  @Builder
  CurrentPage() {
    if (this.selectedIndex === 0) {
      AuthenticatorPage()
    } else if (this.selectedIndex === 1) {
      PasswordVaultPage()
    } else if (this.selectedIndex === 2) {
      GeneratorPage()
    } else {
      SettingsPage()
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
          this.selectedIndex = index;
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
          this.selectedIndex = index;
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

