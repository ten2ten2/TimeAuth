import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const PREFERENCES_NAME: string = 'timeauth_preferences';
const COMPLETED_KEY: string = 'timeauth.onboarding.completed.v1';

export function isOnboardingCompleted(context: common.Context): boolean {
  try {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
    return store.getSync(COMPLETED_KEY, false) === true;
  } catch (_) {
    return false;
  }
}

export async function completeOnboarding(context: common.Context): Promise<boolean> {
  try {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
    const previous: boolean = store.getSync(COMPLETED_KEY, false) === true;
    try {
      store.putSync(COMPLETED_KEY, true);
      await store.flush();
      return true;
    } catch (_) {
      // Do not let a failed disk write look completed in the in-process preferences cache.
      store.putSync(COMPLETED_KEY, previous);
      return false;
    }
  } catch (_) {
    return false;
  }
}
