# TimeAuth

TimeAuth is a HarmonyOS-native security companion for one-time passwords, local password management, and secure password generation.

## Current milestone

Phase 1 implements the UI/UX framework only:

- responsive phone, tablet, and foldable navigation shell;
- semantic light and dark color resources;
- reusable ArkUI components;
- authenticator, password vault, generator, and settings screens;
- mock data behind a repository interface.

No real secret, password, cryptographic generation, persistence, camera scanning, or clipboard integration is enabled in this milestone. Preview values are clearly marked as demo content.

## Open in DevEco Studio

1. Open this repository as a HarmonyOS project.
2. Select an installed HarmonyOS SDK compatible with API 12 or later.
3. Configure automatic signing for the `entry` module.
4. Run the `entry` module on a phone, tablet, foldable emulator, or device.

## Planned next milestone

Build one complete local TOTP vertical slice: validate input, protect a vault key with HUKS, encrypt and persist the item, generate RFC 6238 codes, copy safely, lock, and restore after restart.

## Security notice

The repository contains UI preview data only. Never commit real OTP secrets, Steam shared secrets, credentials, signing material, or exported vaults.

