import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/basic_component_previews.dart' show designIconsPreview;
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';
import 'package:raft_ui/test_themes.dart';

const _ink = Color(0xff111111);
const _frameKey = ValueKey('icon-frame');

Future<ui.Image> _paint(WidgetTester t, Widget icon, Size frame) async {
  await t.pumpWidget(
    MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: _frameKey,
          child: SizedBox.fromSize(size: frame, child: icon),
        ),
      ),
    ),
  );
  await t.pump();
  final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(_frameKey));
  return t.runAsync(() => boundary.toImage(pixelRatio: 2)).then((i) => i!);
}

Future<List<int>> _centerPixels(ui.Image image, double extent) async {
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final side = (extent * 2).round();
  final left = (image.width - side) ~/ 2;
  final top = (image.height - side) ~/ 2;
  return [
    for (var y = top; y < top + side; y++)
      for (var x = left; x < left + side; x++)
        for (var c = 0; c < 4; c++)
          bytes.getUint8((y * image.width + x) * 4 + c),
  ];
}

Future<void> _save(WidgetTester t, String name, Finder boundary) async {
  final directory = Platform.environment['RAFT_ICON_CAPTURE_DIR'];
  if (directory == null) return;
  final render = t.renderObject<RenderRepaintBoundary>(boundary);
  await t.runAsync(() async {
    final image = await render.toImage(pixelRatio: 3);
    try {
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await Directory(directory).create(recursive: true);
      await File('$directory/$name.png').writeAsBytes(png.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Widget _task({required VoidCallback onViewInThread}) => RaftTaskSurface(
  task: const {
    'id': 't1',
    'taskNumber': 276,
    'channelName': 'raft-flutter',
    'title': 'Review task details',
    'status': 'in_progress',
    'createdByName': 'Cody',
  },
  history: const [],
  assignees: const [],
  legacy: false,
  loading: false,
  historyLoading: false,
  busy: false,
  canStatus: false,
  canAssign: false,
  canCleanupDelete: false,
  statusOptions: raftTaskStatuses,
  onClose: () {},
  onViewInThread: onViewInThread,
  onRetry: () async {},
  onLoadAssignees: () async {},
  onUpdate: (_, _) async {},
  formatTime: (_) => 'Oct 27, 2026',
  // The task shell owns this header; the mounted discussion owns its body.
  discussionBuilder: (_) => const Center(child: RaftThreadIcon(size: 36)),
);

void main() {
  testWidgets('design icon gallery renders constrained artwork examples', (
    t,
  ) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    t.view.physicalSize = const Size(640, 440);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: designIconsPreview()),
      ),
    );
    expect(find.text('Square artwork in rectangular slots'), findsOneWidget);
    final icons = find.byType(RaftThreadIcon);
    expect(icons, findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      final paint = find.descendant(
        of: icons.at(i),
        matching: find.byType(CustomPaint),
      );
      expect(t.getSize(paint), Size.square(i == 0 ? 18 : 6));
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('former task-header surface cannot stretch product artwork', (
    t,
  ) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    // +10 (5e7f6f568): RaftThreadViewButton -> RaftButtonSurface passed its
    // child directly to this fixed-width, overflow-centred surface. The
    // current Button inserts a Row first. recipe_surface.dart is unchanged.
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Center(
          child: Builder(
            builder: (context) {
              final tokens = RaftTokens.of(context).recipeTokens;
              return RaftRecipeBox(
                style: RaftSlotStyle(
                  {
                    'height': const CssNum(32, 'px'),
                    for (final side in ['top', 'right', 'bottom', 'left'])
                      'border-$side-width': const CssNum(1, 'px'),
                  },
                  {},
                  const [],
                  tokens,
                ),
                tokens: tokens,
                width: 32,
                overflowCenter: true,
                child: const RaftThreadIcon(size: 14, color: _ink),
              );
            },
          ),
        ),
      ),
    );
    final paint = find.descendant(
      of: find.byType(RaftThreadIcon),
      matching: find.byType(CustomPaint),
    );
    expect(t.getSize(paint), const Size.square(14));
    expect(t.takeException(), isNull);
  });

  testWidgets('constrained absolute strokes match an explicit square icon', (
    t,
  ) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    for (final frame in [const Size(8, 32), const Size(32, 8)]) {
      const icon = RaftIcon(
        RaftGlyph.plus,
        size: 16,
        color: _ink,
        absoluteStrokeWidth: true,
      );
      final reference = await _paint(
        t,
        const Center(
          child: RaftIcon(
            RaftGlyph.plus,
            size: 8,
            color: _ink,
            absoluteStrokeWidth: true,
          ),
        ),
        frame,
      );
      final actual = await _paint(t, icon, frame);
      try {
        expect(
          await t.runAsync(() => _centerPixels(actual, 8)),
          await t.runAsync(() => _centerPixels(reference, 8)),
        );
      } finally {
        reference.dispose();
        actual.dispose();
      }
    }
  });

  testWidgets('icon viewport preserves intrinsic width in composed rows', (
    t,
  ) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    await t.pumpWidget(
      const MaterialApp(
        home: Center(
          child: IntrinsicWidth(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RaftIcon(RaftGlyph.plus, size: 18, absoluteStrokeWidth: true),
                SizedBox(width: 6),
                Text('Label'),
              ],
            ),
          ),
        ),
      ),
    );
    final icon = find.byType(RaftIcon);
    final paint = find.descendant(of: icon, matching: find.byType(CustomPaint));
    expect(t.getSize(paint), const Size.square(18));
    expect(t.takeException(), isNull);
  });

  final icons = <String, Widget Function(double)>{
    'lucide': (s) => RaftIcon(RaftGlyph.messageSquare, size: s, color: _ink),
    'chat': (s) => RaftChatIcon(size: s, color: _ink),
    'direct-message': (s) => RaftDirectMessageIcon(size: s, color: _ink),
    'thread': (s) => RaftThreadIcon(size: s, color: _ink),
    'toolbar-thread': (s) => RaftMessageThreadGlyph(size: s, color: _ink),
    'toolbar-reaction': (s) =>
        RaftMessageAddReactionGlyph(size: s, color: _ink),
    'reaction-sprite': (s) => RaftReactionGlyph('👍', size: s),
    'emoji-category': (s) => RaftEmojiNavIcon('smileys_people', size: s),
    'avatar-placeholder': (_) =>
        const RaftAvatarPlaceholder(size: RaftAvatarSize.md, color: _ink),
  };
  for (final entry in icons.entries) {
    testWidgets('${entry.key} keeps square paint in a rectangular slot', (
      t,
    ) async {
      addTearDown(() => t.pumpWidget(const SizedBox()));
      for (final frame in [
        const Size(64, 24),
        const Size(10, 24),
        const Size(24, 10),
      ]) {
        final extent = frame.shortestSide.clamp(0.0, 18.0);
        // Keep both raster origins equal. Changing the outer frame can change
        // edge quantization even when the vector geometry is identical.
        final reference = await _paint(
          t,
          Center(
            child: SizedBox.square(dimension: extent, child: entry.value(18)),
          ),
          frame,
        );
        final actual = await _paint(t, entry.value(18), frame);
        try {
          await _save(
            t,
            'family-${entry.key}-${frame.width}-${frame.height}',
            find.byKey(_frameKey),
          );
          final paint = find.descendant(
            of: find.byKey(_frameKey),
            matching: find.byType(CustomPaint),
          );
          expect(t.getSize(paint), Size.square(extent), reason: '$frame');
          final expectedPixels = await t.runAsync(
            () => _centerPixels(reference, extent),
          );
          final actualPixels = await t.runAsync(
            () => _centerPixels(actual, extent),
          );
          expect(
            actualPixels,
            expectedPixels,
            reason: 'paint differs in $frame',
          );
          expect(actualPixels!.where((v) => v != 0), isNotEmpty);
        } finally {
          reference.dispose();
          actual.dispose();
        }
      }
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    });
  }

  for (final (look, pack) in [
    (raftLookRaft, builtInRaftTheme),
    (raftLookElegant, builtInElegantTheme),
    (raftLookBrutal, builtInBrutalTheme),
  ]) {
    for (final dark in raftThemeMatrix([false, true], look: (_) => look)) {
      testWidgets('task header has square thread artwork ${pack.id}/$dark', (
        t,
      ) async {
        addTearDown(() => t.pumpWidget(const SizedBox()));
        t.view.physicalSize = const Size(393, 852);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        var taps = 0;
        for (final direction in TextDirection.values) {
          for (final scale in [1.0, 2.5]) {
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(
                  pack: pack,
                  dark: dark,
                  platform: TargetPlatform.iOS,
                ),
                builder: (_, child) => Directionality(
                  textDirection: direction,
                  child: MediaQuery(
                    data: MediaQueryData(
                      size: const Size(393, 852),
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: child!,
                  ),
                ),
                home: RepaintBoundary(
                  key: _frameKey,
                  child: _task(onViewInThread: () => taps++),
                ),
              ),
            );
            await t.pump();
            final action = find.byKey(
              const ValueKey('task-modal-view-in-thread'),
            );
            final icon = find.descendant(
              of: action,
              matching: find.byType(RaftThreadIcon),
            );
            final paint = find.descendant(
              of: icon,
              matching: find.byType(CustomPaint),
            );
            await _save(
              t,
              'task-${pack.id}-$dark-${direction.name}-$scale',
              find.byKey(_frameKey),
            );
            expect(t.getSize(paint).width, t.getSize(paint).height);
            expect(t.getSize(paint), const Size.square(14));
            expect(t.getRect(action).contains(t.getCenter(paint)), isTrue);
            await t.tap(action);
            await t.pump();
            expect(t.takeException(), isNull);
          }
        }
        expect(taps, 4);
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
