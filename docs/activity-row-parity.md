# Activity row structure and input

Source: `raft-source` 26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6, `packages/web/src/components/thread/ThreadsInbox.tsx` InboxRow and legacy toolbar.

The row title now places the original raft-ui ThreadIcon / DirectMessageIcon inline with its text. Continuation lines use the full title column. The row action and timestamp share Source’s 150ms opacity transition: hover, row focus, descendant focus, or touch reveal the action and hide the timestamp without changing the title width. Nested action activation does not open the conversation. Restore uses RotateCcw. The action keeps the original 28px layout box on touch; the former 48px layout box shifted the glyph and could put its center outside a compact Stack’s hit area.

Brutal page overrides use black/30 borders, black/45 icons and subtitles, black/40 timestamps, black/70 sender names, and black or black/55 body/title text according to unread state. These are the product’s explicit CSS utilities; warm semantic ink tokens are different colors. Activity’s segmented toolbar now uses the generated SegmentedControl recipe and its 12px labels. Text reuses the existing CSS line-box component.

The original 342×620 Activity fixture now declares desktop pointer density, matching Chromium’s actual `(hover:none) == false` in that capture. Provider `android` is the official Flutter Widget provider name, not device execution. IDs, Source implementation, cached React PNGs and pass threshold remain unchanged. Real touch behavior is separately exercised in widget and native fixtures.

## Evidence and limits

Private incremental comparisons: 91.957% before, 92.177% after inline structure and input correction, 92.338% after line boxes, 95.974% after actual color overrides, and 96.633% after the generated segmented recipe. Original Brutal case passes; Elegant light 92.643% and dark 88.445% remain different. The header still includes the client’s advanced-filter affordance; the Source feature-gated Activity sidebar and filter flows need further alignment. A pixel pass is not full functional parity.

Six shared native fixtures cover the three themes with desktop and touch input, stable timestamp geometry, keyboard opening, descendant focus, nested action activation, and row navigation. The original minimal touch fixtures failed on both native renderers because the inflated action center was clipped; failure logs and Linux frame captures are retained. The first engineering run separately failed the design-system ratchet for a duplicate inline duration; both opacity users now refer to one Source-derived recipe value. These attempts remain failures, not NOT_RUN.

The full 99-case and project checks, exact input hash, current native receipts, screenshots and prior attempts are recorded in the published batch receipt. Shared native fixtures do not establish authentication, operating-system notifications, or full application flows. Markdown wrapping work was deferred at the owner’s instruction (2941ea76).

## Follow-up: theme paint and inherited typography

Fresh Source measurements retained the exact SHA-256 of all three previously
captured theme PNGs. ActivityInboxPanel has a 1px attached left edge in every
theme, with its own canvas fill beneath translucent borders. Elegant InboxRow
text inherits Inter from this product panel; it does not inherit the explicit
Geist `font-sans` used by its toolbar. Dark row borders are transparent and the
Card elevation includes an inset top-light as well as exterior dark shadows.
The client now follows these rules through the shared CSS painter.

Canonical mobile PanelHeader uses its generated title/meta recipes and CSS
line boxes. The measured Elegant title is Inter 17/21.25 with -0.425px tracking;
the subtitle is Geist 12/15 with a 4px gap. Brutal's title is 16/20 and the
subtitle remains Geist Mono 12/16. The Tasks header retains its separate
product variant. The Activity header no longer adds an unsupported Filters
button; Source places the feature-gated scope controls below the header.
Mark all read uses Source's outline/sm recipe with its explicit 32px height,
8px horizontal padding and 12/16 bold label.

Resource badges reduce CSS rounded-full radii to half their 18px height before
painting; the generated max-double value overflowed Skia's radius arithmetic
and produced square badges. Product decoration overrides now also determine
the CSS painter's inset radius, so InboxRow's 6px corners use the same geometry
for their background, border and inset layers.

The final private comparison is Brutal **96.83% PASS**, Elegant light **95.81%
DIFF**, and Elegant dark **91.44% DIFF**, under the unchanged 96% basic threshold.
Earlier private attempts remain preserved. The final capture receipt confirms
unchanged input during capture, unchanged Source checkout, and no provider
errors. It is a Flutter widget capture, not an Android device result.

Focused verification: 18 app tests cover measured header geometry, Activity
inline layout and existing desktop/touch input; SDK tests verify the painted
badge corners, decoration-override inset geometry and existing three-theme
black-flash transitions. The feature-gated Activity sidebar/scope flows,
desktop canonical header composition, remaining shadow raster differences and
Markdown preview wrapping are still separate parity gaps. This follow-up does
not claim current full application or full 99-case verification; the integrating
agent runs those after consolidation.


## SDK ownership and retained Activity test contracts (2026-10-09)

The conversation card, its source recipe, pointer/focus action scope, timestamp
fade and Source task-row measurement now live in `raft_ui/src/resource_cards.dart`.
The app keeps a compatibility export and its relative-time formatter. This is a
UI-only SDK boundary: no controller, API, account, permission or route payload
moved into the SDK. The measured toolbar/header values live with
`RaftResourceMetrics`; this transfer preserves their paint and geometry.

The classic Source header has no Filters, Unfollowed or group-toggle entry.
Tests previously tried to enter those unsupported controls before exercising
unrelated row actions. They now assert that those entries are absent, invoke the
real ResourceView state for retained done/unfollowed request and local grouping
projection contracts, and still use the real visible All button to return from
terminal protocol states. Original API-path/query/frontier/authority assertions
remain. These state-seeded tests do not prove a visible Source entry for these
protocol states. The `activity_sidebar_inbox_v0` feature-gated sidebar, compact
scope switcher, channel groups and advanced new-inbox behavior remain
unimplemented by this change. No invented switcher opens the old advanced UI.

The Mark-all-read stale-handler test locates the mounted `RaftInteractive` by
its semantic label, captures the actual handler, changes authority, and invokes
that retained handler; no read-all POST is still required. Previous complete-run
failures are retained by the integration owner. This batch does not rerun or
relabel official pixel results, native behavior or any previously failed pair.
