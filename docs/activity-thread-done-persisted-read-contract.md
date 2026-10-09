# Thread Done persisted read-all

This follow-up is based on Flutter `e1747b8` and pinned Source
`26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6` (Web 1.17.5). It adds the
persisted thread read side effect without changing the accepted Done frontier,
marker suppression, follow/unfollow overlay, evaluated Activity page, or routes.

## Source contract

- `packages/web/src/store/inboxStore.ts:1416–1443`: POST thread Done with the
  accepted storage frontier (legacy rows omit it), check the current Done
  generation **before** successful side effects, call `clearThreadUnread` with
  explicit human-self receiver and persisted-notification suppression, then
  await the first owned inbox refresh while marker suppression is still armed.
- `packages/web/src/store/threadStore.ts:853–883`: capture server, epoch and
  principal; always persist read-all, including when the caller suppresses the
  success notification. Do not await this write. A rejection publishes nothing.
  A late success must never perform another blind channel-wide unread clear.
- `packages/web/src/store/transport/inboxTransport.ts:177–249`: human-self uses
  `POST /channels/:threadChannelId/read-all` without a body. Same in-flight
  server/epoch/principal/receiver/channel shares the original promise; separate
  identities have separate slots. A detached success/error handler removes the
  slot without wrapping the returned promise.
- `packages/web/src/store/receiverPrivateIngress.ts:16–20,46–64`: presentation profile
  receiver and human Activity write context are distinct. This Done caller
  explicitly chooses human-self; it does not advance an agent receiver cursor.

The read-all request has no `seq`, Done frontier, receiver, or query parameter.
Its backend boundary is the real read-all operation at request time, not a
historical snapshot inferred from the displayed reply or the Done frontier.
New replies may arrive while it is in flight; its success must not locally
clear their unread state again.

## Implementation and ownership

`ResourceView.activityAction` starts the real read-all only after the existing
accepted authority and per-row Done ticket have passed the ACK guard. The
write's result is independent of the immediately started, awaited inbox
refresh. Read-all failure does not roll back a successful Done.

`SourceReadAllTransport` is scoped to the real shared `RaftClient`. It keys
human-self writes by origin, client generation, selected server, principal and
thread, and returns the exact first request Future to concurrent consumers.
No controller fields or second authentication transport are added.

A Dart Zone carries the owned request through Dio's asynchronous interceptor
queue. Only that matching POST, captured server header and null body receive
local `RequestOptions.extra` metadata. This metadata changes neither HTTP
headers nor the body. `SourceActivityUnreadStore` uses it to suppress the second
background persisted-read refresh; an ordinary concurrent request to the same
path still notifies and refreshes normally. Actual Dio adapter tests verify
both sides, rather than assuming the Zone survives dispatch.

The prior Done intent already clears its accepted local unread projection;
this new response handler does not clear it again. Superseded Done ACKs cannot
capture a new principal/server identity and send the old thread there. Existing
RaftClient response fences reject stale generation results.

## Evidence and limits

All receipts are private under `.local/` in the Activity worktree:

| Receipt | Actual result |
| --- | --- |
| `activity-thread-done-read-all-clean-before.log` | Original product on `e1747b8`: three real ResourceView theme cases FAIL, missing read-all after Done ACK. The test owner disposes its boot timer even on failure. |
| `activity-thread-done-read-all-before.log` | Earlier missing-write failures retained; also includes the first test owner's timer-cleanup failure. |
| `activity-thread-done-read-all-first-after.log` | First consumer proof succeeded, but pending test-owner timers and the old final-RPC assertion failed. Retained. |
| `activity-thread-done-read-all-mounted-1.log` | Interrupted harness deadlock when a manually invoked async Dio load was awaited without pumping; corrected to observe dispatch before awaiting. |
| `activity-thread-done-read-all-mounted-2.log` | 24 new cases PASS; three new channel guard cases failed my incorrect RPC payload assertion. Corrected against existing `activityMutation` and Source, without changing the product channel RPC. |
| `activity-thread-done-read-all-final-tests.log` | 175 tests PASS: 27 new actual ResourceView theme scenarios, eight real transport contracts, prior Done/ACK/flag/unread/authority/control regressions. |
| `activity-thread-done-read-all-scoped-analyze.log` | App lib/test analysis clean. |
| `activity-thread-done-read-all-analyze.log` | Final full private analysis retains only the base integration test's nonexistent `RaftErrorBanner` FAIL. Root fixed its harness separately to `MaterialBanner` in `df59ac2`; this batch does not edit that integration test. Initial local lint findings were corrected and remain in `activity-thread-done-read-all-first-analyze.log`. |
| `activity-thread-done-read-all-ds-check.log` | Full private DS check PASS, 696 violations; baseline and allowlist unchanged. |

The 27 mounted scenarios cover held pre-ACK state, successful independent
write/refresh, failed Done, failed read-all, stale principal/server/permission/
Done generation, late read response after server change, new unread arriving
while read-all waits, and a separate channel Done guard. The old control test
retains the exact storage-domain Done payload and now asserts the real ordered
Follow → Done → bodyless read-all sequence.

The eight transport cases cover exact shared Future identity, success/failure
slot retirement, distinct channel/principal/server/generation, retired capture
rejection, and ordinary persisted-read notification alongside a suppressed Done
write. These are local fixture-backed protocol and mounted component proofs.
No Linux/Android, backend persistence, pixel parity, global Activity store
rewrite, or agent delegation claim is made. Root owns the integrated platform
reruns and preserves their separate earlier failures.
