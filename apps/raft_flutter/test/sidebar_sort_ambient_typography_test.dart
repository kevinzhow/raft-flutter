import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/sidebar_sort_menu.dart';
import 'package:raft_ui/raft_ui.dart';

// Real route, no Material/DefaultTextStyle added to its pageBuilder. The
// SelectionPopover source deliberately inherits body typography. The popup
// must retain its caller's inherited themes instead of MaterialApp's debug
// monospace/double-yellow-underline fallback above the Navigator.
enum _Ambient { document, localTheme, explicitText }

bool _realFontsLoaded = false;

Future<void> _loadRealFonts(WidgetTester tester) async {
  if (_realFontsLoaded) return;
  await tester.runAsync(() async {
    Directory? fonts;
    var directory = Directory.current;
    while (fonts == null) {
      for (final relative in [
        'assets/fonts/',
        'packages/raft_ui/assets/fonts/',
      ]) {
        final candidate = Directory.fromUri(directory.uri.resolve(relative));
        if (File.fromUri(candidate.uri.resolve('SpaceGrotesk.ttf'))
            .existsSync()) {
          fonts = candidate;
          break;
        }
      }
      if (fonts != null) break;
      final parent = directory.parent;
      if (parent.path == directory.path) {
        throw StateError('Cannot locate the checked-out raft_ui font assets.');
      }
      directory = parent;
    }
    for (final family in [
      'SpaceGrotesk',
      'SpaceMono',
      'HankenGrotesk',
      'Inter',
      'Geist',
      'GeistMono',
    ]) {
      final bytes = await File.fromUri(fonts.uri.resolve('$family.ttf'))
          .readAsBytes();
      await (FontLoader(
        'packages/raft_ui/$family',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    // A missing file or failed font registration must fail this case and let
    // the next case retry, never silently cache a fallback to Ahem.
    _realFontsLoaded = true;
  });
  if (!_realFontsLoaded) {
    throw StateError('Real-font loading failed; geometry was not exercised.');
  }
}

TextStyle _style(WidgetTester tester, String label) =>
    tester.renderObject<RenderParagraph>(find.text(label)).text.style!;

void main() {
  for (final dark in [false, true]) {
    for (final ambient in _Ambient.values) {
      testWidgets(
        'Sidebar raw popup retains $ambient typography and theme; dark=$dark',
        (tester) async {
          await _loadRealFonts(tester);
          final pixelRatio = tester.view.devicePixelRatio;
          tester.view.physicalSize = Size(900 * pixelRatio, 844 * pixelRatio);
          final client = RaftClient(
            origin: 'https://fixture.invalid',
            sessionStore: MemorySessionStore(),
          )..user = RaftRecord({'id': 'viewer'});
          final workspace = WorkspaceController(client)
            ..server = RaftRecord({'id': 'server', 'role': 'owner'});
          final anchor = GlobalKey();
          final base = raftTheme(dark: dark, platform: TargetPlatform.linux);
          final tokens = base.extension<RaftTokens>()!;
          final themed = ambient == _Ambient.localTheme
              ? base.copyWith(
                  textTheme: base.textTheme.copyWith(
                    bodyMedium: base.textTheme.bodyMedium!.copyWith(
                      fontFamily: tokens.monoFont,
                    ),
                  ),
                )
              : base;
          final expectedFont = switch (ambient) {
            _Ambient.document => tokens.bodyFont,
            _Ambient.localTheme => tokens.monoFont,
            _Ambient.explicitText => 'packages/raft_ui/Inter',
          };
          final expectedFallback = ambient == _Ambient.explicitText
              ? const ['CallerFallback', 'sans-serif']
              : themed.textTheme.bodyMedium!.fontFamilyFallback;
          String? result;
          try {
            final body = Builder(
              builder: (context) => Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    key: anchor,
                    width: 72,
                    height: 36,
                    child: RaftButton(
                      label: 'Sort',
                      onPressed: () async {
                        result = await showSidebarSortMenu(
                          context,
                          workspace,
                          anchor,
                          'recent',
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpWidget(
              MaterialApp(
                theme: base,
                // This local Theme is deliberately below the Navigator so
                // the real raw route must capture it, as standard dialogs do.
                home: Theme(
                  data: themed,
                  child: Scaffold(
                    body: ambient == _Ambient.explicitText
                        ? DefaultTextStyle(
                            style: themed.textTheme.bodyMedium!.copyWith(
                              fontFamily: expectedFont,
                              fontFamilyFallback: expectedFallback,
                              decoration: TextDecoration.none,
                            ),
                            child: body,
                          )
                        : body,
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Sort'));
            await tester.pumpAndSettle();
            final popup = find.byKey(const Key('sidebar-sort-popover'));
            expect(popup, findsOneWidget);
            for (final label in ['Manual', 'Recent', 'A-Z']) {
              final text = _style(tester, label);
              expect(text.fontFamily, expectedFont);
              expect(text.fontFamilyFallback, expectedFallback);
              expect(
                text.decoration == null ||
                    text.decoration == TextDecoration.none,
                isTrue,
                reason: 'route must not inherit the debug yellow underline',
              );
              expect(text.fontSize, 14);
            }
            expect(
              Theme.of(tester.element(find.text('Manual')))
                  .textTheme
                  .bodyMedium!
                  .fontFamily,
              themed.textTheme.bodyMedium!.fontFamily,
            );
            expect(_style(tester, 'Recent').fontWeight, FontWeight.w700);
            expect(tester.getSize(popup), const Size(160, 132));
            await tester.tap(find.byKey(const ValueKey('sidebar-sort-az')));
            await tester.pumpAndSettle();
            expect(result, 'az');
            expect(popup, findsNothing);
            expect(tester.takeException(), isNull);
          } finally {
            if (find
                .byKey(const Key('sidebar-sort-popover'))
                .evaluate()
                .isNotEmpty) {
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              await tester.pumpAndSettle();
            }
            tester.view.reset();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            workspace.dispose();
            await client.dispose();
          }
        },
      );
    }
  }
}
