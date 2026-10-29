import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/mcp_server_editor.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'parity/parity_harness.dart' show loadParityFonts;

Finder _key(String name) => find.byKey(ValueKey(name));
const _server = {
  'id': 'qa-only',
  'name': 'Example tools',
  'provider': 'custom',
  'authMode': 'headers',
  'endpointUrl': 'https://example.invalid/mcp',
  'credentialHeaderNames': ['Authorization', 'X-Workspace'],
};

Future<void> _mount(
  WidgetTester tester,
  double width, {
  bool dark = false,
  double scale = 1,
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      builder: (context, child) => RepaintBoundary(
        key: capture,
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: RaftTextScaling(child: child!),
        ),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => RaftButton(
            key: const ValueKey('open-mcp-editor'),
            label: 'Open MCP',
            onPressed: () => showRaftForm<bool>(
              context,
              dialogMaxWidth: McpServerEditor.dialogMaxWidth,
              builder: (_) => McpServerEditor(
                server: _server,
                onSave: (_) async {},
                onTest: (_) async => 2,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(_key('open-mcp-editor'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final fonts = await loadParityFonts();
    expect(
      fonts,
      containsAll([
        'packages/raft_ui/SpaceGrotesk',
        'packages/raft_ui/SpaceMono',
      ]),
    );
  });
  for (final dark in raftThemeMatrix([false, true], full: true)) {
    for (final width in [390.0, 1200.0]) {
      for (final scale in [1.0, 3.1]) {
        testWidgets(
          '${dark ? 'dark' : 'light'}/$width/$scale editor actions and semantics',
          (tester) async {
            final semantics = tester.ensureSemantics();
            final capture = GlobalKey();
            try {
              await _mount(
                tester,
                width,
                dark: dark,
                scale: scale,
                capture: capture,
              );
              expect(_key('mcp-server-editor'), findsOneWidget);
              if (width >= 768) {
                expect(tester.getSize(_key('mcp-server-editor')).width, 672);
              }
              await tester.ensureVisible(_key('mcp-editor-test'));
              await tester.pumpAndSettle();
              expect(
                tester.getSemantics(_key('mcp-editor-test')).label,
                contains('Test connection'),
              );
              await tester.ensureVisible(_key('mcp-editor-save'));
              await tester.pumpAndSettle();
              expect(_key('mcp-editor-save').hitTestable(), findsOneWidget);
              expect(tester.takeException(), isNull);
              final out = Platform.environment['RAFT_MCP_QA_DIR'];
              if (out != null) {
                await tester.runAsync(() async {
                  final boundary =
                      capture.currentContext!.findRenderObject()
                          as RenderRepaintBoundary;
                  final image = await boundary.toImage();
                  try {
                    final bytes = (await image.toByteData(
                      format: ui.ImageByteFormat.png,
                    ))!;
                    final target = File(
                      '$out/${dark ? 'dark' : 'light'}-${width.toInt()}-$scale.png',
                    );
                    await target.parent.create(recursive: true);
                    await target.writeAsBytes(bytes.buffer.asUint8List());
                  } finally {
                    image.dispose();
                  }
                });
              }
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              await tester.pumpAndSettle();
              expect(_key('mcp-server-editor'), findsNothing);
            } finally {
              semantics.dispose();
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
            }
          },
        );
      }
    }
  }

  testWidgets('phone to desktop reflow preserves text, caret and focus', (
    tester,
  ) async {
    try {
      await _mount(tester, 390);
      await tester.ensureVisible(_key('mcp-name'));
      await tester.tap(_key('mcp-name'));
      await tester.enterText(_key('mcp-name'), 'Edited fixture');
      await tester.pump();
      final editable = find.descendant(
        of: _key('mcp-name'),
        matching: find.byType(EditableText),
      );
      final before = tester.widget<EditableText>(editable);
      before.controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();
      tester.view.physicalSize = const Size(1200, 1000);
      await tester.pumpAndSettle();
      final after = tester.widget<EditableText>(editable);
      expect(after.controller.text, 'Edited fixture');
      expect(after.controller.selection.baseOffset, 3);
      expect(after.focusNode.hasFocus, isTrue);
      expect(identical(before.focusNode, after.focusNode), isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
