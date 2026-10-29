import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/local_error_diagnostics.dart';
import 'package:raft_flutter/features/local_error_diagnostics.dart';
import 'package:raft_flutter/features/storage_settings.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  Future<void> page(
    WidgetTester tester, {
    Size size = const Size(900, 1600),
    bool dark = false,
    Locale locale = const Locale('en'),
    double scale = 1,
    Widget child = const StorageSettingsPage(),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark, locale: locale),
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: RaftToastHost(child: child!),
        ),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('diagnostics is the last storage section with one Copy action', (
    tester,
  ) async {
    await page(tester);
    final headers = tester
        .widgetList<RaftSettingsSectionHeader>(
          find.byType(RaftSettingsSectionHeader),
        )
        .map((header) => header.label);
    expect(headers, ['Storage', 'Local error diagnostics']);
    final diagnostics = find.byType(LocalErrorDiagnosticsCard);
    expect(
      tester.getTopLeft(diagnostics).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const Key('storage-clear'))).dy,
      ),
    );
    expect(
      find.descendant(of: diagnostics, matching: find.text('Copy')),
      findsOneWidget,
    );
    expect(find.text('Copy diagnostics'), findsNothing);
  });

  for (final theme in ['light', 'dark']) {
    for (final locale in [const Locale('en'), const Locale('zh', 'CN')]) {
      testWidgets('narrow large text stays above Copy: $theme/$locale', (
        tester,
      ) async {
        await page(
          tester,
          size: const Size(390, 1200),
          dark: theme == 'dark',
          locale: locale,
          scale: 2,
          child: const LocalErrorDiagnosticsCard(),
        );
        final description = find.descendant(
          of: find.byType(LocalErrorDiagnosticsCard),
          matching: find.byWidgetPredicate(
            (widget) => widget is Text && (widget.data?.length ?? 0) > 40,
          ),
        );
        final button = find.byType(RaftSettingsRecipeButton);
        expect(description, findsOneWidget);
        expect(button, findsOneWidget);
        expect(
          tester.getTopLeft(button).dy,
          greaterThan(tester.getBottomLeft(description).dy),
        );
        expect(tester.getSize(description).width, greaterThan(250));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a newly recorded error never leaves a no-errors claim', (
    tester,
  ) async {
    final log = LocalErrorDiagnostics();
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await page(tester, child: LocalErrorDiagnosticsCard(log: log));
    log.capture(StateError('synthetic failure'), StackTrace.empty);
    await tester.pump();
    expect(find.textContaining('No storage errors recorded'), findsNothing);
    await tester.tap(find.byType(RaftSettingsRecipeButton));
    await tester.pumpAndSettle();
    expect((jsonDecode(clipboard!)['samples'] as List), hasLength(1));
    expect(find.text('Diagnostics copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
