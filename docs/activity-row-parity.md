# Activity row structure and input

Source: `raft-source` 26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6, `packages/web/src/components/thread/ThreadsInbox.tsx` InboxRow and legacy toolbar.

The row title now places the original raft-ui ThreadIcon / DirectMessageIcon inline with its text. Continuation lines use the full title column. The row action and timestamp share Source’s 150ms opacity transition: hover, row focus, descendant focus, or touch reveal the action and hide the timestamp without changing the title width. Nested action activation does not open the conversation. Restore uses RotateCcw. The action keeps the original 28px layout box on touch; the former 48px layout box shifted the glyph and could put its center outside a compact Stack’s hit area.

Brutal page overrides use black/30 borders, black/45 icons and subtitles, black/40 timestamps, black/70 sender names, and black or black/55 body/title text according to unread state. These are the product’s explicit CSS utilities; warm semantic ink tokens are different colors. Activity’s segmented toolbar now uses the generated SegmentedControl recipe and its 12px labels. Text reuses the existing CSS line-box component.

The original 342×620 Activity fixture now declares desktop pointer density, matching Chromium’s actual `(hover:none) == false` in that capture. Provider `android` is the official Flutter Widget provider name, not device execution. IDs, Source implementation, cached React PNGs and pass threshold remain unchanged. Real touch behavior is separately exercised in widget and native fixtures.

## Evidence and limits

Private incremental comparisons: 91.957% before, 92.177% after inline structure and input correction, 92.338% after line boxes, 95.974% after actual color overrides, and 96.633% after the generated segmented recipe. Original Brutal case passes; Elegant light 92.643% and dark 88.445% remain different. The header still includes the client’s advanced-filter affordance; the Source feature-gated Activity sidebar and filter flows need further alignment. A pixel pass is not full functional parity.

Six shared native fixtures cover the three themes with desktop and touch input, stable timestamp geometry, keyboard opening, descendant focus, nested action activation, and row navigation. The original minimal touch fixtures failed on both native renderers because the inflated action center was clipped; failure logs and Linux frame captures are retained. The first engineering run separately failed the design-system ratchet for a duplicate inline duration; both opacity users now refer to one Source-derived recipe value. These attempts remain failures, not NOT_RUN.

The full 99-case and project checks, exact input hash, current native receipts, screenshots and prior attempts are recorded in the published batch receipt. Shared native fixtures do not establish authentication, operating-system notifications, or full application flows. Markdown wrapping work was deferred at the owner’s instruction (2941ea76).
