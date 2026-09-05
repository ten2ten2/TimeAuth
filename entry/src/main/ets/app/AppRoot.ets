import { AppShell } from './AppShell';
import { OnboardingPage } from '../features/onboarding/OnboardingPage';
import { UnlockPage } from '../features/onboarding/UnlockPage';
import { ScreenSecurityPage, setCurrentScreen } from '../security/ScreenSecurityManager';

enum PreviewStage {
  ONBOARDING = 0,
  LOCKED = 1,
  UNLOCKED = 2
}

@Component
export struct AppRoot {
  @State private stage: PreviewStage = PreviewStage.ONBOARDING;

  private applyScreenSecurity(page: ScreenSecurityPage): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      setCurrentScreen(context, page);
    }
  }

  aboutToAppear(): void {
    this.applyScreenSecurity(ScreenSecurityPage.ONBOARDING);
  }

  build() {
    if (this.stage === PreviewStage.ONBOARDING) {
      OnboardingPage({
        onComplete: () => {
          this.applyScreenSecurity(ScreenSecurityPage.UNLOCK);
          this.stage = PreviewStage.LOCKED;
        }
      })
    } else if (this.stage === PreviewStage.LOCKED) {
      UnlockPage({
        onUnlock: () => {
          this.applyScreenSecurity(ScreenSecurityPage.AUTHENTICATOR);
          this.stage = PreviewStage.UNLOCKED;
        }
      })
    } else {
      AppShell()
    }
  }
}

