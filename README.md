# 时钥 / 時鑰 / TimeAuth

HarmonyOS-native authenticator and password-manager project.

> Authenticator now uses real offline TOTP/Steam generation, encrypted local account storage and system identity verification. **Password Vault is still a demonstration UI: do not store real passwords there.** Backup/export/restore and cloud sync are not implemented. Keep each service's recovery codes and complete the native device acceptance checks before using this development build as a primary authenticator.

## Build

- Minimum compatible system: HarmonyOS 6.0 / API 20.
- `compileSdkVersion` is intentionally omitted so DevEco Studio uses its bundled SDK.
- Configure local signing for the `entry` module, then build or run from DevEco Studio.
- Real authentication requires a supported device with an enrolled secure lock. DevEco Preview has no mock-unlock bypass.

Do not commit signing material, OTP/Steam secrets, passwords, recovery keys or exported databases/vaults.

## License

TimeAuth is proprietary, closed-source software. All rights reserved. Third-party and platform components remain subject to their own applicable terms and licenses. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for attribution and licensing.

## Current implementation

| Area | Status |
| --- | --- |
| First launch | Onboarding completion persists locally. Later launches require system verification. |
| App shell | Onboarding, real unlock, Authenticator, preview Vault, Generator, Settings, About, responsive phone/tablet/2-in-1 navigation. |
| Appearance | System / Light / Dark, persisted preferences and native color-mode API. |
| Language | System / Simplified Chinese / Traditional Chinese (Taiwan) / Traditional Chinese (Hong Kong) / English; English fallback. |
| Authenticator | Standard TOTP: SHA1/256/512, six/eight digits, configurable period, live clock, fresh-code copy, details/edit, confirmed deletion. |
| Steam codes | Offline five-character codes from an existing shared_secret. No Steam registration, sign-in, transfer or trade confirmation. |
| Account import | Native QR scanner with review before Save, plus manual setup-key input. HOTP and bulk migration are not supported. |
| Authenticator storage | ArkData encrypted local database, system-managed encryption key, serialized writes, no plaintext fallback or mock seed. |
| App authentication | System fingerprint/face/PIN widget; immediate background lock; late results cannot bypass locking. Native acceptance required. |
| Screen capture | Onboarding, Settings and About allow capture; Unlock, Authenticator, Vault and Generator are protected by application policy. |
| Recent-app preview | Native privacy mode plus opaque cover; still requires target-device acceptance. |
| Clipboard | Local-device writes, revision-guarded best-effort 30-second clearing and foreground retry. |
| Password generator | System cryptographic randomness, 8–128 characters, configurable symbols/types, entropy estimate, show/hide, copy and saved rules. |
| Passphrase | Offline EFF wordlist, 4–10 words, four separators, optional capitalization/final digit, independent results and rules. |
| PIN | 4/6/8 digits, unbiased secure randomness, leading zeroes, copy, in-memory session and saved rules. |
| Password Vault | Mock data only; real password persistence/autofill are not implemented. |
| Backup / restore / sync | Not implemented. Uninstalling, clearing app data or losing the device may lose authenticator keys. |

## Language mapping

Manual choices are `简体中文`, `正體中文 (台灣)`, `繁體中文 (香港)` and `English`, plus Follow system. Parentheses in Chinese language names are ASCII half-width.

Follow system reads the OS language locale. `zh-Hant-TW` uses the Taiwan resource, `zh-Hant-HK` and `zh-Hant-MO` use the Hong Kong resource, and Simplified Chinese locales including Singapore and Malaysia use the Simplified Chinese resource. Unsupported system languages fall back to English.

## Security notes

Authenticator records, including metadata and keys, use platform database encryption. This is not a claim that every HMAC operation is hardware/biometric-bound. System identity verification gates app access; no application PIN or biometric template is collected. Account data is released from the active session on lock; JavaScript string memory cannot be guaranteed to be physically erased. See the detailed boundary and recovery limitations in [docs/authenticator-interactions.md](docs/authenticator-interactions.md).

Sensitive-page screenshot/recording protection is an application policy, not a user-disableable setting. The separate “Hide recent-app preview” switch controls additional protection for otherwise capture-allowed pages when inactive. Task snapshots are partly controlled by the OS compositor and require real-device verification.

Each fresh app session opens Generator on Password. Tab selection is remembered only within that session; generation rules persist separately. Generated passwords are kept in memory, without disk persistence, logging or network transmission. Generator preferences contain rules only, not password values or history.

Automatic clipboard clearing is best effort. TimeAuth checks the clipboard source and change count before clearing, and retries pending deadlines on foregrounding. Background restrictions may delay clearing; process termination may prevent it. Metadata checks cannot eliminate every cross-process race because the OS provides no atomic compare-and-clear operation.

## Documentation and tests

- [Authenticator behavior, security and native acceptance](docs/authenticator-interactions.md)
- [UI framework and preferences](docs/ui-ux-framework.md)
- [Password generation and device acceptance](docs/password-generator.md)

With Node.js 22.13+, run `node --test tests/*.test.cjs` from a complete checkout. The real-authenticator focused suite has 111 passing host tests, executing non-rendering production logic with mocked platform APIs. This is not a native HAP build, an on-device encryption audit, or evidence that all device-specific behavior is accepted. The full repository suite and native SDK build must be run in the normal development environment.

## Next milestone

Complete native acceptance and security review, then implement encrypted backup/export/restore with a tested recovery flow before treating the app as a sole authenticator. Real password-vault functionality remains a separate milestone.
