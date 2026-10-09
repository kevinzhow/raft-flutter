# Settings header composition

The real Settings route now uses the Settings page's own navigation and content headers. WorkspaceView no longer prepends a full-width Settings header above them on desktop. This is a three-line composition correction; the shared header recipes, settings handlers, theme/default values and forms are unchanged.

## Actual Source contract

Pinned Source is `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`. [MainLayout SettingsRoute](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L661) directly mounts SettingsPanel in the main route body, with Settings navigation in its sibling Sidebar. [SettingsPanel7912](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/settings/SettingsPanel.tsx#L7912) owns the actual active-tab PanelHeader and scrolling body. It supplies no additional full-width Settings header above the sidebar and content.

Fresh real browser DOM at 1280×800/DPR1 measures both Account and Language & Region content headers at y0, with height 62 in Brutal and 56 in Elegant. Native before had its extra outer row and started those own content headers below it. The correction follows the route composition and reserves no artificial offset.

## Private paired Linux result

Source PNGs/metadata are frozen, byte-preserved copies from Root `.local/cody-full-desktop-a00dbe1/visual-testing-results/react`. Fresh browser observations remain separate. Before product is `df59ac2d77562995002a54e62febd9331ac401a4`; after changes only the outer-header composition. Both native runs use the unchanged desktop capture flow, the shared immutable fixture, a private Linux build/Xvfb process and whole 1280×800 raw images. No Root build/backend/emulator or Source mutation was used.

The unmodified pinned Source visual-testing CLI, original manifest and unchanged comparator give:

| Actual screen | Before similarity | After similarity | Actual result |
| --- | ---: | ---: | --- |
| Account Brutal | 65.875293% | 89.231641% | DIFFERENT; improved |
| Account Elegant light | 71.827734% | 86.160254% | DIFFERENT; improved |
| Account Elegant dark | 64.202832% | 78.619238% | DIFFERENT; improved |
| Language Brutal | 84.017773% | 87.739063% | DIFFERENT; improved |
| Language Elegant light | 86.334766% | 83.485645% | DIFFERENT; regressed |
| Language Elegant dark | 79.159668% | 76.611133% | DIFFERENT; regressed |

The two Elegant Language pixel regressions are preserved. Its existing native body only contains display-language/time-format controls, while actual Source additionally shows language/translation choices and a date/time section in cards. Moving that incomplete body into the correct header structure does not establish parity of its content. No coordinates, crops, antialiasing, colors or thresholds were adjusted to compensate for the existing deficit.

All six pairs remain DIFFERENT. This selected result does not establish whole 105/297 acceptance or a full authenticated native replay. Private evidence in `.local/desktop-settings-header-audit/` includes before/after raw PNGs/provider metadata/official diffs, `comparison.json`, `frozen-source-receipt.json`, source header DOM, process logs, test/analyzer receipts and `capture-receipt.json`.

## Mounted behavior evidence

Nine new tests mount the actual WorkspaceView, WorkspaceSettings, Account and Settings page with the real controller/client and named isolated transport. Three themes at 390/1280 prove that the Settings content header starts in the top row and that no outer page header is mounted. Actual mobile Back returns to the Settings root; desktop Language navigation retains the Source `language-region` URI and own header.

Of these, three runs inspect every one of 16 theme-transition frames. The actual Account EditableText state, controller, unsaved text, selection, composing range and focus remain accepted, while one own content header remains at the top and the URI remains Account. This is mounted WidgetTester evidence, not physical/native IME certification.

- 36 focused application checks pass, including the nine new page cases plus existing Settings save/authority and actual shell/footer behavior.
- Application analysis is clean, the design-system audit reports no baseline growth, and `git diff --check` passes.
- Six actual private Linux before/after captures complete. The initial six header failures remain archived. A separate mistaken test-only Language URI expectation was corrected against the pinned Source manifest, with the failed receipt preserved.

General Markdown wrapping, renderer calibration and other page-body discrepancies remain outside this correction.
