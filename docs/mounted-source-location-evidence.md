# Mounted Source location contracts: N01, N02, N03, N13

Authority: Source `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6` (Web 1.17.5,
raft-ui 0.5.27). This batch mounts the real `WorkspaceView` with a local REST
adapter. `LocalClient.connect()` is disabled so selecting a server cannot start
an external socket. Notifications are a local no-op service; the actual native
content coordinator, parser, authorization and controller remain production code.
No OS notification, Linux/Android process, pixel or external browser-history
result follows from these widget tests.

## Change and Source contract

A real thread Search result previously lost its `channelType`, parent channel and
parent message fields in `ResourceView.openSearchMessage`, which passed only
`channelId` and message ID. It consequently tried to open the thread channel as
an ordinary main conversation. Source [MessageSearchPage1281–1315][search]
opens the typed thread directly, using its own channel ID as the accepted thread
hint, independently of its parent metadata. The new optional `onSearchMessage`
callback preserves the scoped, accepted row and selected search query. The
WorkspaceView desktop adapter publishes one thread content slot, then calls
`openThreadIdentity(...initialThreadChannelId:, navigate:false)`. Ordinary
channel/DM hits retain the previous message-opening fallback; embedded consumers
without the new callback retain their existing callback.

This bounded product correction applies to the desktop Search entry. The current
narrow Search callback and external cold-link bootstrap are unchanged. Those
paths require separate Source-parity work; this report does not claim them.

## Executable coverage

All rows run Brutal light, Elegant light and Elegant dark. The test file is
`apps/raft_flutter/test/workspace_source_location_contract_test.dart`.

| Check | Actual page scenario | Assertions | Cases |
| --- | --- | --- | ---: |
| N01 | Narrow Activity opens channel and DM records with the same ID in separate accepted-record fixtures | Typed canonical route, server slug, single-encoded ID/message focus, actual header/body, one PUSH and Back | 6 |
| N01 | Bounded HTTP channel/DM link enters the real NativeContentCoordinator while WorkspaceView is mounted | Real ContentTarget parse, fresh local membership/channel/context authorization, typed route, exact focus and painted target | 6 |
| N01 | Desktop Search ordinary channel/DM message hits | Typed content slot, retained search input and history index, correct context channel and painted focus | 6 |
| N02a | Desktop Search and Activity real thread-row clicks | Thread ID, parent channel/message and focused reply remain independent; actual thread header appears while parent is held; verified thread hint skips resolution GET; reply paints before independent parent response | 6 |
| N02b | Desktop Search thread hit then a genuine parent-channel hit | Parent is focused in the ordinary channel surface; thread retires; no parent context is requested from the reply channel; late replies cannot restore it | 3 |
| N02b | Narrow Activity parent hit then the real replies badge | Actual thread header appears while thread resolution is held; `msg=parent` remains on the canonical URI, reply focus is null, replies use the thread page endpoint and parent is never fetched/highlighted as a reply | 3 |
| N03 | Mounted desktop Search and Activity receive malformed/missing `open` values | No detail/entity is fabricated, hidden accepted main messages remain absent and no context/entity GET starts | 6 |
| N13 | Actual narrow workspace switch Alpha→Bravo, then mobile Back on a cold Bravo thread URI | Retired server history is fenced; Back stays Bravo, first to its parent channel then server root; actual header/tab bar match | 3 |

N02b's real replies-badge path tests parent-focus safety on an actual canonical
presentation. It does not stand in for loading an arbitrary Search thread URI.
N13 observes the production server-selection reset and semantic fallback, rather
than inserting a forbidden foreign-server entry into the local history model.
The existing pure Source ports remain unchanged.

Source references:

- [useAppNavigate446–464][permalink] separates channel/DM permalink kind and
  preserves message/thread parameters.
- [rightPanelUrlSync278–312][panel] separates the parent anchor from reply focus
  and passes a known thread slot ID to the store.
- [ThreadsInbox1111–1147][activity] opens a genuine desktop thread directly.
- [MessageSearchPage1318–1333][ordinary] retains the ordinary channel/DM branch
  and closes an old thread when changing the content entity.
- [searchContentStore63–83][invalid] rejects malformed content parameters.
- [mobileBackNavigation behavior544–566][back] falls back inside the new server
  instead of consuming a previous server's location.

## Receipts and retained failures

- `.local/mounted-foundation-final.log`: **39 PASS** for the new mounted file.
- `.local/mounted-foundation-combined-final.log`: **144 PASS** in the combined selected run;
  includes the unchanged Source model ports, Workspace history, original Activity
  activation, desktop routes and Search authority/memory regressions.
- `.local/mounted-foundation-analysis-final.log`: application analysis, **no issues**.
- `.local/mounted-foundation-ds-final.log`: design-system ratchet **PASS**, no baseline change.

The original real Search click failure in all three themes is preserved in
`.local/mounted-real-n02-second.log` (Activity already passed). Its SHA-256 is
`7f21762a79ca01cc14072209b89d19bdc236355ac3c115591816663cd7c08d3d`.

A prior experiment directly seeded accepted Search/Activity or canonical thread
URIs into `WorkspaceNavigation`, without a production click or native coordinator.
All nine cold thread-identity assertions failed: a header/URI could mount without
hydrating `threadIdentity`. The complete original test source is retained at
`.local/mounted-foundation-original/cold-seeded-location-experiment.dart`, SHA-256
`81282dc50494ce803d1b0af2a4497bc41bdf2cabfeb52783a4e485fe11a86a22`, with the
original `.local/mounted-foundation-fourth.log` (12 PASS / 12 FAIL). Nine failures
were this hydration limitation; three were a socket reconnect teardown from the
unisolated server-switch fixture. This experiment is retained as **FAIL**, not
relabelled as a mounted N02 click result. Later actual page tests replace the
inapplicable checklist entry and isolate the fixture's external socket.

The production native parser currently accepts bounded channel/DM/thread content
links, not external full Search/Activity `open=` URIs. There is no general accepted
RaftLocation hydration bootstrap. These limits remain explicit; this batch makes
no bootstrap/coordinator product changes and does not claim external cold-link
or browser Back/Forward parity. The original screenshot baselines, thresholds,
Source fixtures, Markdown wrapping and calibration are unchanged.

[search]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/search/MessageSearchPage.tsx#L1281-L1315
[ordinary]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/search/MessageSearchPage.tsx#L1318-L1333
[permalink]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/hooks/useAppNavigate.ts#L446-L464
[panel]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/rightPanelUrlSync.ts#L278-L312
[activity]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/thread/ThreadsInbox.tsx#L1111-L1147
[invalid]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/store/searchContentStore.ts#L63-L83
[back]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/mobileBackNavigation.behavior.test.tsx#L544-L566
