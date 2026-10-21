import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';

/// Message attachment cards carry no floating Share / Download icons: the card
/// itself opens the viewer (or saves a file with no preview), and the viewer
/// keeps Download. Mirrors the image-preview change of #295 for every other
/// card type.
class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      path.endsWith('/attachment-preview/enabled')
      ? {'enabled': true}
      : {'url': 'https://storage.example.invalid/private-signed-capability'};
}

class _Files extends AttachmentFiles {
  final saved = <String>[];
  @override
  Future<String?> save({
    required String url,
    required String filename,
    required String mimeType,
    required CancelToken cancel,
    required bool Function() authorized,
    required void Function(int, int) onProgress,
  }) async {
    saved.add(filename);
    return null;
  }
}

class _Sharing extends NativeSharing {
  _Sharing({required bool supported}) : super(supported: supported);
  final shared = <String>[];
  @override
  Future<SharedFileLease?> prepareAttachment({
    required String url,
    required String filename,
    required CancelToken cancel,
    required bool Function() authorized,
    required void Function(int, int) onProgress,
  }) async {
    shared.add(filename);
    return null;
  }
}

class _Kind {
  const _Kind(this.name, this.mime, {this.previews = true});
  final String name, mime;

  /// Opens a preview dialog; otherwise a tap saves the file.
  final bool previews;
}

const _kinds = [
  _Kind('report.pdf', 'application/pdf'),
  _Kind('notes.txt', 'text/plain'),
  _Kind('readme.md', 'text/markdown'),
  _Kind('table.csv', 'text/csv'),

  _Kind('page.html', 'text/html'),
  _Kind('fix.patch', 'text/x-patch', previews: false),
  _Kind('bundle.zip', 'application/zip', previews: false),
  _Kind('main.dart', 'application/octet-stream', previews: false),
];

void main() {
  for (final (family, dark) in const [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final touch in const [false, true]) {
      testWidgets(
        '${family.name} dark=$dark ${touch ? 'touch' : 'mouse'}: file cards '
        'have no Share/Download icons and open on tap, Enter and Space',
        (tester) async {
          final client = _Client()..user = RaftRecord({'id': 'alice'});
          client.selectServer('server');
          final w = WorkspaceController(client)
            ..server = RaftRecord({'id': 'server', 'role': 'owner'})
            ..channel = RaftChannel({'id': 'channel', 'joined': true});
          w.channels = [w.channel!];
          final files = _Files();
          final sharing = _Sharing(supported: true);
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            w.dispose();
            await client.dispose();
          });
          TestGesture? mouse;
          try {
            for (final kind in _kinds) {
              await tester.pumpWidget(
                MaterialApp(
                  theme: raftTheme(family, dark: dark).copyWith(
                    platform: touch
                        ? TargetPlatform.android
                        : TargetPlatform.linux,
                  ),
                  home: Scaffold(
                    body: Align(
                      alignment: Alignment.topLeft,
                      child: AttachmentView(
                        controller: w,
                        files: files,
                        // Sharing is supported: the old card showed a Share icon.
                        sharing: sharing,
                        metadata: {
                          'id': kind.name,
                          'filename': kind.name,
                          'mimeType': kind.mime,
                          'sizeBytes': 2048,
                        },
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              final card = find.byType(RaftAttachmentCard);
              bool cardFocused() =>
                  FocusManager.instance.primaryFocus?.context
                      ?.findAncestorWidgetOfExactType<TextButton>() !=
                  null;
              void expectNoIcons() {
                expect(find.byTooltip('Share ${kind.name}'), findsNothing);
                expect(find.byTooltip('Download ${kind.name}'), findsNothing);
                expect(
                  find.descendant(
                    of: card,
                    matching: find.byType(RaftIconButton),
                  ),
                  findsNothing,
                  reason: kind.name,
                );
              }

              expectNoIcons();
              if (!touch) {
                mouse = await tester.createGesture(
                  kind: PointerDeviceKind.mouse,
                );
                await mouse.addPointer(location: const Offset(700, 550));
                await mouse.moveTo(tester.getCenter(card));
                await tester.pump();
                expectNoIcons();
                await mouse.moveTo(
                  tester.getBottomRight(card) - const Offset(12, 12),
                );
                await tester.pump();
                expectNoIcons();
                await mouse.removePointer();
                mouse = null;
              }
              // The surface and then the card button take focus.
              for (var i = 0; i < 3 && !cardFocused(); i++) {
                await tester.sendKeyEvent(LogicalKeyboardKey.tab);
                await tester.pump();
              }
              expect(cardFocused(), isTrue, reason: kind.name);
              expectNoIcons();

              // Keyboard: the focused card activates with Enter and Space.
              for (final key in [
                LogicalKeyboardKey.enter,
                LogicalKeyboardKey.space,
              ]) {
                final saves = files.saved.length;
                await tester.sendKeyEvent(key);
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 300));
                if (kind.previews) {
                  expect(
                    find.byKey(const ValueKey('attachment-preview-download')),
                    findsOneWidget,
                    reason: '${kind.name} ${key.keyLabel}',
                  );
                  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
                  await tester.pumpAndSettle();
                } else {
                  expect(
                    files.saved.length,
                    saves + 1,
                    reason: '${kind.name} ${key.keyLabel}',
                  );
                }
              }
              // The old Share / Download target (bottom-right) is the card.
              final before = files.saved.length;
              await tester.tapAt(
                tester.getBottomRight(card) - const Offset(20, 20),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
              if (kind.previews) {
                // The viewer keeps Download and gains Share.
                expect(
                  find.byKey(const ValueKey('attachment-preview-download')),
                  findsOneWidget,
                  reason: kind.name,
                );
                final share = find.byKey(
                  const ValueKey('attachment-preview-share'),
                );
                expect(share, findsOneWidget, reason: kind.name);
                await tester.tap(share);
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 100));
                expect(sharing.shared, [kind.name], reason: kind.name);
                sharing.shared.clear();
                await tester.sendKeyEvent(LogicalKeyboardKey.escape);
                await tester.pumpAndSettle();
                expect(
                  find.byKey(const ValueKey('attachment-preview-download')),
                  findsNothing,
                );
              } else {
                expect(files.saved.length, before + 1, reason: kind.name);
              }
              expectNoIcons();

              expect(tester.takeException(), isNull, reason: kind.name);
            }
          } finally {
            await mouse?.removePointer();
            // A download disposes its progress notifier one second later.
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 2));
          }
        },
      );
    }
  }

  testWidgets('a platform without a share sheet shows no Share in the viewer', (
    tester,
  ) async {
    final client = _Client()..user = RaftRecord({'id': 'alice'});
    client.selectServer('server');
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 'server', 'role': 'owner'})
      ..channel = RaftChannel({'id': 'channel', 'joined': true});
    w.channels = [w.channel!];
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: AttachmentView(
            controller: w,
            files: _Files(),
            sharing: _Sharing(supported: false),
            metadata: const {
              'id': 'r',
              'filename': 'report.pdf',
              'mimeType': 'application/pdf',
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(RaftAttachmentCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('attachment-preview-download')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('attachment-preview-share')),
      findsNothing,
    );
  });
}
