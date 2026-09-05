# 时钥 / 時鑰 / TimeAuth

TimeAuth（简体中文“时钥”、繁体中文“時鑰”）is a HarmonyOS-native security companion for one-time passwords, local password management, and secure password generation.

## Current milestone

The project currently provides the application shell and security foundation:

- responsive phone, tablet, foldable, and 2-in-1 navigation;
- flat local SVG navigation icons with theme-aware tinting;
- Simplified Chinese, Traditional Chinese, English, and system-following language preferences;
- persistent theme and security preferences;
- API 20 `windowStageLifecycleEvent` based privacy handling;
- mandatory screenshot/screen-recording protection on Unlock, Authenticator, Vault, and Generator screens;
- screenshot/screen-recording allowed on Onboarding, Settings, and About screens;
- optional recent-app preview protection while the window is paused or hidden;
- real system clipboard writes for preview OTP/password/generator values;
- local-device clipboard restriction and guarded automatic clearing after 30 seconds;
- a complete About screen with real package version information, privacy/security notes, third-party notices, and a source-repository link;
- authenticator, password vault, and generator UI still backed by mock data.

Real OTP secret persistence, cryptographic OTP generation, encrypted password-vault persistence, biometric unlock, camera scanning, and encrypted backup/import/export are not implemented yet.

## Open in DevEco Studio

1. Open this repository as a HarmonyOS project.
2. Use a DevEco Studio toolchain that can compile HarmonyOS 6.0 / API 20 applications. `compileSdkVersion` is intentionally not pinned, so the SDK bundled with the IDE is used for compilation.
3. The minimum compatible system version is HarmonyOS 6.0 / API 20.
4. Configure automatic signing for the `entry` module.
5. Run the `entry` module on a compatible emulator or device.

## Language behavior

The default preference follows the system. TimeAuth provides `zh-Hans`, `zh-Hant`, and English resources. English lives in the base resource directory, so unsupported system languages fall back to English. The localized product names are `时钥`, `時鑰`, and `TimeAuth`.

## Brand and theme behavior

The launcher icon keeps a stable product identity. In-app colors use semantic light/dark resources. The System, Light, and Dark preferences persist across launches.

## Screen security

Capture policy is defined centrally instead of by a user-disableable screenshot switch:

- capture allowed: Onboarding, Settings, About;
- capture blocked: Unlock, Authenticator, Password Vault, Password Generator.

When Hide recent-app preview is enabled, even capture-allowed screens enter privacy mode while the window is paused or hidden.

## Next security milestone

Build one complete local TOTP vertical slice: validate and import a real OTP secret, protect the vault key with HUKS, encrypt and persist the item, generate RFC 6238 codes, integrate real user authentication, lock securely, and restore state after restart.

## Security notice

Never commit real OTP secrets, Steam shared secrets, credentials, signing material, recovery keys, or exported vaults to the repository.
