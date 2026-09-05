import { AppRoot } from '../app/AppRoot';
import { readThemePreference, THEME_PREFERENCE_STORAGE_KEY } from '../design/ThemeManager';
import { applyLanguagePreference, LANGUAGE_PREFERENCE_STORAGE_KEY } from '../localization/LanguageManager';
import { LanguagePreference, ThemePreference } from '../models/AppModels';

PersistentStorage.persistProp(LANGUAGE_PREFERENCE_STORAGE_KEY, LanguagePreference.SYSTEM);
AppStorage.setOrCreate(THEME_PREFERENCE_STORAGE_KEY, ThemePreference.SYSTEM);

@Entry
@Component
struct Index {
  @StorageLink('timeauth.languagePreference') private languagePreference: LanguagePreference =
    LanguagePreference.SYSTEM;
  @StorageLink('timeauth.themePreference') private themePreference: ThemePreference = ThemePreference.SYSTEM;

  aboutToAppear(): void {
    applyLanguagePreference(this.languagePreference);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    this.themePreference = readThemePreference(context);
  }

  build() {
    Column() {
      AppRoot()
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
