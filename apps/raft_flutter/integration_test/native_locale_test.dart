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

import 'package:raft_ui/raft_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('actual native display-language save and application locale', (
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
    try {
      await tester.tap(find.byKey(const Key('account-navigation')));
      await tester.pumpAndSettle();
      final oldLanguage = w.client.user!.json['displayLanguage'];
      try {
        final control = find.byKey(const Key('account-display-language'));
        await tester.ensureVisible(control);
        await tester.pumpAndSettle();
        await tester.tap(control);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('field-displayLanguage')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('简体中文').last);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(RaftButton, 'Save'));
        await until(
          () =>
              w.client.user!.string('displayLanguage') == 'zh-cn' &&
              find.byType(RaftFormDialog).evaluate().isEmpty,
        );
        await tester.pumpAndSettle();
        final scroll = find
            .descendant(
              of: find.byKey(const Key('workspace-account-settings')),
              matching: find.byType(Scrollable),
            )
            .first;
        expect(
          Localizations.localeOf(tester.element(scroll)).languageCode,
          'zh',
        );
        tester.state<ScrollableState>(scroll).position.jumpTo(0);
        await tester.pumpAndSettle();
        expect(find.text('外观'), findsOneWidget);
        expect(find.text('深色'), findsOneWidget);
        expect(find.text('浅色'), findsOneWidget);
        final image =
            await (app.raftScreenshotKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${report.path}/native-chinese-account.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      } finally {
        await w.client.patch(
          '/auth/me',
          data: {'displayLanguage': oldLanguage},
        );
        await w.client.reloadUser();
        await tester.pumpAndSettle();
      }
      await File('${report.path}/locale-result.json').writeAsString(
        jsonEncode({
          'platform': 'linux',
          'completed': true,
          'flow': 'actual-login-language-locale-translated-controls-restored',
          'sourceHash': const String.fromEnvironment('RAFT_TEST_SOURCE_HASH'),
        }),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    }
  });
}
