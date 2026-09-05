# 时钥 / 時鑰 / TimeAuth

HarmonyOS-native authenticator and password-manager project.

> Authenticator and vault contents are still demonstration data, and unlock is not real authentication. Do not store real credentials in the mock vault. The password generator now produces real random passwords locally; it does not save generated passwords.

## Build

- Minimum compatible system: HarmonyOS 6.0 / API 20.
- `compileSdkVersion` is intentionally omitted so DevEco Studio uses its bundled SDK.
- Configure local signing for the `entry` module, then build or run from DevEco Studio.

Do not commit signing material, OTP/Steam secrets, passwords, recovery keys or exported vaults.

## License

TimeAuth is proprietary, closed-source software. All rights reserved. Third-party and platform components remain subject to their own applicable terms and licenses. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for EFF wordlist attribution and licensing.

## Current implementation

| Area | Status |
| --- | --- |
| First launch | Completing the welcome flow is saved locally; subsequent launches start at Unlock. |
| App shell | Implemented: onboarding, mock unlock, Authenticator, Vault, Generator, Settings, About, responsive phone/tablet/2-in-1 navigation. |
| Appearance | Implemented: System / Light / Dark, ArkData persistence, native color-mode API. |
| Language | Implemented: System / Simplified Chinese / Traditional Chinese (Taiwan) / Traditional Chinese (Hong Kong) / English, with locale-specific resources and English fallback. |
| Screen capture policy | Implemented in code: Onboarding, Settings and About allow capture; Unlock, Authenticator, Vault and Generator are protected. |
| Recent-app preview protection | Implemented in code with native privacy mode plus an opaque root cover; still requires real-device acceptance testing on each target OS/device. |
| Clipboard | Implemented: local-device clipboard writes, revision-guarded best-effort 30-second clearing, and foreground retry of pending deadlines. |
| Password generator | Implemented: system cryptographic randomness, 8–128 characters (default 16), thumb-only slider dragging, distinct unsupported-device and retry messages, configurable character types and symbols, estimated entropy, show/hide, copy, session retention, and locally saved generation settings. |
| About | Implemented: installed version, privacy/security information, proprietary-license notice, platform notices, and native ArkUI detail dialogs. |
| Biometric unlock | Preview only. |
| Backup / restore | Not implemented. |
| Authenticator import / export | Not implemented. |
| OTP / password persistence | Not implemented; mock repository only. |
| Real OTP generation | Not implemented. |
| Passphrase generation | Implemented: offline EFF wordlist, 4–10 words (default 6), four separators, optional capitalization and a random final digit; independent password/passphrase tabs with separate results and saved settings. |
| PIN generation | Implemented: independent tab, 4/6/8 digits (default 6), unbiased secure randomness, leading-zero preservation, copy, session retention and separate saved settings. |

## Language mapping

Manual choices are `简体中文`, `正體中文 (台灣)`, `繁體中文 (香港)` and `English`, plus Follow system. Parentheses in Chinese language names are ASCII half-width.

Follow system reads the OS language locale. `zh-Hant-TW` uses the Taiwan resource, `zh-Hant-HK` and `zh-Hant-MO` use the Hong Kong resource, and Simplified Chinese locales including Singapore and Malaysia use the Simplified Chinese resource. Unsupported system languages fall back to English.

## Security notes

Sensitive-page screenshot/recording protection is an application policy, not a user-disableable setting. The separate “Hide recent-app preview” switch only controls additional protection for otherwise capture-allowed pages when the app is inactive.

Recent-app task snapshots are partly controlled by the operating system compositor. Code-level privacy handling must therefore be verified on real hardware; the goal is to hide the card content, not remove the app itself from the task list.

Each fresh app session opens Generator on Password. Tab selection is remembered only within that session; generation rules still persist separately for each tab. Generated passwords are kept in memory for the current app session, without disk persistence, logging, or network transmission. Copying writes the current password to the local-device clipboard. Generator preferences contain rules only, never password values or history.

Automatic clipboard clearing is best effort. TimeAuth checks the clipboard source and change count before clearing, and retries pending deadlines when the app returns to the foreground. Background execution restrictions can delay clearing, and process termination can prevent it. The OS offers no atomic compare-and-clear operation, so the metadata guard cannot eliminate every cross-process race.

## Documentation

See [docs/ui-ux-framework.md](docs/ui-ux-framework.md) for UI rules, preference behavior and the focused real-device acceptance checklist.

See [docs/password-generator.md](docs/password-generator.md) for generation behavior, limitations, host checks, and the device acceptance checklist. With Node.js 22.13 or newer, run `node --test tests/*.test.cjs` from the repository root. All 96 host tests passed: 15 password-engine, 10 passphrase, 7 PIN-engine, 19 settings/session, 17 tab lifecycle/interaction, 5 onboarding-persistence, and 23 clipboard tests. Platform APIs are mocked; a native HAP build and real-device testing have not been executed.

## Next milestone

Implement one complete local TOTP flow: validated import, HUKS-backed key management, encrypted persistence, RFC 6238 generation, real user authentication and tested recovery.
