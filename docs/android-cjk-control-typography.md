# Chinese control labels on Android and Windows

Status: adopted. Owner rule and prior art: the Miraa app's
`docs/android-cjk-control-typography.md` (commit 33d35b15).

## Rule

```text
Android + zh locale + single-line control label (badge, chip, tag, button,
tab, segment, menu row)
    -> TextStyle.height = 1.35 (token) + leadingDistribution: proportional

Windows + zh locale + single-line control label
    -> TextStyle.height = 1.20 (token) + leadingDistribution: proportional

body text, multi-line text, other locales, iOS / macOS / Linux
    -> unchanged
```

`RaftControlTypography` (`packages/raft_ui/lib/src/control_typography.dart`) is
the only entry point:

- `resolve(baseStyle:, platform:, locale:)` and `of(context, style)` replace only
  `height` and `leadingDistribution`; size, weight, colour, family and fallbacks
  are kept. Other platforms/locales get the same `TextStyle` instance back.
- The value is a generated token: `tool/design-source/control-typography.json`
  -> `tool/gen-tokens` -> `tokens/typography.g.dart`
  (`RaftControlTypographyTokens.androidChineseLineHeight` and
  `windowsChineseLineHeight`). Never write a platform line-height factor at a
  call site.

## Why

Flutter centres a font's line box, not the visible glyphs. The recipes use the
CSS half-leading model (`leadingDistribution: even`) and `RaftCssLineBox` snaps
the baseline to Blink's even-leading model. Both keep whatever vertical offset
the Android system font and its CJK fallback have. Proportional leading moves the
baseline with the line height, and the offset of the ink from the box centre is

```text
(h * (a - d) / (2 * (a + d)) - inkCentre) * fontSize     (a, d: font ascent/descent)
```

so a taller proportional line moves the ink down, a shorter one up, for every font
whose natural line (a + d) is not exactly `h`.

The factors differ because the fallback font metrics differ. On Android the
Space Grotesk line with the Noto Sans CJK fallback benefits from a taller
proportional line (`1.35`); Windows'
Microsoft YaHei fallback puts the ink lower and benefits from a shorter one
(`1.20`). The Windows value was selected by a native Windows Flutter renderer
sweep over the three appearances at text scales 1.0, 1.3 and 2.0, rather than
by copying the Android value or adding an offset to the conversation tabs.
The fixture uses production controls and the installed fallback face, and
compares the rasterised text ink with the adjacent icon's ink. Its render-tree
capture is separate from an OS window screenshot or interactive acceptance.
Detailed measurements and raw before/after records belong in the fixing PR.

Both profiles are selected by UI locale. English UI labels retain their
existing line metrics; mixed-language labels inside Chinese UI follow that
UI's control profile. Font family, fallback order, size and weight are kept.

Android uses the bundled Space Grotesk / Space Mono like every other platform:
Latin text is set in the brand face and other scripts fall back. Android's
`fonts.xml` registers its CJK faces as unnamed `lang=` fallback families, so the
`Noto Sans CJK SC/TC/JP/KR` names in `RaftTokens.fontFallback` do not resolve
there; the regional face (SC, TC, JP, KR) is chosen by the text style's
`locale`, which every theme style carries (`textLocale`, the device locale).

## Where it is applied (centrally, in the primitives)

| Primitive | How |
| --- | --- |
| `RaftControl` (buttons, text buttons, tabs, picker triggers, mobile nav, conversation tabs, mounted task chip, ~45 call sites) | `DefaultTextStyle` is resolved |
| `RaftRecipeBox(controlLabel: true)` | `RaftBadge` (and the feedback status/unread badges built on it), `RaftButton`, `RaftTaskFilterButton`, segmented `buttons` items |
| `RaftSegmentedControl` label / suffix / count | the label restates its own style, so it is resolved explicitly (this was a leak) |
| `RaftRecipeButton` | text style resolved |
| `RaftCssText(controlLabel: true)` | `RaftRuntimeChip`, `RaftRecipeBadge`, Activity "mark all read". Resolves the style and replaces the Blink baseline snap in `RaftCssLineBox` by Flutter's own baseline (the snap would move the ink back) |
| Standalone chips | `RaftResourceBadge`, `RaftThreadRepliesBadge`, `RaftTaskStatus`, `RaftTaskSectionBadge`, `RaftActorTypeBadge`, `RaftArchivedBadge`, `RaftFeedbackKindChip` |
| Other fixed-height labels | Activity view buttons (`RaftActivityScopeToolbar`), `RaftMenuItem`, `RaftPanelTabs` (both variants), settings navigation rows |
| Material widgets | `raftTheme(locale:, platform:)` resolves the button families (text, outlined, filled, elevated, segmented, menu button), `chipTheme.labelStyle`, `popupMenuTheme.textStyle` and `navigationBarTheme.labelTextStyle`; `main.dart` passes the app locale |

Deliberately unchanged: `RaftSidebarUnreadCount` (digits only), `RaftReferenceChip`
(inline in a message paragraph, baseline aligned with the text), the sidebar
`RaftNavItem` rows (not measured), text fields, body and multi-line text.

## Maintenance rules

1. A single-line control label inherits its component's `DefaultTextStyle`. Do not
   restate `height` / `leadingDistribution` in a local `TextStyle`.
2. A label that must carry its own style calls `RaftControlTypography.of(context, style)`
   or the widget passes `controlLabel: true` (`RaftRecipeBox`, `RaftCssText`).
3. Multi-colour labels use one `Text.rich` with one root style.
4. Never use the profile for body text, multi-line text or display titles.
5. A new control family gets a case in `packages/raft_ui/test/control_typography_test.dart`
   and, if it appears on a page, in `apps/raft_flutter/test/control_label_typography_test.dart`.
6. Re-measure (below) when Flutter's text metrics, the Android CJK fallback, or a
   control's font size / fixed height change.

## Measuring on a device

`apps/raft_flutter/integration_test/cjk_labels_main.dart` runs the production
`RaftApp` on fixture data (no login, `displayLanguage` zh-CN, Raft look)
and a loopback control server. `tool/cjk-labels` drives it (`adb forward`, isolated
package `app.raft.raft_flutter.linkperf` only): for every small label it compares the
control box taken from the render tree (border box minus border) with the ink bounding
box taken from a real screenshot, and prints the vertical offset in px and dp.
`--height X|off` overrides the token (or disables the profile) at runtime for a sweep.

```sh
cd apps/raft_flutter
../../tool/flutter build apk --profile --target-platform android-x64 \
  --android-project-arg=raftApplicationIdSuffix=.linkperf \
  -t integration_test/cjk_labels_main.dart \
  --dart-define=CJK_LANG=zh-CN
adb -s <emulator> install -r build/app/outputs/flutter-apk/app-profile.apk   # .linkperf only
tool/cjk-labels --serial <emulator> --out /tmp/cjk-labels/run --launch \
  --page activity --page tasks --page computer:m1 --page computers \
  --page channel:kb --page members --scroll 1
```

The same run lists the paragraph style of every label (`h=1.35 proportional`): a CJK label
in a small control that prints anything else is a style leak.

## Evidence (Android 16 / API 36 x86_64 emulator, dpr 2.625, 2026-11-17)

Measured after Android moved from the system font to the bundled Space Grotesk
(Raft look, UI zh-CN, device locale zh-Hans-CN, stock Noto Sans CJK). 22 CJK labels
on the Activity, Tasks, computer, computers, channel and members pages, each
measured twice (scroll 0 and 1). Offsets are the ink-box centre minus the
control-interior centre (positive = ink low); one device pixel is 0.38 dp.

| line height | labels beyond 0.5 dp (of 44) | mean dp | max abs dp |
| --- | ---: | ---: | ---: |
| none | 26 | +0.32 | 1.38 |
| 1.20 | 26 | -0.50 | 1.17 |
| 1.25 | 4 | -0.06 | 1.76 |
| 1.30 (previous token) | 30 | +0.17 | 1.76 |
| 1.33 | 10 | +0.15 | 1.00 |
| 1.35 | 4 | +0.11 | 1.00 |
| 1.37 | 4 | +0.09 | 1.00 |
| 1.40 | 24 | +0.33 | 1.76 |

1.35 is chosen: every label written only in CJK is within 0.5 dp (1.35 and
1.37 form a plateau; the 1.35 run reproduced exactly). The curve is not smooth
because offsets land on whole device pixels. The two remaining labels mix Latin or digits
with CJK and sit on opposite sides at every height: the Activity reply badge
"5 条回复" (`RaftResourceBadge`, -1.0 dp at 1.35 and with the profile off) and
"添加 Computer" (+1.0 dp). The widget audit
(`apps/raft_flutter/test/app_control_label_centre_test.dart`) bounds the
Activity badges at 1.5 px on Android for that reason.

The previous token (1.30, 2026-10-12) was measured with the device's system
sans as the primary face and is superseded by this run.
