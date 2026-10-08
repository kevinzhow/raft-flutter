import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Controlled public source-component fixtures. This is native rendering/input
// evidence, not authentication/API or full-page/master-detail acceptance.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('native mounted conversation selected state and Composer input', (
    t,
  ) async {
    final dir = Directory(const String.fromEnvironment('RAFT_TEST_REPORT'));
    await dir.create(recursive: true);
    const sourceHash = String.fromEnvironment('RAFT_TEST_SOURCE_HASH');
    const platform = String.fromEnvironment(
      'RAFT_TEST_PLATFORM',
      defaultValue: 'linux',
    );
    final runId = DateTime.now().toUtc().toIso8601String();
    final shots = <Map<String, dynamic>>[];
    final imageKey = GlobalKey();
    Future<void> capture(
      String id,
      String theme,
      Finder target,
      String action,
    ) async {
      await t.pump(const Duration(milliseconds: 240));
      final boundary =
          imageKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${dir.path}/$platform-$id-$theme.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
      final rect = t.getRect(target);
      final origin = boundary.localToGlobal(Offset.zero);
      shots.add({
        'id': id,
        'theme': theme,
        'image': '$platform-$id-$theme.png',
        'interaction': action,
        'sourceHash': sourceHash,
        'runId': runId,
        'platform': platform,
        'fixture': 'public-controlled-source-components',
        'rasterDpr': 1,
        'deviceDpr': t.view.devicePixelRatio,
        'componentViewport': {'width': 390, 'height': 480},
        'ambientLogicalViewport': {
          'width': t.view.physicalSize.width / t.view.devicePixelRatio,
          'height': t.view.physicalSize.height / t.view.devicePixelRatio,
        },
        'controlledMediaQuery': {
          'width': 390,
          'height': 480,
          'dpr': 1,
          'insets': 0,
        },
        'density': RaftDensityScope.of(t.element(target)).name,
        'themePlatform': Theme.of(t.element(target)).platform.name,
        'hostPlatform': Platform.operatingSystem,
        'pointer': Platform.isAndroid ? 'touch' : 'fine',
        'geometry': {
          'x': rect.left - origin.dx,
          'y': rect.top - origin.dy,
          'width': rect.width,
          'height': rect.height,
        },
        'API': 'NOT_RUN',
        'pixelParity': 'UNACCEPTED',
      });
      await File('${dir.path}/$platform-restoration-component-captures.json')
          .writeAsString(
            jsonEncode({
              'sourceHash': sourceHash,
              'runId': runId,
              'platform': platform,
              'completed': false,
              'captures': shots,
            }),
          );
    }

    for (final (family, dark, theme) in [
      (RaftFamily.brutal, false, 'brutal-light'),
      (RaftFamily.elegant, false, 'elegant-light'),
      (RaftFamily.elegant, true, 'elegant-dark'),
    ]) {
      var selected = true, taps = 0;
      late StateSetter update;
      await t.pumpWidget(
        MaterialApp(
          builder: (_, child) => RaftDensityScope(
            density: Platform.isAndroid
                ? RaftDensity.touch
                : RaftDensity.desktop,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 480),
                devicePixelRatio: 1,
              ),
              child: child!,
            ),
          ),
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: imageKey,
                child: SizedBox(
                  width: 390,
                  height: 480,
                  child: ColoredBox(
                    color: Colors.white,
                    child: StatefulBuilder(
                      builder: (_, setState) {
                        update = setState;
                        return Column(
                          children: [
                            RaftNavItem(
                              key: const Key('fixture-selected-channel'),
                              label: '首页专修',
                              glyph: RaftGlyph.hash,
                              selected: selected,
                              unread: 24,
                              conversationKind: RaftConversationNavKind.channel,
                              onTap: () {
                                taps++;
                                update(() => selected = true);
                              },
                            ),
                            const Spacer(),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 300));
      final row = find.byKey(const Key('fixture-selected-channel'));
      await capture(
        'channel-selected-rest',
        theme,
        row,
        'Selected source channel label/count; actual native paint',
      );
      if (platform == 'linux') {
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(380, 200));
        await mouse.moveTo(t.getCenter(row));
        await capture(
          'channel-selected-hover',
          theme,
          row,
          'Actual mouse entered selected row',
        );
        final face = t.widget<AnimatedContainer>(
          find
              .descendant(of: row, matching: find.byType(AnimatedContainer))
              .first,
        );
        final decoration = face.decoration! as BoxDecoration;
        final tokens = RaftTokens.of(t.element(row));
        expect(
          decoration.color,
          tokens.brutal
              ? tokens.colors['color-brutal-pink']
              : tokens.colors['fill-muted'],
        );
        expect(decoration.gradient, isNull);
        await mouse.removePointer();
      }
      await t.tap(row);
      await t.pump();
      expect(taps, 1);
      await capture(
        'channel-selected-pointer',
        theme,
        row,
        'Real pointer/touch tap preserves selected surface; callback count1',
      );
      update(() => selected = false);
      await t.pump(const Duration(milliseconds: 240));
      await capture(
        'channel-unselected',
        theme,
        row,
        'Controlled selection clears without changing row identity',
      );

      final sent = <String>[];
      await t.pumpWidget(
        MaterialApp(
          builder: (_, child) => RaftDensityScope(
            density: Platform.isAndroid
                ? RaftDensity.touch
                : RaftDensity.desktop,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 480),
                devicePixelRatio: 1,
              ),
              child: child!,
            ),
          ),
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: imageKey,
                child: SizedBox(
                  width: 390,
                  height: 480,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Column(
                      children: [
                        const Spacer(),
                        RaftComposer(
                          onImagePick: () {},
                          onAttach: () {},
                          onSend: (text) async {
                            sent.add(text);
                            return true;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await capture(
        'composer-empty',
        theme,
        find.byType(RaftComposer),
        'Actual source-slot composition; empty Send disabled',
      );
      await t.enterText(find.byType(TextField), '原生输入 日本語');
      await t.pump();
      await capture(
        'composer-filled',
        theme,
        find.byType(RaftComposer),
        'Real CJK TextField input; Send enabled',
      );
      await t.tap(find.byTooltip('Send message (Ctrl+Enter)'));
      await t.pump(const Duration(milliseconds: 240));
      expect(sent, ['原生输入 日本語']);
      expect(
        t.widget<EditableText>(find.byType(EditableText)).controller.text,
        isEmpty,
      );
      await capture(
        'composer-sent',
        theme,
        find.byType(RaftComposer),
        'Real Send callback accepted; exact draft cleared',
      );
      await t.pumpWidget(const SizedBox());
      await t.pump();
    }
    await File('${dir.path}/$platform-restoration-components-result.json')
        .writeAsString(
          jsonEncode({
            'sourceHash': sourceHash,
            'runId': runId,
            'platform': platform,
            'completed': true,
            'scope': 'native controlled component rendering and pointer/input; API/full route parity NOT_RUN',
            'captures': shots.length,
          }),
        );
  });
}
