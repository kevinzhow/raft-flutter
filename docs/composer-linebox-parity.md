# Composer paint alignment and onboarding opacity

Reference: Source `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`, Web 1.17.5,
raft-ui 0.5.27. This patch follows the mounted `MessageInput.tsx` textarea and
`PendingMentionActionStrip.tsx` controls. Original99 IDs, thresholds and React
PNG bytes are unchanged.

## Changes

The Composer's box geometry already matched Source. Its text paint baseline
and brutal text color differed. The real `TextField` now uses the existing
measured CSS line-box implementation, exposed as `RaftCssLineBox`, and Source's
brutal `text-black` color. Selection, caret hit coordinates, the input
connection and IME remain owned by `EditableText`.

Pending mention action labels use shared CSS text. Add, Notify and Ignore now
use the shared `RaftRecipeButton`, including its keyboard and accessibility
behavior, instead of a private pointer-only control.

The Source disabled onboarding footer has a different captured compositing
result from an ordinary CreateAgent dialog or Composer Send, although all use
opacity. On white, the disabled pink surface is `[255,203,220]` in onboarding,
but `[254,202,219]` in ordinary dialogs and Composer. `RaftOpacityCompositing`
makes this measured boundary explicit: recipe surfaces default to ordinary
`Opacity`; only the actual `RaftCindySetupScreen` footer selects the reusable
alpha-only `RaftCssOpacity`. It changes no source colors or shadow layers.
Wrapper identity stays stable, and zero opacity retains the original semantics
exclusion. This is a mounted-component contract, not a global CSS claim.

A broader alpha-filter trial changed the ordinary dialog-error case from
97.441% to 95.798% and Composer empty from 98.160% to 95.608%. Those regressions
were removed. The shared resolved-radius inset-shadow correction remains.

## Paired evidence

Final selected capture: `.local/composer-final-retained/`, with
`selected-evidence.json` preserving all 16 React PNG SHA-256 values and the
before/after values. This is a selected-case result: 14/16 pass, not a full99
result. The CLI's 83 uncaptured cases must not be counted as verified.

| Original99 case | Before | After | Result |
| --- | ---: | ---: | --- |
| Composer empty | 97.485% | 98.160% | PASS |
| Composer states | 93.867% | 96.653% | PASS |
| Composer task-selected | 93.851% | 96.637% | PASS |
| Composer pending actions | 95.717% | 95.846% | DIFF |
| Composer member suggestions | 97.781% | 97.823% | PASS |
| Composer channel suggestions | 98.530% | 98.560% | PASS |
| Composer image preview | 96.858% | 97.841% | PASS |
| Cindy onboarding | 92.348% | 95.720% | DIFF |

All eight ordinary CreateAgent cases retain their previous pass and pixel
similarity. The pending strip and onboarding remain below the frozen 96%
threshold. Further paint differences are retained for a later repair batch;
no baseline normalization or Markdown wrapping work is included.

## Verification

SDK widget tests exercise all three themes: actual transformed caret hits,
selection ranges, active Japanese IME composition, Ctrl+Enter send gating,
pending-action keyboard receipts and disabled actions, opacity changes with a
live editor, and zero-opacity semantics. A pixel regression preserves all
three distinct Source disabled-surface contracts. Existing Composer draft,
selection-handle and folded-editor tests, three-theme black-flash transition
tests and resolved-radius tests also pass. SDK Previews expose the editable
line box and alpha-only opacity composition.

The SDK targeted suite passes 54 tests; the app onboarding/dialog suite passes
20. SDK and app analysis report no issues. Private logs are
`.local/composer-sdk-final.log`, `.local/composer-sdk-final-analysis.log`,
`.local/composer-app-regression-scoped-final.log` and
`.local/composer-app-analysis-scoped-final.log`.

These are widget and screenshot results. Native Linux/Android account flows,
the full99 three-theme matrix and desktop105 are owned by the integrating
agent and are not claimed here.
