# Workspace entity hydration

Source is frozen at `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`. This change ports accepted in-memory entity projections; it does not change Source fixtures or any visual threshold.

The Source contracts are:

- `packages/web/src/store/agentStore.ts:749–839`: initial `/agents` hydration coalesces requests, keeps accepted rows during refresh, rejects obsolete server epochs, and preserves socket activity newer than the requested snapshot.
- `packages/web/src/store/machineStore.ts:265–305`: `/servers/:id/machines` accepts an array or `{machines: [...]}`; refresh failure preserves accepted machines and exposes a separate error.
- `packages/web/src/store/serverStore.ts:375–395,654–668`: server selection resets members; `/servers/:id/members` is an array and its late response is fenced by the server epoch.
- `packages/web/src/components/profile/ProfilePanel.tsx:67–172,349–401`: resolve actual store/fallback entities before rendering their facts. An unresolved connected profile immediately shows a blank header with usable back/close and a loading body.
- `packages/web/src/components/agent/agentDetailAvailability.ts:21–42`: local Agent details require id, name, status, runtime and model strings; channel summaries and remote public projections have explicit separate predicates.
- `packages/web/src/components/member/resolveHumanProfile.ts:4–17`: accepted live membership overrides fallback profile fields, while detail-only fields are retained.

`WorkspaceEntityDirectory` owns real accepted Agent/Computer/member maps in current-authority memory. The owner starts all authorized loads alongside server selection; borrowed controllers take the same directory instance and never dispose it. Synchronous `agent`, `computer` and `member` lookups give mounted entity views a real first frame. Loading and failures are independent state. Scope includes origin, principal, server, client generation, role and allowed entity kinds; lookups and HTTP acceptance enforce that scope, including same-generation account and role changes. No entity payload is persisted here.

Fleet details reuse a current directory row before their own detail refresh. An id-only Agent or Computer renders the Source loading shell until accepted data arrives. An unresolved Human uses the same shell. A failed Computer refresh retains its accepted machines rather than proving an empty directory. Human fallback hydration merges current live membership over its fallback. Existing accepted views retain their tab selection and geometry during refresh. `FleetView.onOpenDetail` lets the workspace supply URI-owned navigation while standalone callers retain their existing route.

The existing avatar editor test fixture now supplies the model string required by Source local-detail availability. The editor's assertions and production predicate remain intact; an incomplete fixture no longer bypasses the same availability gate as production.

Validation uses delayed local HTTP completers and mounted Flutter widgets, with actual accepted records and explicit failure replies. New tests cover all three themes × Agent/Computer/Human cold and cached first frames, working Back before hydration, stable profile-header height, late authority responses, current-live Human merge, cold failure, retained refresh and explicit denial of late detail replies, directory coalescing/formats/copy isolation, newer socket activity, URI activation delegation, Agent tab and real input focus retention, and borrowed disposal. Logs are local artifacts under `.local/entity-d/`.

These are pure data and mounted widget checks. Linux/Android native execution, physical-device behavior, Source/Flutter pixel parity, and full endpoint event reduction are not claimed. Computer detail still uses the existing scaffold once a real row is accepted; this batch does not claim its visual parity. Source's dedicated missing-entity routes and connected overlay loading are distinct; workspace route presentation remains owned by the navigation integration. See [the loading contract](source-message-loading-contract.md) for the full message and initial shell sequences.

Final changed-input validation: **54 tests passed** (`workspace_entity_directory_test.dart`, `entity_detail_hydration_test.dart`, `agent_avatar_dialog_test.dart`), including 38 new data/widget cases. Targeted analysis of all five changed production files and three touched test files reports no issues; `git diff --check` passes. Logs: `.local/entity-d/accepted-tests.log` and `.local/entity-d/accepted-analyze.log`. An earlier broader nine-file check passed 108 tests before the final explicit-denial test/fence was added; that historical result does not replace the parent's integrated full check.
