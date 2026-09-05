# TimeAuth UI / UX notes

## Navigation and layout

Primary destinations are Authenticator, Vault, Generator and Settings. About is a secondary Settings page.

- Compact layouts use bottom navigation and 16 vp page padding.
- Expanded layouts use a 216 vp side rail and a constrained content column.
- Primary navigation icons use monochrome local SVG assets with theme-aware tinting.
- Onboarding uses a non-looping `Swiper`; users can move between the three introduction pages with horizontal gestures or buttons.
- Primary-page, About and root-stage changes use a short 160–180 ms opacity + small vertical-translation transition.

## Settings interaction

Appearance and Language use full-row `SelectDialog` selection. The current value is shown on the right, the whole row is clickable, choices are mutually exclusive, and the selected value updates immediately. ArkData Preferences remains the persistent source of truth.

Preview-only features are status rows rather than fake toggles or dead navigation items.

## Language behavior

Supported manual application languages:

- `简体中文` → `zh-Hans`
- `正體中文 (台灣)` → `zh-Hant-TW`
- `繁體中文 (香港)` → `zh-Hant-HK`
- `English` → `en`

The language names use ASCII half-width parentheses. Taiwan and Hong Kong are separate resource sets, not one generic `zh-Hant` translation. Taiwan wording follows Taiwan usage; Hong Kong wording follows Hong Kong usage.

Follow system reads the OS language locale. Explicit script subtags take priority. Traditional Chinese for Taiwan uses `zh-Hant-TW`; Hong Kong and Macau use `zh-Hant-HK`; Simplified Chinese, including Singapore and Malaysia, uses `zh-Hans`. Unsupported system languages fall back to English.

## About

About shows the installed application version, privacy/security information, proprietary-license information, platform notices and the minimum supported HarmonyOS version. It does not expose a source-code repository or public-source link. Privacy and license details use ArkUI `CustomContentDialog`.

## Screen security

Foreground capture policy:

- allowed: Onboarding, Settings, About;
- protected: Unlock, Authenticator, Vault, Generator and unknown screens.

The recent-app preview switch adds protection to capture-allowed pages while the app is inactive. Sensitive pages stay protected regardless of that switch.

Protection uses the actual main window, API 20 `windowStageLifecycleEvent`, main-window focus events, UIAbility foreground/background callbacks, native window privacy mode and an opaque root cover for inactive/task-switching states and fail-closed errors.

Normal foreground page/tab navigation must not show the opaque privacy cover. Native privacy mode can remain enabled across a sensitive-to-safe transition until the safe replacement frame is rendered without obscuring the visible UI.

## Clipboard

Sensitive values copied by TimeAuth are restricted to the local device. When automatic clearing is enabled, TimeAuth schedules a best-effort 30-second clear guarded by both the clipboard source and the `getChangeCount()` revision; the revision also distinguishes newer copies from the same app or copies of identical text. Changed ownership metadata cancels cleanup, and unverifiable metadata prevents clearing. Pending deadlines are retried when the app returns to the foreground. Background restrictions can delay cleanup, and process termination can prevent it. The OS has no atomic compare-and-clear operation, so a cross-process race between verification and synchronous clearing remains possible.

See [password-generator.md](password-generator.md) for the real password generator, the host verification results, and the generator/clipboard device acceptance checklist. Host platform APIs are mocked; native HAP and real-device validation remain outstanding.

## Real-device acceptance checklist

| Test | Expected result |
| --- | --- |
| Swipe left/right through Onboarding | Page follows the finger, indicator updates, and buttons remain synchronized. |
| Switch repeatedly between the four primary tabs | Content uses the short transition; no privacy-cover flash appears. |
| Open/close About | Uses lightweight page motion without moving persistent navigation. |
| Dark → Light → Dark in Settings | Actual appearance, right-side value and reopened dialog selection stay in sync. |
| English → 简体中文 → 正體中文 (台灣) → 繁體中文 (香港) | Current page, navigation labels and Settings value switch consistently. |
| Follow system with OS `zh-Hant-TW` | Taiwan wording is used. |
| Follow system with OS `zh-Hant-HK` or `zh-Hant-MO` | Hong Kong wording is used. |
| Follow system with OS Simplified Chinese (including Singapore/Malaysia) | Simplified Chinese is used. |
| Explicit English, then change OS language | App remains English. |
| Kill and reopen | Saved theme/language match the actual UI. |
| Hide recent-app preview ON, enter recents from Settings/About/Onboarding | Task card content is masked/covered. |
| Enter recents with a preference dialog open | Dialog and page content are not exposed. |
| Return from recents | Cover is removed only after the app is active/resumed again. |

If recent-app protection still fails on a device, inspect HiLog entries containing `[ScreenSecurity]` together with the device model and HarmonyOS version.


## First launch and resetting test data

The final Get started button saves `timeauth.onboarding.completed.v1` in ArkData preferences and waits for a successful flush before opening Unlock. Future launches read this flag and start at Unlock, retaining the sensitive-page screen policy. Viewing or abandoning the welcome flow does not mark it complete. A save failure keeps the welcome flow visible with a retry message. Existing installations will finish the flow once after this update.

For a clean-device test, close TimeAuth completely and run the following on the connected development computer with `hdc` available:

```sh
hdc shell bm clean -d -n moe.tenten.timeauth
```

This deletes the app's local data, including preferences and onboarding completion; clearing only the cache (`-c`) does not reset preferences. Reopen the app: the welcome flow should appear and the generator should default to 16. Complete onboarding, close and reopen the process, and confirm that Unlock appears without the welcome flow. Also verify that tapping Reset to 16 retains all other generator rules and persists 16 across restart.

Reference: [Official bm clean documentation](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/tools/bm-tool.md#清理命令clean).
