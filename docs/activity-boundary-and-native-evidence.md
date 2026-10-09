# Activity layout and mobile DM checkpoint

The pinned Source is `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`.
`mounted_activity_boundaries_test.dart` mounts the real `WorkspaceView` with
controlled HTTP responses for all three supported themes. Its 24 layout cases
exercise both real flag responses at 767, 768, 1023 and 1024 pixels, tap the
actual Activity row, and assert the 219/220ms activation boundary, selected
location, displayed content and composer. Nine further cases tap actual mobile
DM rows with mention, unread or latest targets and verify one immediate history
entry, the context request and the displayed target. They do not prove OS input,
authentication or Socket.IO delivery.

The actual workspace grid test now crosses 1023/1024 while retaining its two
editors, draft and cursor, in addition to its existing narrow-screen lifecycle.
It verifies the mounted page rather than only the breakpoint function.

The initial new-test failures are retained under `.local`: they exposed incorrect
fixture expectations for Source's mobile mention priority, an unbound test
ledger and an unsettled initial page. The final attempts passed 33 Activity/DM
cases and the grid case. No product behavior was changed to satisfy those
fixture mistakes. Immutable machine receipts at the next integration checkpoint
bind these checks to the complete source inputs.

## Full native flow repair and pending proof

`integration_test/resource_flow.dart` previously tapped a nonexistent Activity
`Filters` control. Source's classic flag-off branch instead mounts
All/Unread/Mentions; its experimental flag-on branch owns the channel, query,
sort and grouping facets. The harness now checks the actual flag response and
the classic controls, exercises all three filters, and compares each accepted
ordered row identity to an independent backend inbox response. This explicitly
covers the classic branch; it does not cover the experimental facets or global
mark-all-read action.

The three historical full Linux failures remain failures. This harness repair
is not a completed native run. Full Linux and Android runtime receipts must be
reported separately after execution; widget tests and controlled message
process captures cannot substitute for them.

## Completion boundaries

Desktop typed Search-thread navigation has mounted three-theme proof. Narrow
Search-thread navigation and external Search/Activity URI bootstrap remain
separate requirements. N02 cannot be verified until its mobile child passes.
K09's explicit numeric badge API is separate from the actual product attention
indicator and generic sidebar count; its product child also remains required.
