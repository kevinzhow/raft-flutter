# Workspace location presentation integration

This batch connects the existing `RaftLocation` foundation to the actual
workspace presentation. Activity and Search keep their master route while a
picked conversation loads; their outer header no longer follows the retained
data channel. Changing width selects a presentation of the same location.
Message windows, drafts, entity records and authorization remain separate
controller projections.

Source is fixed at `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`
(Web 1.17.5). The full source audit and original test references are in
[source-navigation-contract.md](source-navigation-contract.md) and
[source-message-loading-contract.md](source-message-loading-contract.md).

## Implemented connection

- `WorkspaceNavigation` owns the accepted URI, observed same-server history and
  revision. The legacy section and desktop master/detail adapters project that
  location. Selecting data with `navigate: false` cannot move the rail or master.
- Workspace header, master, detail, sidebar selection, mobile root tabs and Back
  share this projection. A folded master stays mounted without focus or active
  tickers, preserving search state and the conversation editor through resize.
- Channel, DM and thread URI identities remain distinct. Source content slots
  are presented only on Search/Activity. Member and computer selection uses
  dedicated paths and accepted records from the shared entity directory.
- Mobile tabs always push their roots, including repeated active-tab clicks.
  Settings detail paths and conversation `chatTab` project into the mounted
  controls. Initial Search `q`, `channelId` and `defer=1` are consumed without
  converting a revoked channel search into a global search.
- Known-channel loading keeps its header, eligible tabs and composer from the
  first frame. A pending body does not replace the entire workspace with a
  spinner. Draft, selection and hidden-conversation read admission are retained.

These rules follow `packages/web/src/components/layout/MainLayout.tsx:1306–1335,
1519–1619`, `hooks/useMobileNav.ts:89–109`,
`components/message/ChatPanel.tsx:1484–1534` and
`components/layout/rightPanelUrlSync.ts:258–354` in the pinned Source.
Responsive criteria remain those recorded in the audit: viewport 768/1024/1280
and the thread container's 680 threshold, with landscape handled independently.

## Back and authority corrections

Back consumes an observed same-server predecessor first. At a cold detail it
closes one URL-owned slot or replaces with the semantic tab root. The fallback
retains sibling query identities: task, legacy task, profile, effective content,
and side thread are separate. Source `task=1` resolves against the thread anchor
(`rightPanelUrlSync.ts:272, 313–321`); its task modal overlays the lower surfaces
(`MainLayout.tsx:1333–1376`). The new model case checks task-first closure, then
profile, then thread, preserving `msg`. This is model evidence only: this batch
does not mount task/profile overlays, and it does not claim their actual top
surface or Back controls match Source.

Changing principal or role resets observed history and invalidates request
revisions while retaining the same-server requested URI. This allows the current
scoped Search surface to show its unavailable state without issuing a global
request. A denied provider settings tab displays the permitted Account/settings
projection while retaining `/settings/providers`. This follows
`components/settings/SettingsPanel.tsx:7882–7894`; redirecting that case to Home
would be incorrect. Source guest Home redirects for other dedicated routes are
different branches in `MainLayout.tsx:589–594, 693–698, 965–991`.

## Validation and retained failures

The handoff receipt is `.local/navigation-presentation-handoff.log`: **100 PASS**. It runs
the Source-derived 64 foundation/contract cases plus actual workspace, mobile,
conversation, role, scoped-search and grid regressions. The mounted tests cover
all three supported themes, cold header/tabs/composer frames, Activity detail
without an extra outer channel header, widths 767/768, 1023/1024, 1279/1280 and
rotation. They retain the actual master/editor instance and URI. Existing
authority, no-global-search, draft/cursor and read-ACK assertions remain.

The task/profile test above exercises the production navigation model, not a
separate mock navigator. Browser history indices, OS Back, native platform
rendering and pixel parity are outside these widget/model receipts.

Analysis passes in `.local/navigation-analyze-clean.log`; the design-system
ratchet is in `.local/navigation-ds-handoff.log`. No audit baseline or allowance
is raised. No Source fixture, original visual image, threshold or case ID is
changed.

Earlier failed receipts remain in `.local/navigation-presentation-tests*.log`
and `.local/navigation-presentation-validated.log`. They include the incorrect
Home/settings expectation, a legacy thread fixture lacking its URI, a mistaken
test filename and a cold-frame `pumpAndSettle` timeout. The cold fixture keeps
Source's animated sidebar skeleton; the corrected first-frame tests use bounded
frame pumps rather than disabling its animation. No failed native run is retired
by these host tests. The first new task=1 receipt also retains a failed anchor
object-identity assertion; the corrected case compares the actual channel and
item ID values, then checks every subsequent URI slot explicitly.

## Dependencies and remaining coverage

The presentation commit follows the location foundation, directory commits
`dd37340`/`5df1fdf`, navigation seam `0fa0e75`, and chat commits
`22f8403`/`083a309`/`8918208`/`fd850ed`. The directory is shared with borrowed grid
controllers; the main controller owns its lifecycle. `fd850ed` retains the
Source timeline-bottom metric in the SDK without growing the app audit count.

Remaining work is explicit:

- The platform router/browser history adapter is not wired to this location
  owner. These tests do not prove native notification or OS Back delivery.
- Profile, frozen external author, task and legacy-task overlay rendering and
  hydration remain unimplemented by this presentation batch. Their parsed
  identities and model Back cases are not mounted-surface acceptance.
- Live typed Search query/filter writeback and Agent-tab URI synchronization
  still need their page adapters. Initial query projection is implemented.
- Canonical pending thread parent/channel loading needs the adjacent chat
  identity change and Source-specific pending header/body rules. This batch
  retains the URI shell without fabricating a parent record.
- The Source feature-gated Activity sidebar/switcher and Done/unfollow entry
  remain absent. The existing native flow failure at the obsolete Filters entry
  remains a failure; protocol-only controls tests do not replace that UI flow.
- Desktop rail/group/DM visual differences and full visual/native acceptance
  are separate follow-up work. This batch produces no new pixel or native claim.
