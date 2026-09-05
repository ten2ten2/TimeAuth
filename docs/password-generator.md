# Password generator

The Generator tab creates real random passwords and passphrases locally. Authenticator codes, vault entries, and unlock remain preview features; there is no encrypted vault integration or real user authentication in this milestone.

## Supported behavior

| Control | Behavior |
| --- | --- |
| Length | Integer from 8 to 128; default 16. Drag the slider thumb or edit the number field; tapping or starting a drag on the track does not change the value. Existing saved lengths are preserved. The Reset to 16 button restores only the length and updates the saved rules; generating a replacement password still requires Regenerate. |
| Character types | Lowercase letters, uppercase letters, numbers, and symbols can be enabled independently. All four are enabled by default. At least one type is required. |
| Avoid ambiguous characters | Enabled by default; removes exactly `0`, `O`, `1`, `I`, and `l`. |
| Use every selected type | Enabled by default; requires at least one character from every enabled type. |
| Allowed symbols | Custom set of ASCII punctuation. Duplicate symbols count once. Letters, numbers, spaces, full-width punctuation, and other Unicode characters are rejected when symbols are enabled. An empty symbol set is invalid when symbols are enabled. Reset restores the default symbol set. |
| Show / hide | Toggles the displayed password without generating or changing it. |
| Regenerate | Explicitly applies the draft options and replaces the current result after successful generation. |
| Copy | Copies the current valid result using the existing local-device clipboard service. Disabled while options are invalid or changed, or after generation fails. |
| Strength | Displays an estimated entropy value and a qualitative label based on the generation rules. It is not a prediction of cracking time. |
| Remember settings | Persists generation preferences locally. Generated passwords and history are not persisted. |

Editing options does not silently replace the current password. Changed options display a reminder to regenerate; copying stays disabled until a password matches the current options. An explicit missing random capability displays a device-not-supported message. A capability-query exception or random-provider failure displays a separate retry message. Both failure categories clear the current result, prevent copying, and survive page recreation until a subsequent generation succeeds. There is no fallback to demonstration strings or a noncryptographic random source.

The current result remains in memory while switching tabs, changing language or theme, and returning from the background in the same app process. OS process termination or an app restart discards that result. Generation settings survive restarts when preference storage succeeds. Storage failure is reported; do not assume settings were saved after an error.

Dedicated PIN controls, generation history, saving into the vault, and batch generation are future work. The mode selector exposes only implemented password and passphrase modes.

## Randomness and strength

Production randomness comes from HarmonyOS CryptoArchitectureKit. The adapter checks the dedicated `SystemCapability.Security.CryptoFramework.Rand` capability before creating or reading the random source; an unsupported device fails safely without substituting another source. Character selection uses rejection sampling to avoid modulo bias. Each enabled class is adjusted for the ambiguous-character option, and duplicate custom symbols do not increase the sampling weight or entropy estimate. The generator accounts for the requirement to include every selected type when estimating the password space.

The displayed labels are product guidance, with these thresholds:

| Estimated entropy | Label |
| --- | --- |
| Below 40 bits | Weak |
| At least 40, below 60 bits | Fair |
| At least 60, below 80 bits | Strong |
| 80 bits or more | Very strong |

The estimate describes a newly generated random password under the selected rules. It does not evaluate a user-created password, an account's security, password reuse, or whether a service accepts the selected characters.

## Data and screen protection

- Generator preferences store rules only. Passwords are not written to preference storage, disk, logs, analytics, or network requests.
- Copying places the password on the local-device clipboard. SecureClipboard honors the automatic-clearing setting and attempts to clear its own unchanged content after 30 seconds. It checks both the clipboard source and the `getChangeCount()` revision, which also distinguishes later copies of identical text or content copied by the same app. If either changes, the pending cleanup is cancelled. If ownership metadata cannot be verified, it does not clear.
- Clipboard clearing is best effort. A pending deadline is preserved across background suspension and retried on return to the foreground; transient clear failures can also be retried then. Process termination can prevent cleanup. The OS provides no atomic compare-and-clear operation, so a different process can still change the clipboard between the final metadata check and synchronous clearing.
- The existing ScreenSecurityManager treats Generator as a sensitive page: native privacy mode blocks capture and the inactive screen cover hides sensitive app previews. Turning off the extra preview setting does not make Generator a capture-allowed page.
- Retention in memory is for returning to a generated password during the same session. It is not encrypted password storage or a guarantee of forensic memory erasure.

## Host verification

From the repository root, with Node.js 22.13 or newer:

```sh
node --test tests/*.test.cjs
```

All 63 host tests passed:

| Area | Passing tests |
| --- | --- |
| Generator engine | 15 |
| Passphrase engine and wordlist | 10 |
| Settings and session | 10 |
| Clipboard | 23 |
| Onboarding persistence | 5 |

Host checks exercise generator rules and failure behavior with test random sources, settings/session behavior, and clipboard lifecycle handling with mocked platform APIs. They cannot establish that ArkTS compiles, that the native random source works, or that OS clipboard and screen-protection behavior matches the application policy.

The native HAP build and real-device tests have not been executed. This feature still requires a DevEco Studio build and physical HarmonyOS device acceptance.

## Device acceptance checklist

Use a development build with disposable generated values. Record the device model, HarmonyOS version, app version, and result for each case.

1. **Build and offline start:** build and install the `entry` module using the configured compatible SDK. Open Generator in airplane mode. Confirm a real result appears without a network requirement. Confirm both password and passphrase modes are available.
2. **Length boundaries:** generate at 8, 16, and 128 characters, checking the copied length. Confirm a fresh install defaults to 16 and an existing saved length (including 20) survives an update. Confirm the number field and slider agree. Swipe vertically starting on the track and on the thumb, and tap or drag from the track away from the thumb: the length must stay unchanged during page scrolling. Drag horizontally from the thumb's native touch target to adjust; confirm keyboard and accessibility adjustment still work. Enter an empty value, 7, 129, and a decimal if the keyboard permits; invalid drafts must not generate or copy. A 128-character result must remain readable by wrapping or scrolling, without truncating the copied password.
3. **Character classes:** test each class alone and several combinations. Turn off the final remaining class; generating with no characters must be prevented and the UI must explain the requirement or retain one enabled type. Enable the every-type requirement and verify each selected class appears. Disable it and verify generation still obeys the allowed alphabet without promising every class.
4. **Ambiguous characters:** with avoidance enabled, verify generated values exclude `0/O/1/I/l`. With it disabled, those characters become eligible; no individual result is required to contain them.
5. **Custom symbols:** set symbols to `!@!` and generate using symbols only. Results must use only `!` and `@`, with duplicates not changing the reported entropy. Test an empty set, a space, an ASCII letter, a number, a full-width symbol, and an emoji. Invalid active symbol rules must block generation and copying. Reset symbols and confirm generation recovers. Turn symbols off and confirm no punctuation appears in the result.
6. **Draft and result:** note a generated result, change its length or a toggle, and verify that the old result is not silently replaced and copying is disabled. Press Regenerate and verify the new result follows the displayed rules. Show/hide must not replace the result or alter what gets copied.
7. **Clipboard:** copy and paste into a disposable local text field; confirm an exact match and success feedback. With automatic clearing enabled and the app allowed to run, verify clearing after approximately 30 seconds. Repeat but copy unrelated content from another app before the deadline; it must survive. Repeat with newer content from TimeAuth and with identical text copied again; the earlier cleanup must not clear a newer revision. Background the app beyond the deadline and return; verify pending cleanup is retried against the original deadline and current ownership metadata. Also verify the disabled-clearing setting. Test clipboard failures without exposing password values in diagnostics. Record actual process-termination behavior without treating cleanup after a forced kill as guaranteed.
8. **Session and persistence:** switch to Settings and back, change theme, change locale, and background/foreground the app; the password must remain the same until explicitly regenerated while the process survives. After a full process restart, confirm the last successfully saved rules are restored and the previous password is not restored.
9. **Sensitive screen:** attempt a screenshot and recording on Generator; inspect recent-app previews with the result both shown and hidden. Repeat with the optional extra preview setting off. Background content must stay protected; capture policy on Settings and About must retain its existing behavior.
10. **Languages and layout:** check English, Simplified Chinese, Taiwan Traditional Chinese, Hong Kong Traditional Chinese, and Follow system. Check light, dark, and system themes, narrow phones, and large font settings. Error messages, advanced controls, and a 128-character result must fit without blocking Copy or Regenerate.
11. **Failure recovery:** in a local debug-only build, make the Rand capability query return false and confirm the device-not-supported message. Separately make the query throw or the random provider fail and confirm the retry message. In each case confirm that the current result is cleared, copying is disabled, and the error category persists across tab, language, and theme changes. Restore the adapter and confirm regeneration recovers. Separately simulate preference read/write or flush failure; confirm a settings error is surfaced and no generated password is written as a fallback. Remove debug fault injection before shipping.

Repeatedly generating different-looking values is not a proof of cryptographic randomness. Host verification checks selection logic; the native adapter and device behavior need the build and acceptance checks above.


## Passphrase mode

- Uses all 7,776 entries of the EFF Large Wordlist, bundled offline in `PassphraseWords.ets`. The exact original list and its checksum are checked by host tests; see `THIRD_PARTY_NOTICES.md` and the in-app About license notice for attribution.
- Default: 6 English words, hyphen separator, lowercase, no appended digit. Word count supports 4–10 via plus/minus controls. The UI recommends at least 6 for important passwords.
- Separators: hyphen, space, underscore, period. An empty separator is intentionally unavailable. The four hyphenated EFF entries do not have standalone first fragments in the list, so hyphen-delimited outputs remain uniquely decodable; a test verifies this property.
- Optional capitalization changes only each word's first letter; optional number appends one independently sampled digit from 0 to 9 to the whole phrase.
- Word draws use 16-bit rejection sampling: accept values below 62,208, then take modulo 7,776. Sampling is with replacement; repeated words are valid and are not silently replaced.
- Entropy is word count × log2(7,776), plus log2(10) if a random digit is appended. Fixed capitalization and separator selection add no entropy. Six default words provide about 77.55 bits and retain the existing Strong label (Very strong begins at 80 bits).
- Changing mode or rules preserves the current result and disables copying until Regenerate applies the new rules. Generation settings and selected mode persist; generated values remain memory-only, with existing show/hide, clipboard cleanup and screen protection.
- Existing password-only v1 preferences gain default passphrase settings while preserving saved password rules. Password length remains 8–128, default 16. Inactive password rules do not block phrase generation.

Device acceptance: switch to Passphrase, regenerate offline, and check 4/6/10 words, all four separators, capitalization, and digit on/off. Verify copied text exactly matches the shown result, including spaces and any hyphenated words. Switch tabs, language and theme, then restart the process to verify result retention within a session and settings-only retention across restart. Switch modes without regenerating and confirm that copying is disabled with a reminder; regenerate and confirm recovery. Check compact phones, large text, light/dark modes, unsupported capability and retryable failures.
