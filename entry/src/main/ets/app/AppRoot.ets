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
  private stageTransition: TransitionEffect = TransitionEffect.OPACITY
    .animation({ duration: 180, curve: Curve.EaseOut })
    .combine(TransitionEffect.translate({ y: 6 }));

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
    Stack() {
      if (this.stage === PreviewStage.ONBOARDING) {
        Column() {
          OnboardingPage({
            onComplete: () => {
              this.applyScreenSecurity(ScreenSecurityPage.UNLOCK);
              this.stage = PreviewStage.LOCKED;
            }
          })
        }
        .width('100%')
        .height('100%')
        .transition(this.stageTransition)
      } else if (this.stage === PreviewStage.LOCKED) {
        Column() {
          UnlockPage({
            onUnlock: () => {
              this.applyScreenSecurity(ScreenSecurityPage.AUTHENTICATOR);
              this.stage = PreviewStage.UNLOCKED;
            }
          })
        }
        .width('100%')
        .height('100%')
        .transition(this.stageTransition)
      } else {
        Column() {
          AppShell()
        }
        .width('100%')
        .height('100%')
        .transition(this.stageTransition)
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}
