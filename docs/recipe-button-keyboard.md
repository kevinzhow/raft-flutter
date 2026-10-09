# Dialog recipe buttons and avatar Close

The mounted avatar editor's Close action now renders only its 20px X in the
32px `icon-md` button. The accessible name is separate from visible content,
as in pinned Source `AgentProfileEditDialog.tsx:190`. Saving explicitly applies
the disabled recipe and prevents activation.

`RaftRecipeButton` now uses the existing `RaftInteractive` input handling:
Enter, Space, accessibility activation, mouse and touch share the callback.
Keyboard focus passes `focus-visible` to the generated recipe. Elegant shows
the recipe's ring; Brutal retains Source's transparent outline. Null callbacks
remain noninteractive; the explicit `disabled` flag still controls disabled
paint, preserving existing recipe fixtures. Layout dimensions are unchanged.

The old implementation failed Enter activation in all three themes. Retained
logs are `.local/cody-recipe-button-before2.log` (behavior failure) and
`.local/cody-recipe-button-before.log` (initial test compilation failure).
Current tests cover all activation routes, semantic name/role, stable layout,
and disabled input. Actual application tests also cover clean keyboard close,
dirty-close confirmation, keeping the draft, save-time dismissal prevention,
and permission/account revocation.

Input `65e97e2dcaafcfe0257f3856186540594b42d204f20835ad95ef6069e74ec4b1`
passed 1604 project tests (3 skipped), 75 host tests and static analysis.
The original visual suite remains **79/99 passing, 20 different** with no
missing captures. Avatar management improves slightly to 94.932%, still
different. All 99 React baseline PNGs and the pinned Source product are
unchanged. A separate matrix preserves 12 real theme pairs: 3 passing,
9 different, including unresolved Elegant pages. These are Widget captures,
not device screenshots.

Linux and Android emulator-5580 each passed 15 shared-control native tests,
retaining 273 frames per platform: the prior black-flash/menu scenarios and
the new three-theme dialog-button scenarios. Pixel readback confirms the
Elegant ring appears under keyboard input and clears under pointer input.
These controlled native fixtures do not establish full application parity,
authentication, IME or notifications; full application runs for this input
are **not run**. Earlier full-flow failures remain retained separately.

Raw evidence: `.local/cody-avatar-button-native-linux/frames/`, the separate
Linux log, `.local/cody-avatar-button-native-android/`,
`.local/cody-avatar-button-three-themes/`,
`.local/cody-avatar-button-focus-pixels.json`, and the engineering receipt.
Actual DOM and Flutter measurements in `.local/cody-source-avatar-geometry.json`
and `.local/cody-avatar-native-geometry2.log` confirm the modal, header, footer
and avatar-grid coordinates. The grid's pixels already agree nearly exactly;
remaining differences are retained rather than hidden by offsets.

SDK and application Widget Preview entry points expose the actual editor in
the three supported themes. Current evidence is published below the original
99-case report at the existing stable report URL.
