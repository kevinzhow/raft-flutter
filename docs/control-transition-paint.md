# Control transition paint

Mouse exit and selection changes could briefly fill an entire control with black. Final-state screenshots did not catch this: the hovered and idle channel row were both white, but intermediate frames reached `#141111` and obscured its label.

Two shared paint behaviors caused the flash:

- Flutter interpolated a visible fill toward transparent black by changing RGB and alpha independently. A white fill therefore became grey while fading.
- `BoxShadow.scale` reduces geometry but preserves color alpha. `BoxDecoration` paints those shadows underneath the entire box, so a departing opaque black shadow became visible through its fading background.

`RaftCssBoxDecoration` now interpolates colors with premultiplied alpha, fades added/removed shadow layers, and paints outer shadows only outside the border box. The same decoration is used by `RaftControl`, inline thread reply surfaces and channel file rows. Hover, selection, focus, keyboard activation, touch expansion, borders and movement remain active. Generated recipe boxes and the notification trigger already use the shared outer-shadow painter.

The regression captures every sampled intermediate frame at 8ms pump intervals, rather than waiting for an animation to finish. It covers three actual themes and real shared controls: channel hover exit, mobile tab selection/reversal, and opening/closing a menu while another channel remains selected. Each interior sample must remain between its two endpoint colors, allowing one byte for raster rounding. Native runs reuse these fixtures on the Linux renderer and Android emulator; they establish shared-control rendering, not authentication, full-page functionality, or completed platform parity.

Old and new PNG sequences are retained separately. The previous implementation failed 5 of these 9 widget scenarios; the corrected implementation passes all 9. Native frame receipts and full engineering results are published under the original 99-case report's supplemental evidence. The original visual case list, thresholds, Source product files and reference PNGs are unchanged by this fix.

The accompanying historical sender fix displays LEFT, REMOVED and DELETED from authorized identity data and prevents mentioning departed senders. Deleted Agent records remain available for historical presentation, but do not become mention candidates. The public custom `badge` label retains its prior presentation and text; departure labels have a separate field. Agent menus use the actual Source direct-message SVG, with source-sized rows and expanded native touch/semantics targets.

Validated input: `629cb2a65c955c2a139e81cf26eff3df965c58c8b73cb13d2dd13f6a1b514653`. All **1595 project tests pass**, with 3 skipped; **75 host tests pass** and the analyzer is clean. Linux and Android each pass 9 native control scenarios, with **255 PNG frames per platform**. The unchanged original matrix remains **78/99 passing, 21 different, no missing cases or capture errors**; all 99 React PNGs are byte-identical to the previous report. The 12 supplemental paired theme captures are separate evidence and retain their failures.

Raw evidence: `.local/cody-flash-before-frames/`, `.local/cody-flash-before-expanded.log`, `.local/cody-flash-native-linux-final2/`, `.local/cody-flash-native-android-final4/`, `.local/cody-flash-identity-three-themes-final/`, and the final engineering receipt. Initial compilation, legacy badge regression and Android collection/acknowledgement failures remain in separate logs and are superseded by completed checks; no failed attempt is relabeled as unexecuted.

The subsequent [Agent menu fix](agent-menu-anchoring.md) repeats all nine black-flash scenarios on both native renderers and adds three menu anchoring/input scenarios. Its newer input, 12 scenarios and 264 frames per platform are recorded separately from this initial validated batch.
