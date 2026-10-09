# Pending-parent thread revocation (N24a)

Source `packages/server/src/services/channelService.ts:4697–4784` checks a
thread's real parent-channel access recursively. The active server is also an
explicit boundary. Accepted thread replies therefore remain private to that
parent even before the parent-message metadata request completes.

`WorkspaceController._revokeChannel` now derives the child thread ID and parent
draft key from the accepted pending thread identity, as well as the existing
loaded parent and ledger relationships. It retires child ledger/window/read
state, cancels private transfers, and removes the corresponding durable child
cache and `thread:<parentMessageId>` draft. The cache purge uses the captured
origin, principal and server and remains serialized behind previous cache
writes. The change does not require a fabricated parent-message record.

Two async controller tests use actual Dio HTTP requests and a real in-memory
Drift database. They hold parent metadata, a read acknowledgement and upload
responses independently after accepting private replies. Removing the parent
purges memory and durable data; late responses cannot recreate them. Removing
an unrelated channel preserves the real thread. Unrelated main conversation,
main draft/upload/read/cache and a same-named draft for another principal remain
accepted.

Six mounted tests cover those two channel-removal cases in all three themes.
Every observed frame after parent removal excludes private reply and parent
content, including after the held parent response is released. Unrelated
removal retains the visible reply and accepts the real parent.

The original controller fails the new durable test because `private-reply`
remains in the child ledger after parent removal; that baseline receipt is
preserved privately in `.local/pending-thread-revocation-baseline-fail.log`.
The repaired eight tests pass. Earlier widget harness attempts that stalled on
an already-completed FakeAsync gate are retained as private attempt logs; the
final storage tests use ordinary async execution and the mounted tests assert
the actual completed request-start event directly.

This scoped evidence does not cover the separate URI `msg` cleanup mismatch on
thread highlight expiry, nor replace the parent-owned native paired checks.
