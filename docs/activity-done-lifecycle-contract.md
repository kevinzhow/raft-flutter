# Activity Done lifecycle

This bounded repair follows pinned Source Web
`26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`:

- `store/inboxStore.ts:1330–1475`: bind Done to the accepted row, remove it at
  intent, issue a per-row generation, POST the exact storage frontier, refresh
  first with suppression armed, then retire it. Failure disarms before the
  reconciliation; an older generation cannot refresh or retire a newer intent.
- `inboxStore.ts:424–440,492–500,672–706`: suppression uses only the normalized
  authority read-state latest sequence. Display sequence and storage Done
  frontier are different roles and are never fallback keys. Missing, corrupt or
  null authority yields no suppression. A changed marker remains visible.
- `store/readStateSync.ts:291–349`,
  `shared/src/inboxScopeReadFrontier.ts:31–42,77–120`: normalize the authority
  union, retain exact canonical uint64 sequence text, and reject an unsafe
  max-read ledger conversion. A same-source latest message/sequence pair is
  required. The bounded Dart adapter uses the existing canonical uint64 parser.
- `inboxStore.ts:356–378,1479–1489`: remove the accepted row, subtract its known
  active/unread counts, and decrement groups while retaining a selected zero
  group so the filter can still be cleared.

The existing mutation contract remains intact: present usable
`doneFrontierSeq` is sent as `throughActivitySeq` with `frontierSpace=storage`.
A legacy server row that omits the field sends no sequence, never the display
pair. As Source documents, that old-server path snapshots at request time and
can cover newly arrived activity. Present invalid frontier remains fail-closed.

Flutter now owns the same intent/POST/reconciliation sequence in Activity's
accepted page state. It invalidates earlier page/facet requests before any old
payload can compare markers; success refreshes while the bridge is armed.
Rows/counts/groups and cached active rows change at intent, along with the
existing conversation unread presentation. No read-authority cursor is
fabricated, and no additional backend mutation is introduced. Existing accepted
Activity callbacks carry the adjusted window; the independent background
attention owner and cross-page global inbox lifetime are outside this repair.
Saved and Done result buckets remain independent and are not suppressed as
active inbox rows.

The bridge expires after Source's 30 seconds and retires after the owned
refresh. It is deliberately not a persistent local Done fact. An unrelated
later stale server window can therefore return a row after retirement, exactly
as the bounded Source lifecycle permits; backend convergence must be observed
by the separate native run. Missing/corrupt authority cannot be hidden using a
weaker display/storage key merely to make that run pass.

Before the fix, the actual three-theme mounted checkmark/held POST checks fail
because the row remains at intent: `.local/activity-done-before.log`. The real
Linux Root `8c6d425` FAIL26 remains immutable in
`.local/cody-full-native-linux-8c6d425` and is not relabeled. This batch runs no
native process or live API, and changes no Source, fixture, query contract,
renderer, image baseline, threshold, DS baseline or allowlist.

Private evidence: 127 selected app tests pass, including 36 three-theme actual
ResourceView Done cases, six pure marker/lifetime tests, and the prior follow,
flag-page, resource authority and control regressions. Tests exercise first
armed refresh, genuine newer activity, failed POST, failed refresh, principal
retirement, generation supersession, pre-intent late read, legacy sequence
omission, and separate channel/DM/thread paths. App analysis is clean.
Receipts: `.local/activity-done-final-tests.log` and
`.local/activity-done-final-analyze.log`; intermediate failures stay preserved.
These mounted component/page assertions do not claim Linux/Android, global
background-owner or pixel equivalence.
Private full DS check passes at 696 with unchanged baseline and allowlist:
`.local/activity-done-ds-check.log`.

The original row-lifecycle repair did not introduce Source's additional
coalesced read-all (`threadStore.ts:853–883`). The separate follow-up now adds
that real write and its owned refresh suppression; see
[Thread Done persisted read-all](activity-thread-done-persisted-read-contract.md)
for its independent before/after evidence and platform limits.
