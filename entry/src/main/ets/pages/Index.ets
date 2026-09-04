import { AppRoot } from '../app/AppRoot';
import { colorModeForTheme, readThemePreference, THEME_PREFERENCE_STORAGE_KEY } from '../design/ThemeManager';
import { applyLanguagePreference, LANGUAGE_PREFERENCE_STORAGE_KEY } from '../localization/LanguageManager';
import { LanguagePreference, ThemePreference } from '../models/AppModels';

PersistentStorage.persistProp(LANGUAGE_PREFERENCE_STORAGE_KEY, LanguagePreference.SYSTEM);
PersistentStorage.persistProp(THEME_PREFERENCE_STORAGE_KEY, ThemePreference.SYSTEM);

@Entry
@Component
struct Index {
  @StorageLink('timeauth.languagePreference') private languagePreference: LanguagePreference =
    LanguagePreference.SYSTEM;
  @StorageLink('timeauth.themePreference') private themePreference: ThemePreference = ThemePreference.SYSTEM;

  aboutToAppear(): void {
    applyLanguagePreference(this.languagePreference);
    const storedTheme: ThemePreference = readThemePreference(getContext(this));
    this.themePreference = storedTheme;
    getContext(this).getApplicationContext().setColorMode(colorModeForTheme(storedTheme));
  }

  build() {
    AppRoot()
      .width('100%')
      .height('100%')
  }
}
