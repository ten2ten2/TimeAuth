# 时钥 / 時鑰 / TimeAuth

TimeAuth（简体中文“时钥”、繁体中文“時鑰”）is a HarmonyOS-native security companion for one-time passwords, local password management, and secure password generation.

## Current milestone

The project currently provides the application shell and security foundation:

- responsive phone, tablet, foldable, and 2-in-1 navigation;
- flat local SVG navigation icons with theme-aware tinting;
- Simplified Chinese, Traditional Chinese, English, and system-following language preferences;
- ArkData Preferences persistence for theme, language, and available security settings;
- API 20 `windowStageLifecycleEvent` based privacy handling;
- mandatory screenshot/screen-recording protection on Unlock, Authenticator, Vault, and Generator screens;
- screenshot/screen-recording allowed on Onboarding, Settings, and About screens;
- optional recent-app preview protection while the window is paused or hidden;
- real system clipboard writes for preview OTP/password/generator values;
- local-device clipboard restriction and guarded automatic clearing after 30 seconds;
- a dedicated About screen with real package version information, privacy/security notes, third-party notices, and a source-repository link;
- authenticator, password vault, and generator content still backed by mock data.

Real OTP secret persistence, cryptographic OTP generation, encrypted password-vault persistence, biometric unlock, camera scanning, and encrypted backup/import/export are not implemented yet.

## Settings implementation status

| Setting / entry | Status | Behavior |
| --- | --- | --- |
| Appearance | Implemented | Uses the HarmonyOS application color-mode API and persists System / Light / Dark in ArkData Preferences. |
| Language | Implemented | Uses the HarmonyOS preferred-language API and persists System / zh-Hans / zh-Hant / English in ArkData Preferences. |
| Hide recent-app preview | Implemented | Adds privacy mode while the window is not resumed, including otherwise capture-allowed screens. |
| Clear clipboard automatically | Implemented | Clears TimeAuth-owned sensitive clipboard data after 30 seconds without deleting newer content copied by another app. |
| About | Implemented | Shows the real installed version, privacy/security information, dependency/licensing notes, and the source repository. |
| Biometric unlock | Preview only | No User Authentication Kit / HUKS-backed unlock is performed yet. |
| Backup and restore | Not implemented | UI status only; no encrypted backup format or restore pipeline exists yet. |
| Import authenticator codes | Not implemented | UI status only; QR / otpauth / migration import is not wired yet. |
| Local data | Preview only | Authenticator and password-vault entries are still mock data rather than encrypted persistent records. |

Screenshot/recording blocking is an application security policy rather than a user-disableable Settings switch.

## Preview vs real device

DevEco Studio Preview is useful for layout and interaction checks, but it is not authoritative for platform services. In particular, color-mode and preferred-language APIs may be partially emulated or may not force the Preview surface to reload exactly like a real application process.

The Settings rows update their selected values locally as soon as a choice is made. Real system behavior should still be validated with Run/Debug on an emulator or device.

## Open in DevEco Studio

1. Open this repository as a HarmonyOS project.
2. Use a DevEco Studio toolchain that can compile HarmonyOS 6.0 / API 20 applications. `compileSdkVersion` is intentionally not pinned, so the SDK bundled with the IDE is used for compilation.
3. The minimum compatible system version is HarmonyOS 6.0 / API 20.
4. Configure automatic signing for the `entry` module.
5. Run the `entry` module on a compatible emulator or device.

## Language behavior

The default preference follows the system. TimeAuth provides `zh-Hans`, `zh-Hant`, and English resources. English lives in the base resource directory, so unsupported system languages fall back to English. Language preference is stored in ArkData Preferences and applied during `EntryAbility.onCreate()`.

## Brand and theme behavior

The launcher icon keeps a stable product identity. In-app colors use semantic light/dark resources. Theme preference is stored in ArkData Preferences and applied during `EntryAbility.onCreate()` before the page content is loaded.

## Screen security

Capture policy is defined centrally instead of by a user-disableable screenshot switch:

- capture allowed: Onboarding, Settings, About;
- capture blocked: Unlock, Authenticator, Password Vault, Password Generator.

When Hide recent-app preview is enabled, even capture-allowed screens enter privacy mode while the window is paused or hidden.

## Next security milestone

Build one complete local TOTP vertical slice: validate and import a real OTP secret, protect the vault key with HUKS, encrypt and persist the item, generate RFC 6238 codes, integrate real user authentication, lock securely, and restore state after restart.

## Security notice

Never commit real OTP secrets, Steam shared secrets, credentials, signing material, recovery keys, or exported vaults to the repository.
