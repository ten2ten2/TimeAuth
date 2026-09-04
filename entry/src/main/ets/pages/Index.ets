import { AppRoot } from '../app/AppRoot';
import { applyLanguagePreference, LANGUAGE_PREFERENCE_STORAGE_KEY } from '../localization/LanguageManager';
import { LanguagePreference } from '../models/AppModels';

PersistentStorage.persistProp(LANGUAGE_PREFERENCE_STORAGE_KEY, LanguagePreference.SYSTEM);

@Entry
@Component
struct Index {
  @StorageLink('timeauth.languagePreference') private languagePreference: LanguagePreference =
    LanguagePreference.SYSTEM;

  aboutToAppear(): void {
    applyLanguagePreference(this.languagePreference);
  }

  build() {
    AppRoot()
      .width('100%')
      .height('100%')
  }
}
