# TimeAuth UI/UX framework

## Product structure

The preview starts with a three-step onboarding flow and a mock unlock state. After unlocking, the UI shell has four primary destinations: Authenticator, Password Vault, Generator, and Settings. Compact devices use bottom navigation. Expanded devices use a side rail and a constrained content column.

## Interaction principles

1. Keep secrets hidden unless the user performs an explicit action.
2. Do not bind destructive actions to a casual horizontal swipe.
3. Show expiration with text and shape as well as color.
4. Keep import and export available in the free product.
5. Mark all preview-only values so they cannot be mistaken for production security output.

## Theme

Colors are semantic resources with matching `base` and `dark` values. The default preference follows the system. Explicit light and dark overrides are exposed in the Settings preview.

## Language

The UI supports Simplified Chinese (`zh-Hans`), Traditional Chinese (`zh-Hant`), English, and a persistent system-following preference. English is the base resource and therefore the fallback for unsupported system languages. All product chrome and accessibility labels use localized resources; account names and other user-owned content are not translated.

## Responsive behavior

- Compact: bottom navigation and 16 vp page padding.
- Medium: bottom navigation and a wider centered content column.
- Expanded: 216 vp side rail and content limited to 920 vp.

## Phase 1 exclusions

- real OTP generation;
- real password generation;
- vault persistence and encryption;
- clipboard writes;
- camera and photo permissions;
- Steam account enrollment or session handling;
- cloud sync.
