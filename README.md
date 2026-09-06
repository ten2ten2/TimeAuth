# 时钥 / 時鑰 / TimeAuth

HarmonyOS-native authenticator and password-manager project.

> Authenticator uses real offline TOTP, HOTP and Steam code generation with encrypted local account storage. **Password Vault is still a demonstration UI: do not store real passwords there.** Backup/export/restore and cloud sync are not implemented. Keep each service's recovery codes and complete native-device acceptance before using this development build as a primary authenticator.

## Build

- Minimum compatible system: HarmonyOS 6.0 / API 20.
- `compileSdkVersion` is intentionally omitted so DevEco Studio uses its bundled SDK.
- Configure local signing for the `entry` module, then build or run from DevEco Studio.
- App unlock is optional and off by default. If enabled, it requires a supported device with an enrolled secure lock; DevEco Preview has no mock-unlock bypass.

Do not commit signing material, OTP/Steam secrets, passwords, recovery keys or exported databases/vaults.

## License

TimeAuth is proprietary, closed-source software. All rights reserved. Third-party and platform components remain subject to their own applicable terms and licenses. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for attribution and licensing.

## Current implementation

| Area | Status |
| --- | --- |
| First launch | Onboarding completion persists locally. App unlock is optional and defaults off. |
| App shell | Onboarding, optional real unlock, Authenticator, preview Vault, Generator, Settings, About, responsive phone/tablet/2-in-1 navigation. |
| Appearance | System / Light / Dark, persisted preferences and native color-mode API. |
| Language | System / Simplified Chinese / Traditional Chinese (Taiwan) / Traditional Chinese (Hong Kong) / English; English fallback. |
| TOTP | SHA1/256/512, six/eight digits, configurable period, live countdown, fresh-code copy. |
| HOTP | RFC 4226 counter mode, QR/manual provisioning, encrypted counter persistence, six/eight digits, explicit next-code action. Copying does not advance the counter. |
| Steam codes | Offline five-character codes from an existing `shared_secret`. No Steam registration, sign-in, transfer or trade confirmation. |
| Account import | Native QR scanner with review before Save, plus manual setup-key input. Single standard TOTP and HOTP provisioning URIs are supported; Google Authenticator bulk migration is not. |
| Authenticator storage | ArkData encrypted local database, system-managed encryption key, serialized writes, no plaintext fallback or mock seed. |
| App unlock | Optional system fingerprint/face/PIN widget, default off. When enabled, late results cannot bypass a background lock. |
| Screen capture | Onboarding, Settings and About allow capture; Authenticator, Vault and Generator are protected by application policy. Unlock is protected when shown. |
| Recent-app preview | Native privacy mode plus opaque cover; still requires target-device acceptance. |
| Clipboard | Local-device writes, revision-guarded best-effort 30-second clearing and foreground retry. |
| Password generator | System cryptographic randomness, 8–128 characters, configurable symbols/types, entropy estimate, show/hide, copy and saved rules. |
| Passphrase | Offline EFF wordlist, 4–10 words, four separators, optional capitalization/final digit, independent results and rules. |
| PIN | 4/6/8 digits, unbiased secure randomness, leading zeroes, copy, in-memory session and saved rules. |
| Password Vault | Mock data only; real password persistence/autofill are not implemented. |
| Backup / restore / sync | Not implemented. Uninstalling, clearing app data or losing the device may lose authenticator keys. |

## HOTP behavior

HOTP is event/counter based, not time based. TimeAuth stores the current counter in the same encrypted account payload as the setup key. The card shows `HOTP #<counter>` and a dedicated next-code control. Tapping the card copies the code for the **current** counter and does not mutate state. Pressing the next-code control first persists `counter + 1`, then publishes the new code. A failed write leaves the old counter/code intact.

`otpauth://hotp/...` imports require a non-negative `counter=` parameter. Manual HOTP setup exposes the starting counter so a user can intentionally resynchronize with a service. Counter changes are security-sensitive synchronization state; do not advance or edit them casually.

## Language mapping

Manual choices are `简体中文`, `正體中文 (台灣)`, `繁體中文 (香港)` and `English`, plus Follow system. Parentheses in Chinese language names are ASCII half-width.

Follow system reads the OS language locale. `zh-Hant-TW` uses the Taiwan resource, `zh-Hant-HK` and `zh-Hant-MO` use the Hong Kong resource, and Simplified Chinese locales including Singapore and Malaysia use the Simplified Chinese resource. Unsupported system languages fall back to English.

## Security notes

Authenticator records, including labels, keys, HOTP counters and parameters, use platform database encryption. This is not a claim that every HMAC operation is hardware/biometric-bound. When optional App unlock is enabled, system identity verification gates app access; TimeAuth does not receive the device password or biometric template. Whether App unlock is enabled or not, backgrounding closes the active Authenticator session and releases active references to decoded credentials/codes. JavaScript string memory cannot be guaranteed to be physically erased.

Sensitive-page screenshot/recording protection is an application policy, not a user-disableable setting. The separate “Hide recent-app preview” switch controls additional protection for otherwise capture-allowed pages when inactive. Task snapshots are partly controlled by the OS compositor and require real-device verification.

Automatic clipboard clearing is best effort. TimeAuth checks the clipboard source and change count before clearing, and retries pending deadlines on foregrounding. Background restrictions may delay clearing; process termination may prevent it. Metadata checks cannot eliminate every cross-process race because the OS provides no atomic compare-and-clear operation.

## Documentation and tests

- [Authenticator behavior, HOTP synchronization, security and native acceptance](docs/authenticator-interactions.md)
- [UI framework and preferences](docs/ui-ux-framework.md)
- [Password generation and device acceptance](docs/password-generator.md)

With Node.js 22.13+, run `node --test tests/*.test.cjs` from a complete checkout. The host tests execute non-rendering production logic with mocked platform APIs. They do not replace a native HAP build, on-device encryption inspection, scanner testing or real hardware acceptance.

## Next milestone

Complete native acceptance and security review, then implement encrypted backup/export/restore with a tested recovery flow before treating the app as a sole authenticator. Real password-vault functionality remains a separate milestone.
