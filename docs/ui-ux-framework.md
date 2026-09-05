# 时钥 / 時鑰 / TimeAuth UI/UX framework

## Product structure

The app starts with a three-step onboarding flow and a mock unlock state. After unlocking, the primary destinations are Authenticator, Password Vault, Generator, and Settings. Compact devices use bottom navigation; expanded devices use a side rail and a constrained content column.

Settings contains an About entry that opens a dedicated About screen while keeping Settings as the selected primary destination.

## Interaction principles

1. Keep secrets hidden unless the user performs an explicit action.
2. Do not bind destructive actions to a casual horizontal swipe.
3. Show expiration with text and shape as well as color.
4. Keep import and export available in the free product.
5. Do not present preview-only controls as working settings: unavailable items are status rows, not fake toggles or dead navigation targets.
6. Use full-row hit targets and clear selected/current-value feedback in settings lists.
7. Use HarmonyOS selection dialogs for mutually exclusive preference values such as Appearance and Language.

## Settings interaction

Appearance and Language use a compact settings-list pattern:

- the full row is clickable;
- the current value is shown on the right;
- a chevron indicates that tapping the row opens a selection surface;
- `SelectDialog` presents the mutually exclusive choices with a radio-style selected state;
- selecting an option updates the row immediately, persists the value, closes the dialog, and then applies the platform setting.

The row value uses component-local `@State` so the UI does not depend on Preview emulation of system services. Persistence is handled separately through ArkData Preferences.

## Theme and language state

Theme and language use the same architecture:

1. ArkData Preferences is the single persistent source of truth.
2. `EntryAbility.onCreate()` reads and applies stored values at application startup.
3. Settings reads the stored values when the page appears.
4. Component-local `@State` provides immediate selected-value feedback.
5. Platform APIs apply the actual color mode or preferred app language.

`PersistentStorage`, `AppStorage`, and duplicated preference initialization are intentionally not used for these preferences.

DevEco Studio Preview validates layout and interaction but is not considered proof that a system service has taken effect. Platform behavior must be verified with Run/Debug on an emulator or real device.

## Navigation icons

Primary navigation uses four monochrome local SVG assets instead of Unicode glyphs:

- Authenticator: clock;
- Password Vault: lock;
- Generator: magic wand/spark;
- Settings: sliders.

ArkUI applies active/inactive tint at runtime, providing consistent geometry, baseline alignment, and light/dark behavior.

## Screen security

The app requires HarmonyOS 6.0 / API 20 and uses `windowStageLifecycleEvent` for ordered window lifecycle handling.

Capture policy is centralized:

- capture allowed: Onboarding, Settings, About;
- capture blocked: Unlock, Authenticator, Password Vault, Password Generator.

The screenshot policy is not user-disableable. The separate Hide recent-app preview preference adds privacy mode while the window is paused or hidden, including on otherwise capture-allowed screens.

## Clipboard security

Preview OTP, password, and generated values are written to the real system clipboard. Clipboard data is restricted to the local device. When automatic clearing is enabled, TimeAuth schedules clearing after 30 seconds and cancels/guards the clear operation when newer clipboard data has been written by another app.

## Current Settings status

Implemented:

- Appearance;
- Language;
- Hide recent-app preview;
- automatic clipboard clearing;
- About.

Preview / not implemented:

- biometric unlock;
- encrypted backup and restore;
- authenticator import/export;
- encrypted persistent local OTP/password data.

## Responsive behavior

- Compact: bottom navigation and 16 vp page padding.
- Medium: bottom navigation and a wider centered content column.
- Expanded: 216 vp side rail and content limited to 920 vp.

## Still not implemented

- real OTP secret persistence and RFC 6238 generation;
- cryptographically secure password generation;
- encrypted password-vault persistence;
- biometric/device-credential unlock;
- camera/photo QR import;
- Steam account enrollment or session handling;
- encrypted backup/restore and authenticator import/export;
- cloud sync.
