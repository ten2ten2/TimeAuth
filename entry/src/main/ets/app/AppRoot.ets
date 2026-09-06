import { AppShell } from './AppShell';
import { OnboardingPage } from '../features/onboarding/OnboardingPage';
import { UnlockPage } from '../features/onboarding/UnlockPage';
import { completeOnboarding, isOnboardingCompleted } from '../features/onboarding/OnboardingSettings';
import { ScreenSecurityPage, setCurrentScreen } from '../security/ScreenSecurityManager';

enum AppStage {
  ONBOARDING = 0,
  APPLICATION = 1
}

@Component
export struct AppRoot {
  @State private stage: AppStage = AppStage.ONBOARDING;
  @State private savingOnboarding: boolean = false;
  @State private onboardingSaveFailed: boolean = false;
  @StorageLink('timeauth.sessionUnlocked') @Watch('onSessionChanged') private unlocked: boolean = false;

  private applyScreenSecurity(page: ScreenSecurityPage): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) { setCurrentScreen(context, page); }
  }

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    this.stage = context !== undefined && isOnboardingCompleted(context) ?
      AppStage.APPLICATION : AppStage.ONBOARDING;
    this.applyScreenSecurity(this.stage === AppStage.APPLICATION ?
      (this.unlocked ? ScreenSecurityPage.AUTHENTICATOR : ScreenSecurityPage.UNLOCK) : ScreenSecurityPage.ONBOARDING);
  }

  private onSessionChanged(): void {
    if (!this.unlocked && this.stage === AppStage.APPLICATION) {
      this.applyScreenSecurity(ScreenSecurityPage.UNLOCK);
    }
    // AppShell restores the selected page's policy whenever the session becomes available.
  }

  private async finishOnboarding(): Promise<void> {
    if (this.savingOnboarding) { return; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.onboardingSaveFailed = true; return; }
    this.savingOnboarding = true;
    this.onboardingSaveFailed = false;
    const success: boolean = await completeOnboarding(context);
    this.savingOnboarding = false;
    this.onboardingSaveFailed = !success;
    if (success) {
      this.applyScreenSecurity(this.unlocked ? ScreenSecurityPage.AUTHENTICATOR : ScreenSecurityPage.UNLOCK);
      this.stage = AppStage.APPLICATION;
    }
  }

  build() {
    Stack() {
      if (this.stage === AppStage.ONBOARDING) {
        OnboardingPage({ saving: this.savingOnboarding, saveFailed: this.onboardingSaveFailed,
          onComplete: () => { this.finishOnboarding(); } })
      } else {
        // App content remains mounted for native callbacks, but is inaccessible whenever the transient session is closed.
        AppShell()
          .visibility(this.unlocked ? Visibility.Visible : Visibility.Hidden)
          .enabled(this.unlocked)
        if (!this.unlocked) {
          UnlockPage()
        }
      }
    }
    .width('100%').height('100%').clip(true)
  }
}
