# 时钥 / 時鑰 / TimeAuth UI/UX framework

## Product structure

The preview starts with a three-step onboarding flow and a mock unlock state. After unlocking, the UI shell has four primary destinations: Authenticator, Password Vault, Generator, and Settings. Compact devices use bottom navigation; expanded devices use a side rail and a constrained content column.

Settings contains an About entry that opens a dedicated About screen while keeping Settings as the selected primary destination.

## Interaction principles

1. Keep secrets hidden unless the user performs an explicit action.
2. Do not bind destructive actions to a casual horizontal swipe.
3. Show expiration with text and shape as well as color.
4. Keep import and export available in the free product.
5. Do not present preview-only controls as working settings: unavailable items are status rows, not fake toggles or dead navigation targets.
6. Use full-row hit targets and clear selected/current-value feedback in settings lists.

## Theme

Colors are semantic resources with matching `base` and `dark` values. The default preference follows the system. Explicit light and dark overrides are exposed in Settings and persist across launches.

Theme preference is persisted once through ArkData Preferences so it can be read by `UIAbility` before page content is loaded. AppStorage is used only as the in-memory reactive value shared by UI components.

## Language

The UI supports Simplified Chinese (`zh-Hans`), Traditional Chinese (`zh-Hant`), English, and a persistent system-following preference. English is the base resource and therefore the fallback for unsupported system languages. User-owned account names and labels are not translated.

## Navigation icons

Primary navigation uses four monochrome local SVG assets instead of Unicode glyphs:

- Authenticator: clock;
- Password Vault: lock;
- Generator: magic wand/spark;
- Settings: sliders.

ArkUI applies the active/inactive tint at runtime, providing consistent geometry, baseline alignment, and light/dark behavior.

## Screen security

The app requires HarmonyOS 6.0 / API 20 and uses `windowStageLifecycleEvent` for ordered window lifecycle handling.

Capture policy is centralized:

- capture allowed: Onboarding, Settings, About;
- capture blocked: Unlock, Authenticator, Password Vault, Password Generator.

The screenshot policy is not user-disableable. The separate Hide recent-app preview preference adds privacy mode while the window is paused or hidden, including on otherwise capture-allowed screens.

## Clipboard security

Preview OTP, password, and generated values are written to the real system clipboard. Clipboard data is restricted to the local device. When automatic clearing is enabled, TimeAuth schedules clearing after 30 seconds and cancels/guards the clear operation when newer clipboard data has been written by another app.

## Responsive behavior

- Compact: bottom navigation and 16 vp page padding.
- Medium: bottom navigation and a wider centered content column.
- Expanded: 216 vp side rail and content limited to 920 vp.

## Still not implemented

- real OTP secret persistence and RFC 6238 generation;
- cryptographically secure password generation;
- encrypted password-vault persistence;
- biometric/device-credential unlock;
- camera/photo QR import;
- Steam account enrollment or session handling;
- encrypted backup/restore and authenticator import/export;
- cloud sync.
