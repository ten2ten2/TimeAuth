# Authenticator interaction preview

## Scope

This change implements the reviewed Authenticator **UI and mock-data management**, not the real OTP milestone. The existing `PageHeader` and `auth_title` / `auth_subtitle` resources are unchanged, including the explicit preview-data notice. Existing bottom navigation, global appearance preferences and screenshot/clipboard security policies are unchanged.

The page has no search field or day/night shortcut. The only top-right action is **+**, opening a native anchored menu with exactly **Scan QR code** and **Enter manually**. Each menu entry has a local leading SVG icon. Both remain clearly marked future-feature actions. No camera permission, import, secret input, real OTP calculation or encrypted persistence is added by this change.

The preview list contains one mock entry for every service in the first icon batch: Alibaba Cloud, Tencent Cloud, Huawei Cloud, Baidu AI Cloud, Volcano Engine, Google, Microsoft, GitHub, Apple, AWS, Cloudflare, Steam, Discord, Dropbox, Slack, Bitwarden, 1Password, GitLab, Proton and OpenAI. This intentionally makes the preview long so all service badges can be visually reviewed in one scroll. Steam uses a five-character mock code; the other nineteen entries use six-digit mock TOTP values.

## Service badges

- Known issuers are matched locally using normalized, case-insensitive aliases and render a bundled monochrome SVG on a service-specific background color.
- Matching includes common forms such as `Aliyun`, `Google Workspace`, `Microsoft Entra`, `Amazon Web Services`, `Proton Mail` and `ChatGPT`.
- Unknown issuers fall back to the issuer's first character on the item's existing accent color. No network request is made to resolve or download icons.
- Service icons are decorative. The card's existing accessibility text continues to expose issuer, account and code rather than a separate logo label.
- See `THIRD_PARTY_NOTICES.md` for icon-source and trademark notes.

## Interactions

- Tapping any part of a closed card copies its current displayed OTP through `SecureClipboard`; display spaces are removed, leading zeroes and Steam letters are preserved. A single native Button owns the whole card and provides pressed feedback. There is no separate Copy button, chevron, tap-to-details region or long-press management menu.
- Left-swiping a `ListItem` reveals icon-only **Edit** and **Delete** actions in that order. Accessible localized labels remain attached to both buttons. `SwipeEdgeEffect.None` and `actionAreaDistance: 0` prevent long-swipe direct deletion; there is no `onAction` delete handler. Tapping exposed card content dismisses its swipe actions first. Action buttons do not copy.
- Edit opens one combined details/editor sheet. Service and account fields are drafts until Save. Service name is required; account is optional. Type and period are read-only. The preview does not offer a secret field. Cancel, outside dismissal and Back discard drafts. Edited cards get a content-derived ForEach key so plain-object snapshots do not leave stale card labels on screen.
- Delete opens a native confirmation dialog showing the service name and account. Nothing is removed until the red Delete confirmation is pressed. Cancel, outside dismissal and Back do not delete. The callback targets a stable account ID, not a list index. Cancel receives default focus.
- Edits and deletions stay in the **in-memory preview store** across tab/page reconstruction, including an empty list. A fresh app process reloads the original demo data. This is not durable storage or an undo/backup feature.
- Short feedback is localized, does not intercept list touches and replaces the preceding timeout. Clipboard completions after page disposal are ignored; no code or account is logged.

## Host checks

Run from the repository root with Node.js 22.13+:

```sh
node --test tests/authenticator-interactions.test.cjs tests/authenticator-swipe-icons.test.cjs tests/authenticator-service-icons.test.cjs
```

The suites execute the pure preview store and the page's non-rendering controller methods with mocked ArkUI/clipboard APIs; they also check UI source contracts, local SVG resources and locale parity. They do **not** compile ArkTS UI DSL, render native widgets, emulate native gestures or prove device behavior. Run the existing `node --test tests/*.test.cjs` suite too when a complete checkout is available.

## Required DevEco / real-device acceptance

1. Build with the repository's current minimum target (HarmonyOS 6.0 / API 20). Check both native runtime and DevEco Preview; clipboard access may be unavailable in Preview.
2. Confirm the original header on light/dark and all four explicit locales, no search, no theme shortcut, and exactly two + menu choices. Confirm the QR and manual-entry icons are aligned with their menu labels. Menu dismissal must not copy or delete.
3. Scroll through all twenty preview entries. Confirm each known issuer uses the intended local SVG badge and unknown issuer test data still falls back cleanly to a first character. Check dark/light contrast and large-font behavior.
4. Tap avatar, title, account, whitespace, code and timer of closed cards. Check the clipboard contains digits without grouping (including a leading-zero case) or the unchanged five-character Steam code. Verify the copied feedback and automatic clipboard policy.
5. Swipe each card left, including dragging beyond the action width and releasing. Both icon-only actions must have full-height touch targets; there must be no direct deletion and no accidental copy during a horizontal swipe or vertical scroll.
6. Tap Edit, change labels (including changing to a known service alias), save and confirm immediate card/icon updates. Edit a different account, cancel, use Back, and dismiss by the scrim; unsaved drafts must not leak between accounts.
7. Tap Delete; test Cancel, Back and outside dismissal before confirming. Verify only the named account is removed. Delete the last item and check the non-search empty state.
8. Switch to Generator and back after an edit/deletion. Check that mock changes remain during the process; restart the app and confirm that all twenty demo entries return.
9. Check a narrow phone, large font settings, a tablet/2-in-1, keyboard focus and screen-reader operation. Native swipe-action discovery, menu/sheet placement, keyboard avoidance and accessibility all require hardware acceptance.
