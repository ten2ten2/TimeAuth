# TimeAuth UI / UX notes

## Navigation and layout

Primary destinations are Authenticator, Vault, Generator and Settings. About is a secondary Settings page.

- Compact layouts use bottom navigation and 16 vp page padding.
- Expanded layouts use a 216 vp side rail and a constrained content column.
- Primary navigation icons use monochrome local SVG assets with theme-aware tinting.

## Settings interaction

Appearance and Language use full-row `SelectDialog` selection:

- current value is shown on the right;
- the whole row is clickable;
- choices are mutually exclusive;
- the selected value updates immediately in the row;
- persistence and native application happen separately.

Preview-only features are status rows rather than fake toggles or dead navigation items.

ArkData Preferences is the persistent source of truth for theme, language and security settings. UI components use local reactive state for rendering; the application applies native configuration after content is loaded.

## Language behavior

Supported application languages:

- Follow system
- Simplified Chinese (`zh-Hans`)
- Traditional Chinese, Taiwan usage (`zh-Hant`)
- English (`en`)

English is the base resource and fallback for unsupported system languages. The Traditional Chinese resource uses Taiwan terminology and wording rather than a generic Mainland-to-Traditional conversion.

When Follow system is selected, the stored preference remains `SYSTEM`. TimeAuth resolves the current OS language and refreshes it on startup, foreground entry and locale-change events. Explicit language selections do not follow later OS language changes.

## About

About shows the installed application version, privacy/security information, proprietary-license information, platform notices and the minimum supported HarmonyOS version. It does not expose a source-code repository or public-source link.

Privacy and license details use ArkUI `CustomContentDialog`, keeping the HarmonyOS dialog shell, motion and button layout while allowing longer scrollable text. The application is currently proprietary and closed source; platform and third-party components remain under their own terms.

## Screen security

Foreground capture policy:

- allowed: Onboarding, Settings, About;
- protected: Unlock, Authenticator, Vault, Generator and unknown screens.

The recent-app preview switch adds protection to capture-allowed pages while the app is inactive. Sensitive pages stay protected regardless of that switch.

Protection uses:

- the actual main window;
- API 20 `windowStageLifecycleEvent`;
- main-window focus events;
- UIAbility foreground/background callbacks;
- native window privacy mode;
- an opaque root cover shown before native privacy changes complete.

The root cover keeps page state mounted while hiding pixels and accessibility descendants. Preference dialogs are closed when the cover appears. Native privacy requests are serialized so an older request cannot override a newer protection state.

Task snapshots are ultimately produced by the operating system. Real-device testing is therefore required; code-level checks cannot prove that every device captures the task card at the same lifecycle point.

## Clipboard

Sensitive values copied by TimeAuth are restricted to the local device. When automatic clearing is enabled, TimeAuth schedules a 30-second clear and avoids deleting newer clipboard data written afterward.

## Real-device acceptance checklist

| Test | Expected result |
| --- | --- |
| Dark → Light → Dark in Settings | Actual appearance, right-side value and reopened dialog selection stay in sync. |
| English → 简体中文 → 繁體中文（台灣） | Current page, navigation labels and Settings value switch consistently. |
| App English → Follow system while OS is Chinese | App switches to the current supported system Chinese variant immediately; Settings still shows Follow system. |
| Follow system, then change OS language | App follows after returning to the foreground. |
| Explicit English, then change OS language | App remains English. |
| Kill and reopen | Saved theme/language match the actual UI. |
| Hide recent-app preview ON, enter recents from Settings/About/Onboarding | Task card content is masked/covered. |
| Enter recents with a preference dialog open | Dialog and page content are not exposed. |
| Return from recents | Cover is removed only after the app is active/resumed again. |
| Hide recent-app preview OFF on a sensitive page | Sensitive page remains protected. |

If recent-app protection still fails on a device, inspect HiLog entries containing `[ScreenSecurity]` together with the device model and HarmonyOS version.
