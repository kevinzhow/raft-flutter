# Navigation foundation

Reference: raft-source `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`.

`apps/raft_flutter/lib/data/raft_location.dart` is the immutable workspace
location contract shared by the desktop, mobile, message and profile branches.
It parses local `/s/<serverSlug>/...` URLs and generates them with escaped path
identifiers. HTTP origins must be authenticated by the host before parsing.
Unknown routes remain explicit and do not manufacture entity identities.

The model keeps the original URI. Named query edits preserve unrelated query
parameters, duplicate values and the fragment. Independent slots represent
`thread`, `task`, `legacyTask`, `profile`, `open`, `msg`, `agentTab` and `chatTab`.
Malformed slot values remain in the URI, but typed getters return null. Task
modals can coexist with side threads; legacy `task=1` binds to the thread anchor.

Source contracts:

- `packages/web/src/components/layout/MainLayout.tsx:2439–2463`: mounted routes.
- `packages/web/src/components/layout/rightPanelUrlSync.ts:262–542`: anchor
  parsing, focused replies, independent modal slots and overlay history writes.
- `packages/web/src/store/searchContentStore.ts`: `open` parser and content slot.
- `packages/web/src/store/mobileNavStore.ts`: tab-home mapping and cold overlay
  hydration. The current mounted `useMobileNav.ts:89–109` sends **every** tab tap
  to its root; obsolete inactive-tab restoration comments are not the contract.
- `packages/web/src/hooks/useAppNavigate.ts:13–109,205–231`: the pure history
  functions ported in `raft_navigation_history.dart`. Missing browser entries
  and other-server entries cannot authorize an in-app Back operation.

The first eight focused tests verify escaped identities, input validation,
query preservation, overlay coexistence and history safety. Additional ports
of the existing Source navigation tests are owned by the test branch.

This commit defines and tests the common interface. It does **not** connect the
existing workspace widgets to it, replace their old state, or claim that the
reported Activity header and loading transitions are fixed. The routing branch
must replace the old presentation authority and be accepted by process tests.
