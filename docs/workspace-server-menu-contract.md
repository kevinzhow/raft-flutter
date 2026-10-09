# Workspace server menu: Source contract and bounded evidence

This batch replaces the desktop rail's legacy server `SimpleDialog` with a shared `raft_ui` flyout. It preserves accepted server records, permission gates and app-owned routing. **K08 remains partial:** the full invitation dialog, direct cross-server remembered-surface restoration and the narrow/mobile server menu are not implemented here.

## Authority

Source is pinned at `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6` (Web 1.17.5, raft-ui 0.5.27). Paths below are relative to `packages/web/src/`.

| Mounted Source contract | Exact source | Flutter ownership and proof |
| --- | --- | --- |
| Server rows are 48px; current check reserves 14px; row avatar is 32px; name is 14/20; slug is 12/16; drag handle is 24px. Only non-current, proven Activity unread counts paint. | `components/ui/ServerSwitcherMenu.tsx:120–185` | SDK `RaftServerMenuRow`/`RaftServerMenuPanel`; three-theme row, count and real-list input tests. Avatar fallback pixel equivalence is not claimed. |
| Flyout anchors to the rail header with `left-full top-1 ml-2 w-64`; height is capped at viewport minus 16px, shifts up if needed, and its footer remains outside the scrolling list. | `components/layout/LeftRail.tsx:624–625`; `components/ui/ServerSwitcherMenu.tsx:242–265,363–397`; `components/ui/serverSwitcherMenuLayout.ts:27–43` | Shared overlay/placement and three-theme exact geometry plus 20-server internal scrolling. At 1280×800, actual Source is Brutal `(70,4,256,162)` and Elegant `(64,4,256,167)`. |
| Opening focuses the container; Tab reaches the first server link. Outside pointer and Escape close without restoring the trigger/previous textarea. | `components/ui/ServerSwitcherMenu.tsx:273–307` | Actual Source browser and SDK input tests. Current-row activation closes with no route/history change. |
| Current server closes without navigation. Another server restores its remembered surface on desktop; mobile switches to server Home with replace semantics. | `components/ui/ServerSwitcherMenu.tsx:310–324`; `utils/serverSwitcherNavigation.ts`; `hooks/useTabRouteMemory.ts:118–148` | Current-row preservation is mounted and tested. Other-server selection still uses existing `WorkspaceController.selectServer`; remembered-route hydration is a retained gap. |
| Reordering updates the real server order optimistically, persists it, and restores previous order on failure. Mouse drag activates after movement over 6px; touch uses a 500ms delay and 10px tolerance. | `components/ui/ServerSwitcherMenu.tsx:213–214,330–342`; `store/serverStore.ts:466–514` | Actual desktop mouse drag persists `PATCH /servers/order`; accepted membership/request/authority fences prevent a stale drag resurrecting records. SDK touch recognizer is wired but not separately platform tested. |
| Community actions precede Switch/Create; the latter closes, clears last-server persistence and navigates to global `/`. Invite is capability-gated, closes the flyout and opens the shared invitation dialog. Invite's Brutal hover is pink; standard actions use primary fill. | `components/ui/ServerSwitcherMenu.tsx:351–360,401–448` | SDK ordered footer and caller-specific action tone. WorkspaceView delegates Switch/Create to `onChooseServer`; actual global root handling belongs to the independent RaftApp bridge. This batch proves delegation, not the app-root flow. |
| Server menu badges use cross-server Activity summary, not the current Activity inbox or Chat unread. Unknown/unsafe Activity counts are absent; refresh failure retains accepted values. | `store/serverStore.ts:699–720`; `utils/serverUnreadSummary.ts` | Independent `SourceServerUnreadStore` GET `/servers/unread-summary`, finite safe integer validation, authority/request fencing and failure retention. It refreshes on menu open; Source's complete background reconciliation is not ported. |
| Invitation trims and validates each target email, sends the role, then routes to Administration. | `components/member/InviteHumanDialog.tsx:309–352`; repository-root `packages/shared/src/emailValidation.ts:3–22` | Bounded one-email/member dialog uses `showRaftDialog`/`RaftFormDialog`, rejects invalid input before POST and sends `/servers/:id/invites`. Real WorkspaceView tests verify the Administration URI. Multi-person/guest/link/billing/seat flows remain absent. |

The currently mounted `LeftRail` and `ServerSwitcherMenu` have no account flyout. A stale Sidebar comment referring to a server/account menu is not a mounted UI contract. Account and logout remain available through their real Settings/ServerSelector entries; this batch does not remove access or invent another rail action.

## Actual Source browser observation

An isolated local runtime used the unchanged `tool/desktop-parity/desktop-fixture.json` on private port 15416, then stopped. Evidence is in `.local/k08-server-menu-v1/{brutal,elegant-light,elegant-dark}/result.json`, `menu.png` and `invite.png`. All three **menu-input** probes passed with no page exceptions: actual pointer opening, focus/container → Tab/server link, Escape, outside click, current-row close and unchanged current URI/history length 2. Invitation was visibly mounted, but the fixture lacked billing metadata; no invitation API or full dialog parity is claimed from that browser probe.

| Evidence identity | SHA-256 |
| --- | --- |
| Unchanged desktop fixture | `e8cb691d2f49743247d2ee5aee0839f6d9c13cb0589d69c871eb435838c50e71` |
| Source input | `799c42a7703b30e809471e9835dfeeb1adbb75c06ae8689562685970292fef17` |
| Runtime | `ba8f7cb55572030b1651e1b2aace7cf98b4e6b65af3983d67852035171aefd1f` |
| Capture script | `c6c6a5fa288c9c9f182862d57f07c0887cf227f4dcc27405bb9f0a9187e0d8a7` |

`source-before.json` and `source-after.json` record the same captured dirty paths and the same Root-owned `scripts/dev/raftdev.ts` 2GiB development-infrastructure patch, SHA `029a4e98f156670e924c72147068d48a43eab968199971128c24db653b8497f8`. Pre-existing dirty paths were server seed/verification scripts, `packages/web/visual-testing/VisualTestingCases.tsx`, the infrastructure script and untracked `packages/visual-testing/build/`. This lane changed none of them. These receipts do **not** claim that the entire raw Source diff was unchanged.

## Flutter verification and retained failures

Three actual WorkspaceView cases per theme cover `[K08h]` current-row/Escape/chooser delegation, `[K08i]` capability-gated invitation and Administration URI, and `[K08j]` real pointer reorder/API/authority retirement. Three data tests cover unread parser/request authority and exact email validation. SDK cases cover geometry, keyboard/focus/outside input, caller-specific invitation hover, actual pointer reordering and internal scrolling. The standalone Preview exercises the shared component without any API ownership.

Final combined receipts: `.local/k08-server-app-verified.log` **39 PASS**; `.local/k08-server-sdk-verified.log` **30 PASS**. These include the existing mobile navigation, shell, DM and Elegant navigation regressions. Both analyses are clean; the design-system ratchet remains **711** (the preceding shell batch reduced 727 to 711). Receipts are recorded alongside as `k08-server-{app,sdk}-analyze-verified.log` and `k08-server-ds-verified.log`. No audit allowance or baseline is increased.

All earlier started failures are retained in `.local/k08-server-{app,sdk}-{before,second,third,fourth,fifth,final}.log` where those files exist: negative separator padding, wrong reorder ancestor and intermediate insertion while the original test teleported the pointer. Final reorder input sends continuous pointer motion through the same handle; the expected final order is unchanged. API-test fixture pending timers were fixed by awaiting the single actual request through `runAsync`; assertions were retained. `.local/k08-server-ds.log` retains the initial `showDialog` audit growth, corrected by using the existing SDK dialog entry.

No native Linux/Android menu execution, whole-page pixel acceptance, cross-server remembered-route acceptance, complete Community agreement flow, mobile server menu or full invitation parity is claimed. Existing six primary rail entries/four footer controls, persisted sidebar preferences and platform defaults are retained. K08 and the target of reducing all design-system bypasses to 300 remain incomplete.
