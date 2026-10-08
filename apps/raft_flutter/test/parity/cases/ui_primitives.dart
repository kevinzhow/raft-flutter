// components.ui.* — raft-ui primitive fixtures (the 26 components.ui.*
// default cases in sharedCases.json). Each builder mirrors the React render
// host frame (packages/web/visual-testing/VisualTestingCases.tsx, same
// width/height/padding/flex gaps and plain fixture labels) and renders the
// Flutter widget the app uses for that primitive (raft_ui or the app-level
// Material idiom themed by raftTheme). Missing Flutter variants are NOT
// patched here: the closest product widget is rendered and the diff shows
// the gap; primitives with no Flutter implementation are listed in
// [uiPrimitiveUncovered].
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

final Map<String, ParityUncovered> uiPrimitiveUncovered = {
  'components.ui.badge.states': const ParityUncovered(
    ParityGap.noFlutterSurface,
    'No shared Badge primitive in raft_ui or the app. Badge-like labels are '
    'private, single-purpose feature helpers (resource_search.dart _badge / '
    '_entityBadge, resource_view.dart activityBadge, source_channel_files '
    'extension chip, RaftActionCard success badge) with no '
    'outline/success/warning/muted/danger/accent tones or uppercase toggle, '
    'and none is instantiable from a test.',
  ),
  'components.ui.status-dot.states': const ParityUncovered(
    ParityGap.noFlutterSurface,
    'No standalone StatusDot widget. Presence dots only exist as the private '
    '_PresenceDot overlay inside RaftMountedAvatarFrame (mounted_avatar_'
    'recipe.dart) and an inline 8px Container in live_agent_activity_bar.dart; '
    'there is no public lime/orange/gray/external tone or sm/md/lg size API.',
  ),
};

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
    child: OverflowBox(
      alignment: Alignment.topLeft,
      minHeight: 0,
      maxHeight: double.infinity,
      child: child,
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
  children: [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) SizedBox(width: gap),
      children[i],
    ],
  ],
);

/// Plain fixture label markup (`text-sm font-bold`, inherits text-black).
Widget _fixtureLabel(String text) => Builder(
  builder: (context) {
    final t = RaftTokens.of(context);
    return Text(
      text,
      style: TextStyle(
        fontFamily: t.bodyFont,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w700,
        color: t.ink,
      ),
    );
  },
);

Widget _reducedMotion(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

// ---------------------------------------------------------------------------

final ParityCase _segmentedControl = ParityCase(
  widgets: const ['raft_ui:RaftSegmentedControl', 'raft_ui:RaftControl'],
  notes:
      'Rendered as the app Activity inbox filter (resource_view.dart: '
      'RaftSegmentedStyle.tabs, visualHeight 32). RaftSegmentedOption has no '
      'count slot, so the React SegmentedControlCount badges (24 / 3 / 9) are '
      'absent; item order follows the React fixture (All, Mentions, Unread).',
  build: (ctx) => _frame(
    ctx,
    height: 96,
    child: Align(
      alignment: Alignment.topLeft,
      child: RaftSegmentedControl<String>(
        style: RaftSegmentedStyle.tabs,
        visualHeight: 32,
        value: 'mentions',
        label: 'Inbox filter visual fixture',
        items: const [
          RaftSegmentedOption(value: 'all', label: 'All'),
          RaftSegmentedOption(value: 'mentions', label: 'Mentions'),
          RaftSegmentedOption(value: 'unread', label: 'Unread'),
        ],
        onChanged: (_) {},
      ),
    ),
  ),
);

final ParityCase _button = ParityCase(
  widgets: const ['raft_ui:RaftButton', 'raft_ui:RaftControl'],
  notes:
      'React Button tones information/success/muted have no RaftControlVariant; '
      'rendered with the nearest Flutter variants (surface/primary/ghost).',
  build: (ctx) => _frame(
    ctx,
    height: 150,
    child: _column(12, [
      Row(
        children: [
          RaftButton(
            label: 'Save',
            onPressed: () {},
            variant: RaftControlVariant.outline,
            visualHeight: RaftMetrics.buttonSm,
          ),
          const SizedBox(width: 12),
          RaftButton(
            label: 'Sync',
            onPressed: () {},
            variant: RaftControlVariant.primary,
            visualHeight: RaftMetrics.buttonSm,
          ),
          const SizedBox(width: 12),
          RaftButton(
            label: 'Delete',
            onPressed: () {},
            variant: RaftControlVariant.accent,
            visualHeight: RaftMetrics.buttonSm,
          ),
        ],
      ),
      Row(
        children: [
          RaftButton(
            label: 'Add',
            onPressed: () {},
            variant: RaftControlVariant.surface,
            visualHeight: RaftMetrics.buttonXs,
          ),
          const SizedBox(width: 12),
          RaftButton(
            label: 'Continue',
            onPressed: () {},
            variant: RaftControlVariant.primary,
            visualHeight: RaftMetrics.buttonMd,
          ),
          const SizedBox(width: 12),
          const RaftButton(
            label: 'Disabled',
            variant: RaftControlVariant.ghost,
            visualHeight: RaftMetrics.buttonSm,
          ),
        ],
      ),
    ]),
  ),
);

final ParityCase _card = ParityCase(
  widgets: const ['raft_ui:RaftPanel', 'raft_ui:RaftButton'],
  notes:
      'Fixture flex-col stretches the button to the card width, but '
      'RaftButton exposes no width/expand option (RaftControl centers its '
      'visual box), so it stays content-sized. Title and description are '
      'plain fixture markup.',
  build: (ctx) => _frame(
    ctx,
    height: 190,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 310,
        child: RaftPanel(
          padding: const EdgeInsets.all(14),
          shadow: true,
          child: Builder(
            builder: (context) {
              final t = RaftTokens.of(context);
              return _column(8, [
                Text(
                  'Channel settings',
                  style: TextStyle(
                    fontFamily: t.bodyFont,
                    fontSize: 16,
                    height: 20 / 16,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
                Text(
                  'Control who can post and how the channel appears to members.',
                  style: TextStyle(
                    fontFamily: t.bodyFont,
                    fontSize: 12,
                    height: 16 / 12,
                    color: t.muted,
                  ),
                ),
                RaftButton(
                  label: 'Save changes',
                  onPressed: () {},
                  variant: RaftControlVariant.primary,
                  visualHeight: RaftMetrics.buttonSm,
                ),
              ]);
            },
          ),
        ),
      ),
    ),
  ),
);

final ParityCase _formField = ParityCase(
  widgets: const ['material:TextFormField', 'raft_ui:raftTheme.inputDecoration'],
  notes:
      'Flutter has no public FormField primitive (RaftFormDialog._field is '
      'private); rendered with the app form idiom (runtime_form_dialog.dart / '
      'auth_view.dart): TextFormField + InputDecoration(labelText, helperText, '
      'errorText) themed by raftTheme. No required asterisk, "(optional)" '
      'suffix, plain-vs-uppercase label style or compact size exist.',
  build: (ctx) => _frame(
    ctx,
    height: 296,
    child: _column(12, [
      TextFormField(
        initialValue: 'cindy@slock.ai',
        readOnly: true,
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      TextFormField(
        initialValue: 'Visual parity fixture',
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Description',
          helperText: 'Shown in channel discovery.',
        ),
      ),
      TextFormField(
        initialValue: '',
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Server Name',
          errorText: 'Name is required',
        ),
      ),
    ]),
  ),
);

const _agreement = 'This agreement copy is too long for the configured limit.';

final ParityCase _textarea = ParityCase(
  widgets: const ['material:TextFormField', 'raft_ui:raftTheme.inputDecoration'],
  notes:
      'Rendered with the app multi-line note idiom (forward_messages_dialog.dart: '
      'TextField maxLines 2 + maxLength); the Material counter shows 57/40 and '
      'errorText carries the fixture alert. No resize handle in Flutter.',
  build: (ctx) => _frame(
    ctx,
    height: 252,
    child: _column(16, [
      TextFormField(
        initialValue: _agreement,
        readOnly: true,
        minLines: 2,
        maxLines: 2,
        maxLength: 40,
        decoration: const InputDecoration(
          errorText: 'Agreement body must be shorter.',
        ),
      ),
    ]),
  ),
);

final ParityCase _checkbox = ParityCase(
  widgets: const ['material:Checkbox', 'raft_ui:raftTheme.checkboxTheme'],
  notes:
      'Material Checkbox themed by raftTheme (as chat_view.dart message '
      'selection uses it); padded 48px touch target per the theme. No sm/md '
      'size variants. Row labels are plain fixture markup; the disabled row '
      'keeps the fixture opacity-60.',
  build: (ctx) => _frame(
    ctx,
    height: 132,
    child: _column(12, [
      _row(8, [
        Checkbox(value: true, onChanged: (_) {}),
        _fixtureLabel('As Task selected'),
      ]),
      _row(8, [
        Checkbox(value: false, onChanged: (_) {}),
        _fixtureLabel('Permission row unchecked'),
      ]),
      Opacity(
        opacity: .6,
        child: _row(8, [
          const Checkbox(value: true, onChanged: null),
          _fixtureLabel('Disabled checked'),
        ]),
      ),
    ]),
  ),
);

final ParityCase _checkMarker = ParityCase(
  widgets: const ['raft_ui:RaftComposerTaskToggle'],
  notes:
      'The only Flutter CheckMarker is the composer "As Task" marker inside '
      'RaftComposerTaskToggle (14px square, black fill, label owned by the '
      'widget). No md/lg sizes, circle shape or yellow-fill tone: the circle '
      'yellow row uses the same square checked marker.',
  build: (ctx) => _frame(
    ctx,
    height: 112,
    child: Align(
      alignment: Alignment.topLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftComposerTaskToggle(
            checked: true,
            label: 'Square checked',
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          RaftComposerTaskToggle(
            checked: false,
            label: 'Square unchecked',
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          RaftComposerTaskToggle(
            checked: true,
            label: 'Circle yellow',
            onChanged: (_) {},
          ),
        ],
      ),
    ),
  ),
);

final ParityCase _attentionDot = ParityCase(
  widgets: const ['raft_ui:RaftNotificationAttention'],
  notes:
      'RaftNotificationAttention is the only public attention dot (10px, the '
      'canonical lg size). No sm size or orange warning tone: all three rows '
      'use the default dot. Labels are plain fixture markup.',
  build: (ctx) => _frame(
    ctx,
    height: 80,
    child: Align(
      alignment: Alignment.topLeft,
      child: _row(20, [
        _row(8, [
          const RaftNotificationAttention(count: 1),
          _fixtureLabel('Unread'),
        ]),
        _row(8, [
          const RaftNotificationAttention(count: 1),
          _fixtureLabel('Compact'),
        ]),
        _row(8, [
          const RaftNotificationAttention(count: 1),
          _fixtureLabel('Warning'),
        ]),
      ]),
    ),
  ),
);

final ParityCase _progressBar = ParityCase(
  widgets: const ['material:LinearProgressIndicator'],
  notes:
      'The app only has the unthemed Material LinearProgressIndicator(value:) '
      '(attachment_view.dart download dialog). No label / percent row and no '
      'pink/cyan tone variants: values 0.64 and 0.28 rendered bare.',
  build: (ctx) => _frame(
    ctx,
    height: 124,
    child: _reducedMotion(
      _column(16, const [
        LinearProgressIndicator(value: .64),
        LinearProgressIndicator(value: .28),
      ]),
    ),
  ),
);

final ParityCase _skeleton = ParityCase(
  widgets: const ['raft_ui:RaftChatSidebarLoadingRows'],
  notes:
      'Flutter has no generic Skeleton primitive; the only skeleton is the '
      'sidebar loading row (18px bordered circle + 60% line, px8 py8). It '
      'stands in for the SkeletonRow; the block and circle+line variants have '
      'no Flutter equivalent and are absent. Pulse frozen via reduced motion.',
  build: (ctx) => _frame(
    ctx,
    height: 150,
    child: _reducedMotion(
      _column(12, const [RaftChatSidebarLoadingRows(rows: 1)]),
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
  widgets: const ['material:TextFormField', 'raft_ui:raftTheme.inputDecoration'],
  notes:
      'Flutter has no InputGroup/SlugInput; prefixed inputs use the app idiom '
      'InputDecoration(prefixText:) (account_settings.dart "@" username). The '
      "'/' prefix is inline text, not a bordered addon. Second row keeps the "
      'fixture opacity-60.',
  build: (ctx) => _frame(
    ctx,
    height: 122,
    child: _column(16, [
      TextFormField(
        initialValue: 'design-lab',
        readOnly: true,
        decoration: const InputDecoration(prefixText: '/'),
      ),
      Opacity(
        opacity: .6,
        child: TextFormField(
          initialValue: 'partner-workspace',
          readOnly: true,
          decoration: const InputDecoration(prefixText: '/'),
        ),
      ),
    ]),
  ),
);

final ParityCase _sectionEyebrow = ParityCase(
  widgets: const ['raft_flutter:RaftSettingsLayoutRecipe.modeLabel'],
  notes:
      'No SectionEyebrow widget; the app renders eyebrows as uppercase Text '
      'with RaftSettingsLayoutRecipe.modeLabel (settings_page.dart "MODE", '
      '12/16 bold, tracking 1.2, muted). The fixture !text-black override has '
      'no Flutter variant (same muted style); the label row keeps the fixture '
      'px-2 py-1 inset.',
  build: (ctx) => _frame(
    ctx,
    height: 92,
    child: Builder(
      builder: (context) {
        final style = RaftSettingsLayoutRecipe(RaftTokens.of(context)).modeLabel;
        return _column(12, [
          Text('Recent Activity'.toUpperCase(), style: style),
          Text('Applications'.toUpperCase(), style: style),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('Choose Avatar'.toUpperCase(), style: style),
            ),
          ),
        ]);
      },
    ),
  ),
);

final ParityCase _sectionHeader = ParityCase(
  widgets: const ['raft_ui:RaftSidebarSectionHeader'],
  notes:
      'Nearest Flutter header with label + count + action is '
      'RaftSidebarSectionHeader (static, onExpandedChanged null); its action '
      'is a 14px plus icon target, not an outline "Add" button, and it keeps '
      'its own 8/12/8/4 inset. The fixture border-b-2 pb-2 is reproduced '
      'around it.',
  build: (ctx) => _frame(
    ctx,
    height: 88,
    child: Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
      ),
      child: RaftSidebarSectionHeader(
        label: 'Applications',
        count: 3,
        expanded: true,
        onExpandedChanged: null,
        actions: [
          RaftSidebarSectionAction(
            label: 'Add',
            glyph: RaftGlyph.plus,
            onPressed: () {},
          ),
        ],
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
  widgets: const ['raft_ui:RaftMenuPanel', 'raft_ui:RaftMenuItem'],
  notes:
      'RaftMenuPanel (full fixture width) + RaftMenuItem as composed by '
      'thread_actions.dart. RaftMenuItem has no trailing shortcut slot (no '
      '⌘K) and app menu panels have no per-item divider; touch density keeps '
      '48px rows, so the content-sized React frame height (148) clips them.',
  build: (ctx) => _frame(
    ctx,
    height: 148,
    child: RaftMenuPanel(
      width: 310,
      children: [
        RaftMenuItem(label: 'Open Channel', onPressed: () {}),
        RaftMenuItem(label: 'Mark as Read', onPressed: () {}),
        const RaftMenuItem(label: 'Archive unavailable'),
        RaftMenuItem(label: 'Delete Message', onPressed: () {}),
      ],
    ),
  ),
);

final ParityCase _select = ParityCase(
  widgets: const ['raft_ui:RaftSelectField'],
  notes:
      'RaftSelectField (locale_settings_page.dart / resource_view.dart). It '
      'has no placeholder/hint, so the disabled empty select shows no '
      '"Select..." text.',
  build: (ctx) => _frame(
    ctx,
    height: 194,
    child: _column(16, [
      RaftSelectField<String>(
        label: 'Runtime',
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
        label: 'Runtime',
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
  widgets: const ['material:Card'],
  notes:
      'Flutter list cards are the Material Card + Padding(16) idiom '
      '(agent_apps_view.dart, mcp_views.dart); raftTheme has no CardTheme, '
      'so Material defaults apply. No selected state: both rows render the '
      'same card. Row text is the fixture child markup.',
  build: (ctx) => _frame(
    ctx,
    height: 182,
    child: _column(12, [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _surfaceItemBody('Private app', 'Available to this server'),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _surfaceItemBody(
            'Active integration',
            'Selected list item state',
          ),
        ),
      ),
    ]),
  ),
);

final ParityCase _avatarListRow = ParityCase(
  widgets: const ['material:ListTile', 'raft_ui:RaftAvatar', 'raft_ui:RaftButton'],
  notes:
      'Flutter member/agent rows are ListTile(leading: RaftAvatar) themed by '
      'raftTheme (fleet_views.dart directory). No Badge primitive, so the '
      '"Online" badge is absent; selected uses ListTile.selected.',
  build: (ctx) => _frame(
    ctx,
    height: 168,
    child: _column(12, [
      const ListTile(
        leading: RaftAvatar(name: 'Cindy'),
        title: Text('Cindy'),
        subtitle: Text('Claude Code'),
      ),
      ListTile(
        selected: true,
        leading: const RaftAvatar(name: 'Product UX Designer'),
        title: const Text('Product UX Designer'),
        subtitle: const Text('product@slock.ai'),
        trailing: RaftButton(
          label: 'Open',
          onPressed: () {},
          variant: RaftControlVariant.outline,
          visualHeight: RaftMetrics.buttonXs,
        ),
      ),
    ]),
  ),
);
