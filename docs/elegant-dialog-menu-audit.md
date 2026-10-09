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

## Bounded Card used-border follow-up

`RaftAgentDialogCard` represents the actual Source `DialogCard` (`packages/web/src/components/ui/DialogCard.tsx:45`, used by `CreateAgentDialog.tsx:1727`). `RaftRecipeCard` represents the direct No Computer `Card` (`CreateAgentDialog.tsx:1689`). Both actual Source nodes specify Elegant `border-[0.5px]` through the installed Card recipe. At the original mobile capture size 390×844, DPR 3 and normal zoom, Chromium computes a **1 CSS-pixel** border for both nodes; Brutal stays at 2 pixels. The normal Card's left child offset is thus 24+1, not 24+0.5. This observation includes the transparent dark border, which still contributes to the box.

The opt-in `withCssUsedBorderWidths()` projection is used only by these two Card wrappers. Specified recipe values remain 0.5px, the global renderer is unchanged, and no zoom/DPR generalization is claimed. `agent_card_used_border_test.dart` covers the specified-to-used mapping and both mounted consumers in all three themes at DPR 3, including retained generated values and the actual child offset. The Source DOM observations and six private raw Source rasters are preserved separately from all 36 immutable official PNGs.

## Selected current visual results

The combined cascade and bounded border candidate was captured against the existing 12 cases in each theme. These are SDK/widget captures with TargetPlatform.android, not native Android runs. The official strict >96% threshold is unchanged; all 36 Source bytes still match the frozen root matrix hashes.

| Theme | Selected PASS before → after | Mean similarity before → after |
| --- | --- | --- |
| Brutal light | 12/12 → 12/12 | 97.91% → 97.91% |
| Elegant light | 2/12 → 11/12 | 90.54% → 96.61% |
| Elegant dark | 0/12 → 0/12 | 62.78% → 92.46% |

The nine new selected passes are the two message-menu cases and seven ordinary Create Agent cases in Elegant light. The No Computer light case remains PASS but drops 96.84%→96.24%; its Source generic button is deliberately kept distinct from the ordinary footer override. Dark ordinary Agent cases improve 72–74%→93.3–93.8%, No Computer 22.55%→94.62%, and menus 19.28%→89.06%; they remain DIFF. The unchanged legacy Card and generic form controls remain 86.27% and 94.99% in dark. The Source menu fixture has a white MessageItem caller; the application ChatView still supplies conversation-panel chrome and retains a measured residual rectangle behind that fixture's message. ChatView is outside this repair lane.

`.local/foundation-comparison.json` records every exact before/after metric and unchanged Source hash. Current outputs are `.local/foundation-validated-{brutal,light,dark}`; earlier candidate outputs and analysis failures remain preserved. This selected receipt adds no claim about the unrun full297/desktop105/native suites. Final combined SDK validation passes 50 checks (including the four isolated used-border proofs); both SDK and app analyses are clean, and the DS ratchet passes all six checks without updating its baseline. The three actual Create Agent app checks pass. Final targeted validation is recorded in `.local/foundation-final-sdk.log` and `.local/foundation-final-sdk-analyze.log`; application analysis and the three actual Create Agent checks are unchanged by the bounded Card projection.
