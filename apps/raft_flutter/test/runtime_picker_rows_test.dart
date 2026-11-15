// Web components/agent/runtimePickerOptions.ts: the runtime picker's rows,
// grouped by whether they can run on this computer right now.
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/runtime_picker_rows.dart';

const _labels = RuntimePickerGroupLabels(
  current: 'Current runtime',
  ready: 'Ready on this computer',
  notAvailable: 'Not available on this server',
  needsUpdate: 'Needs a Raft Computer update',
  notInstalled: 'Not installed on this computer',
);

RuntimePickerRow _row(
  String id, {
  String status = 'available',
  bool selectable = true,
  bool current = false,
  bool experimental = false,
  String? suffix,
}) => RuntimePickerRow(
  value: id,
  label: id.toUpperCase(),
  disabled: !selectable,
  capabilityStatus: status,
  selectable: selectable,
  current: current,
  experimental: experimental,
  availabilitySuffix: suffix,
);

({List<String> ids, List<String?> groups, bool canToggle}) _group(
  List<RuntimePickerRow> rows, {
  bool showAll = false,
  String selected = '',
}) {
  final result = groupRuntimePickerRows(
    rows,
    showAll: showAll,
    selectedValue: selected,
    labels: _labels,
    experimentalLabel: 'Experimental',
  );
  return (
    ids: [for (final o in result.options) o.value],
    groups: [for (final o in result.options) o.group],
    canToggle: result.canToggle,
  );
}

void main() {
  final rows = [
    _row('claude'),
    _row('codex', status: 'update_required', selectable: false),
    _row('grok', status: 'not_installed', selectable: false),
    _row('pi', status: 'available', selectable: false),
  ];

  test('ready first, a needs-update group, not-installed only on request', () {
    final collapsed = _group(rows);
    expect(collapsed.ids, ['claude', 'codex']);
    expect(collapsed.groups, [
      'Ready on this computer',
      'Needs a Raft Computer update',
    ]);
    expect(collapsed.canToggle, isTrue);
    final all = _group(rows, showAll: true);
    expect(all.ids, ['claude', 'codex', 'grok']);
    expect(all.groups.last, 'Not installed on this computer');
  });

  test('a runtime the server does not offer shows only as the value', () {
    expect(_group(rows).ids, isNot(contains('pi')));
    final asValue = _group(rows, selected: 'pi');
    expect(asValue.ids, ['claude', 'pi', 'codex']);
    expect(asValue.groups[1], 'Not available on this server');
  });

  test('the selected not-installed row stays listed', () {
    expect(_group(rows, selected: 'grok').ids, contains('grok'));
  });

  test('with nothing else to list, not-installed rows show without asking', () {
    final only = [
      _row('grok', status: 'not_installed', selectable: false),
      _row('pi', status: 'not_installed', selectable: false),
    ];
    final result = _group(only);
    expect(result.ids, ['grok', 'pi']);
    expect(result.canToggle, isFalse);
  });

  test('no not-installed runtimes means nothing to toggle', () {
    expect(_group([_row('claude')]).canToggle, isFalse);
  });

  test('the current runtime leads, in its own group, with its suffix', () {
    final result = groupRuntimePickerRows(
      [
        _row('claude'),
        _row('codex', current: true, suffix: ' (not installed)'),
      ],
      showAll: false,
      selectedValue: 'codex',
      labels: _labels,
      experimentalLabel: 'Experimental',
    );
    expect(result.options.map((o) => o.value), ['codex', 'claude']);
    expect(result.options.first.group, 'Current runtime');
    expect(result.options.first.suffix, ' (not installed)');
    expect(result.options.first.suffixInList, isTrue);
  });

  test('headings that say it drop the suffix in the list, not the field', () {
    final result = groupRuntimePickerRows(
      [
        _row(
          'codex',
          status: 'update_required',
          selectable: false,
          suffix: ' · Update required',
        ),
        _row('claude', suffix: ''),
      ],
      showAll: false,
      selectedValue: '',
      labels: _labels,
      experimentalLabel: 'Experimental',
    );
    final needs = result.options.firstWhere((o) => o.value == 'codex');
    expect(needs.suffix, ' · Update required');
    expect(needs.suffixInList, isFalse);
    expect(needs.enabled, isFalse);
    expect(
      result.options.firstWhere((o) => o.value == 'claude').suffix,
      isNull,
    );
  });

  test('the Experimental badge rides on the row', () {
    final result = groupRuntimePickerRows(
      [_row('qoder', experimental: true), _row('claude')],
      showAll: false,
      selectedValue: '',
      labels: _labels,
      experimentalLabel: 'Experimental',
    );
    expect(result.options.map((o) => o.badge), ['Experimental', null]);
  });

  test('onboarding keeps one flat list with the suffixes', () {
    final flat = flatRuntimePickerOptions([
      _row('claude'),
      _row(
        'grok',
        status: 'not_installed',
        selectable: false,
        suffix: ' (not installed)',
      ),
    ], experimentalLabel: 'Experimental');
    expect(flat.map((o) => o.group), [null, null]);
    expect(flat.map((o) => o.suffix), [null, ' (not installed)']);
    expect(flat.map((o) => o.suffixInList), [true, true]);
    expect(flat.map((o) => o.enabled), [true, false]);
  });

  test('the show-all row only exists when there is something to toggle', () {
    var toggles = 0;
    expect(
      runtimeShowAllAction(
        canToggle: false,
        showAll: false,
        showAllLabel: 'Show all supported',
        installedOnlyLabel: 'Show installed only',
        onToggle: () => toggles++,
      ),
      isNull,
    );
    final action = runtimeShowAllAction(
      canToggle: true,
      showAll: true,
      showAllLabel: 'Show all supported',
      installedOnlyLabel: 'Show installed only',
      onToggle: () => toggles++,
    )!;
    expect(action.label, 'Show installed only');
    action.onAction!();
    expect(toggles, 1);
  });
}
