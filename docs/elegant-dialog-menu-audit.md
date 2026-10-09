# Elegant dialog and message-menu audit

## Source and caller boundaries

The authority is Source `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`, its installed `raft-ui` 0.5.27 package, and the accepted three-theme matrix on Flutter `8282dcae13fd702cc5d0504b1f6017d4dfd7e774`. Generated specified recipes, Source files, baseline images, antialiasing, thresholds, and Markdown wrapping are unchanged.

- `packages/web/visual-testing/VisualTestingCases.tsx:2493` explicitly supplies a white Create Agent caller background in every theme. The Message Item menu caller does the same at line 3500. The Flutter fixture now supplies those actual caller backgrounds; ordinary application canvas defaults retain their themes.
- The Agent modal is a portal outside the caller's `font-display` main. `packages/web/src/index.css:183` gives the body `font-sans`. The real rendered Card inherits Hanken Grotesk for Brutal and Geist for both Elegant modes. The shared Agent Card now inherits that body font instead of forcing the heading font.
- Agent Card, input, select, Banner, and the message-menu popup now use the existing `RaftRecipeBox` painter. This preserves the actual dark inset layers that plain `BoxDecoration` consumers omitted. The global painter and recipe generator are unchanged.
- FieldLabel's `dark:text-foreground-hint` wins over StableField's base `text-foreground-strong`. The shared label resolves the actual dark recipe before the caller's base color.
- Banner descendants resolve `group-data-[status=warning]/banner` and the inline action's `text-current`. Ordinary warning recipes retain their default colors. The capacity caller alone supplies `dark:bg-warning-soft` and `dark:!text-warning-strong`, matching `CreateAgentDialog.tsx:1780–1799`.
- The ordinary Create Agent footer alone supplies `dark:!text-foreground-inverse`, matching `CreateAgentDialog.tsx:2103`. The No Computer and runtime primary buttons retain the generic accent recipe. Public foreground options express an explicit caller class; they do not change shared defaults.

## Interaction evidence

`packages/raft_ui/lib/agent_surface_previews.dart` provides a live three-theme form preview with input, select, disabled submit, explicit capacity-caller toggle, and close. `agent_surface_cascade_test.dart` exercises the actual editable text focus, Japanese IME composition, selection and keyboard state across theme/invalid-state repaint; warning-default versus capacity-caller color; menu pointer/Enter/Escape/disabled semantics; and button default versus explicit caller foreground. All 18 focused checks pass. The actual Create Agent app tests pass all three cases.

The existing three-theme control-transition and menu/selection tests were also run with this paint change: 47 combined checks passed before the card used-border proof was separated into its own follow-up. This count includes the separate border projection experiment and is not page or native-flow evidence. Original experiment/failure logs remain under `.local/foundation-*`.

## Private evidence

- `.local/foundation-frozen-byte-receipt.json`: 36 selected Source PNG hashes copied from `.local/cody-full-three-themes-8282dca-retry1` in the root checkout.
- `.local/foundation-source-dom.json`: real rendered Source font/cascade/shadow observations at 390×844, DPR 3, normal zoom.
- `.local/foundation-source-card-dom.json` and six `.local/foundation-source-card-*.png`: real ordinary DialogCard and No Computer Card observations in each theme.
- `.local/foundation-source-border-rules.json`: actual matching specified rules and computed used border widths.
- `.local/foundation-cascade-commit-test.log`, `.local/foundation-validated-app.log`, `.local/foundation-ds-audit.log`: focused validation; DS ratchet passes without any baseline update.

The DOM audit uses a private Source host and neutral request replies to inspect actual styles. Its screenshots are observations, not replacement official baselines or complete real-account flow evidence. A separate bounded card-box commit records the specified-to-used border projection and final selected visual comparisons. Full 297, desktop 105, Linux native, and Android native consolidation remain the parent agent's responsibility.
