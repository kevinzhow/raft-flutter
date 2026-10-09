# Global server selection at the app root

The signed-in app now owns the real global `/` and `/servers` routes. The workspace location model continues to own authorized `/s/:slug` surfaces. Choosing a server hydrates the existing workspace controller before mounting its view; opening the global chooser removes that view while retaining its controller, accepted draft cache and main connection. It suspends message presentation and native-content delivery until the chosen workspace mounts again.

## Source contract

Authority is the mounted Web app at Source commit `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6` (Web 1.17.5, raft-ui 0.5.27), under `packages/web/src`:

| Source | Required behavior |
| --- | --- |
| `App.tsx:683–704` | `/servers` waits for the server directory and then mounts ServerSelector; selection navigates to the remembered server surface, using a history push. |
| `App.tsx:705–779` | The deliberate chooser request wins over last-server restoration. Ordinary `/` can restore an authorized last server; root-to-server transitions replace the root history entry. |
| `App.tsx:1174–1176` | `/servers`, `/s/:serverSlug/*` and the global fallback are distinct mounted routes. |
| `components/ui/ServerSwitcherMenu.tsx:419–429` | Switch or create server closes the menu, clears last-server restoration and navigates to `/`. |
| `components/auth/ServerSelector.tsx:24–92` | An unresolved empty directory does not imply first-server creation; choose/create state is based on the actual directory. Input slug derivation replaces each non-ASCII-letter/digit/hyphen with a hyphen. |
| `components/auth/ServerSelector.tsx:104–177` | A confirmed first-server state has a create form with no Cancel destination. |
| `components/auth/ServerSelector.tsx:182–251` | Existing-server creation has Cancel, which clears both inputs and returns to the chooser. |
| `components/auth/ServerSelector.tsx:258–304` | Authorized server option cards, signed-in email, create action and logout are real controls. |
| `components/layout/MainLayout.tsx:914–955` | Desktop default server entry redirects to the first channel with replacement; mobile keeps the inline channel list. |

The Flutter root keeps a deliberate selector visit visible until a user chooses or returns. Surface preferences are isolated by API origin and authenticated principal. A directory failure remains an error with Retry; it does not render a successful empty directory or manufacture a server. Creation requires the actual POST identity to be present in a refreshed authorized directory before any workspace is mounted.

## Lifetime and authority

`WorkspaceController.loadServerDirectory()` is the only controller addition. It does not select a server. It uses the existing principal/generation, membership request/revision, revocation filter and serialized cache queue. Normal discovery accepts the live directory; a restored offline session preserves the previous origin/principal-scoped directory cache behavior. Existing bootstrap and message/navigation reducers are unchanged.

The app root owns a separate request revision for discovery, creation and selection. Back, a different target, membership changes, logout and principal replacement retire pending completions. Returning from the chooser uses its recorded original server URI, including when a different server has started hydrating. Logout clears the original principal's cache after pending cache writes finish; an account record replacement cannot transfer old private projections or drafts to the new principal.

The root RouteInformationProvider reports real engine replacement intent. Workspace history index changes determine whether a committed workspace URI adds an entry or replaces the current entry. This bridge does not change WorkspaceNavigation's history, anchor or message ownership rules.

## Mounted test evidence

`apps/raft_flutter/test/app_global_server_selector_test.dart` runs real `RaftApp`, `MaterialApp.router`, GlobalServerSelector and WorkspaceView with real RaftClient/Dio response handling. The HTTP adapter is isolated; platform content services and socket connection are stubbed. No live account or backend is used.

The final private v8 run passes **35 scenarios**:

- Six actual narrow/wide page flows: Brutal light, Elegant light and Elegant dark at 390 and 1280 logical pixels. Each selects a real fixture server, edits the actual composer, leaves for `/`, returns with the same controller/URI/draft, and switches servers without losing the accepted draft.
- Nine additional behaviors in each theme: keyboard creation/logout with a late POST, keyboard selection and incoming platform URI, Back during held cross-server hydration, membership removal during selection, principal replacement/cache clearing, accepted offline directory restoration, engine push/replace readback, unresolved-versus-confirmed-empty directory, and successful creation through a refreshed authorized directory.
- Two real HTTP error cases: creation 403 and directory 503 with a successful Retry. Neither opens fabricated private content.

Platform URI tests send actual `flutter/navigation` `pushRouteInformation`. History tests read the outgoing `routeInformationUpdated` `replace` value. Hidden chooser tests observe actual POST `/channels/:id/read` calls. Late-result tests release the original held response after the competing input and check mounted pages, URI and accepted controller data.

`.local/global-server-selector-regressions-v1.log` additionally passes 19 existing session-persistence, offline-read, inline-auth, auth-page and native-content authority checks.

Private receipts are `.local/global-server-selector-tests-v8.log` (35 passed), `.local/global-server-selector-analysis-v6.log` (no issues), and `.local/global-server-selector-evidence-v1.json` (input and receipt hashes). Run from `apps/raft_flutter`:

```sh
../../tool/flutter test test/app_global_server_selector_test.dart --no-pub --reporter expanded
../../tool/flutter analyze lib/main.dart lib/features/app_root_router.dart lib/features/global_server_selector.dart lib/data/workspace_controller.dart test/app_global_server_selector_test.dart
```

## Remaining evidence and presentation boundaries

The required WorkspaceView callback constructor seam is F's commit `5096315` (private cherry `dff70f2`). These app-root tests invoke the callback on the mounted WorkspaceView; the actual Source server-menu opener is a separate F product commit and has not been included in this batch. Cross-server selection directly inside that menu still needs its separately coordinated remembered-surface hydration path.

No Linux or Android native run, compositor capture, browser history replay or visual acceptance is claimed for this batch. Parent owns both native lanes and will select the fixture server explicitly in the full native startup after integration. All previous native and Source failures remain unchanged.

The chooser reuses the shared auth shell, option-card recipe, fields and keyboard/semantics controls. The first-server form is functional, but the Source wide OnboardingCreateShell demonstration pane, first-server explanatory presentation and SlugInput prefix are not yet reproduced; this batch does not claim first-server visual parity or the hosted/Electron server-switch handshake.
