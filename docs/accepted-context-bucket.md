# Accepted channel memory during context navigation

N24g covers a previously accepted channel window after a canonical thread and
Back. Double-clicking its Activity row opens the channel immediately while an
uncached message context request waits. The destination's accepted memory
rows and pagination metadata must remain available until the context replaces
them atomically.

Pinned Source `messageStore.ts:1246–1252` projects each channel's accepted
bucket. `ChatPanel.tsx:223` subscribes to that destination bucket, independent
of the last selected channel. `messageStore.ts:2374–2412` changes the current
channel, loading metadata and focus without replacing `channelMessages`.
Context acceptance at `messageStore.ts:2440–2460` replaces the bucket and its
metadata together. These are memory buckets; this contract does not imply
that disk-only or unaccepted private records may become visible.

The controller now records the owning session, principal, server and authority
epoch with each accepted in-memory window. A cross-channel pending context
projects that destination bucket only if its owner token and channel capability
authority still match. Its accepted `hasMore`, `hasNewer` and `historyLimited`
metadata are restored together. Unknown ledger rows and windows from a changed
principal, client generation or capability remain suppressed. Context request
generation, navigation revision, revocation and atomic acceptance fences remain
in force.

`accepted_context_bucket_test.dart` contains three actual N24g WorkspaceView
pages, one for each theme. Each first accepts a channel tail through its real
GET, double-clicks a different Activity thread, observes its painted reply,
uses platform Back, and double-clicks the original channel row. All 12 observed
pending frames contain the accepted destination tail and its original metadata;
neither the unrelated parent nor its private reply paints. There is no extra
destination-tail GET. Releasing the held context paints only the new target and
accepts its replacement metadata without another history entry. Four additional
controller tests check an accepted context window and its owner-token fences.
The existing unaccepted cross-channel suppression regression is retained.

The unchanged pre-fix controller failed all three mounted cases with an empty
destination projection. That receipt is preserved at
`.local/accepted-context-bucket-baseline-fail.log`. The final related run passed
97 tests, including the seven new N24g checks, and application analysis was
clean. Receipts are `.local/accepted-context-bucket-final-v3.log` and
`.local/accepted-context-bucket-analysis.log`. Earlier command attempts are
preserved separately and are not used as the passing receipt.

C's original real Source/Linux pair remains a FAIL, under
`cody-parallel-members/.local/process-parity-c/pair-after-thread-double-v5-brutal-desktop.json`.
Its unchanged fixture SHA-256 is
`85bfcae038858f916e479734017c0d559523b23ef800749017125fe1b7e7a056`.
The real Source browser restored its earlier Android memory tail during the
held context GET; the earlier Flutter process omitted it. This commit supplies
mounted page and controller evidence. A native rerun of this repair belongs
to the process verification owner and is not claimed here.
