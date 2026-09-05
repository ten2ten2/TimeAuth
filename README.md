# 时钥 / 時鑰 / TimeAuth

A HarmonyOS-native authenticator and password-manager project. **The OTP, vault and generator contents are still demonstration data; do not use this build to store real credentials.**

## Build and run

Open the project in DevEco Studio, configure local signing for `entry`, and build/run the module on a compatible device. Minimum and target SDK are HarmonyOS 6.0 / API 20. `compileSdkVersion` is intentionally omitted so compilation uses the IDE's bundled SDK; a newer compile SDK does not increase the minimum device API.

Do not commit signing material, real OTP/Steam secrets, passwords, recovery keys or exported vaults.

## Current status

| Area | Implementation boundary |
| --- | --- |
| App shell | Onboarding, mock unlock, four primary tabs, responsive side rail, local SVG icons and light/dark resources. |
| Appearance and language | Native APIs and ArkData Preferences are connected. Settings rows observe their own state inside the render scope. Language supports Simplified Chinese, Traditional Chinese, English and system following, with English fallback. See the device regression checklist below. |
| Screen protection | Native privacy mode plus an opaque root cover are integrated. The latest recent-apps fix still requires device/compositor acceptance testing; code-level tests are not proof that task snapshots are hidden on a device. |
| Clipboard | Real local-device clipboard writes, update monitoring and a scheduled 30-second clear. Timing when suspended/killed and replacement races require device testing; the timer is not a guaranteed background service. |
| About | Dedicated page, installed package version lookup, privacy/security and dependency notices, and a source-repository link. |
| Biometric unlock, backup/restore, authenticator import/export | Not implemented; displayed as preview/status entries. |
| OTP and password data | Mock repository, not encrypted persistent storage. OTP generation and cryptographically secure password generation are not implemented. |

## Preference behavior

ArkData Preferences is the persistent source of truth. The UI uses local reactive state; selected labels are not snapshots passed by value to an `@Builder`. Native configuration is applied after `loadContent`, when the window and page exist. Save/application failures are shown in Settings.

Selecting system language retains `SYSTEM` in the app's preferences. The current OS language is resolved immediately, and is re-evaluated on the system locale-change event, foreground entry and startup. This does not rely on the native `'default'` sentinel, whose documented follow-system effect requires a cold start. Explicit app languages are not overwritten by later OS changes.

## Capture policy

In the active foreground, Onboarding, Settings and About allow screenshots/recording. Unlock, Authenticator, Vault, Generator and unknown screens are protected. The optional recent-apps preference adds protection while inactive, including otherwise capture-allowed screens. It hides **content**, not the app's existence in the task list.

The implementation uses the actual main window, `windowStageLifecycleEvent`, main-window `windowEvent`, UIAbility foreground/background callbacks, an opaque cover, serialized native writes and privacy-state acknowledgement. A failed request must not reveal sensitive content. Returning to the ability alone is insufficient to remove the cover. The source does not call system-only snapshot APIs.

## Validation

The Settings/native behavior must be checked in a device Run/Debug build, not inferred from Preview. [UI architecture and the regression checklist](docs/ui-ux-framework.md) distinguish mocked tests from device acceptance.

With Node.js and TypeScript available as test tooling:

```sh
NODE_PATH="$(npm root -g)" node --test scripts/test-settings-regressions.cjs
```

These tests transpile the non-UI ArkTS modules as TypeScript and run them against explicit native-service mocks, plus check source/resource invariants. They do **not** replace `assembleHap`, ArkTSCheck, ArkUI rendering or real task-snapshot tests. No additional runtime dependency is added to the app.

## Next milestone

A complete local TOTP flow: validated input/import, HUKS-protected key management, encrypted persistence, RFC 6238 generation, real user authentication and tested recovery.
