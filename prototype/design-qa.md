# Product Design QA — 见舟提词

final result: passed

Scope: interaction prototype only. This result does not verify iOS/Android native overlay, speech recognition, microphone sharing or device installation.

## Source and comparison evidence

- Selected source: `../design/03-writing-selected.png`, the third displayed generated design, explicitly selected by the user.
- Browser: local Microsoft Edge via Playwright, authorized by the user in this chat. The in-app browser tool was unavailable.
- Host viewport: 1400 × 1200, deviceScaleFactor 1. Verified iPhone screen: 393 × 852 CSS pixels, no scaling. Android preview: 427 × 952.
- Source normalized proportionally to 393 px width for comparison. Source omits system chrome; implementation retains template-owned status bar, camera cutout, device frame and home indicator. Vertical shifts from the 54 px iOS top area are expected.
- Both source and current implementation were opened together in `qa/home-comparison.png`; typography and editor hierarchy were inspected together in `qa/typography-comparison.png`.
- Additional visible states inspected: `qa/prepare.png`, `qa/settings.png`, `qa/reading.png`, `qa/floating-demo.png`, `qa/home-android.png`.

## Findings and fixes

- [P1, fixed] Initial content extended behind the fixed header and status area. The app-owned MobileScroll wrapper now has a sufficiently specific relative-position rule; the protected runtime was not changed. Subsequent home screenshots show the header and content separated.
- [P2, fixed] The large-font preview expanded with its text and pushed the main action below the viewport. Preview height is now fixed, with an explicitly clipped preview area; the updated 48-point screenshot keeps the action available.
- [P2, fixed] A fully dark reading toolbar put black template status icons on dark content. Reading uses the product's light toolbar above its dark reading area, preserving readable system chrome.
- [P2, fixed] Initial textarea line spacing was looser than the selected mock. Line height changed to 1.6; the subsequent combined comparison shows closer paragraph rhythm and preserves the original content.
- No unresolved P0/P1/P2 issues in the checked prototype states.

## Required fidelity surfaces

| Surface | Result |
| --- | --- |
| Typography | System Chinese sans-serif, 29 px main heading, 17 px script title, 16 px script body. Heading, subtitle and editor hierarchy match the selected direction. The focused comparison was inspected after the line-spacing fix. |
| Layout and spacing | Script-first hierarchy, large editor, two-mode selector, primary action, import and recent scripts preserved. Additional new-script/help items continue below the fold. Keyboard and sheets use the template components. |
| Color and tokens | Near-white surface, charcoal text, purple primary action, pale-purple selected mode. A flat primary fill replaces minor generative shading; no invented decorative imagery. |
| Assets and icons | Consistent Radix icons; no fake camera screenshot. A standard Reader icon marks the product entry, rather than treating the generated boat as a finalized brand logo. This is a minor brand detail, not a missing functional asset. |
| Copy and content | Source copy preserved where meaningful. The image's illustrative “328 字” is replaced with the actual computed count and duration. Floating demo states explicitly describe their limits. |

## Interaction evidence

`qa/flow-results.json` records the actual browser checks: editing and reload persistence, settings, countdown cancellation, reading/pause, sentence navigation and reset, floating-demo drag/close, UTF-8 import, TXT export, empty-script disabling and both device previews. No uncaught browser errors were observed.

Settings were captured after the keyboard/sheet animation settled; the test asserts the simulated keyboard is closed before operating the sheet. The temporary transition capture was not accepted as the final layout.

## Implementation checklist

- [x] Source and implementation opened and compared in one visual input.
- [x] Required fidelity surfaces checked.
- [x] Primary flow and relevant states exercised in the browser.
- [x] Reported P1/P2 issues corrected and new screenshots inspected.
- [x] Production build and protected mobile runtime check passed.
- [x] Preview remains available locally.

## Follow-up polish and limits

- P3: A final brand mark can replace the neutral Reader icon if the user wants a dedicated app identity.
- Browser simulation does not verify a physical iPhone keyboard, native PiP controls, Android accessibility service or continuous voice following.
- The current reading prototype advances sentence emphasis by the configured timed pace. Native delivery still needs smooth reading-band scrolling and real-device tuning.
