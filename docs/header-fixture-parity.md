# Channel header fixture and product parity

The official mobile matrix is **78/99 passing**, with **21 different**, no missing cases or capture errors and 9 strict passes. Original cases, crop sizes and thresholds are retained. Source remains pinned to `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`.

The original header fixture mounted the complete read-only ChatPanel in its 390×120 screenshot clip. Its message body collapsed to zero; its footer began at y=92 and appeared in a header-only screenshot. An exact replay of the previous official provider reproduced the original PNG byte for byte. The owner-authorized fixture adapter now lays out that same ChatPanel at the declared 390×844 viewport inside the unchanged 390×120 clip. Browser assertions verify the viewport, header, tabs, title and footer exclusion separately for Brutal and Elegant. Source product files and read-only state are unchanged.

The original header PNG is archived with SHA-256 `1e3b56409c067d13c2e51557977a870b851309c362b6a6006d326953c193d8b1`. The other **98 React PNGs remain byte-identical**. The report provides the old PNG and the new actual DOM receipt. Repairing the fixture alone scored 88.9%, still different.

The product header uses the actual outline `Button size="icon-sm"` recipe for Search and Settings, retaining the separate PanelAction back control. The shared icon button supports keyboard activation, disabled state, focus and a 48px touch target without inflating its 28px layout. The header title and tab labels use CSS line boxes. The header icon and active tab use the actual CSS primary alias (`--color-primary` → `--primary-400`) rather than the distinct legacy `--primary` component role.

| Theme | Pixel similarity | Result |
| --- | ---: | --- |
| Brutal light | 97.589% | Pass |
| Elegant light | 93.661% | Different |
| Elegant dark | 94.317% | Different |

Validation for input `50302eb83f12d726feebb973a7c787c2280a5bef4dfb711dce128c6dde6ef915`: **1580 project tests passed, 3 skipped; 75 host tests passed; analyzer clean**. Focused header and tabs checks cover keyboard/touch callbacks, disabled actions and source-sized geometry across three themes. Both providers completed the theme capture without errors or input drift.

Evidence: `.local/cody-header-final-engineering/`, `.local/cody-header-three-themes-final/`, `.local/cody-header-source-probe/`, `.local/cody-header-reference-before.json` and `.local/cody-header-final-receipt.json`. Failed compile and theme-height verifier attempts remain in separate output directories and are superseded, not relabeled as unexecuted.

These are Linux Flutter widget captures at mobile dimensions, not Android device verification. Native Linux and Android workflows for this input remain **NOT_RUN**. Whole-app parity remains incomplete; this batch does not approve a merge, release or deployment.
