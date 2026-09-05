import { AppShell } from './AppShell';
import { OnboardingPage } from '../features/onboarding/OnboardingPage';
import { UnlockPage } from '../features/onboarding/UnlockPage';
import { completeOnboarding, isOnboardingCompleted } from '../features/onboarding/OnboardingSettings';
import { ScreenSecurityPage, setCurrentScreen } from '../security/ScreenSecurityManager';

enum PreviewStage {
  ONBOARDING = 0,
  LOCKED = 1,
  UNLOCKED = 2
}

@Component
export struct AppRoot {
  @State private stage: PreviewStage = PreviewStage.ONBOARDING;
  @State private savingOnboarding: boolean = false;
  @State private onboardingSaveFailed: boolean = false;
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
    const context = this.getUIContext().getHostContext();
    this.stage = context !== undefined && isOnboardingCompleted(context) ?
      PreviewStage.LOCKED : PreviewStage.ONBOARDING;
    this.applyScreenSecurity(this.stage === PreviewStage.LOCKED ?
      ScreenSecurityPage.UNLOCK : ScreenSecurityPage.ONBOARDING);
  }

  private finishOnboarding(): void {
    if (this.savingOnboarding) {
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.onboardingSaveFailed = true;
      return;
    }
    this.savingOnboarding = true;
    this.onboardingSaveFailed = false;
    completeOnboarding(context).then((success: boolean) => {
      this.savingOnboarding = false;
      this.onboardingSaveFailed = !success;
      if (success) {
        this.applyScreenSecurity(ScreenSecurityPage.UNLOCK);
        this.stage = PreviewStage.LOCKED;
      }
    });
  }

  build() {
    Stack() {
      if (this.stage === PreviewStage.ONBOARDING) {
        Column() {
          OnboardingPage({
            saving: this.savingOnboarding,
            saveFailed: this.onboardingSaveFailed,
            onComplete: () => {
              this.finishOnboarding();
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
