import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/main.dart' as app;

import 'media_preview_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('actual native uploaded document PDF audio and video previews', (
    tester,
  ) async {
    final fixture = jsonDecode(
      File(const String.fromEnvironment('RAFT_TEST_CONFIG')).readAsStringSync(),
    ) as Map;
    final report = Directory(const String.fromEnvironment('RAFT_TEST_REPORT'));
    await report.create(recursive: true);
    Future<void> until(bool Function() ready) async {
      for (var i = 0; i < 300 && !ready(); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(ready(), true);
    }

    await tester.pumpWidget(app.RaftApp(sessionStore: MemorySessionStore()));
    await until(
      () => find.byKey(const Key('login-email')).evaluate().isNotEmpty,
    );
    for (final field in ['origin', 'email', 'password']) {
      await tester.tap(find.byKey(Key('login-$field')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byKey(Key('login-$field')), fixture[field]);
    }
    await tester.tap(find.byKey(const Key('login-submit')));
    await until(() => find.byType(RaftChatView).evaluate().isNotEmpty);
    final w = tester
        .widget<RaftChatView>(find.byType(RaftChatView).first)
        .controller;
    await until(() => !w.loading && w.server != null);
    final created = await w.client.request(
      'POST',
      '/channels',
      data: {
        'name': 'native-media-${DateTime.now().microsecondsSinceEpoch}',
        'type': 'channel',
      },
    );
    final owned = RaftChannel(Map<String, dynamic>.from(created));
    try {
      await w.refreshChannels();
      await w.selectChannel(owned);
      await until(
        () =>
            !w.channelLoading &&
            find.byType(RaftChatView).evaluate().isNotEmpty,
      );
      await verifyNativeMediaPreviewFlow(tester, w, (name) async {
        await tester.pump(const Duration(milliseconds: 300));
        final image =
            await (app.raftScreenshotKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${report.path}/linux-$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
      await File('${report.path}/media-result.json').writeAsString(
        jsonEncode({
          'platform': 'linux',
          'completed': true,
          'flow': 'actual-login-upload-private-input-native-decoder',
          'sourceHash': const String.fromEnvironment('RAFT_TEST_SOURCE_HASH'),
        }),
      );
    } finally {
      // Delete only the channel created by this test; never enumerate/mutate others.
      await w.client.request('DELETE', '/channels/${owned.id}');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    }
  });
}
