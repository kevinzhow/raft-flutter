import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_ui/raft_ui.dart';

import '../test/chat_tall_focus_scenario.dart';
import 'native_message_menu.dart' show createNativeMouse;

// Controlled native RaftChatView rendering/input. This fixture does not prove
// authentication, a real backend Activity route, OS keyboard or pixel parity.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  final runId = DateTime.now().toUtc().toIso8601String();
  for (final (family, dark, theme) in [
    (RaftFamily.brutal, false, 'brutal-light'),
    (RaftFamily.elegant, false, 'elegant-light'),
    (RaftFamily.elegant, true, 'elegant-dark'),
  ]) {
    testWidgets('[P01] native tall focus and first context-menu input $theme', (
      tester,
    ) async {
      const sourceHash = String.fromEnvironment('RAFT_TEST_SOURCE_HASH');
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sourceHash)) {
        throw StateError('Pass the frozen RAFT_TEST_SOURCE_HASH.');
      }
      final out = Directory(
        const String.fromEnvironment(
          'RAFT_TEST_REPORT',
          defaultValue: '/tmp/raft-tall-focus-native',
        ),
      );
      await out.create(recursive: true);
      final hostSize = ValueNotifier(const Size(411, 605));
      addTearDown(hostSize.dispose);
      final imageKey = GlobalKey();
      final evidence = <Map<String, dynamic>>[];
      final report = <String, dynamic>{
        'runId': runId,
        'sourceHash': sourceHash,
        'platform': Platform.operatingSystem,
        'theme': theme,
        'scope': 'Controlled real native RaftChatView / fixture HTTP adapter',
        'backendActivity': 'NOT_RUN',
        'osKeyboard': 'NOT_RUN; constrained keyboard-sized viewport',
        'pixelParity': 'UNACCEPTED',
        'status': 'RUNNING',
        'captures': evidence,
      };
      Future<void> save() =>
          File('${out.path}/tall-focus-$theme.json')
              .writeAsString(jsonEncode(report));
      Future<void> capture(String phase, Rect target, Rect clip) async {
        await tester.pump();
        final boundary =
            imageKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final origin = boundary.localToGlobal(Offset.zero);
        final image = await boundary.toImage(pixelRatio: 1);
        final name = 'tall-focus-$theme-$phase.png';
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${out.path}/$name')
              .writeAsBytes(data!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
        Map<String, double> rect(Rect r) => {
          'left': r.left,
          'top': r.top,
          'width': r.width,
          'height': r.height,
        };
        evidence.add({
          'phase': phase,
          'image': name,
          'target': rect(target.shift(-origin)),
          'viewport': rect(clip.shift(-origin)),
          'coordinateSpace': 'native-host-logical',
          'deviceDpr': tester.view.devicePixelRatio,
          'rasterDpr': 1,
        });
        await save();
      }

      await save();
      try {
        await checkTallFocusReceipt(
          tester,
          family: family,
          dark: dark,
          hostBuilder: (child) => Center(
            child: ValueListenableBuilder<Size>(
              valueListenable: hostSize,
              child: child,
              builder: (context, size, child) => SizedBox(
                width: size.width,
                height: size.height,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: size,
                    padding: EdgeInsets.zero,
                    viewPadding: EdgeInsets.zero,
                    viewInsets: EdgeInsets.zero,
                  ),
                  child: RepaintBoundary(key: imageKey, child: child!),
                ),
              ),
            ),
          ),
          resize: () async => hostSize.value = const Size(465, 625),
          onAccepted: (tester, row, bounds, clip) async {
            await capture('published', bounds, clip);
            final press = Offset(bounds.left + 2, clip.center.dy);
            // No ensureVisible, re-centering or gesture retries. The accepted
            // row's visible padding must handle the first native pointer.
            if (Platform.isLinux) {
              final mouse = createNativeMouse(
                tester,
                buttons: kSecondaryMouseButton,
              );
              await mouse.addPointer(location: press);
              try {
                await mouse.down(press);
                await mouse.up();
              } finally {
                await mouse.removePointer();
              }
            } else {
              await tester.longPressAt(press);
            }
            final copy = find.text('Copy Markdown');
            for (var i = 0; i < 20 && copy.evaluate().isEmpty; i++) {
              await tester.pump(const Duration(milliseconds: 16));
            }
            expect(copy, findsOneWidget);
            report['pointerCount'] = 1;
            report['pointer'] = Platform.isLinux
                ? 'secondary-mouse'
                : 'long-press';
            await capture('first-menu', bounds, clip);
            await tester.tap(copy);
            await tester.pumpAndSettle();
            final copied = await Clipboard.getData(Clipboard.kTextPlain);
            expect(
              copied?.text,
              [for (var i = 0; i < 14; i++) 'Tall line $i 中文'].join('  \n'),
            );
            report['copiedAcceptedTarget'] = true;
          },
          onComplete: (tester, row) async {
            final render = tester.element(row).findRenderObject() as RenderBox;
            final view = RenderAbstractViewport.of(render) as RenderBox;
            report['mountedRowsAfterResize'] = find
                .byType(RaftMessageTile, skipOffstage: false)
                .evaluate()
                .length;
            await capture(
              'retained-resized',
              render.localToGlobal(Offset.zero) & render.size,
              view.localToGlobal(Offset.zero) & view.size,
            );
          },
        );
        report['status'] = 'PASS';
        report['checks'] = [
          'centered tall row publishes',
          'cache and mounted rows bounded',
          'first accepted-padding pointer opens menu',
          'copy reads accepted target content',
          'top and bottom 25px-only intersections rejected',
          'accepted element survives highlight expiry and resize',
        ];
      } catch (error) {
        report['status'] = 'FAIL';
        report['error'] = '$error';
        rethrow;
      } finally {
        report['endedAt'] = DateTime.now().toUtc().toIso8601String();
        await save();
        binding.reportData = {
          ...?binding.reportData,
          'tallFocus-$theme': report,
        };
      }
    });
  }
}
