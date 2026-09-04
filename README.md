# 时钥 / 時鑰 / TimeAuth

TimeAuth（简体中文“时钥”、繁体中文“時鑰”）is a HarmonyOS-native security companion for one-time passwords, local password management, and secure password generation.

## Current milestone

Phase 1 implements the UI/UX framework only:

- responsive phone, tablet, and foldable navigation shell;
- semantic light and dark color resources;
- Simplified Chinese, Traditional Chinese, English, and system-following language preferences;
- reusable ArkUI components;
- authenticator, password vault, generator, and settings screens;
- mock data behind a repository interface.

No real secret, password, cryptographic generation, persistence, camera scanning, or clipboard integration is enabled in this milestone. Preview values are clearly marked as demo content.

## Open in DevEco Studio

1. Open this repository as a HarmonyOS project.
2. Select an installed HarmonyOS SDK compatible with API 12 or later.
3. Configure automatic signing for the `entry` module.
4. Run the `entry` module on a phone, tablet, foldable emulator, or device.

## Language behavior

The default preference follows the system. TimeAuth provides `zh-Hans`, `zh-Hant`, and English resources. English lives in the base resource directory, so unsupported system languages fall back to English. The localized product names are `时钥`, `時鑰`, and `TimeAuth`. The selection is available under Settings and persists across launches.

## Brand and theme behavior

The launcher icon remains the ink-black (`#171717`) version in every system theme so it keeps a stable identity. In-app brand marks and the launch window use ink black on warm ivory (`#F5F2EA`) in light mode, and warm ivory on ink black in dark mode. The System, Light, and Dark preferences persist across launches.

## Planned next milestone

Build one complete local TOTP vertical slice: validate input, protect a vault key with HUKS, encrypt and persist the item, generate RFC 6238 codes, copy safely, lock, and restore after restart.

## Security notice

The repository contains UI preview data only. Never commit real OTP secrets, Steam shared secrets, credentials, signing material, or exported vaults.
