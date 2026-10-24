// Settings, administration and channel-management controls above the default
// text size: fixed heights become minimums, labels wrap, side-by-side rows
// stack, inputs grow with their text. At 1.0x nothing changes.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipe_min_height.dart';

Future<void> _pump(
  WidgetTester t,
  Widget child, {
  double scale = 1.0,
  double width = 390,
}) async {
  t.view.physicalSize = Size(width, 844);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await t.pumpAndSettle();
}

/// Texts the layout cut short (an ellipsis or a maxLines limit that applies).
List<String> _truncated(WidgetTester t, {List<String> ignore = const []}) {
  final found = <String>[];
  void visit(RenderObject r) {
    if (r is RenderParagraph &&
        r.didExceedMaxLines &&
        !ignore.contains(r.text.toPlainText())) {
      found.add(r.text.toPlainText());
    }
    r.visitChildren(visit);
  }

  visit(t.binding.renderViews.first);
  return found;
}

void main() {
  const long = 'Language and Region preferences for this workspace';

  testWidgets('settings sidebar row wraps and grows above 1.0x', (t) async {
    Widget list() => RaftSettingsSidebarList(
      groups: [
        RaftSettingsNavGroup('Workspace', [
          RaftSettingsNavEntry(
            id: 'lang',
            label: long,
            glyph: RaftGlyph.globe,
            onTap: () {},
          ),
        ]),
      ],
    );
    await _pump(t, list());
    final base = t.getSize(
      find.byKey(const ValueKey('workspace-settings-nav-lang')),
    );
    expect(base.height, lessThan(45), reason: 'one line at 1.0x');
    await _pump(t, list(), scale: 2.0);
    final big = t.getSize(
      find.byKey(const ValueKey('workspace-settings-nav-lang')),
    );
    expect(big.height, greaterThan(base.height * 2));

    expect(_truncated(t), isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('settings button keeps 28px at 1.0x and grows with its label', (
    t,
  ) async {
    const key = ValueKey('save');
    Widget button() => const Center(
      child: RaftSettingsRecipeButton(
        key: key,
        label: 'Save Changes',
        size: RaftButtonRecipeSize.sm,
      ),
    );
    await _pump(t, button());
    expect(t.getSize(find.byKey(key)).height, 28);
    await _pump(t, button(), scale: 2.0);
    final big = t.getSize(find.byKey(key));
    expect(big.height, greaterThan(28));
    // The label is inside the button box.
    final label = t.getRect(find.text('Save Changes'));
    expect(label.height, lessThanOrEqualTo(big.height));
    expect(t.getRect(find.byKey(key)).contains(label.center), isTrue);

    expect(_truncated(t), isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('avatar list row stacks its action under the identity', (
    t,
  ) async {
    Widget row() => RaftAvatarListRow(
      avatar: const SizedBox.square(dimension: 32),
      name: 'A rather long member name',
      subtitle: 'Agent · Admin',
      rightContent: const [
        RaftSettingsRecipeButton(
          key: ValueKey('remove'),
          label: 'Remove Admin',
          size: RaftButtonRecipeSize.sm,
        ),
      ],
    );
    await _pump(t, row());
    expect(
      t.getTopLeft(find.byKey(const ValueKey('remove'))).dx,
      greaterThan(200),
      reason: 'beside the name at 1.0x',
    );
    await _pump(t, row(), scale: 2.0);
    final name = t.getRect(find.text('A rather long member name'));
    final remove = t.getRect(find.byKey(const ValueKey('remove')));
    expect(remove.top, greaterThanOrEqualTo(name.bottom));
    expect(remove.right, lessThanOrEqualTo(390));

    expect(_truncated(t), isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('recipe input is a minimum height and still edits', (t) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    Widget input() => Padding(
      padding: const EdgeInsets.all(16),
      child: RaftRecipeInput(
        fieldKey: const ValueKey('input'),
        controller: controller,
        placeholder: 'Find',
        height: 40,
      ),
    );
    await _pump(t, input());
    expect(t.getSize(find.byType(RaftRecipeInput)).height, 40);
    await _pump(t, input(), scale: 3.0);
    expect(t.getSize(find.byType(RaftRecipeInput)).height, greaterThan(40));
    await t.enterText(find.byKey(const ValueKey('input')), 'hello');
    expect(controller.text, 'hello');
    controller.selection = const TextSelection(baseOffset: 1, extentOffset: 3);
    await t.pump();
    expect(controller.selection.textInside(controller.text), 'el');

    expect(_truncated(t), isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('multiline dialog input grows past 96px with its text', (
    t,
  ) async {
    final controller = TextEditingController(
      text: List.filled(12, 'a line of the description').join('\n'),
    );
    addTearDown(controller.dispose);
    Widget input() => Padding(
      padding: const EdgeInsets.all(16),
      child: RaftDialogTextInput(
        fieldKey: const ValueKey('area'),
        controller: controller,
        multiline: true,
      ),
    );
    await _pump(t, input());
    expect(
      t.getSize(find.byKey(const ValueKey('area'))).height,
      96 - 0,
      skip: false,
    );
    await _pump(t, input(), scale: 2.0);
    final field = t.getSize(find.byType(RaftFieldSurface));
    expect(field.height, greaterThan(96));

    expect(_truncated(t), isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('channel form footer wraps its buttons instead of overflowing', (
    t,
  ) async {
    final name = TextEditingController(text: 'general');
    final description = TextEditingController();
    addTearDown(name.dispose);
    addTearDown(description.dispose);
    Widget form() => Padding(
      padding: const EdgeInsets.all(16),
      child: RaftChannelInfoForm(
        nameController: name,
        descriptionController: description,
        onCancel: () {},
        onSave: () {},
        canCancel: true,
        canSave: true,
      ),
    );
    await _pump(t, form());
    final cancel1 = t.getRect(
      find.byKey(const ValueKey('channel-settings-discard-draft')),
    );
    final save1 = t.getRect(
      find.byKey(const ValueKey('channel-settings-save-inline')),
    );
    expect(save1.top, cancel1.top, reason: 'one line at 1.0x');
    await _pump(t, form(), scale: 3.1, width: 320);
    final cancel = t.getRect(
      find.byKey(const ValueKey('channel-settings-discard-draft')),
    );
    final save = t.getRect(
      find.byKey(const ValueKey('channel-settings-save-inline')),
    );
    expect(save.top, greaterThanOrEqualTo(cancel.bottom), reason: 'stacked');
    expect(save.right, lessThanOrEqualTo(320));

    expect(_truncated(t, ignore: ['e.g. ai-research']), isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('admins card stacks picker, role and action above 1.0x', (
    t,
  ) async {
    Widget card() => RaftAdminsCard(
      candidates: const [
        RaftAdminPrincipal(key: 'human:dana', label: 'Dana', agent: false),
      ],
      rows: const [],
      selectedKey: null,
      onSelect: (_) {},
      role: 'admin',
      roleOptions: const {'admin'},
      onRole: (_) {},
      onPromote: () {},
    );
    await _pump(t, card(), width: 760);
    final picker1 = t.getRect(
      find.byKey(const ValueKey('admin-principal-picker')),
    );
    final promote1 = t.getRect(find.byKey(const ValueKey('admin-update-role')));
    expect(promote1.top, lessThan(picker1.bottom), reason: 'one row at 1.0x');
    await _pump(t, card(), scale: 2.0, width: 760);
    final picker = t.getRect(
      find.byKey(const ValueKey('admin-principal-picker')),
    );
    final promote = t.getRect(find.byKey(const ValueKey('admin-update-role')));
    expect(promote.top, greaterThanOrEqualTo(picker.bottom));
    expect(picker.height, greaterThanOrEqualTo(40));

    expect(_truncated(t), isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('RaftMinHeightBox is exact at 1.0x and a minimum above', (
    t,
  ) async {
    Widget box() => const Align(
      alignment: Alignment.topLeft,
      child: RaftMinHeightBox(
        height: 24,
        child: Text('Humans and agents in this channel'),
      ),
    );
    await _pump(t, box());
    expect(t.getSize(find.byType(RaftMinHeightBox)).height, 24);
    await _pump(t, box(), scale: 2.0, width: 200);
    expect(t.getSize(find.byType(RaftMinHeightBox)).height, greaterThan(24));

    expect(_truncated(t), isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('panel header bar grows and wraps its title above 1.0x', (
    t,
  ) async {
    Widget bar() => const RaftPanelHeaderBar(
      title: 'Conversation settings for this direct message',
    );
    await _pump(t, bar());
    final base = t.getSize(find.byType(RaftPanelHeaderBar)).height;
    await _pump(t, bar(), scale: 2.0);
    expect(
      t.getSize(find.byType(RaftPanelHeaderBar)).height,
      greaterThan(base),
    );

    expect(_truncated(t), isEmpty);
    expect(t.takeException(), isNull);
  });
}
