# Current acceptance checkpoint

The current product and verification input hash is `0e049d15ba2903ad884f9139c29bc0927752c0220972c672176f7c6afbd78d75`. Original Web is pinned to `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`, Web1.17.5 / raft-ui0.5.27.

463 Dart tests,29 host collector tests and whole-project static analysis passed. Linux and Android complete native runs for this checkpoint are now being executed. The previously completed6ab functional runs remain historical; they do not validate subsequent visual edits. Acceptance artifacts for the current checkpoint have not yet been built.

## Actual visual and interaction evidence

[Live comparison](http://100.109.192.23:18931/raft_flutter_visual_audit_20261008T032121Z/live/index.html) contains30 actual unscaled, same-size/DPR1 pairs:6 Inputs/Menus,6 folded/expanded forwarded bundles and18 Search/Account/Appearance/Tasks/Saved/Activity. All30 retain explicit visual failures. The523-row catalogue is a source inventory, not523 completed comparisons. [Immutable checkpoint](http://100.109.192.23:18931/raft_flutter_visual_audit_20261008T032121Z/checkpoints/0e049d15ba29/index.html) preserves this batch.

- Menu pointer selection, ArrowDown/Enter, Escape and restored trigger focus pass in all three themes. Actual browser activeElement becomes the focused Copy link menuitem, with tabindex0. This confirms the focus semantics correction.
- Forwarded target-label rightmost ink now matches the original in all six states: Brutal x532 and Elegant x526. Loose-parent regression reproduces and prevents the former free-space allocation error. Long labels have widget-test truncation proof; a long-label actual SDK capture remains pending.
- Tasks immediate filtering/Escape and Saved/Activity message navigation have actual browser receipts. Search Scope→Humans visibly updates to Scope(1); Account Reading preferences opens. The Appearance two-axis browser receipt remains pending after an SDK overlay blocked dialog cancellation; widget tests do not substitute for that receipt.

## Remaining differences

Dark input interiors match, but compound rims remain shifted: native top rim y52 versus original y53 and the source left inset remains absent. Forwarded dark header/footer is native#0d0d0b versus original#1b1b19; its inner body#242422 matches. Search filter widths/insets, message typography and SettingsPanel header/section composition still differ. The screenshots expose these differences without cropping away missing source sections.

Font audit loaded the same font versions and equal unshaped advances. Chromium loaded both the bundled Geist TTF and upstream WOFF with equal measured widths; Flutter automatic weights matched explicit variable axes. The remaining renderer/shaping discrepancy is measured, but its specific backend cause is unproved. No blanket weight or letter-spacing compensation has been applied. Full Mermaid grammar/layout, Shiki token styling and broader interaction-state visual parity remain limited.

## Background notifications

[Android background evidence](android-background-evidence.md) covers pushed c598 source: real killed-process headless polling, a genuine DM and OS notification, natural next-period deduplication, shade pointer navigation to the exact message, opt-out and sign-out cleanup. It is distinct from this whole-app checkpoint. iOS native execution still needs a Mac/device; Linux does not establish iOS locked-device or scheduler behavior.
