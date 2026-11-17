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
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

import '../parity_harness.dart';

final Map<String, ParityCase> uiPrimitiveCases = {
  'components.ui.segmented-control.states': _segmentedControl,
  'components.ui.button.states': _button,
  'components.ui.card.states': _card,
  'components.ui.form-field.states': _formField,
  'components.ui.textarea.states': _textarea,
  'components.ui.checkbox.states': _checkbox,
  'components.ui.typography.specimen': _typography,
  'components.ui.check-marker.states': _checkMarker,
  'components.ui.badge.states': _badge,
  'components.ui.skeleton.states': _skeleton,
  'components.ui.slug-input.states': _slugInput,
  'components.ui.selection-popover.states': _selectionPopover,
  'components.ui.menu-item.states': _menuItem,
  'components.ui.select.states': _select,
  'components.ui.surface-list-item.states': _surfaceListItem,
  'components.ui.avatar-list-row.states': _avatarListRow,
};

final Map<String, ParityUncovered> uiPrimitiveUncovered = {};

// Source: v1.24.0-source.1 VisualTestingCases.tsx ui-typography-specimen.
// Draw the product's current token/typography path (`typeSlot` + `scale`, CSS
// line box). The frame is a 390px phone viewport: the Web keeps its base scale
// there, and so does `RaftTokens.of` (the desktop scale needs 768px and a
// pointer, see packages/raft_ui/test/responsive_type_scale_test.dart).
final ParityCase _typography = ParityCase(
  widgets: const ['raft_ui:RaftTokens'],
  build: (ctx) => Builder(
    builder: (context) {
      final t = RaftTokens.of(context);
      const lines = [
        ('Headline 17', 'headline', null),
        ('Body 16 400', 'body', FontWeight.w400),
        ('Body 16 500', 'body', FontWeight.w500),
        ('Body 16 600', 'body', FontWeight.w600),
        ('Body 16 700', 'body', FontWeight.w700),
        ('Subhead 15', 'subhead', null),
        ('Callout 14', 'callout', null),
        ('Footnote 13', 'footnote', null),
        ('Caption 12 500', 'caption', null),
        ('Label 11 600', 'label', null),
        ('Mono meta 12', 'mono-meta', null),
        ('Mono code 13', 'mono-code', null),
      ];
      // The source case owns one 16px inset and the active canvas colour.
      // The shared historical frame has a white background and its own inset.
      return ctx.frame(
        width: 342,
        height: 300,
        background: t.ui.layerCanvas,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: t.ui.foreground,
            decoration: TextDecoration.none,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, slot, weight) in lines)
                RaftCssText(
                  '$label 排版 Aa 0123',
                  maxLines: 1,
                  softWrap: false,
                  // Space Mono has no Han: the Web's `--font-mono` stack falls through to
                  // the system CJK faces, so the fixture chains them after monospace.
                  style: t
                      .scale(
                        t.typeSlot(slot),
                        weight: weight,
                        mono: slot.startsWith('mono-'),
                      )
                      .copyWith(
                        fontFamilyFallback: slot.startsWith('mono-')
                            ? ['monospace', ...t.fontFallback]
                            : null,
                      ),
                ),
            ],
          ),
        ),
      );
    },
  ),
);

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
          // `<main class="... text-foreground">` in the current Source.
          color: RaftTokens.of(context).colors['foreground'],
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
  children: [
    lead,
    SizedBox(width: gap),
    _fixtureLabel(label),
  ],
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
                'Channel Settings',
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
                label: 'Save',
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
  notes: 'Against the Web the raft-ui Input (default chrome) is used.',
  build: (ctx) {
    const chrome = RaftInputChrome.recipe;
    return _frame(
      ctx,
      height: 296,
      child: _column(12, [
        RaftField(
          label: 'Email',
          required: true,
          child: RaftTextInput(
            initialValue: 'cindy@slock.ai',
            readOnly: true,
            chrome: chrome,
          ),
        ),
        RaftField(
          label: 'Description',
          optional: true,
          hint: 'Shown in channel discovery.',
          child: RaftTextInput(
            initialValue: 'Visual parity fixture',
            readOnly: true,
            chrome: chrome,
          ),
        ),
        RaftField(
          label: 'Server Name',
          compact: true,
          error: 'Name is required',
          child: RaftTextInput(
            initialValue: '',
            readOnly: true,
            invalid: true,
            chrome: chrome,
          ),
        ),
      ]),
    );
  },
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
                    color: t.semantic.danger,
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
      _labelRow(
        8,
        RaftCheckbox(value: true, onChanged: (_) {}),
        'As Task selected',
      ),
      _labelRow(
        8,
        RaftCheckbox(value: false, onChanged: (_) {}),
        'Permission row unchecked',
      ),
      Opacity(
        opacity: .6,
        child: _labelRow(
          8,
          const RaftCheckbox(value: true),
          'Disabled checked',
        ),
      ),
    ]),
  ),
);

final ParityCase _checkMarker = ParityCase(
  widgets: const ['raft_ui:RaftCheckboxIndicator'],
  build: (ctx) => _frame(
    ctx,
    height: 112,
    child: Align(
      alignment: Alignment.topLeft,
      child: _column(12, [
        _labelRow(
          12,
          const RaftCheckboxIndicator(size: 14, checked: true),
          'Square checked',
        ),
        _labelRow(
          12,
          const RaftCheckboxIndicator(size: 16, checked: false),
          'Square unchecked',
        ),
        _labelRow(
          12,
          const RaftCheckboxIndicator(
            checked: true,
            shape: RaftCheckboxShape.circle,
          ),
          'Circle yellow',
        ),
      ]),
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

final ParityCase _skeleton = ParityCase(
  widgets: const ['raft_ui:RaftSkeleton', 'raft_ui:RaftSkeletonRow'],
  notes:
      'Pulse frozen at full opacity via reduced motion (React frame ~0.999).',
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

final ParityCase _selectionPopover = ParityCase(
  widgets: const ['raft_ui:RaftSelectionPopover'],
  notes:
      'Actual Source caller className replaces the product default: w-full '
      'overflow-hidden border-2 border-black bg-white shadow-brutal. '
      'Card rounding/dark transparent border and its surviving shadow remain.',
  build: (ctx) => _frame(
    ctx,
    height: 252,
    child: Builder(
      builder: (context) {
        final tokens = RaftTokens.of(context);
        final card = RaftCardRecipe.resolve(
          states: tokens.recipeStates(),
          tokens: tokens.recipeTokens,
        ).root;
        // Final CSS from the real Card + caller class merge. The dark-prefixed
        // border transparency beats unprefixed border-black; shadow-brutal does
        // not remove the recipe's shadow-raft-md/xs in this actual Source call.
        final surface = RaftSlotStyle(
          {
            ...card.properties,
            'background-color': const CssColor(0xffffffff),
            for (final side in ['top', 'right', 'bottom', 'left']) ...{
              'border-$side-width': const CssNum(2, 'px'),
              if (!tokens.dark)
                'border-$side-color': const CssColor(0xff000000),
            },
          },
          card.targets,
          [
            ...card.classes.where(
              (name) => !const {
                'overflow-hidden',
                'border-2',
                'border-[0.5px]',
                'border-black',
                'border-line-muted',
                'border-line-strong',
                'bg-white',
                'bg-layer-panel',
              }.contains(name),
            ),
            'w-full',
            'overflow-hidden',
            'border-2',
            'border-black',
            'bg-white',
            'shadow-brutal',
          ],
          tokens.recipeTokens,
        );
        final search = TextEditingController(text: 'des');
        ctx.onDispose(search.dispose);
        return RaftSelectionPopover(
          surfaceStyle: surface,
          title: 'Channels',
          width: 310,
          onClear: () {},
          searchController: search,
          searchPlaceholder: 'Search channels',
          options: [
            RaftSelectionOption(
              label: 'design',
              checked: true,
              onTap: () {},
              reserveLeadingSlot: true,
            ),
            RaftSelectionOption(
              label: 'visual-testing',
              checked: false,
              onTap: () {},
              reserveLeadingSlot: true,
            ),
            RaftSelectionOption(
              label: 'archived channel',
              checked: false,
              disabled: true,
              onTap: () {},
              reserveLeadingSlot: true,
            ),
            RaftSelectionOption(
              label: 'No channel',
              checked: false,
              italic: true,
              onTap: () {},
              reserveLeadingSlot: true,
            ),
          ],
        );
      },
    ),
  ),
);

final ParityCase _menuItem = ParityCase(
  widgets: const ['raft_ui:RaftMenuButtonItem'],
  notes:
      'Container is fixture markup: `w-full overflow-hidden rounded-container '
      'border border-line-seam bg-layer-popover shadow-float`; the '
      'frame is content-sized in React (16 + 116 + 16).',
  build: (ctx) => Builder(
    builder: (context) {
      final t = RaftTokens.of(context);
      final decoration = BoxDecoration(
        color: t.popover,
        borderRadius: BorderRadius.circular(
          t.size('radius.container', fallback: 10),
        ),
        border: Border.all(color: t.colors['line-seam']!),
        boxShadow: [
          for (final layer in t.shadowLayers('shadow.float'))
            if (!layer.inset) layer.toBoxShadow(),
        ],
      );
      return _frame(
        ctx,
        height: 178,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: decoration,
          child: Semantics(
            role: SemanticsRole.menu,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RaftMenuButtonItem(
                  label: 'Open Channel',
                  onPressed: () {},
                  trailing: Text(
                    '⌘K',
                    style: TextStyle(
                      fontFamily: t.monoFont,
                      fontFamilyFallback: t.fontFallback,
                      fontSize: 12,
                      height: 16 / 12,
                      color: t.colors['foreground-hint'],
                    ),
                  ),
                ),
                RaftMenuButtonItem(label: 'Mark as read', onPressed: () {}),
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
      );
    },
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
          RaftSelectItem(value: 'codex', label: 'Codex'),
          RaftSelectItem(value: 'claude', label: 'Claude'),
          RaftSelectItem(
            value: 'disabled',
            enabled: false,
            label: 'Unavailable Runtime',
          ),
        ],
        onChanged: (_) {},
      ),
      const RaftSelectField<String>(
        value: null,
        items: [RaftSelectItem(value: 'codex', label: 'Codex')],
        onChanged: null,
      ),
    ]),
  ),
);

/// The Source fixture markup: `text-callout font-bold text-foreground` over a
/// `font-mono text-mono-meta text-foreground-muted` line.
Widget _surfaceItemBody(ParityContext ctx, String title, String detail) =>
    Builder(
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
                color: t.colors['foreground'],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: RaftTypography.mono(
                t,
                size: 12,
                line: 16,
                color: t.colors['foreground-muted'],
              ),
            ),
          ],
        );
      },
    );

final ParityCase _surfaceListItem = ParityCase(
  widgets: const ['raft_ui:RaftCard'],
  notes: 'Row text is the Source fixture child markup: text-black and text-black/50 in every theme.',
  build: (ctx) => _frame(
    ctx,
    height: 182,
    child: _column(12, [
      RaftCard.item(
        interactive: false,
        child: _surfaceItemBody(ctx, 'Private app', 'Available to this server'),
      ),
      RaftCard.item(
        selected: true,
        interactive: false,
        child: _surfaceItemBody(
          ctx,
          'Active integration',
          'Selected list item state',
        ),
      ),
    ]),
  ),
);

final ParityCase _avatarListRow = ParityCase(
  widgets: const [
    'raft_ui:RaftAvatarListRow',
    'raft_ui:RaftAvatar',
    'raft_ui:RaftBadge',
  ],
  notes:
      'AvatarSlot context="surface-list" humanPlaceholder is rendered with '
      'the generic RaftAvatar(size 32) (no surface-list mounted context). '
      'Against the Web the rows sit in a ListRowGroup, as the Source fixture has them.',
  build: (ctx) {
    final rows = [
      RaftAvatarListRow(
        avatar: RaftAvatar(name: '', size: 32),
        name: 'Cindy',
        subtitle: 'Claude Code',
        rightContent: const [
          RaftBadge(label: 'Online', variant: RaftBadgeRecipeVariant.success),
        ],
      ),
      RaftAvatarListRow(
        avatar: RaftAvatar(name: '', size: 32),
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
    ];
    return _frame(ctx, height: 168, child: RaftListRowGroup(children: rows));
  },
);
