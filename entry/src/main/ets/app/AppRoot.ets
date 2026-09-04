import { AppShell } from './AppShell';
import { OnboardingPage } from '../features/onboarding/OnboardingPage';
import { UnlockPage } from '../features/onboarding/UnlockPage';

enum PreviewStage {
  ONBOARDING = 0,
  LOCKED = 1,
  UNLOCKED = 2
}

@Component
export struct AppRoot {
  @State private stage: PreviewStage = PreviewStage.ONBOARDING;

  build() {
    if (this.stage === PreviewStage.ONBOARDING) {
      OnboardingPage({
        onComplete: () => {
          this.stage = PreviewStage.LOCKED;
        }
      })
    } else if (this.stage === PreviewStage.LOCKED) {
      UnlockPage({
        onUnlock: () => {
          this.stage = PreviewStage.UNLOCKED;
        }
      })
    } else {
      AppShell()
    }
  }
}

