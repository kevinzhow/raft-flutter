# Activity follow acknowledgement

Authority: pinned Source Web `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`.
`ThreadsInbox.tsx:1385–1433` awaits the actual follow/unfollow persistence before
changing the retained Activity row. Success does not refresh the inbox; failure
preserves the canonical state and reconciles. `inboxStore.ts:1491–1533` keeps the
thread row, sets its acknowledged follow state, clears existing unread/mention
on Unfollow, subtracts that known unread contribution, and does not resurrect
unread on Follow.

Flutter now applies that successful acknowledgement directly to its accepted
row. It keeps accepted rows while a follow mutation is pending, and emits the
adjusted accepted row/count through its existing scoped Activity callbacks.
It performs no optimistic success before the POST response, no extra backend
write, and no immediate eventually consistent inbox reload on success.

A transient application-owned projection protects acknowledged follow state
from a stale read until the server confirms it. Existing request/principal/
server/capability guards remain intact. The cleared unread projection is limited
to the exact real `latestActivityMessageId`/`latestActivitySeq` pair seen when
Unfollow was acknowledged; this pair identifies the retained row version, **not**
a fabricated read-authority watermark. New activity stays unread. Server
convergence retires the projection so a later real external follow change is
accepted. Scope retirement clears mutation tickets and projections; failed or
denied writes cannot create a success projection. Failed ordinary writes
reconcile, while 401/403 use the existing authority-retirement behavior.

The original mounted consumer fails all three real menu/POST-ACK checks with
`isFollowing:true`: `.local/activity-follow-ack-before.log`. The original real
Linux full-flow failure at checkpoint 23 remains preserved in Root's
`.local/cody-full-native-linux-db50083`; it is not relabeled or replaced here.
Fixture-backed mounted tests independently exercise real secondary-click menu,
held POST, stale held read, subsequent stale read, convergence, refollow,
ordinary failure, denial and principal change in all three themes. Pure tests
add independent total fields, input immutability, newer activity and operation
retirement. Native/Linux replay and real backend convergence are for Root's
separate lane; this private batch claims no native or full-page pixel pass.

Source files, fixture responses, renderers, frozen images, thresholds, DS
baseline and allowlists remain unchanged. The separately prepared evaluated
Activity-page branch is deliberately excluded from this commit.

Private receipt: 64 selected tests pass, including 18 three-theme mounted ACK
cases and five pure projection cases, with existing resource authority and
control regressions retained. App analysis is clean. Evidence:
`.local/activity-follow-ack-tests-final-v2.log` and
`.local/activity-follow-ack-analyze-final-v2.log`. The earlier compilation failure
for a nullable retained test handler is also preserved separately; it was fixed
by explicitly asserting the actual handler exists.
The private full DS check passes with no baseline or allowlist growth; receipt
`.local/activity-follow-ack-ds-check.log`. Root may independently lower its
ratchet after combining other lanes.
