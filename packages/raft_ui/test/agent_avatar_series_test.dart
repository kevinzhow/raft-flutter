import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/avatar_pixel_data.dart';

Widget _frame(Widget child, {TargetPlatform? platform}) => MaterialApp(
  theme: raftTheme().copyWith(platform: platform),
  home: Scaffold(body: SizedBox(width: 48, height: 48, child: child)),
);

Future<void> _picker(
  WidgetTester tester,
  Size size,
  TargetPlatform platform, {
  ValueChanged<String>? onChoice,
  String? selected,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      home: Scaffold(
        body: SingleChildScrollView(
          child: RaftAgentAvatarPicker(
            name: 'Cindy',
            selectedKey: selected,
            preview: const SizedBox.shrink(),
            onChoice: onChoice,
            onUpload: () {},
            onClose: () {},
            onSave: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('nine series of eight, reserved keys in none (pixelAvatars v3)', () {
    expect(raftPixelAvatarSeries.map((s) => s.$1), [
      'bots',
      'critters',
      'space',
      'desk',
      'food',
      'quest',
      'weather',
      'plants',
      'spooky',
    ]);
    final keys = [for (final s in raftPixelAvatarSeries) ...s.$2];
    expect(keys.length, 72);
    expect(keys.toSet().length, 72);
    expect(raftReservedPixelAvatarKeys, ['finch', 'mug', 'ottie']);
    for (final key in keys) {
      expect(raftPixelAvatarPresets, contains(key));
    }
    for (final key in raftReservedPixelAvatarKeys) {
      expect(keys, isNot(contains(key)));
      expect(raftPixelAvatarPresets, contains(key));
    }
    expect(raftAgentAvatarChoices, keys);
  });

  testWidgets('an unknown key draws the default avatar, not nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _frame(const RaftPixelAvatar(avatarKey: 'from-a-newer-build')),
    );
    expect(
      find.descendant(
        of: find.byType(RaftPixelAvatar),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
    expect(
      raftPixelAvatarData('from-a-newer-build'),
      same(raftPixelAvatarPresets[raftDefaultPixelAvatarKey]),
    );
  });

  testWidgets('pixel:ottie draws the otter art with the sprite as fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _frame(
        const RaftAvatarContent(
          name: 'Ottie',
          kind: RaftAvatarContentKind.agent,
          pixelKey: 'ottie',
        ),
      ),
    );
    final image = find.byWidgetPredicate(
      (w) =>
          w is RaftSizedImage &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/otter/wave.webp',
    );
    expect(image, findsOneWidget);
    expect(find.byType(RaftPixelAvatar), findsNothing);
  });

  for (final c in [
    ('fold 856x944 (Android)', const Size(856, 944), TargetPlatform.android, 8),
    ('fold 944x856 (Android)', const Size(944, 856), TargetPlatform.android, 8),
    (
      'narrow desktop 390x844 (Linux)',
      const Size(390, 844),
      TargetPlatform.linux,
      4,
    ),
  ]) {
    testWidgets('picker groups by series with headings, ${c.$1}', (
      tester,
    ) async {
      final chosen = <String>[];
      await _picker(tester, c.$2, c.$3, onChoice: chosen.add, selected: 'cat');
      for (final title in const [
        'Bot family',
        'Critters',
        'Space',
        'Desk',
        'Food',
        'Quest',
        'Weather',
        'Plants',
        'Spooky',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      // The upload tile sits beside the preview, not among the presets.
      expect(find.byKey(const ValueKey('avatar-upload')), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar-choice-ottie')), findsNothing);
      expect(find.byKey(const ValueKey('avatar-choice-mug')), findsNothing);
      // Eight tiles in one row on a wide body, two rows of four on a narrow one.
      final tops = {
        for (final key in raftPixelAvatarSeries.first.$2)
          tester.getTopLeft(find.byKey(ValueKey('avatar-choice-$key'))).dy,
      };
      expect(tops.length, 8 ~/ c.$4);
      await tester.ensureVisible(
        find.byKey(const ValueKey('avatar-choice-cat')),
      );
      await tester.tap(find.byKey(const ValueKey('avatar-choice-cat')));
      await tester.pump();
      expect(chosen, ['cat']);
    });
  }
}
