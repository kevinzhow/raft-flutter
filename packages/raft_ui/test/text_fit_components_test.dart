// Text fit of the label-bearing components of raft_ui: every pill, chip,
// button, tab, segmented control, menu item, list row, input and counter below
// is pumped with a Latin label with descenders ("gpqy High") and a CJK label
// ("默认 设置") on the Web line boxes and on the Android Chinese control profile
// (line 1.3, proportional leading), at text scales 1.0 / 1.3 / 2.0, and must
//
//  * keep its label ink inside every clip (inkClipped),
//  * not overflow (RenderFlex overflow errors) or let the line box escape a
//    fixed-height parent (escapes),
//  * keep a single-line label within one pixel of its box's vertical centre
//    and inside the box (offCentre).
//
// The box around a label is a minimum height (RaftScaled / `minHeight`), never
// a fixed one: a taller line box grows the box. The surfaces audit
// (text_scale_audit_*_test.dart) covers the previews; this test names the
// components, so a pill that no preview shows is still caught. Add new
// label-bearing components to [_cases].
@Tags(['slow'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import '../../../tool/testing/text_scale_audit.dart';

const _latin = 'gpqy High';
const _cjk = '默认 设置';

typedef _Build = Widget Function(String label);

class _Case {
  const _Case(this.name, this.build, {this.labels = true});
  final String name;
  final _Build build;

  /// False when the component's label is fixed by its API (a count, a status):
  /// it is pumped once.
  final bool labels;
}

void _noop() {}

final _cases = <_Case>[
  // Buttons and controls.
  _Case('RaftButton', (l) => RaftButton(label: l, onPressed: _noop)),
  _Case(
    'RaftButton.primary',
    (l) => RaftButton(
      label: l,
      variant: RaftControlVariant.primary,
      onPressed: _noop,
    ),
  ),
  _Case(
    'RaftButton.ghost+glyph',
    (l) => RaftButton(
      label: l,
      variant: RaftControlVariant.ghost,
      glyph: RaftGlyph.plus,
      onPressed: _noop,
    ),
  ),
  _Case(
    'RaftButton.destructive',
    (l) => RaftButton(label: l, destructive: true, onPressed: _noop),
  ),
  _Case('RaftTextButton', (l) => RaftTextButton(label: l, onPressed: _noop)),
  _Case(
    'RaftTextButton.filter',
    (l) => RaftTextButton(
      label: l,
      glyph: RaftGlyph.hash,
      kind: RaftControlKind.filter,
      onPressed: _noop,
    ),
  ),
  _Case(
    'RaftControl.tab',
    (l) => RaftControl(
      kind: RaftControlKind.tab,
      selected: true,
      shadow: false,
      visualHeight: 24,
      onPressed: _noop,
      child: Text(l),
    ),
  ),
  _Case(
    'RaftPickerTriggerButton',
    (l) => RaftPickerTriggerButton(label: l, onPressed: _noop),
  ),
  _Case('RaftTextLink', (l) => RaftTextLink(label: l, onPressed: _noop)),
  _Case(
    'RaftShowMoreToggle',
    (l) => RaftShowMoreToggle(label: l, onPressed: _noop),
  ),
  _Case(
    'RaftSegmentedControl.buttons',
    (l) => RaftSegmentedControl<int>(
      value: 0,
      onChanged: (_) {},
      items: [
        RaftSegmentedOption(value: 0, label: l),
        RaftSegmentedOption(value: 1, label: l),
      ],
    ),
  ),
  _Case(
    'RaftSegmentedControl.tabs',
    (l) => RaftSegmentedControl<int>(
      value: 0,
      style: RaftSegmentedStyle.tabs,
      onChanged: (_) {},
      items: [
        RaftSegmentedOption(value: 0, label: l),
        RaftSegmentedOption(value: 1, label: l),
      ],
    ),
  ),
  _Case(
    'RaftRecipeSegmentedControl',
    (l) => RaftRecipeSegmentedControl<int>(
      value: 0,
      onChanged: (_) {},
      items: [(0, null, l), (1, null, l)],
    ),
  ),
  _Case(
    'RaftPanelTabBar',
    (l) => RaftPanelTabBar<int>(
      value: 0,
      onChanged: (_) {},
      tabs: [
        RaftPanelTab(0, l, RaftGlyph.hash),
        RaftPanelTab(1, l, RaftGlyph.hash),
      ],
    ),
  ),
  _Case(
    'RaftConversationTabs',
    (l) => RaftConversationTabs(
      value: RaftConversationTabId.chat,
      onChanged: (_) {},
      tabs: [
        RaftConversationTab(id: RaftConversationTabId.chat, label: l),
        RaftConversationTab(id: RaftConversationTabId.tasks, label: l),
      ],
    ),
  ),
  // Badges, pills, chips and counters.
  _Case(
    'RaftBadge',
    (l) => RaftBadge(
      label: l,
      appearance: RaftBadgeRecipeAppearance.soft,
      variant: RaftBadgeRecipeVariant.accent,
    ),
  ),
  _Case(
    'RaftBadge.solid',
    (l) => RaftBadge(
      label: l,
      appearance: RaftBadgeRecipeAppearance.solid,
      variant: RaftBadgeRecipeVariant.information,
    ),
  ),
  _Case(
    'RaftSearchHistoryTag',
    (l) => RaftSearchHistoryTag(
      query: l,
      touch: true,
      editing: true,
      onPressed: _noop,
      onRemove: _noop,
    ),
  ),
  _Case('RaftRecipeBadge', (l) => RaftRecipeBadge(l)),
  _Case('RaftInlineBadge', (l) => RaftInlineBadge(badge: RaftRecipeBadge(l))),
  _Case('RaftActorTypeBadge', (l) => RaftActorTypeBadge(label: l)),
  _Case('RaftArchivedBadge', (l) => RaftArchivedBadge(label: l)),
  _Case('RaftResourceBadge', (l) => RaftResourceBadge(label: l)),
  _Case('RaftSettingsRecipeBadge', (l) => RaftSettingsRecipeBadge(label: l)),
  _Case(
    'RaftTaskStatusBadge',
    (l) => RaftTaskStatusBadge(status: RaftMessageTaskStatus.todo, label: l),
  ),
  _Case(
    'RaftTaskSectionBadge',
    (l) => RaftTaskSectionBadge(status: 'todo', label: l),
  ),
  _Case(
    'RaftTaskStatus',
    (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftTaskStatus(status: 'todo'),
        RaftTaskStatus(status: 'in_progress'),
        RaftTaskStatus(status: 'done'),
      ],
    ),
    labels: false,
  ),
  _Case(
    'RaftTaskStatusEditor',
    (_) => RaftTaskStatusEditor(
      status: 'todo',
      options: const ['todo', 'done'],
      onSelect: (_) {},
    ),
    labels: false,
  ),
  _Case(
    'RaftMountedMessageTaskChip',
    (l) => RaftMountedMessageTaskChip(
      number: 8,
      status: RaftMessageTaskStatus.todo,
      title: l,
      openLabel: l,
      onOpen: _noop,
    ),
  ),
  _Case('RaftFeedbackUnreadCount', (l) => RaftFeedbackUnreadCount(label: l)),
  _Case(
    'RaftFeedbackStatusBadge',
    (_) => const RaftFeedbackStatusBadge(status: RaftFeedbackStatus.inProgress),
    labels: false,
  ),
  _Case('RaftRuntimeChip', (l) => RaftRuntimeChip(label: l, detected: true)),
  _Case('RaftTransferChip', (l) => RaftTransferChip(label: l)),
  _Case('RaftCommentAnchorChip', (l) => RaftCommentAnchorChip(label: l)),
  _Case(
    'RaftForwardTargetBadge',
    (l) => RaftForwardTargetBadge(glyph: RaftGlyph.hash, label: l),
  ),
  _Case(
    'RaftSidebarUnreadCount',
    (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftSidebarUnreadCount(count: 7),
        RaftSidebarUnreadCount(count: 128),
        RaftRailUnreadCount(count: 7),
      ],
    ),
    labels: false,
  ),
  // Menus, list rows, headings.
  _Case(
    'RaftMenuItem',
    (l) => RaftMenuPanel(
      width: 300,
      children: [
        RaftMenuItem(label: l, onPressed: _noop),
        RaftMenuItem(label: l, glyph: RaftGlyph.hash, onPressed: _noop),
      ],
    ),
  ),
  _Case(
    'RaftMenuButtonItem',
    (l) => RaftMenuPanel(
      width: 300,
      children: [RaftMenuButtonItem(label: l, onPressed: _noop)],
    ),
  ),
  _Case(
    'RaftNavItem',
    (l) => RaftNavItem(label: l, glyph: RaftGlyph.hash, onTap: _noop),
  ),
  _Case(
    'RaftNavItem.activityUnread',
    (l) => RaftNavItem(
      label: l,
      glyph: RaftGlyph.hash,
      role: RaftNavItemRole.activity,
      unread: 12,
      onTap: _noop,
    ),
  ),
  _Case('RaftSectionEyebrow', (l) => RaftSectionEyebrow(l)),
  _Case('RaftSectionHeader', (l) => RaftSectionHeader(label: l)),
  _Case('RaftInfoRow', (l) => RaftInfoRow(label: l, child: Text(l))),
  _Case(
    'RaftAvatarListRow',
    (l) => RaftAvatarListRow(
      avatar: RaftAvatar(name: l, size: 32),
      name: l,
      subtitle: l,
    ),
  ),
  _Case(
    'RaftSurfaceListItem',
    (l) => RaftSurfaceListItem(onTap: _noop, child: Text(l)),
  ),
  _Case(
    'RaftComposerTaskToggle',
    (l) => RaftComposerTaskToggle(checked: true, label: l, onChanged: (_) {}),
  ),
  _Case('RaftEmptyState', (l) => RaftEmptyState(title: l, detail: l)),
  // Inputs.
  _Case('RaftTextInput.hint', (l) => RaftTextInput(hintText: l)),
  _Case('RaftTextInput.value', (l) => RaftTextInput(initialValue: l)),
  _Case('RaftTextarea', (l) => RaftTextarea(initialValue: l)),
  _Case(
    'RaftSelectField',
    (l) => RaftSelectField<String>(
      value: 'a',
      onChanged: (_) {},
      items: [DropdownMenuItem(value: 'a', child: Text(l))],
    ),
  ),
  _Case('RaftPrefixedInput', (l) => RaftPrefixedInput(prefix: l)),
  _Case(
    'RaftField',
    (l) => RaftField(
      label: l,
      hint: l,
      child: RaftTextInput(hintText: l),
    ),
  ),
];

class _Profile {
  const _Profile(this.name, {this.android = false});
  final String name;
  final bool android;
}

const _profiles = [_Profile('web'), _Profile('android-zh', android: true)];
const _scales = [1.0, 1.3, 2.0];

/// `RAFT_TEXT_FIT_SURVEY=<file>` appends one TSV row per finding (theme,
/// profile, component, scale, kind, text, detail) whether the test fails or
/// not: the before/after table of a fix.
final _survey = Platform.environment['RAFT_TEXT_FIT_SURVEY'];

String _short(AuditFinding f) =>
    '${f.kind} "${f.text}" ${f.detail}'
    '${f.where.isEmpty ? '' : ' @ ${f.where.split(' < ').first}'}';

void main() {
  for (final (name, family, dark) in raftThemeMatrix([
    ('brutal-light', RaftFamily.brutal, false),
    ('elegant-light', RaftFamily.elegant, false),
    ('elegant-dark', RaftFamily.elegant, true),
  ])) {
    for (final profile in _profiles) {
      testWidgets('component labels fit: $name ${profile.name}', (t) async {
        await loadAuditFonts(t, AuditFonts.real);
        const zh = Locale('zh', 'CN');
        final theme = raftTheme(
          family,
          dark: dark,
          locale: profile.android ? zh : null,
          platform: profile.android ? TargetPlatform.android : null,
        );
        final problems = <String>[];
        var checked = 0;
        for (final c in _cases) {
          for (final scale in _scales) {
            final truncation = <String, bool>{};
            final report = await auditSurface(
              t,
              surface: c.name,
              theme: theme,
              // Tall enough for every case at every scale: the frame is a slot in a
              // scrolling page, only the component may fail.
              size: Size(420, 500 * scale),
              mode: AuditMode(
                '${scale}x',
                textScale: scale,
                locale: profile.android ? zh : null,
              ),
              truncationBaseline: truncation,
              centring: true,
              build: () => RaftPanelTextScope(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        if (c.labels) ...[
                          c.build(_latin),
                          c.build(_cjk),
                        ] else
                          c.build(''),
                      ],
                    ),
                  ),
                ),
              ),
            );
            checked += report.centreChecked;
            // Hard cuts and truncation are the component's ellipsis at the
            // 420px frame, not a fit defect; only the geometry kinds count.
            final failures = [
              ...report.overflow,
              ...report.inkClipped,
              ...report.escapes,
              ...report.offCentre,
              ...report.errors,
            ];
            if (failures.isNotEmpty) {
              problems.add(
                '${c.name} @ ${scale}x:\n  ${failures.map(_short).join('\n  ')}',
              );
              if (_survey != null) {
                File(_survey!).writeAsStringSync(
                  [
                    for (final f in failures)
                      '$name\t${profile.name}\t${c.name}\t$scale\t${f.kind}\t'
                          '${f.text}\t${f.detail}\t${f.where.split(' < ').first}\n',
                  ].join(),
                  mode: FileMode.append,
                );
              }
            }
          }
        }
        // The check must have measured something: a detector that matches no
        // box would pass every component.
        expect(checked, greaterThan(_cases.length));
        expect(problems, isEmpty, reason: problems.join('\n'));
      }, timeout: const Timeout(Duration(minutes: 4)));
    }
  }
}
