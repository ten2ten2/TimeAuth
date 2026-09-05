# 时钥 / 時鑰 / TimeAuth

HarmonyOS-native authenticator and password-manager project.

> Current OTP, vault and generator contents are demonstration data. Do not store real credentials in this build.

## Build

- Minimum compatible system: HarmonyOS 6.0 / API 20.
- `compileSdkVersion` is intentionally omitted so DevEco Studio uses its bundled SDK.
- Configure local signing for the `entry` module, then build or run from DevEco Studio.

Do not commit signing material, OTP/Steam secrets, passwords, recovery keys or exported vaults.

## License

TimeAuth is proprietary, closed-source software. All rights reserved. Third-party and platform components remain subject to their own applicable terms and licenses.

## Current implementation

| Area | Status |
| --- | --- |
| App shell | Implemented: onboarding, mock unlock, Authenticator, Vault, Generator, Settings, About, responsive phone/tablet/2-in-1 navigation. |
| Appearance | Implemented: System / Light / Dark, ArkData persistence, native color-mode API. |
| Language | Implemented: System / Simplified Chinese / Traditional Chinese (Taiwan) / Traditional Chinese (Hong Kong) / English, with locale-specific resources and English fallback. |
| Screen capture policy | Implemented in code: Onboarding, Settings and About allow capture; Unlock, Authenticator, Vault and Generator are protected. |
| Recent-app preview protection | Implemented in code with native privacy mode plus an opaque root cover; still requires real-device acceptance testing on each target OS/device. |
| Clipboard | Implemented: local-device clipboard writes and guarded 30-second automatic clearing. |
| About | Implemented: installed version, privacy/security information, proprietary-license notice, platform notices, and native ArkUI detail dialogs. |
| Biometric unlock | Preview only. |
| Backup / restore | Not implemented. |
| Authenticator import / export | Not implemented. |
| OTP / password persistence | Not implemented; mock repository only. |
| Real OTP/password generation | Not implemented. |

## Language mapping

Manual choices are `简体中文`, `正體中文 (台灣)`, `繁體中文 (香港)` and `English`, plus Follow system. Parentheses in Chinese language names are ASCII half-width.

Follow system reads the OS language locale. `zh-Hant-TW` uses the Taiwan resource, `zh-Hant-HK` and `zh-Hant-MO` use the Hong Kong resource, and Simplified Chinese locales including Singapore and Malaysia use the Simplified Chinese resource. Unsupported system languages fall back to English.

## Security notes

Sensitive-page screenshot/recording protection is an application policy, not a user-disableable setting. The separate “Hide recent-app preview” switch only controls additional protection for otherwise capture-allowed pages when the app is inactive.

Recent-app task snapshots are partly controlled by the operating system compositor. Code-level privacy handling must therefore be verified on real hardware; the goal is to hide the card content, not remove the app itself from the task list.

## Documentation

See [docs/ui-ux-framework.md](docs/ui-ux-framework.md) for UI rules, preference behavior and the focused real-device acceptance checklist.

## Next milestone

Implement one complete local TOTP flow: validated import, HUKS-backed key management, encrypted persistence, RFC 6238 generation, real user authentication and tested recovery.
