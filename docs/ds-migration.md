# Design-system migration map (apps/raft_flutter/lib → raft_ui)

Snapshot: branch `cindy/ds-guard` on top of `3f3c72f`, measured with `tool/ds-audit`.
The snapshot covers 125 Dart files. It found **1118 enforced violations in 65 files**
(widget 492, style 626) and **0 allowlisted**. The ratchet baseline is
`tool/ds-audit-baseline.json`. Every number below comes from `.local/ds-audit.json`
for this snapshot. Re-run the tool before you start a package, because the numbers
change as work lands.

## 1. Tooling

| Command | Effect |
|---|---|
| `tool/ds-audit` | Prints totals per category, the top 15 files and the comparison with the baseline. Writes `.local/ds-audit.json`, which holds every finding with file, line, column, category, name and argument shape. |
| `tool/ds-audit --check` | Exits 1 if any file/category count is above the baseline (new files and new categories count from 0), or if a `ds-allow` comment has no reason. |
| `tool/ds-audit --update-baseline` | Writes the current counts after you remove violations. It refuses to raise any count unless you also pass `--accept-increase`, and a raised count must be reviewed. |
| `tool/ds-audit --json <path>…` | Prints the aggregated report for arbitrary paths. The tests use this. |

- **Ratchet test:** `tool/tests/test_ds_audit.py` runs in `tool/check-project`. It runs the
  scanner over `apps/raft_flutter/lib` and fails on any per-file, per-category increase. When
  counts go down, it prints the `--update-baseline` hint. The same file also pins the scanner
  semantics with exact counts on `apps/raft_flutter/test/fixtures/ds_audit_sample.dart`, which
  includes negative cases.
- **Scanner:** `tool/ds_audit/` is a Dart program that uses the analyzer's **resolved** AST.
  Every finding is decided from the declaring library of the resolved constructor, getter or
  function, so it does not depend on the source text. Comments, strings, app-local classes and
  raft_ui subclasses are never miscounted. For example, `RaftTooltip extends Tooltip` does not
  count. The scan aborts (exit 2) when a file has analysis errors, because unresolved code would
  silently undercount.
- **Allowlist:** put `// ds-allow: <reason>` on the offending line or on the line directly
  above it. Allowlisted findings are reported separately and do not count toward the ratchet. A
  `ds-allow:` with no reason still counts and fails `--check`. Use it only for genuinely
  platform-only code, and expect it to be reviewed like an API change.

### Audit rules (what each category counts)

| Category | Counted when |
|---|---|
| `widget.<group>` | A constructor of a Material/Cupertino class in the group table (`materialGroups` in `tool/ds_audit/lib/ds_audit.dart`), or a Material top-level function (`showDialog`, `showModalBottomSheet`, `showMenu`, …), or `ScaffoldMessengerState.showSnackBar/showMaterialBanner`, or `X.styleFrom()`. Other Material/Cupertino `Widget` subclasses count as `widget.other`. `MaterialApp` and `ScaffoldMessenger` are not counted. |
| `style.edge_insets` | An `EdgeInsets*`/`EdgeInsetsDirectional*` constructor with a numeric literal anywhere in its arguments (`EdgeInsets.all(t.border * 4)` counts; `EdgeInsets.only(left: t.border)` does not). |
| `style.sized_box` | A `SizedBox*` constructor whose `width`/`height`/`dimension` argument contains a numeric literal (`SizedBox.shrink()` and `double.infinity` do not count). |
| `style.dimension` | Any other `package:flutter` constructor argument named `width height size dimension min/maxWidth min/maxHeight iconSize strokeWidth thickness indent endIndent spacing runSpacing elevation radius splashRadius` that contains a numeric literal. Each argument counts once. |
| `style.font_size` / `style.font_weight` | A `fontSize:` argument with a numeric literal, or a `fontWeight:` argument that references `FontWeight.*`, in any call (including `copyWith`). |
| `style.text_metrics` | A `height:`, `letterSpacing:` or `wordSpacing:` argument with a numeric literal on `TextStyle`/`StrutStyle` constructors or methods. |
| `style.text_style` | A `TextStyle(...)` constructed in app code. |
| `style.border_radius` | A `BorderRadius*`/`Radius.*` constructor with a direct numeric literal (`BorderRadius.all(Radius.circular(4))` counts once). |
| `style.color_literal` / `style.material_colors` | A `Color(...)`/`Color.from*` constructor, or a use of `Colors.*`/`CupertinoColors.*`. |
| `style.material_icons` | A use of `Icons.*`/`CupertinoIcons.*`. |
| `style.duration` | A `Duration(...)` literal passed (possibly through `?:`) to a parameter whose name contains "duration", or a use of `Durations.*`. Timers and timeouts do not count. |
| `style.material_theme` | Any `ThemeData` member access except `extension<T>()`, `extensions` and `platform`; `ColorScheme.of`/`TextTheme.of`; constructing `Theme`/`ThemeData`/`*Theme`/`*ThemeData`. |

**Known blind spot:** a literal hidden behind a local constant (`const _gap = 12.0;
SizedBox(height: _gap)`) is not counted. Reviewers should reject new private size or color
constants in feature files.

## 2. What raft_ui already exports

From `packages/raft_ui/lib/raft_ui.dart`:

- **Tokens:**
  - `RaftTokens.of(context)`: semantic colors (`ink strong muted canvas sidebar panel card popover line fieldLine accent accentSoft accentFill primaryFill`, plus the full `colors[...]` map), `radius`, `fieldRadius`, `border`, `shadows`, `fieldStyle`.
  - `RaftTypography`: `heading`, `textHeading(level)`, `sans(RaftSansSize.large/body/small/caption)`, `body`, `mono`, `code`, `attachmentTitle/Meta`.
  - `RaftShapes`: `control`, `field`, `panel`, `attachment`.
  - `RaftMetrics`: button, icon, field, rail, panel-header and composer sizes.
  - `RaftLayoutMetrics`: `panelInset 20`, `panelGap 12`, `toolbarInset`, breakpoints.
  - `RaftPrimitives`: `controlDuration 100ms`, `switchDuration 180ms`, `radii [0,2,4,6,8]`, and `spacing [0,2,4,…,64]`. **The spacing scale is an unnamed list.**
- **Controls:** `RaftButton`, `RaftTextButton`, `RaftTextLink`, `RaftIconButton`, `RaftBackButton`, `RaftSavedActionButton`, `RaftControl` (+ `RaftControlRecipe`, `RaftControlVariant surface/primary/accent/outline/ghost/danger`), `RaftSegmentedControl<T>`, `RaftPickerTriggerButton`, `RaftSwitch`.
- **Menus and select:** `RaftDropdownMenu`, `RaftMenuPanel`, `RaftMenuItem`, `RaftMenuEntry` (incl. `.separator()`), `RaftMenuController`, `RaftSelectField<T>`. `RaftSelectField` still takes Material `DropdownMenuItem<T>` items.
- **Fields and forms:** `RaftFieldSurface`, `RaftFieldRecipe`, `RaftFieldBorder`, `RaftFormDialog` + `RaftFormField`, `RaftSecretView`.
- **Feedback:** `RaftSpinner`, `RaftTooltip` + `RaftTooltipProvider`, `RaftEmptyState`, `RaftNotificationCenter`, `RaftSystemMessage`.
- **Surfaces and layout:**
  - Surfaces: `RaftPanel`, `RaftPopoverSurface`, `RaftCollapsible`, `RaftShowMoreToggle`.
  - Workspace and navigation: `RaftAdaptiveWorkspace`, `RaftWorkspaceRail`, `RaftPanelResizeHandle`, `RaftNavItem`, `RaftSidebarSectionHeader`, `RaftMobileNav`, `RaftMobileRootHeader`, `RaftMobileServerSelector`.
  - Recipes: `RaftPanelHeaderRecipe`, `RaftSidebarRecipe`.
- **Icons:** `RaftIcon(RaftGlyph.x)` with 88 Lucide glyphs, and `RaftSymbol`.
- **Chat, tasks and attachments:** the message/composer/thread/attachment/task families. These are not relevant to the groups below.

The app also contains its own design components that belong in raft_ui:

- `features/page_layout.dart`: `RaftPageHeader`, `RaftSettingsSection`.
- `features/page_component_recipes.dart`: `RaftSearchRecipe`, `RaftSettingsProfileCard`, `RaftSettingsLayoutRecipe`, ….

Package C5 promotes these.

raft_ui itself still has some Material drift, outside this scan's scope. For example,
`RaftEmptyState` uses `Icons.forum_outlined` and `Theme.of(context).textTheme`. The C packages
should fix this kind of drift where they touch it.

## 3. Violation groups, biggest first

"Existing" means the call site can migrate today. "Missing" names the raft_ui component that
must be built first, the raft-ui (npm `raft-ui` 0.5.27) export it mirrors, and the Web source
it follows. Web paths are relative to `raft-source/packages/web/src/`. The **C#** label points
to the component package in §4.

### 3.1 Spacing and hand-written sizes — 355 (C1)

- **Counts:**
  - `style.sized_box` 134
  - `style.edge_insets` 123: `.all` 59, `.symmetric` 30, `.only` 24, `.fromLTRB` 10
  - `style.dimension` 98: `Wrap(spacing:)` 26, `Wrap(runSpacing:)` 16, `Container(height:)` 8, `Divider(height:)` 7, `BoxConstraints(maxWidth:)` 6, `Border(width:)` 6, `Icon(size:)` 5, `Container(width:)` 5, `BorderSide(width:)` 5, …
- **Biggest files:** `resource_view.dart` 52, `settings_page.dart` 33, `page_component_recipes.dart` 19, `account_settings.dart` 17, `resource_search.dart` 15.
- **Missing (C1): named spacing tokens.** raft-ui defines no spacing scale; the Web uses Tailwind's default 0.25rem steps (`gap-2`, `p-4`, …). `RaftPrimitives.spacing` already holds the same steps, but only as an unnamed list.
  - Add `RaftSpace` (named steps, e.g. `RaftSpace.s1 = 4 … s16 = 64`) plus a `RaftGap` widget.
  - Then use `RaftLayoutMetrics`/`RaftMetrics` for component sizes and `RaftTokens.border` for border widths.
  - `Icon(size:)` becomes `RaftIcon` with `RaftMetrics.iconSm/iconMd`.
  - `Divider(height:)` goes away with the RaftSeparator (C4).

### 3.2 Material icons — 113 uses, 68 distinct `Icons.*` (existing + C6)

- **Existing:** `RaftIcon(RaftGlyph.x)`. 74 uses (41 distinct icons) have a candidate glyph today.
- **Missing (C6):** 39 uses need 26 Lucide glyphs added to `RaftGlyph`. The Web imports these from `lucide-react`.
- Candidate mapping (confirm each against the lucide import of the matching Web screen):
  - **Available today:**
    - `add`→plus, `refresh`→refreshCw, `search`→search
    - `delete/delete_outline`→trash2, `close`→x
    - `edit/edit_outlined`→pencil, `chevron_right`→chevronRight, `expand_more`→chevronDown
    - `visibility(_off)`→eye/eyeOff, `logout`→logOut, `link`→link
    - `computer(_outlined)`→monitor, `smart_toy_outlined`→bot, `tag`→hash
    - `tune`→slidersHorizontal, `open_in_new/open_in_browser`→externalLink
    - `check_circle_outline`→circleCheck, `check_box_outlined`→squareCheck
    - `bookmark_border`→bookmark, `people_outline`→users, `person_outline`→user
    - `account_circle_outlined`→circleUserRound, `public`→globe, `lock_outline`→lock
    - `notifications_outlined`→bell, `insert_drive_file`→file, `chat_bubble_outline`→messageSquare
    - `share_outlined`→share2, `forward`→forward, `copy`→copy
    - `check/done`→check, `arrow_upward`→arrowUp, `circle`→circle
    - `add_a_photo`→imagePlus, `view_list_outlined`→list
  - **To add:**
    - `folder`, `messagesSquare` (forum ×3), `unlink` (link_off ×3), `gripHorizontal` (drag_handle ×3)
    - `archive`, `layoutGrid` (apps), `circleAlert` (error_outline), `inbox`, `bellOff`, `bellRing`
    - `smilePlus`, `bookmarkMinus`, `puzzle`, `wrench`, `history`, `network`
    - `keyRound`, `arrowUpFromLine`, `music`, `userPlus`, `brain`, `rotateCcw`
    - `shield`, `undo2`, `badgeCheck`, `squareKanban`

### 3.3 List rows (ListTile family) — 91 (C2)

- **Counts:** `ListTile` 71, `SwitchListTile` 13, `CheckboxListTile` 7.
- **Biggest files:** `fleet_views.dart` 26, `channel_settings.dart` 11, `admin_views.dart` 9, `chat_view.dart` 8, `joint_channel_views.dart` 6.
- **Shapes, from the recorded argument shape:**
  - 37 action rows (`onTap`)
  - 16 key/value rows (title+subtitle, no tap)
  - 15 rows with a trailing control
  - 3 avatar rows (`leading: RaftAvatar`)
- **Missing (C2):** raft-ui has no generic list item. Mirror the Web primitives:

| Shape | New raft_ui component | Web source |
|---|---|---|
| action row | `RaftActionRow` | `components/ui/MenuItem.tsx`; `components/ui/OverflowSheet.tsx` (`OverflowActionRow`) |
| key/value | `RaftKeyValueRow` | `components/ui/KeyValueRow.tsx` |
| avatar row | `RaftAvatarListRow` | `components/ui/AvatarListRow.tsx` |
| framed row | `RaftSurfaceListItem` | `components/ui/SurfaceListItem.tsx` (raft-ui `Card`) |
| switch row | `RaftSwitchRow` (uses `RaftSwitch`) | `OverflowSheet.tsx` (`OverflowSwitchRow`) |
| checkbox row | `RaftCheckbox` + row | raft-ui `Checkbox`; `components/auth/LegalAcceptanceCheckbox.tsx` |

Settings navigation lists mirror `components/settings/SettingsNavList.tsx` and
`SettingsSidebarList.tsx`, which wrap the raft-ui `SidebarItem`. `RaftNavItem` already covers
those.

### 3.4 Buttons — 73 (existing)

- **Counts:** `TextButton` 62, `TextButton.icon` 9, `FilledButton` 1, `ButtonStyle` 1. Of these, 62 calls have the plain `child: Text + onPressed` shape.
- **Biggest file:** `resource_view.dart` 14.
- **Replacements:**
  - `RaftButton(label:, onPressed:, variant:, busy:, destructive:)` for dialog and page actions.
  - `RaftTextButton(label:, glyph:)` for icon+label buttons.
  - `RaftTextLink` for inline links.
- **Variants:** match raft-ui `Button` variants (`primary/outline/ghost/danger…`). Web examples: `components/ConfirmDialog.tsx`, `components/ui/CloseButton.tsx`.

### 3.5 Dialogs — 73 (C3; form dialogs existing)

- **Counts:** `showDialog()` 30, `AlertDialog` 22 (all `title+content+actions`), `SimpleDialogOption` 10, `SimpleDialog` 7, `Dialog` 3, `Dialog.fullscreen` 1.
- **Biggest files:** `server_views.dart` 12, `workspace_view.dart` 10, `resource_view.dart` 8, `managed_agent_launcher.dart` 7.
- **Existing:** `RaftFormDialog` for form dialogs. 12 of the 30 `showDialog` calls already open it (measured by grep on the builder lines), but they still go through the Material route (default barrier and transition).
- **Missing (C3):**
  - `showRaftDialog`: barrier from `layer-backdrop`, raft transition. Mirrors raft-ui `DialogOverlay/DialogPortal`; Web `components/Modal.tsx`.
  - `RaftConfirmDialog`: mirrors raft-ui `AlertDialog*` (`AlertDialogAction/Cancel`); Web `components/ConfirmDialog.tsx`.
  - `RaftDialog` frame (header, body, footer): mirrors raft-ui `Dialog*`; Web `components/ui/DialogCard.tsx`.
  - `RaftSelectionDialog` for the `SimpleDialog` "Choose computer/runtime/workspace" pickers: rows of `RaftActionRow` with a ✓. Web `components/ui/SelectionPopover.tsx`.

### 3.6 Material theme reads — 52 (existing)

- **Counts:** `ThemeData.textTheme` 31, `ThemeData.colorScheme` 17, `Theme` widget 2, `brightness` 1, `scaffoldBackgroundColor` 1.
- **Spread:** 28 files; `server_views.dart` has the most (6).
- **Replacements:**
  - `RaftTypography.*` for text styles.
  - `RaftTokens.of(context)` for colors.
  - `RaftTokens.dark` for brightness.
  - `Theme(data: …copyWith)` overrides should become raft components.

### 3.7 Typography literals — 48 (existing)

- **Counts:** `TextStyle(...)` 26, `fontWeight:` 15, `letterSpacing:` 4, `fontSize:` 2, `height:` 1.
- **Biggest files:** `resource_view.dart` 10, `channel_settings.dart` 7, `page_component_recipes.dart` 6.
- **Replacements:** `RaftTypography.heading/textHeading/sans/body/mono`. These mirror raft-ui `TextHeading` (levels 1–6), `TextSans` (`large/body/small/caption`) and `TextMono`.
- **Gap:** raft-ui has no named semibold body variant, so a weight that isn't in a recipe needs a recipe addition, not a page `copyWith`.

### 3.8 Text fields — 45 (C4)

- **Counts:** `InputDecoration` 24, `TextField` 13, `TextFormField` 8.
- **Biggest files:** `auth_view.dart` 8, `account_onboarding.dart` 6, `resource_view.dart` 6, `runtime_form_dialog.dart` 6.
- **Existing building blocks:** `RaftFieldSurface`, `RaftFieldRecipe`, `RaftFieldBorder`, `RaftTokens.fieldStyle`. There is no reusable field widget yet.
- **Missing (C4):** `RaftTextField`/`RaftTextArea` with label, help and error slots.
  - Mirrors raft-ui `Input`, `InputGroup(+Addon)`, `Textarea`, and `Field`/`FieldLabel`/`FieldDescription`/`FieldError`.
  - Web: `components/ui/FormField.tsx`, `components/ui/SlugInput.tsx` (`PrefixedInput`), `components/agent/StableField.tsx`.
  - `RaftFormDialog` should use it internally.

### 3.9 Snackbars and banners — 38 (C3)

- **Counts:** `showSnackBar()` 18, `SnackBar` 18 (16 are text-only), `SnackBarAction` 1, `MaterialBanner` 1.
- **Biggest files:** `chat_view.dart` 10, `attachment_view.dart` 9.
- **Missing (C3):**
  - `showRaftToast(context, message, intent:)` + `RaftToast`. Mirrors raft-ui `toast` / `Toast*` (`ToastIntent info/success/warning/error`). Web: `components/toastBridge.ts` (`showToast`), `components/LocalizedToastProvider.tsx`.
  - `MaterialBanner` → `RaftBanner`. Mirrors raft-ui `Banner*`; Web `components/ui/Banner.tsx` (`AppBanner`).

### 3.10 Colors — 34 (existing; one decision)

- **Counts:** `Colors.transparent` 21, `Colors.black` 9, `Colors.white` 3, `Color(0x…)` 1.
- **Biggest files:** `source_channel_files_view.dart` 19, `resource_cards.dart` 4, `platform/system_bars.dart` 3.
- **Replacement:** `RaftTokens` semantic colors (`colors['layer-backdrop']`, `ink`, …).
- **Decision for the reviewer:** `Colors.transparent` carries no design value. Either add `RaftTokens.transparent` or exempt it in the scanner. Do not allowlist it 21 times.
- **Platform case:** `system_bars.dart` sets OS system-bar colors. It is the one plausible `// ds-allow: platform system bars` case.

### 3.11 Menus — 25 (existing)

- **Counts:** `PopupMenuItem` 15, `PopupMenuButton` 6, `MenuAnchor` 2, `MenuItemButton` 1, `PopupMenuDivider` 1.
- **Files:** `resource_view.dart` 9, `workspace_view.dart` 6, `channel_settings.dart` 4, `server_views.dart` 3, `source_channel_files_view.dart` 2, `task_selection_filter.dart` 1.
- **Replacements:** `RaftDropdownMenu` + `RaftMenuEntry` (+ `.separator()`), or `RaftMenuPanel`/`RaftMenuItem` with a `RaftMenuController`. These mirror raft-ui `DropdownMenu*`/`ContextMenu*`; Web `components/ui/ContextMenuDivider.tsx`, `components/channel/ChannelOverflowMenu.tsx`.

### 3.12 Surfaces and raw ink — 22 (existing)

- **Counts:** `Material` 12, `Card` 6, `InkWell` 4.
- **Replacements:**
  - `Card` → `RaftPanel`, or `RaftSurfaceListItem` (C2) when it wraps a row (2 `Card(child: ListTile)`).
  - `Material(color:)` used as a backdrop → `RaftPanel`/`RaftPopoverSurface`.
  - `InkWell` and `Material(shape:, child: InkWell)` → `RaftControl` (hover, pressed and focus come from the recipe).

### 3.13 Other Material widgets — 22 (C4 + decision)

- **`SelectableText` 19:** raft-ui has no counterpart because Web text is natively selectable. Option 1: add a thin `RaftSelectableText` (C4) that applies raft selection colors and typography. Option 2: allowlist with a reason.
- **`ReorderableListView.builder` 3** (`sidebar_preferences_view.dart`): Web sorting uses raft-ui `SortableTabsList`/dnd. Keep the Flutter list with `// ds-allow: platform reorder gesture` unless a raft sortable list is built.

### 3.14 Page scaffold and app bars — 21 (C5)

- **Counts:** `Scaffold` 13 (8 of them with `appBar: AppBar`, which accounts for every `AppBar`), `AppBar` 8.
- **Files:** `fleet_views.dart` 4, `integrations_views.dart` 4, `main.dart` 2 (`Scaffold(body: Center(child: CircularProgressIndicator()))` loading screens), ….
- **Existing:** the app-local `RaftPageHeader` (`features/page_layout.dart`), and `RaftMobileRootHeader` for mobile roots.
- **Missing (C5):** a raft_ui `RaftPage` + `RaftPanelHeader`, created by promoting `RaftPageHeader`.
  - Mirrors raft-ui `Panel`, `PanelHeader(+Content/Title/Actions)`, `PanelBody`.
  - Web: `components/ui/PanelHeader.tsx` (`AppPanelHeader`), `components/ui/SectionHeader.tsx`.

### 3.15 Border radius — 21 (existing)

- **Counts:** `BorderRadius.circular` 13, `Radius.circular` 8.
- **Files:** `source_channel_file_glyph.dart` 8, `settings_page.dart` 5, ….
- **Replacements:** `RaftShapes.control/field/panel/attachment` or `RaftTokens.radius`. The Web gets radius only from component recipes; raft-ui has no radius scale.

### 3.16 Icon buttons — 20 (existing)

- **Counts:** `IconButton` 20; `resource_view.dart` has the most (6).
- **Replacements:** `RaftIconButton(glyph:, tooltip:)`, and `RaftBackButton` for back navigation. These mirror raft-ui `Button size="icon-*"`; Web `components/ui/CopyIconButton.tsx`, `CloseButton.tsx`.

### 3.17 Progress — 19 (existing + C4)

- **Existing:** `CircularProgressIndicator` 13 → `RaftSpinner` (raft-ui `Spinner`).
- **Missing (C4):** `LinearProgressIndicator` 6 → `RaftProgressBar`. Mirrors raft-ui `Progress`/`ProgressTrack`/`ProgressIndicator`; Web `components/ui/ProgressBar.tsx`.

### 3.18 Selects — 14 (C4: API change)

- **Counts:** `DropdownMenuItem` 10, `DropdownButtonFormField` 4.
- **Existing:** `RaftSelectField<T>`, but it takes Material `DropdownMenuItem<T>`, so the `DropdownMenuItem` constructions survive a migration.
- **C4 change:** give it a `RaftSelectOption<T>` item type. This mirrors raft-ui `SelectItem`/`SelectItemText`; Web `components/agent/StableField.tsx` (`FieldSelectTrigger`).

### 3.19 Dividers — 12 (C4)

- **Counts:** `Divider` 11, `VerticalDivider` 1.
- **Missing (C4):** `RaftSeparator` (horizontal/vertical, `line` token, `RaftTokens.border` width). Mirrors raft-ui `Separator`.
- **Existing:** inside menus, `RaftMenuEntry.separator()` already exists.

### 3.20 Chips and badges — 8 (existing + C4)

- **Existing:** `ChoiceChip` 3 (single choice) → `RaftSegmentedControl`. This mirrors raft-ui `SegmentedControl`; Web `components/settings/SettingsSegmentedControls.tsx`.
- **Missing (C4):**
  - `FilterChip` 2 (multi-select scopes, `resource_view.dart`) → `RaftToggleGroup`, mirroring raft-ui `ToggleGroup*`.
  - `InputChip` 1, `ActionChip` 1, `Badge` 1 → `RaftBadge`, mirroring raft-ui `Badge`; Web `components/task/StatusBadge.tsx`.

### 3.21 Tooltips — 6 (existing)

- `Tooltip` 6 → `RaftTooltip`, which mirrors raft-ui `Tooltip*`; Web `components/ui/Tooltip.tsx` (`AppTooltip`).
- Two of these are in `page_component_recipes.dart`.

### 3.22 Motion durations — 3 (C1)

- **Counts:** three `Duration(milliseconds: 150)` on hover fades/containers.
- **Existing:** `RaftPrimitives.controlDuration` (100ms), which mirrors raft-ui transition defaults.
- **Missing (C1):** a named 150ms hover token. Web Tailwind uses `duration-150`.

### 3.23 Sheets and drawers — 2 (C3)

- **Counts:** `showModalBottomSheet` 1 (`chat_view.dart`), `Drawer` 1 (`workspace_view.dart` mobile sidebar).
- **Missing (C3):** `RaftSheet` (bottom and side). Mirrors raft-ui `Drawer*`; Web `components/ui/OverflowSheet.tsx`, `components/ui/BottomSheet.tsx`.

### 3.24 Toggles — 1 (C2)

- `Checkbox` 1 (`chat_view.dart`) → `RaftCheckbox` (C2).

## 4. Work packages

The packages are independent. **Each app file belongs to exactly one package**, and each
component package owns its own new raft_ui files. The only shared touch point is the export list
in `packages/raft_ui/lib/raft_ui.dart`, which needs one line per C package. Append those lines;
the conflicts are trivial.

Each app package can start right away on its "existing" share. The remainder waits on the listed
C packages. The counts below are enforced violations at this snapshot.

### Component packages (packages/raft_ui; each needs a Widget Preview and theme/state/keyboard/semantics tests per AGENTS.md)

| Package | New files | Builds | Unblocks |
|---|---|---|---|
| **C1 Layout and motion tokens** | `src/layout_tokens.dart` | `RaftSpace` named scale over `RaftPrimitives.spacing`, `RaftGap`, hover-duration token | 358 (all spacing/size/duration findings) |
| **C2 List rows** | `src/list_rows.dart`, `src/checkbox.dart` | `RaftActionRow`, `RaftKeyValueRow`, `RaftAvatarListRow`, `RaftSurfaceListItem`, `RaftSwitchRow`, `RaftCheckbox`(+row) | 92 |
| **C3 Overlays and feedback** | `src/dialog.dart`, `src/toast.dart`, `src/sheet.dart` | `showRaftDialog`, `RaftDialog`, `RaftConfirmDialog`, `RaftSelectionDialog`, `showRaftToast`/`RaftToast`, `RaftBanner`, `RaftSheet` | 113 |
| **C4 Inputs and small primitives** | `src/text_field.dart`, `src/progress.dart`, `src/badge.dart`, `src/separator.dart`, `src/toggle_group.dart`; `RaftSelectOption` in `design_primitives.dart` | `RaftTextField`/`RaftTextArea`, `RaftProgressBar`, `RaftBadge`, `RaftSeparator`, `RaftToggleGroup`, `RaftSelectOption<T>`, optional `RaftSelectableText` | 101 |
| **C5 Page shell** | `src/page.dart`; app files `features/page_layout.dart`, `features/page_component_recipes.dart`, `features/page_alignment_previews.dart` | Promote `RaftPageHeader`/`RaftSettingsSection`/settings and search recipes into raft_ui as `RaftPage`/`RaftPanelHeader`; clear those 3 files (35 violations: spacing 24, typography 6, tooltip 2, color 1, surface 1, divider 1) | 21 Scaffold/AppBar |
| **C6 Glyphs** | `src/icons.dart` (+ path data) | The 26 Lucide glyphs listed in §3.2 | 39 |

### App packages (apps/raft_flutter/lib; disjoint file sets)

| Package | Files (violations) | Total | Now | Waits on |
|---|---|---|---|---|
| **WP1 Resource surfaces** | `features/resource_view.dart` (136), `resource_search.dart` (25), `resource_cards.dart` (12), `search_home.dart` (6) | 179 | 76 | C1 76, C4 12, C3 8, C6 5, C2 2 |
| **WP2 Fleet, agents and providers** | `features/fleet_views.dart` (88), `runtime_form_dialog.dart` (22), `provider_views.dart` (20), `mcp_views.dart` (14), `agent_apps_view.dart` (13), `agent_migration_view.dart` (12), `agent_scopes_view.dart` (11), `managed_agent_launcher.dart` (7) | 187 | 57 | C2 34, C1 28, C3 23, C4 21, C6 16, C5 8 |
| **WP3 Workspace shell and chat** | `features/workspace_view.dart` (63), `chat_view.dart` (37), `forward_messages_dialog.dart` (17), `live_agent_activity_bar.dart` (8), `thread_actions.dart` (7), `message_presentation.dart` (5), `message_image_export.dart` (5), `desktop_directory_view.dart` (4), `sidebar_sort_menu.dart` (4), `message_action_card.dart` (2), `share_message_link.dart` (2), `workspace_browser.dart` (2), `system_notification_center.dart` (2), `system_notification_copy.dart` (2), `desktop_master_detail.dart` (1), `main.dart` (4), `platform/system_bars.dart` (5) | 170 | 58 | C1 39, C3 37, C2 15, C6 8, C4 8, C5 5 |
| **WP4 Servers, channels and integrations** | `features/server_views.dart` (55), `channel_settings.dart` (53), `integrations_views.dart` (23), `joint_channel_views.dart` (22), `server_setup_gate.dart` (19), `admin_views.dart` (11), `channel_conversion_section.dart` (9), `channel_conversion_previews.dart` (7), `channel_conversion_progress.dart` (4), `im_bridges_view.dart` (1) | 204 | 82 | C1 35, C2 33, C3 25, C4 19, C6 6, C5 4 |
| **WP5 Settings and profile pages** | `features/settings_page.dart` (44), `account_settings.dart` (36), `sidebar_preferences_view.dart` (35), `management_support.dart` (19), `appearance_section.dart` (11), `account_password_editor.dart` (9), `locale_settings_page.dart` (8), `member_profile_view.dart` (7), `account_connections_view.dart` (6), `notification_settings_view.dart` (5) | 180 | 41 | C1 100, C4 21, C2 7, C3 3, C6 3, C5 2, decision 3 (ReorderableListView) |
| **WP6 Auth and onboarding** | `features/auth_view.dart` (40), `account_onboarding.dart` (23), `account_sign_in_recipe.dart` (2), `account_auth_previews.dart` (1) | 66 | 27 | C1 22, C4 14, C5 2, C2 1 |
| **WP7 Files, attachments and feedback** | `features/source_channel_files_view.dart` (37), `attachment_view.dart` (13), `source_feedback_view.dart` (11), `task_selection_filter.dart` (11), `incoming_share_review.dart` (9), `source_channel_file_glyph.dart` (8), `attachment_html_preview.dart` (4), `source_channel_files_actions.dart` (2), `attachment_preview_dialog.dart` (2) | 97 | 40 | C1 34, C3 17, C4 5, C6 1 |

WP1–WP7 plus the C5 app files cover all 65 files and all 1118 violations.

**Suggested order:**
1. Run C1 and C6 first. They are small, and they unblock 397 findings. Run C2, C3 and C4 in parallel with them.
2. App packages do their "Now" share immediately: buttons, icon buttons, menus, tooltips, spinner, typography, theme reads, colors, radius and existing glyphs.
3. App packages then pick up the rest as each C package lands.

**After every package:**
1. Run `tool/ds-audit --update-baseline` and commit the lowered baseline in the same commit as the migration.
2. Run `tool/check-project`.
3. Compare against Web with the existing parity evidence flow. The audit proves only that the
   raw Material/style usage is gone; it does not prove visual parity.
