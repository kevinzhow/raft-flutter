# Selected-server Activity flag implementation

Source authority is Web `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`,
raft-ui 0.5.27. This change uses the existing remote evaluator, never a local
production flag override. Unknown, denied and disabled evaluation retain the
classic All/Unread/Mentions page. The selected server and real platform are in
`POST /feature-flags/evaluate`; origin, principal, generation, server and role
changes retire an earlier evaluation.

The normal desktop Activity master actually mounts `compactActivitySidebar`
in `MainLayout.tsx:2344–2348`; workspace sidebar mode also mounts it at
`MainLayout.tsx:2184–2189`. Enabled desktop therefore has the full-width scope
switcher and second-row sort/read controls, rather than forcing the standalone
224px sidebar into the master column. Mobile uses the five horizontal views.
These are the live mounts implemented by this batch; the standalone noncompact
desktop sidebar renderer is outside this page coverage.

Source contracts ported:

- `ThreadsInbox.tsx:632,665–774,776–793`: evaluated flag, independent top-level
  views and source selection, accepted active facets, selected/unread/stable
  source ordering, and scoped group toggle.
- `ThreadsInbox.tsx:795–821,865–883`: Done uses `/channels/inbox/done` with
  limit 30/offset/sort/q/channelId; Saved is selected-server scoped.
  `store/savedStore.ts:58–103,107–143`: Saved uses `/channels/saved`, page size
  20, and preserves the global badge independently of filtered result total.
- `ThreadsInbox.tsx:143–201`: Saved entries become real channel/DM/thread inbox
  DTOs, preserving their canonical message/thread identity. No channel records
  are fabricated. `ThreadsInbox.tsx:1737–1766` gives Saved `doneAction=none` and
  Done a restore action.
- `ThreadsInbox.tsx:1239–1345,1464–1557,1568–1590,1781–1793`: picker views,
  mixed source facets, active state/counts, compact toolbar, mobile strip and
  close-after-selection dialog. There is no Unfollowed view in either flag
  branch. The 88px compact CSS **minimum** produces 90px Brutal / 89px Elegant
  with its two 32px controls, gap, padding and border; it is not a fixed height.
- `ThreadsInbox.tsx:891–933`: Activity-owned Cmd/Ctrl+F opens the desktop finder;
  empty Escape closes its input. Conversation focus remains outside that scope.
- `ThreadsInbox.tsx:1706–1738`, `ui/Skeleton.tsx:102–122`: pending empty results
  use six conversation skeleton cards; empty views have the real Source copy.

The application owns requests and accepted windows. New SDK components own
only presentation, focus, keyboard actions and semantics, with three-theme
Previews. Saved/Done retain independent accepted result buckets and never
replace active groups or active header counts. Old requests and old facets
cannot replace a later selected result view. The optional sender directory also
cannot finish a pending Activity results request: its failure uses DTO-provided
names, as Source's independent sender lookup does.

Validation is fixture-backed mounted page proof, not live server or native
proof. `workspace_activity_server_flag_test.dart` mounts real WorkspaceView,
observes the actual evaluator HTTP request and tests both responses on Linux
and Android platform variants, in all three themes. It also exercises Done,
Saved, group scope, retained active counts, old-server evaluation and late result
windows. The SDK suite verifies min-height, keyboard activation, semantics and
independent group counts. Existing classic activation and resource authority /
protocol controls remain separate regressions.

The original app consumer files from `414bae6` fail all three enabled desktop
page checks: `.local/activity-flag-original-page-fail.log`. Additive SDK classes
were left available solely to compile the new assertions; those original app
files were restored byte for byte afterward, recorded in
`.local/activity-flag-before-restoration.json`. Intermediate test/harness failures
are retained in `.local/activity-flag-*v*.log`; they are not reclassified as
not-run. The prior Linux Filters/Unfollowed failure remains archived separately.

No Source Web file, frozen Source image, threshold, checklist rule, DS baseline
or allowlist was changed. Source already has dirty seed, RisingWave verification,
visual-testing and `scripts/dev/raftdev.ts` infrastructure files owned by other
lanes; this batch only read them and makes no whole-tree raw-diff claim. No
Linux/Android native execution or full-page pixel equivalence is claimed here.

Private `414bae6` receipt: the combined app selection passed 77 cases; SDK
passed 9; final three-theme mounted page rerun passed all 18 cases. App and SDK
analysis are clean. The private design-system audit remains 711 with no baseline
or allowlist growth. Logs are `.local/activity-flag-app-tests-final.log`,
`.local/activity-flag-sdk-tests-final.log`, `.local/activity-flag-mounted-final.log`,
`.local/activity-flag-app-analyze-final-v3.log`,
`.local/activity-flag-sdk-analyze-final.log` and
`.local/activity-flag-ds-check-v1.log`.

After the independently committed follow ACK repair, the combined selection
passes 103 app cases, including 21 real WorkspaceView flag cases and 18 mounted
ACK cases. The added enabled-page checks prove that Saved's independent active
facets and the cached All return preserve the acknowledged follow/unread state.
Saved DTO conversion remains separate from an inbox-window projection. SDK
still passes all 9 cases and app analysis is clean. Receipts:
`.local/activity-flag-ack-combined-tests.log`,
`.local/activity-flag-ack-sdk-tests.log` and
`.local/activity-flag-ack-combined-analyze.log`. This page commit depends on the
separate acknowledged-state commit; the earlier isolated page receipts remain
historical evidence, rather than a native or pixel acceptance claim.
Combined full private DS check also passes at 711 with unchanged baseline and
allowlist: `.local/activity-flag-ack-ds-check.log`.
