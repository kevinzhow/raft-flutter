# Live arrival during context preparation

The full Linux application run at `d3efafc`, source input
`e90fa508115f6f50d3e8acf3c69ad702e677a85eb435dd4ae99e0580d205da11`,
failed after eight checkpoints. `ChatAnimatedList._onInserted` dereferenced a
missing `SliverAnimatedListState` at vendored line1104. The unchanged-source
receipt, native log and screenshots remain in
`.local/cody-full-native-linux-d3efafc/`; this run remains failed.

The app's hidden context measurement replaced Flyer's animated sliver with a
plain bounded column. Flyer's message-operation subscription remained alive,
so a real insertion between measurement and the next frame had no animated
list to update. `chat_arrival_staging_test.dart` reproduces the same exception
in all three themes using an independently completed context request and a
peer message arriving between frames. The exact baseline test hash is recorded
in `.local/cody-arrival-staging-exact-before.json`; all three matching failures
remain in `.local/cody-arrival-staging-before-peer-exact.log`.

The animated sliver now remains mounted offstage during bounded measurement.
It owns the focus anchors throughout; the measurement column supplies height
without duplicate anchors. During preparation, the app's context positioning
also owns scrolling. Once published, normal own-message scrolling resumes and
incoming-message scrolling uses the app's actual at-bottom state. No operation
or exception is discarded, and the dependency is unchanged.

The three regressions verify continuous old paint, the first published target
centered without visible retry, and the new message reachable by real scrolling.
Together with the existing context and accepted-cache tests, the focused run
passed13 checks. Earlier fixture setup failures, the interrupted test, and the
first repair's positioning failures remain separate logs, rather than being
reclassified as the original product exception.

This is mounted component proof. Full Linux, Android and paired-process
receipts must be reported at their actual tested snapshots after execution.
Neither the focused pass nor older native passes verifies the new full app.
