# Real local Authenticator

## Scope

Authenticator starts empty and uses real locally stored accounts. Supported code types are standard TOTP, counter-based HOTP, and Steam's five-character code format from an existing `shared_secret`. The old demo OTP records are not restored. The bundled service icons, issuer aliases, Apple optical offset, rounded card container, whole-card copy and left-swipe edit/delete interactions remain.

Password Vault is still a separate preview milestone. Backup/export/restore, cloud sync, Google Authenticator protobuf migration QR codes, external deep-link import, Steam sign-in/enrollment/transfer and Steam trade confirmations are not implemented. Keep service recovery codes and another working recovery method.

## TOTP and Steam

`OtpCore.ets` validates bounded provisioning input and single `otpauth://totp/...` URIs. TOTP supports SHA1/SHA256/SHA512, six/eight digits and periods of 1–86400 seconds. Defaults are SHA1, six digits and thirty seconds. Keys are canonicalized to unpadded Base32; malformed alphabet/padding/unused bits are rejected. Keys must contain 10–512 bytes.

Steam is an explicit type with SHA1, a 30-second step and five-character output. Manual entry accepts an existing 20-byte Base64 `shared_secret` or Base32 equivalent. Merely naming an issuer “Steam” never changes the algorithm/type.

TOTP/Steam code steps derive from `Date.now()` rather than a decrementing software clock. Copy recalculates at tap time and retries a calculation that crosses a time-step boundary.

## HOTP

HOTP implements the RFC 4226 event-counter model. `otpauth://hotp/...` imports require a `counter=` value. Manual setup also exposes the starting counter. The app accepts non-negative JavaScript safe integers; this avoids silently losing precision even though the RFC counter field is encoded as eight bytes.

The setup key, algorithm, code length and current HOTP counter are stored together in the encrypted account payload. Existing pre-HOTP TOTP/Steam rows have no counter property; they load as counter `0` without a destructive schema migration or rewrite.

HOTP behavior is deliberately explicit:

- The card displays `HOTP #<counter>` instead of a time ring.
- Tapping anywhere on the normal card body copies the code for the **current** counter.
- Copying never advances HOTP, so accidental/repeated copy cannot desynchronize local state from the service.
- A separate next-code button persists exactly `counter + 1`; only after the database update succeeds does the UI publish/generate the next code.
- If that write fails, the current counter and current code remain unchanged.
- Editing the HOTP counter is allowed for intentional resynchronization and is accompanied by a warning.
- The same HOTP credential cannot be duplicated merely by selecting another counter; counter is mutable synchronization state, not duplicate identity.

HOTP defaults to SHA1 and six digits as expected by RFC 4226. The editor/import path also accepts SHA256/SHA512 and eight-digit codes when a service explicitly provisions those parameters; those are interoperability extensions rather than the base RFC 4226 profile.

## Persistence and security boundary

Authenticator uses ArkData relational storage configured with encrypted S3 storage:

```ts
{ name: 'timeauth_authenticator_v1.db', securityLevel: relationalStore.SecurityLevel.S3, encrypt: true }
```

The existing table schema does not require a migration for HOTP because credential configuration is held in the encrypted JSON payload. Writes are serialized and bound through native values/predicates. No plaintext fallback is added. Database/open/read corruption does not trigger automatic deletion or rebuilding.

App unlock is optional and off by default. When enabled, `UserAuthenticationKit` performs system fingerprint/face/PIN verification; the app never receives biometric templates or the device password. Regardless of that setting, moving the app to background closes the active Authenticator session and drops live account/code references. With App unlock off, foregrounding automatically reopens the encrypted session. JavaScript memory cannot be guaranteed to be physically erased.

The existing privacy-window policy, recent-task protection and best-effort sensitive clipboard cleanup continue to apply.

## UI flows

- **Add:** + retains exactly Scan QR code and Enter manually. Scans support one standard TOTP or HOTP provisioning URI and are reviewed before Save. Google Authenticator bulk migration is still unsupported.
- **Copy:** the card body remains the primary copy action. TOTP/Steam are recalculated for the current time step; HOTP uses the current persisted counter without mutation.
- **HOTP next:** a separate local-SVG circular action appears at the former timer position. It advances only HOTP and has an account-aware accessibility label.
- **Edit:** one combined editor supports labels, secret replacement, type-specific parameters, and HOTP counter resynchronization. Account type remains fixed after creation.
- **Delete:** left swipe retains icon-only Edit/Delete; deletion requires stable-ID confirmation. Full-swipe delete remains disabled.

## Host checks

Focused HOTP coverage includes all ten RFC 4226 reference values, all existing RFC 6238 vectors, URI/counter validation, legacy-row hydration, persistent counter advancement, duplicate rules, failed-write preservation, session caching, copy-without-advance and stable observed row updates.

Run from a complete checkout with Node.js 22.13+:

```sh
node --test tests/*.test.cjs
```

Host tests mock platform APIs. They do **not** compile ArkTS UI DSL, render native widgets, verify the database ciphertext on device, or prove scanner/identity behavior.

## Required DevEco / device acceptance

1. Build the HarmonyOS 6.0 / API 20 target with local signing. Verify both App-unlock-off (default) and App-unlock-on behavior.
2. Add a test TOTP account and independently compare SHA1/256/512, six/eight digits, non-default periods and exact step boundaries.
3. Add an RFC/test-only HOTP account with a known starting counter. Compare the displayed code independently before advancing.
4. Tap/copy the HOTP card repeatedly and confirm the counter never changes. Then tap the next-code icon once and confirm the counter increments exactly once and survives restart.
5. Simulate/induce a failed persistent write in a debug-only environment and verify the HOTP counter/code do not advance.
6. Import valid HOTP QR codes, missing/negative/oversized counter cases, TOTP QR codes containing a forbidden counter, and Google Authenticator migration QR codes.
7. Intentionally edit a HOTP counter to resynchronize and confirm the new value persists. Do not perform this against an important account without another recovery method.
8. Verify horizontal swipe, vertical scroll and the top-right HOTP button cannot trigger one another accidentally; card body still copies while the button only advances.
9. Check round corners, pressed-state clipping, large fonts, light/dark, all four explicit locales, accessibility focus and phone/tablet/2-in-1 layouts.
10. Inspect native encrypted DB/journal behavior without logging/exporting real seeds, and keep recovery codes throughout testing.

## References

- RFC 4226 (HOTP): https://www.rfc-editor.org/rfc/rfc4226
- RFC 6238 (TOTP): https://www.rfc-editor.org/rfc/rfc6238
- RFC 4648 (Base32): https://www.rfc-editor.org/rfc/rfc4648
- ArkData encrypted storage: https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/data-encryption
