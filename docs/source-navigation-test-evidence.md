# Source navigation test port

`apps/raft_flutter/test/source_navigation_contract_test.dart` adds 56 tests
against the actual immutable location/history foundation from product commit
`1867d36`. The source authority is
`26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`. No product file changes are included
in this test commit.

The expected decisions come from these pinned sources:

- [mobileBackNavigation.test.ts](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/mobileBackNavigation.test.ts):
  PUSH/REPLACE/POP, cold fallback, same-server Back, index-keyed multi-entry
  POP/Forward, branch truncation and unknown history predecessors.
- [mobileBackNavigation.behavior.test.tsx](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/mobileBackNavigation.behavior.test.tsx):
  synchronous navigation ownership and same-key/changed-index commits.
- [rightPanelUrlSyncContract.test.tsx](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/rightPanelUrlSyncContract.test.tsx):
  independent thread/task/profile/external identities, legacy task links,
  Activity/search entries, known thread-channel identity and focused reply.
- [rightPanelUrlSync.ts:451–537](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/rightPanelUrlSync.ts#L451):
  opening an overlay PUSHes; retarget/removal REPLACEs; opening a task retains
  the side thread; explicit replace mode overrides first-open PUSH.
- [back-navigation.spec.ts:113–184](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/e2e/tests/mobile/back-navigation.spec.ts#L113):
  the port checks the history sequence under Activity → thread → mobile
  View-in-channel REPLACE, so one Back reaches the exact filtered Activity
  origin. The host must still choose that route transition's replace mode.
- [live useMobileNav.ts:89–109](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/hooks/useMobileNav.ts#L89):
  every tab tap chooses its root, including inactive tabs. Older iOS restore
  comments in this file and mobileNavStore are superseded by this mounted code.

The test file labels each group with its precise source. Three additional tests
check the new local value contract (origin rejection, repeated unknown query
values/fragment preservation, generated permalink round-trip); they are not
claimed as direct Web behavior ports.

Validation: the 56 added tests and 8 existing foundation tests passed together
(64 total); targeted analysis and `git diff --check` passed. Raw private logs
are `.local/navigation-b/model-tests-final2.log` and
`.local/navigation-b/model-analyze-final.log`. The initial analysis reported
two relative-library-import infos; imports were corrected before final checks.

These are pure model tests. They do not establish mounted navigation, native OS
Back, UI tab actions, entity/network hydration, frozen external-author restoration
or cancellation after Back, principal/permission-switch async fencing, or the
pending legacy-task loading marker. In particular, async pending legacy-task
retention is intentionally untested because the foundation has no corresponding
state. Source state-sequence requirements for those later layers are recorded in
[the loading contract](source-message-loading-contract.md).
