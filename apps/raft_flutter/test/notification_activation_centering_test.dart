import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/notification_activation_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_notifications_test.dart' show deferredMacNotifications;
import 'notification_activation_banner_test.dart' show host;
import 'notification_first_workspace_test.dart' show turn;
import 'parity/parity_harness.dart' show loadParityFonts;

void main() {
  late List<String> loadedFonts;
  setUpAll(() async => loadedFonts = await loadParityFonts());
  for (final dark in [false, true]) {
    for (final chinese in [false, true]) {
      for (final width in [480.0, 900.0]) {
        testWidgets(
          'activation action and text centered ${dark ? 'dark' : 'light'}/$chinese/$width',
          (t) async {
            SharedPreferences.setMockInitialValues({});
            t.view.physicalSize = const Size(1200, 800);
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.resetPhysicalSize);
            addTearDown(t.view.resetDevicePixelRatio);
            final (s, _, _) = deferredMacNotifications();
            addTearDown(s.dispose);
            await s.bindAuthenticatedWorkspace('alice');
            final imageKey = GlobalKey();
            await t.pumpWidget(
              host(
                Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: RepaintBoundary(
                      key: imageKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NotificationActivationBanner(
                            service: s,
                            onSettings: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                s,
                dark: dark,
                chinese: chinese,
              ),
            );
            await turn(t);
            final banner = t.getRect(
              find.byKey(const ValueKey('notification-activation-banner')),
            );
            final button = t.getRect(
              find.widgetWithText(
                RaftButton,
                chinese ? '开启通知' : 'Enable Notifications',
              ),
            );
            final label = t.getRect(
              find.text(chinese ? '开启通知' : 'Enable Notifications'),
            );
            final close = t.getRect(find.byType(RaftCloseButton));
            expect(close.size, const Size(32, 32));
            Map<String, double> rect(Rect r) => {
              'x': r.left,
              'y': r.top,
              'width': r.width,
              'height': r.height,
              'centerY': r.center.dy,
            };
            final measurements = {
              'banner': rect(banner),
              'button': rect(button),
              'label': rect(label),
              'close': rect(close),
              'buttonOffset': button.center.dy - banner.center.dy,
              'labelOffset': label.center.dy - button.center.dy,
              'above': button.top - banner.top,
              'below': banner.bottom - button.bottom,
            };
            final name =
                '${dark ? 'dark' : 'light'}-${chinese ? 'zh' : 'en'}-${width.toInt()}';
            final capture = Platform.environment['RAFT_NOTIFICATION_CAPTURE'];
            if (capture != null) {
              if (chinese) {
                expect(
                  loadedFonts,
                  contains('Noto Sans CJK JP'),
                  reason:
                      'A Chinese capture requires a real CJK fallback font; '
                      'set RAFT_TEST_FONT_DIR before capturing.',
                );
              }
              await t.runAsync(() async {
                await Directory(capture).create(recursive: true);
                final boundary =
                    imageKey.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                final raster = await boundary.toImage(pixelRatio: 2);
                final data = await raster.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(p.join(capture, '$name.png'))
                    .writeAsBytes(data!.buffer.asUint8List());
                raster.dispose();
                await File(p.join(capture, '$name.json'))
                    .writeAsString(jsonEncode(measurements));
              });
            }
            await t.pumpWidget(const SizedBox());
            await t.pumpAndSettle();
            expect(
              (button.center.dy - banner.center.dy).abs(),
              lessThanOrEqualTo(.5),
              reason: jsonEncode(measurements),
            );
            expect(
              (label.center.dy - button.center.dy).abs(),
              lessThanOrEqualTo(.5),
              reason: jsonEncode(measurements),
            );
            expect(
              (close.center.dy - button.center.dy).abs(),
              lessThanOrEqualTo(.5),
            );
          },
        );
      }
    }
  }
}
