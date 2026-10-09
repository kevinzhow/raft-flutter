# Desktop shell: Source contract and bounded K08 evidence

This batch restores the common desktop shell from the pinned, mounted Source. It does not certify K08 pixel parity or complete the design-system migration to 300 violations. Product code, SDK input behavior, actual Source browser observations, and native screenshots are separate evidence levels.

## Authority and mounted conditions

Source is `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`, Web 1.17.5, raft-ui 0.5.27. Web paths below are relative to `packages/web/src/` unless already written in full; recipe lines refer to the matching installed package's `dist/index.mjs`.

| Contract | Exact Source authority | Implemented behavior |
| --- | --- | --- |
| Classic primary rail | `packages/web/src/components/layout/LeftRail.tsx:649–689` | Search, Chat, Activity, Tasks, Members, Computers remain available for the owner; a guest omits Members and Computers. Workspace-mode layout and public projection are separate branches. |
| Primary spacing | raft-ui `dist/index.mjs:2133–2183`, `LeftRail.tsx:1037–1060` | Generated AppRail nav gap 6, theme-specific padding, product 40 px buttons or 36 px at height ≤600. |
| Footer entries | `LeftRail.tsx:693–763`, `MainLayout.tsx:2273–2281` | Bell, Help, Settings; workspace toggle only at width ≥1024 with resolved enabled availability. Footer cells are 44 px; its own padding is separate from the rail root padding. |
| One sidebar heading | `Sidebar.tsx:3840–3848` | Shared bordered Chat heading; workspace mode uses its actual compact heading recipe. No duplicate server selector in the desktop sidebar. |
| No bottom account bar | `Sidebar.tsx:4554–4561` | Remove the extra account row and dividers; retain the live agent activity slot. Workspace switching stays in the existing rail entry. |
| Empty sections | `components/layout/sidebarEmptySectionVisibility.ts:19–36`, `store/appearanceStore.ts:1–5,119–149`, `Sidebar.tsx:1485,1521–1528` | Native/Electron default hides empty groups, browser default shows them; a persisted user choice wins. The underlying presentation store already had this contract. |
| Ordinary DM | `Sidebar.tsx:922–1019`, `components/layout/agentDmProfileSource.ts:23–33` | Real 18 px avatar slot, ordinary title/description in one baseline row, title maximum 70%, 4 px text gap, 14/20 title and 12/16 description at weight 500. Only actual unread makes the title bold. A live agent directory owns name/description; null live avatar falls back to the DM snapshot. |
| Help input and routes | `LeftRail.tsx:827–988` | Right/end menu, width 320, offset 8, hover opens immediately and closes after 120 ms; initial focus only for keyboard. Documentation opens its actual URL. Mobile App and Feedback push `/settings/about` and `/settings/feedback`. Already joined current Community pushes its home without a join request or destructive server reselection. |
| Workspace button styling | `LeftRail.tsx:1053–1060` | Active depressed state uses the actual workspace background, black border and generated inset shadow token. |

The same desktop fixture's real browser did **not** reproduce a two-entry classic rail. All three themes mounted six primary entries under the actual owner/classic conditions. The nearby `MainLayout.tsx:2273–2276` comment mentions “Chat/Members”; executable `LeftRail` above mounts six. We therefore retain the actual entries rather than treat that comment, a cropped image, or an unidentified older state as a new feature constraint. The old two-entry observation's exact role/branch is not established.

## Actual Source browser readback

An isolated runtime used the unchanged `tool/desktop-parity/desktop-fixture.json` on owned port 15416, at 1280×800. Its three contexts were Brutal light, Elegant light and Elegant dark. The recorded owner, `workspaceEnabled=false`, `workspaceActive=false`, browser default `hideEmpty=false` and available workspace toggle explain the mounted branch. The runtime has been stopped and port closure verified.

| Bound input | SHA-256 |
| --- | --- |
| Fixture | `e8cb691d2f49743247d2ee5aee0839f6d9c13cb0589d69c871eb435838c50e71` |
| Source input | `799c42a7703b30e809471e9835dfeeb1adbb75c06ae8689562685970292fef17` |
| Fixture runtime | `ba8f7cb55572030b1651e1b2aace7cf98b4e6b65af3983d67852035171aefd1f` |
| Actual input capture v3 runner | `80ad01c3c00e652d29737385969b84d756253e982115a132870ca5f73e900009` |

Evidence remains in the private worktree under `.local/k08-source-shell-input-v3/{brutal,elegant-light,elegant-dark}/result.json` and its PNGs. Each result is PASS with no browser page exceptions. Real composer textarea focus survives hovering Help; clicking Help retains trigger focus. Four resource entries are present. The earlier geometry-only v1 receipts remain under `.local/k08-source-shell/`. The v2 runner's incorrect contenteditable selector failed; that attempt remains in `.local/k08-source-shell-input-v2/capture.log` and is not a product result.

Measured Source first primary button y is 70 for Brutal and 72 for Elegant, with 46 px pitch. Footer button tops are 592, 642, 692, 742 in all three themes at height 800. Ordinary DM is 32 px high in Brutal and 34 px in Elegant, with an 18 px outer/16 px inner avatar. The captured title and description have font weight 500. These are measured recipe inputs, not a whole-image acceptance score.

The existing desktop105 native collector had inherited the native hide-empty default while its immutable Source images came from Chromium Web with no stored choice. This is a fixture-state mismatch. The collector now explicitly supplies `PersonalPresentationStore(desktop:false)` and records `effectivePresentation` in each receipt. This changes the Flutter test input only; native product defaults, the original Source105 PNGs, fixture, IDs and thresholds are unchanged. No native collector was executed by this lane for this batch.

## Product and SDK changes

`raft_ui` owns the new heading, footer, rail action and Help menu components, their generated recipes, public exports and interactive previews. Optional menu header/trailing/right-side/hover APIs preserve existing dropdown defaults. Ordinary DM composition extends `RaftNavItem`; the app supplies accepted profile/avatar data and authorized actions. Client and native-service code remains outside the SDK.

The old duplicate sidebar server selector is removed; its native “Open workspace in browser” and middle-click behavior moved into the rail workspace switcher. The later bounded desktop server flyout and its retained gaps are documented in [workspace-server-menu-contract.md](workspace-server-menu-contract.md). The current mounted Source rail has no account flyout; the Sidebar's old account-menu comment does not define a mounted entry.

Actual workspace-toggle tests uncovered a real SDK error: an inner editor `Semantics(role:tab)` omitted the required selected state. Role and selected state now belong to the same existing `RaftInteractive` node. This retains the original selection callback, labels and visual layout; SDK semantic-state/input tests and actual workspace toggles cover the correction.

## Verification and retained failures

| Evidence | Result | Receipt |
| --- | --- | --- |
| New actual WorkspaceView K08a–f, three themes with Linux target | 18 PASS | `apps/raft_flutter/test/workspace_shell_contract_test.dart` |
| App shell plus Search/Activity/attention/grid/presentation/browser regressions | 63 PASS | `.local/k08-app-final.log` |
| SDK shell plus rail/dropdown/collision/theme/touch input regressions | 46 PASS, including 12 new shell/semantic cases | `.local/k08-sdk-final-verified.log` |
| App and SDK analysis | No issues | `.local/k08-{app,sdk}-analyze-final.log` |
| Design-system audit | 711 violations; no growth against 727 | `.local/k08-ds-final.log`, `.local/ds-audit.json` |
| Design-system host regression | 6 PASS | `.local/k08-ds-host.log` |

The extra Source-derived DM color assertion also retained a real Brutal mismatch at `.local/k08-dm-color-before.log` (62 PASS, 1 FAIL): the shared control inherited near-black while mounted Source DM text is black. The bounded DM text projection now uses actual black in Brutal and the inherited recipe color in Elegant; channel behavior is unchanged.

The actual workspace semantic error was retained at `.local/k08-mounted-fourth.log`: 12 PASS, 3 FAIL. All 15 then-current K08 cases passed after the fix in `.local/k08-mounted-fifth.log`. Earlier logs preserve test-platform and fixture focus mistakes separately from this real failure. The final test uses `TargetPlatformVariant({TargetPlatform.linux})`, a correctly expanded popup host, and separate keyboard frames; it does not disable assertions or skip the failing domain.

This batch removes 16 measured app violations, all from WorkspaceView: dimension 7→3, Material icons 4→2, dividers 2→0, icon button 1→0, list tile 1→0, menus 6→0. No allowlist or audit baseline is increased or masked. The target **727→300 remains incomplete** and requires further Source-derived component migrations. Full app checks, native process checks and the unchanged 402-image matrix belong to integration; this report does not reuse their older results as this batch's result.

## Remaining boundaries

K08 remains partial. This original shell batch did not implement the Community agreement dialog or Chinese discovery page, Mobile App's one-shot attention dot, exact joining spinner, workspace-mode Settings modal, full Source server flyout, server ordering/unread/remembered-surface state, pinned DM wrapping, or native visual pixel acceptance. The later bounded server-menu batch separately supplies ordering and accepted unread-summary state; its remaining gaps and evidence are recorded in [workspace-server-menu-contract.md](workspace-server-menu-contract.md). Ordinary Community joining is wired to the real API and accepted refreshed server list, but only the already joined current-server branch has new mounted proof here. Documentation launch uses the native service and was not exercised by the SDK/widget tests.

External full Search/Activity URI bootstrap remains the previously recorded gap. Markdown and visual calibration work remain paused. This batch does not alter message loading, focus expiry, route authority, or PopScope. The separately aborted Linux `handlePopRoute` probe used a platform input different from the app's actual desktop Escape history shortcut; its failure remains with the process lane and is not “fixed” by changing mobile Back or root window-pop behavior.

## Source-derived DM assertion correction after integration

Integration's original four failures are retained verbatim in `.local/k08-merged-before-fail.log`. The reported mobile 18-versus-10 difference is the human avatar placeholder, not the page heading: `AvatarSlot.tsx:90–95,126,229–230` separates the 18 px occupied sidebar avatar, 16 px face and 10 px User glyph. `Sidebar.tsx:1001` uses `text-sm` (14/20 px), with bold only for actual unread; its Brutalist black is inherited from the sidebar at `Sidebar.tsx:3754`. These agree with the already recorded three-theme actual Source browser capture.

The old assertions treated the DM as a count-only generic row. They now assert the actual avatar's outer box and mounted context, inner glyph, Source title line box/unread weight and theme-specific color. The existing channel selection, raster fill, hover, callbacks, navigation, Back, settings and semantic assertions remain. A separate real `WorkspaceView` mobile human-DM test covers all three themes with the no-unread weight 500, actual 18 px avatar and 10 px placeholder; it retains the mobile Home and Members entry checks.

Focused app tests are **27 PASS** (`.local/k08-merged-mobile-after.log`); SDK selection/navigation tests are **28 PASS** (`.local/k08-merged-sdk-after.log`). This is a test-contract correction with no product change. These mounted tests do not establish native Android execution or whole-page pixel parity, and they do not erase the original four-failure integration receipt.
