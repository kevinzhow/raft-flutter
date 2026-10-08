// components.ui.* — raft-ui primitive fixtures (the 26 components.ui.*
// default cases in sharedCases.json). Each builder mirrors the React render
// host frame (packages/web/visual-testing/VisualTestingCases.tsx, same
// width/height/padding/flex gaps and plain fixture labels) and renders the
// Flutter widget the app uses for that primitive (raft_ui or the app-level
// Material idiom themed by raftTheme). Missing Flutter variants are NOT
// patched here: the closest product widget is rendered and the diff shows
// the gap; primitives with no Flutter implementation are listed in
// [uiPrimitiveUncovered].
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/page_component_recipes.dart';
import 'package:raft_flutter/features/task_selection_filter.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';

final Map<String, ParityCase> uiPrimitiveCases = {
  'components.ui.segmented-control.states': _segmentedControl,
  'components.ui.button.states': _button,
  'components.ui.button.states.elegant': _button,
  'components.ui.card.states': _card,
  'components.ui.card.states.elegant': _card,
  'components.ui.form-field.states': _formField,
  'components.ui.form-field.states.elegant': _formField,
  'components.ui.textarea.states': _textarea,
  'components.ui.textarea.states.elegant': _textarea,
  'components.ui.checkbox.states': _checkbox,
  'components.ui.checkbox.states.elegant': _checkbox,
  'components.ui.check-marker.states': _checkMarker,
  'components.ui.attention-dot.states': _attentionDot,
  'components.ui.status-dot.states': _statusDot,
  'components.ui.badge.states': _badge,
  'components.ui.progress-bar.states': _progressBar,
  'components.ui.skeleton.states': _skeleton,
  'components.ui.spinner.states': _spinner,
  'components.ui.slug-input.states': _slugInput,
  'components.ui.section-eyebrow.states': _sectionEyebrow,
  'components.ui.section-header.states': _sectionHeader,
  'components.ui.selection-popover.states': _selectionPopover,
  'components.ui.menu-item.states': _menuItem,
  'components.ui.select.states': _select,
  'components.ui.surface-list-item.states': _surfaceListItem,
  'components.ui.avatar-list-row.states': _avatarListRow,
};

final Map<String, ParityUncovered> uiPrimitiveUncovered = {};

// ---------------------------------------------------------------------------
// Fixture scaffolding helpers (frame + plain markup text), not product UI.

/// The React fixture frame (`overflow: hidden`, fixed height). Content flows
/// at its natural height and is clipped like CSS instead of throwing a
/// RenderFlex overflow; the transparent Material only supplies the ancestor
/// Material widgets (TextField, Checkbox, ListTile) require.
Widget _frame(
  ParityContext ctx, {
  double width = 342,
  required double height,
  required Widget child,
}) => ctx.frame(
  width: width,
  height: height,
  child: Material(
    type: MaterialType.transparency,
    child: Builder(
      // <main class="font-display text-black">: heading font, black, the
      // preflight html line-height 1.5 at 16px.
      builder: (context) => DefaultTextStyle(
        style: TextStyle(
          fontFamily: RaftTokens.of(context).headingFont,
          fontSize: 16,
          height: 1.5,
          color: Colors.black,
          leadingDistribution: TextLeadingDistribution.even,
        ),
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minHeight: 0,
          maxHeight: double.infinity,
          child: child,
        ),
      ),
    ),
  ),
);

/// `flex flex-col gap-N` (children stretch on the cross axis).
Widget _column(double gap, List<Widget> children) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      children[i],
    ],
  ],
);

/// `flex items-center gap-N`.
Widget _row(double gap, List<Widget> children) => Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) SizedBox(width: gap),
      children[i],
    ],
  ],
);

/// Plain fixture label markup (`text-sm font-bold`, inherits text-black and
/// font-display from the frame).
Widget _fixtureLabel(String text) => Text(
  text,
  style: const TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
  ),
);

/// `flex items-center gap-N` row whose line box is the `text-sm` 20px.
Widget _labelRow(double gap, Widget lead, String label) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [lead, SizedBox(width: gap), _fixtureLabel(label)],
);

Widget _reducedMotion(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

// ---------------------------------------------------------------------------

final ParityCase _segmentedControl = ParityCase(
  widgets: const ['raft_ui:RaftSegmentedControl'],
  build: (ctx) => _frame(
    ctx,
    height: 96,
    child: Align(
      alignment: Alignment.topLeft,
      child: RaftSegmentedControl<String>(
        value: 'mentions',
        label: 'Inbox filter visual fixture',
        items: const [
          RaftSegmentedOption(value: 'all', label: 'All', count: '24'),
          RaftSegmentedOption(value: 'mentions', label: 'Mentions', count: '3'),
          RaftSegmentedOption(value: 'unread', label: 'Unread', count: '9'),
        ],
        onChanged: (_) {},
      ),
    ),
  ),
);

final ParityCase _button = ParityCase(
  widgets: const ['raft_ui:RaftButton'],
  build: (ctx) => _frame(
    ctx,
    height: 150,
    child: _column(12, [
      _row(12, [
        RaftButton(
          label: 'Save',
          onPressed: () {},
          tone: RaftButtonRecipeVariant.outline,
          size: RaftButtonRecipeSize.sm,
        ),
        RaftButton(
          label: 'Sync',
          onPressed: () {},
          tone: RaftButtonRecipeVariant.primary,
          size: RaftButtonRecipeSize.sm,
        ),
        RaftButton(
          label: 'Delete',
          onPressed: () {},
          tone: RaftButtonRecipeVariant.accent,
          size: RaftButtonRecipeSize.sm,
        ),
      ]),
      _row(12, [
        RaftButton(
          label: 'Add',
          onPressed: () {},
          tone: RaftButtonRecipeVariant.information,
          size: RaftButtonRecipeSize.xs,
        ),
        RaftButton(
          label: 'Continue',
          onPressed: () {},
          tone: RaftButtonRecipeVariant.success,
          size: RaftButtonRecipeSize.md,
        ),
        const RaftButton(
          label: 'Disabled',
          tone: RaftButtonRecipeVariant.muted,
          size: RaftButtonRecipeSize.sm,
        ),
      ]),
    ]),
  ),
);

final ParityCase _card = ParityCase(
  widgets: const ['raft_ui:RaftPanel', 'raft_ui:RaftButton'],
  notes:
      'The fixture card is the Web .card-brutal class (RaftPanelStyle.'
      'legacyCard); title/description are fixture markup (text-neutral-500 '
      'has no rule for card-register-muted).',
  build: (ctx) => _frame(
    ctx,
    height: 190,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 310,
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.black),
          child: RaftPanel(
            padding: const EdgeInsets.all(14),
            style: RaftPanelStyle.legacyCard,
            child: _column(8, [
              const Text(
                'Channel settings',
                style: TextStyle(
                  fontSize: 16,
                  height: 20 / 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'Control who can post and how the channel appears to members.',
                style: TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  color: RaftWebPalette.neutral500,
                ),
              ),
              RaftButton(
                label: 'Save changes',
                onPressed: () {},
                tone: RaftButtonRecipeVariant.primary,
                size: RaftButtonRecipeSize.sm,
                expand: true,
              ),
            ]),
          ),
        ),
      ),
    ),
  ),
);

final ParityCase _formField = ParityCase(
  widgets: const ['raft_ui:RaftField', 'raft_ui:RaftTextInput'],
  notes:
      'Fixture inputs are the Web legacy .input-brutal class '
      '(RaftInputChrome.legacy); the error input adds the callsite '
      '!border-brutal-red ring-2 ring-brutal-red/60 (invalid).',
  build: (ctx) => _frame(
    ctx,
    height: 296,
    child: _column(12, [
      const RaftField(
        label: 'Email',
        uppercase: false,
        required: true,
        child: RaftTextInput(
          initialValue: 'cindy@slock.ai',
          readOnly: true,
          chrome: RaftInputChrome.legacy,
        ),
      ),
      const RaftField(
        label: 'Description',
        optional: true,
        hint: 'Shown in channel discovery.',
        child: RaftTextInput(
          initialValue: 'Visual parity fixture',
          readOnly: true,
          chrome: RaftInputChrome.legacy,
        ),
      ),
      const RaftField(
        label: 'Server Name',
        compact: true,
        error: 'Name is required',
        child: RaftTextInput(
          initialValue: '',
          readOnly: true,
          invalid: true,
          chrome: RaftInputChrome.legacy,
        ),
      ),
    ]),
  ),
);

const _agreement = 'This agreement copy is too long for the configured limit.';

final ParityCase _textarea = ParityCase(
  widgets: const ['raft_ui:RaftTextarea', 'raft_ui:RaftTextareaCounter'],
  notes:
      'The alert line is fixture markup (text-xs text-danger '
      'theme-brutal:text-brutal-red). No resize handle in Flutter.',
  build: (ctx) => _frame(
    ctx,
    height: 252,
    child: _column(16, [
      const RaftTextarea(initialValue: _agreement, readOnly: true, rows: 2),
      Builder(
        builder: (context) {
          final t = RaftTokens.of(context);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Agreement body must be shorter.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    color: t.brutal ? t.product.brutalRed : t.semantic.danger,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              RaftTextareaCounter(length: _agreement.length, limit: 40),
            ],
          );
        },
      ),
    ]),
  ),
);

final ParityCase _checkbox = ParityCase(
  widgets: const ['raft_ui:RaftCheckbox'],
  notes: 'Row labels are fixture markup; the disabled row keeps opacity-60.',
  build: (ctx) => _frame(
    ctx,
    height: 132,
    child: _column(12, [
      _labelRow(8, RaftCheckbox(value: true, onChanged: (_) {}), 'As Task selected'),
      _labelRow(
        8,
        RaftCheckbox(
          value: false,
          onChanged: (_) {},
          size: RaftCheckboxRecipeSize.md,
        ),
        'Permission row unchecked',
      ),
      Opacity(
        opacity: .6,
        child: _labelRow(
          8,
          const RaftCheckbox(value: true, size: RaftCheckboxRecipeSize.md),
          'Disabled checked',
        ),
      ),
    ]),
  ),
);

final ParityCase _checkMarker = ParityCase(
  widgets: const ['raft_ui:RaftCheckMarker'],
  build: (ctx) => _frame(
    ctx,
    height: 112,
    child: Align(
      alignment: Alignment.topLeft,
      child: _column(12, [
        _labelRow(12, const RaftCheckMarker(checked: true), 'Square checked'),
        _labelRow(
          12,
          const RaftCheckMarker(checked: false, size: RaftCheckMarkerSize.md),
          'Square unchecked',
        ),
        _labelRow(
          12,
          const RaftCheckMarker(
            checked: true,
            circle: true,
            size: RaftCheckMarkerSize.lg,
            yellow: true,
          ),
          'Circle yellow',
        ),
      ]),
    ),
  ),
);

final ParityCase _attentionDot = ParityCase(
  widgets: const ['raft_ui:RaftAttentionDot'],
  build: (ctx) => _frame(
    ctx,
    height: 80,
    child: Align(
      alignment: Alignment.topLeft,
      child: _row(20, [
        _labelRow(8, const RaftAttentionDot(), 'Unread'),
        _labelRow(8, const RaftAttentionDot(compact: true), 'Compact'),
        _labelRow(8, const RaftAttentionDot(warning: true), 'Warning'),
      ]),
    ),
  ),
);

final ParityCase _statusDot = ParityCase(
  widgets: const ['raft_ui:RaftStatusDot'],
  build: (ctx) => _frame(
    ctx,
    height: 92,
    child: Align(
      alignment: Alignment.topLeft,
      child: Builder(
        builder: (context) {
          final p = RaftTokens.of(context).product;
          // `flex items-center gap-3` inside the `text-sm` column: the row's
          // cross size is the tallest dot (11px), as in CSS.
          return _row(12, [
            RaftStatusDot(color: p.brutalLime),
            RaftStatusDot(color: p.brutalOrange, size: RaftStatusDotSize.sm),
            const RaftStatusDot(
              color: RaftWebPalette.gray400,
              size: RaftStatusDotSize.lg,
            ),
            const RaftStatusDot(external: true),
          ]);
        },
      ),
    ),
  ),
);

final ParityCase _badge = ParityCase(
  widgets: const ['raft_ui:RaftBadge'],
  build: (ctx) => _frame(
    ctx,
    height: 92,
    child: Align(
      alignment: Alignment.topLeft,
      // `flex flex-wrap items-center gap-2`
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const RaftBadge(
            label: 'Shared',
            appearance: RaftBadgeRecipeAppearance.outline,
          ),
          const RaftBadge(
            label: 'Installed',
            variant: RaftBadgeRecipeVariant.success,
          ),
          const RaftBadge(
            label: 'Update',
            variant: RaftBadgeRecipeVariant.warning,
          ),
          const RaftBadge(
            label: 'Built In',
            variant: RaftBadgeRecipeVariant.muted,
          ),
          const RaftBadge(
            label: 'task #273',
            variant: RaftBadgeRecipeVariant.danger,
          ),
          RaftBadge(
            label: 'Install',
            variant: RaftBadgeRecipeVariant.accent,
            onPressed: () {},
          ),
        ],
      ),
    ),
  ),
);

final ParityCase _progressBar = ParityCase(
  widgets: const ['raft_ui:RaftProgressBar'],
  build: (ctx) => _frame(
    ctx,
    height: 124,
    child: _column(16, const [
      RaftProgressBar(
        value: 64,
        label: 'Downloading update',
        showPercent: true,
        tone: RaftProgressRecipeVariant.accent,
      ),
      RaftProgressBar(
        value: 28,
        label: 'Verifying package',
        showPercent: true,
        tone: RaftProgressRecipeVariant.information,
      ),
    ]),
  ),
);

final ParityCase _skeleton = ParityCase(
  widgets: const ['raft_ui:RaftSkeleton', 'raft_ui:RaftSkeletonRow'],
  notes: 'Pulse frozen at full opacity via reduced motion (React frame ~0.999).',
  build: (ctx) => _frame(
    ctx,
    height: 150,
    child: _reducedMotion(
      _column(12, const [
        RaftSkeletonRow(
          avatar: true,
          avatarSize: 20,
          gap: 12,
          lineWidths: [128, 80],
        ),
        RaftSkeleton(height: 48),
        Row(
          children: [
            RaftSkeleton(
              variant: RaftSkeletonVariant.circle,
              width: 32,
              height: 32,
            ),
            SizedBox(width: 12),
            RaftSkeleton(variant: RaftSkeletonVariant.line, width: 160),
          ],
        ),
      ]),
    ),
  ),
);

final ParityCase _spinner = ParityCase(
  widgets: const ['raft_ui:RaftSpinner'],
  notes:
      'React renders spinners with animation:none; Flutter uses reduced '
      'motion (MediaQuery.disableAnimations) for the same static frame. '
      'RaftSpinner takes a free size: React xs/sm/md/lg = 10/16/20/32px. '
      'The black inverse box reproduces the fixture span (p-2 around a 24px '
      'line box).',
  build: (ctx) => _reducedMotion(
    _frame(
      ctx,
      height: 92,
      child: Align(
        alignment: Alignment.topLeft,
        child: _row(20, [
          const RaftSpinner(size: 10),
          const RaftSpinner(size: 16),
          const RaftSpinner(size: 20),
          const RaftSpinner(size: 32),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
            child: const RaftSpinner(size: 16, inverse: true),
          ),
        ]),
      ),
    ),
  ),
);

final ParityCase _slugInput = ParityCase(
  widgets: const ['raft_ui:RaftSlugInput'],
  notes: 'Second row keeps the fixture opacity-60 className.',
  build: (ctx) => _frame(
    ctx,
    height: 122,
    child: _column(16, const [
      RaftSlugInput(initialValue: 'design-lab', readOnly: true),
      Opacity(
        opacity: .6,
        child: RaftSlugInput(initialValue: 'partner-workspace', readOnly: true),
      ),
    ]),
  ),
);

final ParityCase _sectionEyebrow = ParityCase(
  widgets: const ['raft_ui:RaftSectionEyebrow'],
  notes: 'Second row has the fixture !text-black; third the bg-white/50 px-2 py-1 label.',
  build: (ctx) => _frame(
    ctx,
    height: 92,
    child: _column(12, [
      const RaftSectionEyebrow('Recent Activity'),
      const RaftSectionEyebrow('Applications', color: Colors.black),
      Container(
        color: Colors.white.withValues(alpha: .5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: const RaftSectionEyebrow('Choose Avatar'),
      ),
    ]),
  ),
);

final ParityCase _sectionHeader = ParityCase(
  widgets: const ['raft_ui:RaftSectionHeader', 'raft_ui:RaftButton'],
  notes: 'The fixture className border-b-2 border-black pb-2 wraps the header.',
  build: (ctx) => _frame(
    ctx,
    height: 88,
    child: Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
      ),
      child: RaftSectionHeader(
        label: 'Applications',
        count: 3,
        action: RaftButton(
          label: 'Add',
          onPressed: () {},
          tone: RaftButtonRecipeVariant.outline,
          size: RaftButtonRecipeSize.xs,
        ),
      ),
    ),
  ),
);

/// MenuController handed out by the mounted TaskSelectionFilter.
MenuController? _selectionMenu;

final ParityCase _selectionPopover = ParityCase(
  widgets: const [
    'raft_flutter:TaskSelectionFilter',
    'raft_ui:RaftMenuPanel',
    'raft_ui:RaftMenuItem',
  ],
  notes:
      'Real product SelectionPopover: TaskSelectionFilter (tasks channel '
      'filter) opened through its MenuController and searched for "des". Its '
      'anchor sits just above the frame so the popover lands at the fixture '
      '16px inset. Product differences kept: title is the field name '
      '"Channel" in mono, width min(248, viewport-24), search filters the '
      'option list (only "design" stays), no disabled or italic options.',
  build: (ctx) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned(
        left: 16,
        bottom: ctx.height - 12,
        child: Material(
          type: MaterialType.transparency,
          child: TaskSelectionFilter(
            field: 'Channel',
            options: const {
              'design': 'design',
              'visual-testing': 'visual-testing',
              'archive': 'archived channel',
              'none': 'No channel',
            },
            selection: const {'design'},
            valid: () => true,
            onToggle: (_) {},
            onClear: () {},
            onController: (menu, mounted) =>
                _selectionMenu = mounted ? menu : null,
          ),
        ),
      ),
      // Painted after the anchor so the off-fixture trigger stays hidden
      // under the white frame; the popover itself paints in the Overlay.
      _frame(ctx, height: 252, child: const SizedBox.shrink()),
    ],
  ),
  interact: (t, ctx) async {
    _selectionMenu!.open();
    await t.pump(const Duration(milliseconds: 50));
    await t.enterText(find.byType(TextField), 'des');
    await t.pump(const Duration(milliseconds: 50));
  },
);

final ParityCase _menuItem = ParityCase(
  widgets: const ['raft_ui:RaftMenuButtonItem'],
  notes:
      'Container is fixture markup (w-full overflow-hidden border-2 '
      'border-black bg-white shadow-brutal); the frame is content-sized in '
      'React (16 + 116 + 16).',
  build: (ctx) => _frame(
    ctx,
    height: 148,
    child: Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(width: 2),
        boxShadow: RaftProductShadows.shadowBrutal.paintOrder,
      ),
      child: Semantics(
        role: SemanticsRole.menu,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftMenuButtonItem(
            label: 'Open Channel',
            onPressed: () {},
            trailing: Builder(
              builder: (context) => Text(
                '⌘K',
                style: TextStyle(
                  fontFamily: RaftTokens.of(context).monoFont,
                  fontSize: 12,
                  height: 16 / 12,
                  color: Colors.black.withValues(alpha: .4),
                ),
              ),
            ),
          ),
          RaftMenuButtonItem(label: 'Mark as Read', onPressed: () {}),
          const RaftMenuButtonItem(label: 'Archive unavailable'),
          RaftMenuButtonItem(
            label: 'Delete Message',
            onPressed: () {},
            topDivider: true,
          ),
        ],
      ),
      ),
    ),
  ),
);

final ParityCase _select = ParityCase(
  widgets: const ['raft_ui:RaftSelectField'],
  build: (ctx) => _frame(
    ctx,
    height: 194,
    child: _column(16, [
      RaftSelectField<String>(
        value: 'codex',
        items: const [
          DropdownMenuItem(value: 'codex', child: Text('Codex')),
          DropdownMenuItem(value: 'claude', child: Text('Claude')),
          DropdownMenuItem(
            value: 'disabled',
            enabled: false,
            child: Text('Unavailable Runtime'),
          ),
        ],
        onChanged: (_) {},
      ),
      const RaftSelectField<String>(
        value: null,
        items: [DropdownMenuItem(value: 'codex', child: Text('Codex'))],
        onChanged: null,
      ),
    ]),
  ),
);

Widget _surfaceItemBody(String title, String detail) => Builder(
  builder: (context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: t.bodyFont,
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w700,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: RaftTypography.mono(
            t,
            size: 12,
            line: 16,
            color: t.ink.withValues(alpha: .5),
          ),
        ),
      ],
    );
  },
);

final ParityCase _surfaceListItem = ParityCase(
  widgets: const ['raft_ui:RaftSurfaceListItem'],
  notes: 'Row text is the fixture child markup.',
  build: (ctx) => _frame(
    ctx,
    height: 182,
    child: _column(12, [
      RaftSurfaceListItem(
        interactive: false,
        child: _surfaceItemBody('Private app', 'Available to this server'),
      ),
      RaftSurfaceListItem(
        selected: true,
        interactive: false,
        child: _surfaceItemBody('Active integration', 'Selected list item state'),
      ),
    ]),
  ),
);

final ParityCase _avatarListRow = ParityCase(
  widgets: const ['raft_ui:RaftAvatarListRow', 'raft_ui:RaftAvatar', 'raft_ui:RaftBadge'],
  notes:
      'AvatarSlot context="surface-list" humanPlaceholder is rendered with '
      'the generic RaftAvatar(size 32) (no surface-list mounted context).',
  build: (ctx) => _frame(
    ctx,
    height: 168,
    child: _column(12, [
      const RaftAvatarListRow(
        avatar: RaftAvatar(name: 'Cindy', size: 32),
        name: 'Cindy',
        subtitle: 'Claude Code',
        rightContent: [
          RaftBadge(label: 'Online', variant: RaftBadgeRecipeVariant.success),
        ],
      ),
      RaftAvatarListRow(
        avatar: const RaftAvatar(name: 'Product UX Designer', size: 32),
        name: 'Product UX Designer',
        subtitle: 'product@slock.ai',
        selected: true,
        rightContent: [
          RaftButton(
            label: 'Open',
            onPressed: () {},
            tone: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.xs,
          ),
        ],
      ),
    ]),
  ),
);
