# Desktop footer and empty sidebar groups

This bounded follow-up starts from Flutter `db50083232765455cfcfd7705d0cc737e8cbc943`. It repairs three shared composition omissions: the empty sidebar drop-target height, CSS line boxes for sidebar hints, and footer SVG descendant size. It also connects the existing rail attention painter to the actual Help announcement lifecycle. It does not change navigation, theme recipes, stored empty-group preferences, Source, screenshot baselines, antialiasing, thresholds or the comparator.

## Source authority

The pinned Web is `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`, using the installed `raft-ui` recipes. References below are relative to that checkout.

- `packages/web/src/components/layout/Sidebar.tsx:335–371`: the section header is `mt-3 h-6 mb-1`; the description is `text-xs font-mono leading-snug`, with caller-owned spacing.
- `Sidebar.tsx:460–513`: `SidebarDndContainer` reserves `min-h-7` when empty. This is a 28px drop target, including when its actual text only needs 16.5px.
- `Sidebar.tsx:4092–4100`: the Pinned hint adds `mb-1 min-h-9 py-1.5` and a normally wrapping block span. At the real 222/223px sidebar content width the hint is two 16.5px lines plus 12px padding. Its body is 45px, followed by 4px margin; its whole group is 89px.
- `Sidebar.tsx:4203`: Joint Channels uses the ordinary section description inside that empty drop target. Its group is 40px header/margins plus 28px body: 68px.
- `packages/web/src/components/layout/LeftRail.tsx:693–771,1012–1098`: the bottom controls are Notification Center, Help, optional Workspace mode and Settings. The footer uses 44px slots with the resolved footer gap. Actual 1280×800 DOM button rectangles are 40px at y=592,642,692,742. Elegant `AppRailItem` descendant SVGs resolve to 16px; Brutal resolves to 18px. The Bell explicitly stays 18px in all themes.
- `packages/web/src/components/layout/mobileAppBadge.ts:30–56` and `LeftRail.tsx:191–203,719–729`: Help announces the Mobile App until that human opens the Mobile App resource. It is a per-user, per-device local flag. Opening Help alone does not consume it; anonymous users have no announcement. Optional storage failures retain the usable unseen/session-seen behavior.

The real DOM observations, classes, rectangles, computed styles and raw screenshots are retained in the private worktree at `.local/desktop-shell-audit/source-observation/react/*.shell-dom.json`. These are fresh diagnostic captures, not replacements for the frozen acceptance PNGs. The fresh dark diagnostic PNG matches the frozen dark reference; the other fresh diagnostic PNGs are retained separately and are never used as the acceptance baseline.

## Product changes and proofs

`RaftChatSidebarGroup` now uses the existing `RaftCssText` line-box renderer for its real hint and reserves the actual empty drop-target minimum. `RaftWorkspaceRailAction` reads its resolved `& svg` size rather than forcing 18px. Its optional attention child inherits the existing attention mask's current color. `RaftWorkspaceHelpMenu` exposes that controlled attention input; its interactive three-theme Preview consumes it on the actual Mobile App menu item.

`SourceMobileAppBadge` owns only the local seen flag. The browser's implicit origin boundary is represented explicitly in the native storage key, along with the human ID. Workspace switches preserve the choice. Late reads, a consumed pending read, principal changes and stale callbacks cannot restore or consume another person's flag. WorkspaceView binds that owner and supplies its accepted attention state to Help. The actual About action remains the existing host-owned route.

The browser fixture's `hideEmptySections=false` and native/Electron's existing default remain distinct. Existing persisted choices, collapse callbacks, sort/create actions, capabilities and group order are preserved.

Validation:

- 45 SDK checks pass, including nine new real-font layout/input/interactive Preview checks plus existing sidebar, footer and attention regressions.
- 27 app checks pass: six new three-theme actual WorkspaceView cases, three local-storage authority tests, and the existing 18 shell contract cases. The new page tests invoke actual Help/Mobile App/collapse handlers, inspect the four real buttons and group layout, and verify per-person dismissal.
- SDK and app analysis have no issues; design-system audit has no baseline growth.
- Three actual Linux captures before and three after pass on private Xvfb, using the real WorkspaceController/WorkspaceView and the unchanged shared desktop fixture. The private before PNGs match the Root db50083 native PNGs byte-for-byte.

## Selected frozen comparison

The comparator is the unmodified pinned Source `packages/visual-testing/src/cli.mjs diff`, with Sharp and its original pass/basic-pass thresholds. Its Source PNGs are copied byte-for-byte from Root `.local/cody-full-desktop-db50083/visual-testing-results/react`. No crop, scale, color, font, antialiasing or image modification was introduced.

| Actual 1280×800 Linux channel case | Pixel-perfect before | After | Status before / after |
| --- | ---: | ---: | --- |
| Brutal | 90.550586% | 91.292285% | DIFFERENT / DIFFERENT |
| Elegant light | 88.612598% | 89.339648% | DIFFERENT / DIFFERENT |
| Elegant dark | 88.622266% | 89.354199% | DIFFERENT / DIFFERENT |

Each selected case improved, but none crossed the original acceptance threshold. This is three selected cases, not a new result for the complete 105 desktop cases, original99, three-theme297 or functional native workflows. Remaining screenshot differences include the deferred panel-header flow/font cascade and wider conversation/composer surfaces. Brutal's shared rail currently paints its 2px right border without reserving the child width, leaving the known 1px horizontal centering difference; it is outside this first slice. Settings' separate feedback attention lifecycle is also outside this change.

## Artifact and environment receipt

All following paths are relative to the private worktree `.local/desktop-shell-audit/`:

- `before/visual-testing-results` and `after2/visual-testing-results`: raw images, native metadata and official `diff/react__android.json`.
- `comparison.json`: exact before/after scores, native and frozen Source SHA-256s, proof that the private before images match Root, and readback of all105 frozen Source PNG hashes.
- `frozen-source-byte-receipt.json`: selected baseline copy/readback equality.
- `before-linux-private-prefix.log`, `after2-linux.log`: actual private Linux process receipts.
- `sdk-before.log`: the original measured layout/SVG failures; `sdk-final.log`: 45 passing checks.
- `app-candidate1.log`: the retained initial test receipt with incorrect slot-vs-button top assertions; those test coordinates were corrected to the observed actual Source button rectangles, without changing product layout. `app-final.log`: 27 passing checks.
- `sdk-analyze.log`, `app-analyze.log`, `ds-check.log`.

The first private build failed because this new worktree lacked the local media runtime. `tool/prepare-media-linux` prepared only this worktree's pinned runtime. The next build failed because that interrupted CMake configuration cached `/usr/local` as its install prefix; the private build cache was corrected to this worktree's own `apps/raft_flutter/build/linux/x64/debug/bundle`. Both failures are retained in `before-linux.log` and `before-linux-prepared.log`; no host installation, Root build output, shared backend13041 or emulator5580 was used.
