# Real local Authenticator

## Scope and migration

Authenticator now starts empty and uses real locally stored accounts. The old in-memory preview store and twenty mock OTP records are removed; no demo keys are imported or converted to real accounts. The twenty bundled service icons, local alias matching, Apple-only -1vp optical offset, original header style, and rounded card container remain. Password Vault is still a separate preview milestone. Password/passphrase/PIN generation is unchanged.

Implemented: standard TOTP provisioning QR scan, manual entry, review before Save, encrypted persistence, offline generation, live countdown, fresh-code copying, combined details/editor, confirmed deletion, and system identity verification on launch and after backgrounding. The UI strings cover English, Simplified Chinese, Traditional Chinese (Taiwan) and Traditional Chinese (Hong Kong).

Not implemented: encrypted backup/export/restore, cloud synchronization, HOTP account support, Google Authenticator protobuf migration QR codes, external deep-link import, Steam sign-in/enrollment/transfer, or Steam trade confirmations. An icon or issuer name is only a visual label; it is not proof of protocol compatibility and never chooses an OTP algorithm. Keep each service's recovery codes and another working recovery method. Do not make this development build your sole authenticator before native acceptance testing.

## Provisioning and generation

`OtpCore.ets` validates bounded inputs and parses single `otpauth://totp/...` URIs. Percent-encoding is decoded once, duplicate query parameters and conflicting issuer names are rejected, and unsupported modes fail explicitly. SHA1/SHA256/SHA512, six/eight digits and periods of 1–86400 seconds are supported. Defaults are SHA1, six digits and thirty seconds. Keys are canonicalized to unpadded Base32; malformed padding, symbols and non-zero unused bits are rejected. TOTP keys must contain 10–512 bytes. Labels are bounded and control/bidi override characters are rejected. Maximum: 500 accounts.

`OtpCrypto.ets` uses the platform CryptoArchitectureKit HMAC implementation. No handwritten hash or insecure random fallback is used. SHA1 is intentional for legacy TOTP interoperability, not password hashing. Temporary byte buffers and imported native key objects are cleared in `finally`. IDs use system cryptographic randomness.

Steam is an explicit type with a five-character code, SHA1 and thirty-second period. Manual entry accepts an existing twenty-byte Base64 `shared_secret` or its Base32 encoding. QR import accepts the explicit `encoder=steam` extension. Merely naming an entry Steam does not select Steam mode. No Steam credentials are collected or network login performed.

`OtpSession.ets` derives the counter and remaining time from `Date.now()`, never by decrementing an independent timer. Codes are cached for their exact time step and hidden when that step has expired while recalculation is pending. Copy recalculates at tap time and retries if the counter changes during calculation. A revision invalidates obsolete calculations after edits, deletion, navigation or locking. `@Observed OtpViewItem` / `@ObjectLink` and stable account IDs keep list items alive during countdown updates instead of rebuilding swipe controls each second.

## Persistence and security boundary

The authenticator uses ArkData relational storage configured with:

```ts
{ name: 'timeauth_authenticator_v1.db', securityLevel: relationalStore.SecurityLevel.S3, encrypt: true }
```

The platform manages the database encryption key. All account metadata and secrets are inside the encrypted database, including the duplicate-detection index. The application does not supply a hard-coded key, write plaintext credential files/preferences, or fall back to unencrypted storage. This is **platform database encryption plus an application authentication gate**, not a claim of a custom biometric-bound HUKS envelope or hardware authorization for every HMAC operation.

Writes are serialized, bound to SQL parameters, and performed as single native row operations. Memory/UI is updated after a successful write, not optimistically. A failed write does not poison later operations. Corrupt records, unknown schema versions, and database-open failures display an error and disable adding; the app does not intentionally erase, rebuild, or replace the database with an empty one. UI deletion removes a logical record; it is not a claim of forensic secure erasure of previously used database pages.

System authentication uses `UserAuthenticationKit.getUserAuthInstance`, a random challenge, available fingerprint/face/PIN methods at ATL2, and only the SDK's `UserAuthResultCode.SUCCESS`. Unsupported devices, missing enrollment, cancellation, timeout and failure do not unlock. There is no fake PIN field or Preview bypass. Authentication results from an earlier app epoch cannot unlock after backgrounding.

On background/destroy, the ability locks the session. Authenticator clears displayed rows, account references, editor drafts, timers and pending delete confirmation, then closes the database behind accepted operations. JavaScript string memory cannot be guaranteed to be physically erased; references are released and byte buffers are zeroed where supported. The existing native privacy-window, inactive-content cover and best-effort clipboard cleanup remain. Clipboard clearing is not guaranteed after process termination or OS background restrictions.

## UI flows

- **Add:** + opens exactly two local-SVG menu items. Manual entry opens an empty editor. Scanning opens Scan Kit's native default UI with QR-only recognition and its album option. A scan is parsed and reviewed; it does not write until Save. Errors never log raw QR data. If the native scanner backgrounds the app, a newly returned draft waits in memory for successful re-authentication and database loading, expires after 120 seconds, and is discarded on page disposal. Existing account secrets are not kept alive for this purpose.
- **Copy:** the entire closed card is one native Button. The outer clipped Column owns the 22vp shape and border; the button is transparent and retains native pressed feedback/accessibility. Empty/failed codes are disabled. Clicking an exposed swipe item first dismisses actions rather than copying.
- **Edit:** left swipe exposes a 24vp pencil in a full-height 68vp target. One combined editor keeps labels, algorithm, length and period as drafts. The current key is hidden and retained unless Replace key is enabled. Cancel, Back and outside dismissal discard unsaved changes. Native writes already submitted are not undone by dismissing a sheet.
- **Delete:** left swipe exposes a 24vp trash icon in a 68vp target. Full-swipe deletion is disabled. Confirmation names the exact service/account and warns that removing a local key does not turn off the service's two-step verification. Cancel is the default focus. Stable ID, dialog token and lifecycle revision prevent stale dialog callbacks from deleting a different account or acting after locking.

## Host checks

Node.js 22.13+ is required for the type-stripping test harness:

```sh
node --test tests/otp-core.test.cjs tests/otp-storage.test.cjs tests/otp-platform.test.cjs tests/otp-ui-contracts.test.cjs tests/authenticator-interactions.test.cjs
```

These 111 tests passed in the development environment. They execute production non-rendering logic with mocked native APIs, including all eighteen RFC 6238 vectors, RFC 4226 truncation vectors, Base32 validation, persistence failures, concurrent duplicate prevention, time-step copying, stale callbacks, native scan return flow, system-authentication lifecycle and locale parity. They do **not** compile ArkTS UI DSL, render native widgets, verify on-device database ciphertext, or prove hardware biometric/scanner behavior. The existing icon-resource tests were updated for real data; run `node --test tests/*.test.cjs` from a complete checkout for the full repository regression suite. A full SDK build/full repository test run was not performed in this environment.

## Required DevEco / device acceptance

1. Build the existing HarmonyOS 6.0 / API 20 target, with local signing. There is no auth bypass for DevEco Preview; test the native flow on a supported device with a secure lock configured.
2. Verify first-run onboarding, real system unlock, cancellation, failed authentication, background/foreground, screen locking, and no stale callback bypass. Check that fingerprint/face availability does not remove the system password fallback when it is supported.
3. Start with the empty list. Add a **test-only** standard TOTP account manually, independently compare generated codes, and confirm restart persistence before adding important accounts. Never use public RFC seeds to secure real accounts.
4. Scan a provisioning QR, cancel scanning, scan invalid QR/unsupported HOTP/migration data, and scan through the native album. Check re-authentication on return, review-before-save, duplicate handling and no duplicate writes on repeated taps.
5. Check SHA1/256/512, six/eight digits, non-default periods, leading zeroes, device time changes and exact period boundaries. Test Steam only with an existing test secret and independently compare codes.
6. Copy the icon, issuer, account, whitespace, code and timer areas. Confirm ungrouped output, native feedback and clipboard expiry policy. Horizontal swipes and vertical scrolls must not accidentally copy.
7. Edit/cancel/Back/outside-dismiss, replace a key, change parameters, and switch tabs during a pending operation. Check stable row identity during countdowns and immediate saved-label/icon updates.
8. Confirm/cancel/delete/Back, rapidly open different confirmation dialogs, and background while a dialog is open. Only the positively confirmed stable ID may be removed.
9. Check storage-open errors, disk-full/write failures and corrupt test records on a debug-only fixture. Preserve data; never test destructive scenarios against users' only authenticator database. Inspect native encrypted database/journal/key handling without logging/exporting real secrets.
10. Check round corners and pressed-state clipping on hardware, large fonts, light/dark themes, all locales, accessibility focus, and phone/tablet/2-in-1 layouts. Validate that native sheets/dialogs and the system scanner cannot expose sensitive content through task snapshots or capture.

## Primary references

- RFC 6238: https://www.rfc-editor.org/rfc/rfc6238
- RFC 4226: https://www.rfc-editor.org/rfc/rfc4226
- RFC 4648: https://www.rfc-editor.org/rfc/rfc4648
- ArkData encrypted storage: https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/data-encryption
- Crypto key conversion: https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-crypto-architecture-66
- System authentication: https://developer.huawei.com/consumer/en/doc/harmonyos-references-V14/js-apis-useriam-userauth-V14
- Native default scanner: https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V14/scan-scanbarcode-V14
- Steam interoperability reference implementation (not Valve endorsement): https://github.com/DoctorMcKay/node-steam-totp/blob/master/index.js
