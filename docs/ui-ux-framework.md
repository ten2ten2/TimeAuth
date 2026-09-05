# UI architecture and regression checks

## Shell and interaction

The app begins with onboarding and a mock unlock screen. The main destinations are Authenticator, Vault, Generator and Settings. About is a secondary Settings destination. Compact devices use bottom navigation and 16 vp padding; expanded devices use a 216 vp rail with content constrained to 920 vp.

Use full-row touch targets for preferences and native `SelectDialog` for mutually exclusive choices. Selected values must update without navigating away. Preview-only features are status rows, not fake active toggles or dead navigation. Keep irreversible actions away from casual swipes, and do not expose secrets without explicit action.

## Settings state: why the previous labels were stale

`@Builder` arguments are passed by value by default. Passing `currentThemeLabel()` or `currentLanguageLabel()` into a multi-argument builder does not make the builder's `Text(value)` reactive. Changing the storage decorator or waiting for `flush()` does not address this rendering defect.

`PreferenceSelectionRow` now receives only static row identity. Its `Text` reads `this.themePreference` / `this.languagePreference` in its own render scope. Security toggles follow the same rule. Dialog indices are derived from these preferences instead of being maintained as duplicate state. Concurrent selections are blocked while a save is pending. Save failures restore the Preferences cache; application failures are surfaced and trigger a rollback attempt.

The durable source remains ArkData Preferences. `EntryAbility` applies native theme/language after `loadContent`. `Index` mounts the shell and the transient privacy cover. The cover's AppStorage booleans are in-memory UI notifications only, not another preference database.

## System language

`i18n.System.setAppPreferredLanguage('default')` is documented to take effect on a cold start. For immediate system following, TimeAuth keeps `SYSTEM` as its own persisted choice but resolves the current OS language with `getSystemLanguage()` before applying a concrete supported tag. It listens for `COMMON_EVENT_LOCALE_CHANGED` and also refreshes on foreground entry and launch. The native preferred-language and application-context language are updated consistently after the page loads.

Explicit selections never follow later OS changes. Chinese script/region variants map to `zh-Hans` or `zh-Hant`; unsupported languages map to English. Translation resources and reactive UI correctness are separate from functional device acceptance.

## Window protection

Capture-allowed foreground pages: Onboarding, Settings, About. All other pages default to sensitive. The separate recent-apps switch adds protection to allowed pages when the app is inactive; disabling it must not weaken sensitive-page protection.

The main window is obtained explicitly in `EntryAbility`, before loading content. API 20 `windowStageLifecycleEvent` supplies lifecycle state; main-window `windowEvent` supplies focus state. `onBackground()` supplies an additional ability-level guard. The old `windowStageEvent` focus listener has been removed.

Before awaiting a native privacy request, the root hides the real shell (including its accessibility descendants) behind an opaque cover. Preference dialogs close on coverage so they cannot remain above it. The shell stays mounted, preserving its route state. There is no fade exposing content during the transition. Native requests are serialized/coalesced and the acknowledged `isPrivacyMode` is checked. Callbacks from a destroyed window cannot change a replacement window's state.

When navigating from a sensitive page to an allowed page, privacy is not relaxed until a frame callback indicates that the replacement page has rendered. Restoration requires foreground, focus and RESUMED state. A native failure keeps sensitive content hidden and shows an error. Setup/frame errors are not silently reported as protection success.

**This is a software implementation, not device acceptance evidence.** An operating-system task snapshot can be cached or captured at a platform-specific point in the transition. Only a real device test establishes whether the content was hidden in that transition. The app card/icon may remain visible; only its content is intended to be blank/masked. `setSnapshotSkip` is system-only and is not used.

## Device acceptance checklist

Use a freshly installed build from the tested commit. Close the old running instance first; do not uninstall or clear user data just to test. Record device model, OS/API and build commit. Exercise both gesture navigation and the recent-apps button when the device supports them.

| Test | Expected result |
| --- | --- |
| Dark -> Light -> Dark without leaving Settings | Actual colors, right-side value and reopened dialog selection match after each change. |
| English -> 简体中文 -> 繁體中文 | Current page, navigation, value and reopened dialog language are consistent. |
| OS 简体中文; app English -> System | Switches to Simplified Chinese immediately; value remains “跟随系统”. |
| System selected; change OS language, then return | Follows the new OS language without killing the app. |
| Explicit English selected; change OS language | App remains English. |
| System selected; OS language not supported | App UI falls back to English. |
| Kill/reopen application | Saved choice and actual native appearance/language agree. |
| Hide preview ON; enter recents directly from Settings/About/Onboarding | Card content blank/masked or covered; no old page visible after transition. |
| Enter recents with a preference dialog open | Neither page nor dialog remains exposed. |
| Return from recents | No premature reveal; normal screen restores once active/resumed. |
| Foreground Settings with hide preview ON | Screenshots still work. Sensitive pages remain screenshot/recording-blocked. |
| Hide preview OFF; enter recents from a sensitive page | Sensitive content still protected. |
| Rapid app switching and page switching | No delayed “privacy off” request defeats the newer protection request. |

Current validation for this revision: mocked/source regression tests were run; HarmonyOS build, live ArkUI rendering and the device checklist remain to be run in DevEco/on hardware.

For remaining recents failures, inspect HiLog entries containing `[ScreenSecurity]`: they record page identity, lifecycle/focus/foreground, hide-preview setting, cover state, acknowledged privacy state and errors, without recording secrets. This distinguishes missing callbacks, failed native requests and a cached/compositor snapshot instead of guessing about timing again.

## Reference contracts

- OpenHarmony docs: `ui/state-management/arkts-builder.md`, by-value vs direct state reads.
- Localization Kit: `js-apis-i18n.md`, `setAppPreferredLanguage`.
- Ability Kit: `js-apis-inner-application-applicationContext.md`, `setLanguage` and `setColorMode` prerequisites.
- Basic Services Kit: `COMMON_EVENT_LOCALE_CHANGED` and `commonEventManager` subscription lifecycle.
- ArkUI: `Window.setWindowPrivacyMode`, `Window.on('windowEvent')`, `WindowStage.on('windowStageLifecycleEvent')`, and `FrameCallback.onIdle`.

The feature-status boundary is maintained in README rather than duplicated here. UI/security resources do not turn mock OTP/vault/generator content into real encrypted data.
