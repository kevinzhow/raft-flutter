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
// must retain its trigger's inherited themes even when the actual owner
// State.context is above Scaffold/body typography, as WorkspaceView passes it.
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

// Mirrors WorkspaceView.sortSidebarGroup: the method passes this State.context,
// while the actual trigger is rendered below Scaffold's DefaultTextStyle.
class _SortOwner extends StatefulWidget {
  const _SortOwner({
    super.key,
    required this.workspace,
    required this.theme,
    required this.explicitStyle,
  });

  final WorkspaceController workspace;
  final ThemeData theme;
  final TextStyle? explicitStyle;

  @override
  State<_SortOwner> createState() => _SortOwnerState();
}

class _SortOwnerState extends State<_SortOwner> {
  final anchor = GlobalKey();
  String? result;

  Future<void> open() async {
    result = await showSidebarSortMenu(
      context,
      widget.workspace,
      anchor,
      'recent',
    );
  }

  @override
  Widget build(BuildContext context) {
    final trigger = Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          key: anchor,
          width: 72,
          height: 36,
          child: RaftButton(label: 'Sort', onPressed: open),
        ),
      ),
    );
    return Theme(
      data: widget.theme,
      child: Scaffold(
        body: widget.explicitStyle == null
            ? trigger
            : DefaultTextStyle(style: widget.explicitStyle!, child: trigger),
      ),
    );
  }
}

void main() {
  for (final dark in [false, true]) {
    for (final ambient in _Ambient.values) {
      testWidgets(
        'State-owned Sidebar popup inherits anchor $ambient typography; dark=$dark',
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
          final ownerKey = GlobalKey<_SortOwnerState>();
          try {
            await tester.pumpWidget(
              MaterialApp(
                theme: base,
                home: _SortOwner(
                  key: ownerKey,
                  workspace: workspace,
                  theme: themed,
                  explicitStyle: ambient == _Ambient.explicitText
                      ? themed.textTheme.bodyMedium!.copyWith(
                          fontFamily: expectedFont,
                          fontFamilyFallback: expectedFallback,
                          decoration: TextDecoration.none,
                        )
                      : null,
                ),
              ),
            );
            final owner = ownerKey.currentState!;
            expect(
              DefaultTextStyle.of(owner.context).style.fontFamily,
              isNot(expectedFont),
              reason: 'actual owner State is outside the body typography',
            );
            expect(
              DefaultTextStyle.of(owner.anchor.currentContext!)
                  .style
                  .fontFamily,
              expectedFont,
              reason: 'trigger inherits the real source document typography',
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
            expect(owner.result, 'az');
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
