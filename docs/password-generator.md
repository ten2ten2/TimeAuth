# Password generator

The Generator tab creates real random passwords, passphrases and PINs locally. Authenticator codes, vault entries, and unlock remain preview features; there is no encrypted vault integration or real user authentication in this milestone.

## Supported behavior

| Control | Behavior |
| --- | --- |
| Tabs | Native top tabs for Password, Passphrase and PIN, each with its own result, settings and scrolling area. Horizontal swipe switching is disabled. Each fresh app session starts on Password; navigating away and back within the same session retains the selected tab. First visible entry into each tab generates once; revisiting a tab retains its result. |
| Length | Integer from 8 to 128; default 16. Drag the slider thumb or edit the number field; tapping or starting a drag on the track does not change the value. Existing saved lengths are preserved. The Reset to 16 button restores only the length and updates the saved rules; generating a replacement password still requires Regenerate. |
| Character types | Lowercase letters, uppercase letters, numbers, and symbols can be enabled independently. All four are enabled by default. At least one type is required. |
| Avoid ambiguous characters | Enabled by default; removes exactly `0`, `O`, `1`, `I`, and `l`. |
| Use every selected type | Enabled by default; requires at least one character from every enabled type. |
| Allowed symbols | Custom set of ASCII punctuation. Duplicate symbols count once. Letters, numbers, spaces, full-width punctuation, and other Unicode characters are rejected when symbols are enabled. An empty symbol set is invalid when symbols are enabled. Reset restores the default symbol set. |
| Tap result | Tap the shown result or its hidden placeholder to copy the exact underlying value. A lightweight background press/release effect confirms interaction. Native button semantics also support keyboard and accessibility activation. Changed rules, invalid drafts and inactive tabs cannot copy. |
| Show / hide | Secondary button beside Regenerate; toggles visibility without generating or changing the result. Disabled when there is no result. |
| Regenerate | Explicitly applies the draft options and replaces the current result after successful generation. |
| Action row | Regenerate is the primary action; Show/Hide is the secondary action on the same row. There is no separate Copy button; the result area is the copy target. |
| Strength | Password and Passphrase combine the current result's strength and estimated entropy in one paragraph below the result/copy hint, for example, "Password strength: Very strong. Estimated entropy: 100 bits…". Only the qualitative rating uses its strength color; the remaining explanation uses secondary text color. There is no top strength/count header. PIN has no strength/entropy display. |
| Remember settings | Persists generation preferences locally. Generated passwords and history are not persisted. |

Editing options does not silently replace the current password. Changed options display a reminder to regenerate; copying stays disabled until a password matches the current options. An explicit missing random capability displays a device-not-supported message. A capability-query exception or random-provider failure displays a separate retry message. Both failure categories clear the current result, prevent copying, and survive page recreation until a subsequent generation succeeds. There is no fallback to demonstration strings or a noncryptographic random source.

All three tabs keep independent results, draft settings and generation errors in memory while switching tabs, changing language or theme, and returning from the background in the same app process. Clipboard feedback belongs to the tab that initiated the copy; a late completion after leaving the tab cannot announce success on a subsequent visit. OS process termination or an app restart discards that result. Generation settings survive restarts when preference storage succeeds. Storage failure is reported; do not assume settings were saved after an error.

Generation history, saving into the vault, and batch generation are future work. All three modes in the top tab bar are implemented.

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

All 100 host tests passed:

| Area | Passing tests |
| --- | --- |
| Generator engine | 15 |
| Passphrase engine and wordlist | 10 |
| PIN engine | 7 |
| Settings and session | 19 |
| Tab lifecycle and interaction methods | 21 |
| Clipboard | 23 |
| Onboarding persistence | 5 |

Host checks exercise generator rules and failure behavior with test random sources, settings/session behavior, and clipboard lifecycle handling with mocked platform APIs. Tab tests execute actual component lifecycle and event methods after removing decorators and UI builders; native prop notifications, layout and touch behavior require device testing. They cannot establish that ArkTS compiles, that the native random source works, or that OS clipboard and screen-protection behavior matches the application policy.

The native HAP build and real-device tests have not been executed. This feature still requires a DevEco Studio build and physical HarmonyOS device acceptance.

## Device acceptance checklist

Use a development build with disposable generated values. Record the device model, HarmonyOS version, app version, and result for each case.

1. **Build and offline start:** build and install the `entry` module using the configured compatible SDK. Open Generator in airplane mode. Confirm a real result appears without a network requirement. Confirm Password, Passphrase and PIN are separate top tabs. Each generates on its first visible visit without pressing Regenerate; switching back retains the same result and copy eligibility. Check that horizontal gestures do not change tabs, and each page scrolls vertically with its tab bar remaining accessible.
2. **Length boundaries:** generate at 8, 16, and 128 characters, checking the copied length. Confirm a fresh install defaults to 16 and an existing saved length (including 20) survives an update. Confirm the number field and slider agree. Swipe vertically starting on the track and on the thumb, and tap or drag from the track away from the thumb: the length must stay unchanged during page scrolling. Drag horizontally from the thumb's native touch target to adjust; confirm keyboard and accessibility adjustment still work. Enter an empty value, 7, 129, and a decimal if the keyboard permits; invalid drafts must not generate or copy. A 128-character result must remain readable by wrapping or scrolling, without truncating the copied password.
3. **Character classes:** test each class alone and several combinations. Turn off the final remaining class; generating with no characters must be prevented and the UI must explain the requirement or retain one enabled type. Enable the every-type requirement and verify each selected class appears. Disable it and verify generation still obeys the allowed alphabet without promising every class.
4. **Ambiguous characters:** with avoidance enabled, verify generated values exclude `0/O/1/I/l`. With it disabled, those characters become eligible; no individual result is required to contain them.
5. **Custom symbols:** set symbols to `!@!` and generate using symbols only. Results must use only `!` and `@`, with duplicates not changing the reported entropy. Test an empty set, a space, an ASCII letter, a number, a full-width symbol, and an emoji. Invalid active symbol rules must block generation and copying. Reset symbols and confirm generation recovers. Turn symbols off and confirm no punctuation appears in the result.
6. **Draft and result:** tap shown and hidden results in all three tabs and verify exact clipboard content, including PIN leading zeros and passphrase separators. Confirm success feedback and that rapid taps do not start concurrent copies. After changing rules, tapping must not copy the old result. Then note a generated result, change its length or a toggle, and verify that the old result is not silently replaced and copying is disabled. Press Regenerate and verify the new result follows the displayed rules. Show/hide must not replace the result or alter what gets copied.
7. **Clipboard:** copy and paste into a disposable local text field; confirm an exact match and success feedback. With automatic clearing enabled and the app allowed to run, verify clearing after approximately 30 seconds. Repeat but copy unrelated content from another app before the deadline; it must survive. Repeat with newer content from TimeAuth and with identical text copied again; the earlier cleanup must not clear a newer revision. Background the app beyond the deadline and return; verify pending cleanup is retried against the original deadline and current ownership metadata. Also verify the disabled-clearing setting. Test clipboard failures without exposing password values in diagnostics. Record actual process-termination behavior without treating cleanup after a forced kill as guaranteed.
8. **Session and persistence:** switch to Settings and back, change theme, change locale, and background/foreground the app; the password, passphrase and PIN must each remain the same until explicitly regenerated while the process survives. Leave different draft rules in all three tabs, switch repeatedly, and confirm each draft and its copy-disabled state stay with the appropriate result. After a full process restart, confirm Password opens by default and each tab restores its last successfully saved rules when visited, while none of the previous results are restored. Update from the shared-settings version and verify the saved password length and phrase word count both migrate, even if one tab is edited before the other is first visited.
9. **Sensitive screen:** attempt a screenshot and recording on Generator; inspect recent-app previews with the result both shown and hidden. Repeat with the optional extra preview setting off. Background content must stay protected; capture policy on Settings and About must retain its existing behavior.
10. **Languages and layout:** check English, Simplified Chinese, Taiwan Traditional Chinese, Hong Kong Traditional Chinese, and Follow system. Check light, dark, and system themes, narrow phones, and large font settings. Error messages, advanced controls, and a 128-character result must fit without blocking the copy target or the Regenerate / Show-Hide row.
11. **Failure recovery:** in a local debug-only build, make the Rand capability query return false and confirm the device-not-supported message. Separately make the query throw or the random provider fail and confirm the retry message. In each case confirm that only the failing tab's result is cleared, copying is disabled there, and the error category persists across tab, language, and theme changes. Switching away and back must not implicitly retry a failed generation or clear the other tab's result. Restore the adapter and confirm regeneration recovers. Separately simulate preference read/write or flush failure; confirm a settings error is surfaced and no generated password is written as a fallback. Remove debug fault injection before shipping.

Repeatedly generating different-looking values is not a proof of cryptographic randomness. Host verification checks selection logic; the native adapter and device behavior need the build and acceptance checks above.


## Passphrase mode

- Uses all 7,776 entries of the EFF Large Wordlist, bundled offline in `PassphraseWords.ets`. The exact original list and its checksum are checked by host tests; see `THIRD_PARTY_NOTICES.md` and the in-app About license notice for attribution.
- Default: 6 English words, hyphen separator, lowercase, no appended digit. Word count supports 4–10 via plus/minus controls. The UI recommends at least 6 for important passwords.
- Separators: hyphen, space, underscore, period. An empty separator is intentionally unavailable. The four hyphenated EFF entries do not have standalone first fragments in the list, so hyphen-delimited outputs remain uniquely decodable; a test verifies this property.
- Optional capitalization changes only each word's first letter; optional number appends one independently sampled digit from 0 to 9 to the whole phrase.
- Word draws use 16-bit rejection sampling: accept values below 62,208, then take modulo 7,776. Sampling is with replacement; repeated words are valid and are not silently replaced.
- Entropy is word count × log2(7,776), plus log2(10) if a random digit is appended. Fixed capitalization and separator selection add no entropy. Six default words provide about 77.55 bits and retain the existing Strong label (Very strong begins at 80 bits).
- Switching tabs displays the selected tab's own result and settings. Each tab generates once on its first visible visit; later visits retain that result. Changing rules within a tab preserves its old result and disables copying until Regenerate applies those rules. Generation settings persist across restarts; the selected tab is remembered only within the running app session; generated values remain memory-only, with existing show/hide, clipboard cleanup and screen protection.
- Each tab has a separate v2 preference key. The old `timeauth.generator.mode.v1` selection key is ignored and no longer written; a legacy mode stored alongside generation rules also does not select the startup tab. Password and Passphrase tabs without v2 settings read their rules from the original v1 record. PIN starts with its own default six-digit settings and does not read the legacy record. The original record is retained so saving the first migrated tab cannot overwrite the second tab's not-yet-migrated rules. Invalid drafts are retained only in their own memory session and never replace valid saved settings. A settings flush failure that completes while a tab is hidden is retained and displayed when it is revisited.
- Existing password-only v1 preferences gain default passphrase settings while preserving saved password rules. Password length remains 8–128, default 16. Inactive password rules do not block phrase generation.

Device acceptance: first enter the Passphrase tab offline and confirm automatic generation, and check 4/6/10 words, all four separators, capitalization, and digit on/off. Verify copied text exactly matches the shown result, including spaces and any hyphenated words. Switch tabs, language and theme, then restart the process to verify result retention within a session and settings-only retention across restart. Switch between tabs without changing rules and confirm each result remains copyable and unchanged. Edit rules within one tab and confirm only that tab requires regeneration; the other tab remains usable. Check compact phones, large text, light/dark modes, unsupported capability and retryable failures.


## PIN mode

- A third native tab produces fixed numeric strings of 4, 6 or 8 digits; default 6. These are user-settable numeric passwords, not server-issued verification codes or TOTP codes.
- Uses the same HarmonyOS secure random adapter and bounded rejection sampler as the other generators. Each digit accepts random bytes below 250 and maps them modulo 10. All ten digits are equally eligible in every position, including zero in the first position. Repeated digits and all-zero outputs remain eligible; no pattern filtering is applied.
- PIN length is a separate `pinLength` setting. Password character exclusions, password length and passphrase rules never alter PIN generation. Results remain strings through display, session retention and copying, so leading zeros survive.
- Entropy is digit count × log2(10): about 13.29, 19.93 or 26.58 bits. PIN does not show a strength label or entropy detail in the UI; the internal entropy calculation remains available for verification. Password and passphrase strength displays are unchanged. The PIN card explains that short numeric codes depend on a device or app limiting guessing attempts; secure randomness does not give a short PIN the search space of a long password.
- PIN digits use equal-width cells (normally 20 vp) with 6 vp gaps only between cells, and an adaptive 18–28 fp monospace font. The complete row is centered on the same axis as the copy hint, without trailing letter spacing. Hidden dots occupy the same cells so showing/hiding does not shift the group. The row is constrained to the available width and cells can shrink on narrow screens. Spacing is visual only: copying uses the original continuous numeric string, including leading zeros.
- First visible visit generates once. Returning to the tab preserves its current result. Changing the digit count keeps the old result and disables copying until explicit regeneration. Show/hide and copy feedback refer to PIN, and the existing sensitive-screen and clipboard protections apply.
- PIN settings use `timeauth.generator.options.pin.v2`; PIN selection is retained only in memory until the app session ends. Upgrading older password/passphrase preferences supplies the missing PIN default without changing their own settings. Teardown clears the retained results for all three sessions.

Device acceptance: in airplane mode, first enter PIN and confirm six digits. Confirm PIN has no strength/entropy assessment and both shown digits and hidden dots are centered with clear spacing. Test all three digit counts, including a disposable result starting with zero; paste into a local text field and verify exact length and all leading zeros. Change length and verify the result changes only after Regenerate. Switch among all three tabs, edit their settings independently, return from Settings, change language/theme, and verify each result and draft stays in its own tab. Restart the process: Generator must first open Password. Then select PIN and confirm its last saved length restores while its old result does not. Check the three-tab labels and length controls on narrow screens and large fonts, in all four locales and both themes. Repeat unsupported-capability, retryable-failure, clipboard and sensitive-screen checks in PIN mode.


## Tab lifecycle regression

- Native `Tabs` and every `GeneratorPanel` share the same selected index through `@Link`, instead of passing a computed active/inactive boolean into lazy `TabContent` builders. This lets panels observe index changes directly without depending on a builder being re-evaluated.
- Every panel restores its own fixed mode, rules, retained result and failure state in `aboutToAppear`, even when initially inactive. Rendering the options card uses the panel's fixed mode. Automatic generation waits until that tab is selected and has neither a retained result nor a generation error.
- Host regression cases cover inactive restoration, index changes before a lazy child appears, and the reported sequence: **PIN → Password → Authenticator → Generator → PIN**. The final PIN tab must show its retained numeric result, remain copyable and leave the Password result unchanged. Cold-start tests seed the old persisted PIN/passphrase selection keys and verify that Password still opens first.
- Repeat that sequence on the physical device, including fast repeated switching and both themes. Host tests simulate lifecycle calls and link notifications; they do not execute native ArkUI binding or layout. HAP compilation and the native reproduction path still require DevEco Studio/device verification.


## Result press feedback

- The shown/hidden result and its copy hint form one native Button with custom content. Its background uses the existing surface colors: 80 ms into the pressed state and 120 ms back to normal. No scaling or positional animation is applied to the digits or text.
- Touch handlers only manage visual feedback. The native `onClick(callback, 8)` recognizer owns the click movement threshold and competes with the parent Scroll; touch-up never copies. The existing in-flight guard prevents repeated clicks from creating concurrent writes, while the copy target stays visually stable during the pending operation.
- Movement beyond 8 vp on either axis, leaving the measured result bounds, multi-touch, touch cancellation, scroll start, rule edits, regeneration and tab disappearance reset the visual press. Finger movement is measured in window coordinates so a result resizing after regeneration cannot look like finger motion. No event propagation is stopped.
- Visual feedback cannot veto a recognized native click: touch samples may be empty, resampled, or delivered separately from click recognition. There is no persistent touch-cancel flag to carry into the next result. Up/Cancel always reset the visual state, and a new Down starts fresh even if the last visual Up was missing. See the official [touch-event contract](https://github.com/openharmony/docs/blob/master/en/application-dev/reference/apis-arkui/arkui-ts/ts-universal-events-touch.md) and [native click movement threshold](https://github.com/openharmony/docs/blob/master/en/application-dev/reference/apis-arkui/arkui-ts/ts-universal-events-click.md).
- The tab's active flag is observable state because the result button's enabled state depends on it. Returning to an existing tab must refresh eligibility even when the retained result and rules have not changed.
- Mouse, keyboard and accessibility clicks retain the same result-validity, active-tab and clipboard checks. The original string is copied, including PIN leading zeros and passphrase separators; visual spacing never enters the clipboard.

Host regressions cover repeated option edits followed by regeneration and copying in all three modes, empty release samples, a prior cancelled press, click-before-release/missing visual release, and result reflow under a stationary finger. They invoke component methods; they do not emulate native gesture recognition or ArkUI state subscriptions.

Device acceptance: press/release shown and hidden results in all three modes, in light/dark themes; confirm the subtle background transition, stable text, and exactly one success message after the copy succeeds. Repeatedly change length, character types, word count, separator and PIN length, regenerate, then immediately tap to copy; paste into a disposable field and confirm the latest result. Repeat after scrolling and switching away/back with a retained result. Start a vertical scroll on the result, drag outside and back in, use two fingers, and leave the tab while pressed; verify native gesture cancellation without unintended copies or a stuck background. Confirm long passwords and 10-word passphrases fit and scroll inside the page, and that keyboard/screen-reader activation can copy with no dedicated Copy button. Check the combined strength/entropy paragraph for Password/Passphrase in all four locales: only the rating is colored, the text wraps naturally, and the rating/color/entropy update after regeneration. Confirm there is no top strength/count header or empty header gap in any mode, and that PIN has no strength paragraph. Check the shared Regenerate / Show-Hide action row. Native animation, layout, gesture arbitration and accessibility still require HAP/device verification.
