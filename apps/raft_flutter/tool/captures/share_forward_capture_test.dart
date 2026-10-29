// Run from apps/raft_flutter: tool/flutter test tool/captures/share_forward_capture_test.dart
// Flutter-only captures of the incoming-share target picker (390x844 @3x) in
// the three themes: tool/share-forward-sheet builds the Web | before | after
// contact sheet from them. Skipped unless SHARE_SHEET_OUT names a directory.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/incoming_share_picker.dart';
import 'package:raft_flutter/platform/incoming_share_staging.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../test/flutter_test_config.dart' show RaftTestBinding;
import '../../test/parity/parity_harness.dart' show loadParityFonts;

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://example.test', sessionStore: MemorySessionStore());
  static const t0 = '2026-06-18T00:00:00.000Z';
  Map<String, dynamic> ch(String id, String name, {String type = 'channel'}) =>
      {'id': id, 'name': name, 'type': type, 'joined': true, 'createdAt': t0};
  Map<String, dynamic> dm(String id, String name, {bool agent = true}) => {
    'id': id,
    'name': name,
    'type': 'dm',
    'joined': true,
    'peerType': agent ? 'agent' : 'user',
    'peerDisplayName': name,
    'createdAt': t0,
  };
  @override
  Future<dynamic> getForServer(
    String server,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (path == '/channels/dm') {
      return [
        dm('d1', 'Cindy'),
        dm('d2', 'Grok'),
        dm('d3', 'Designer', agent: false),
      ];
    }
    if (path == '/channels') {
      return [
        ch('c1', 'general'),
        ch('c2', 'design', type: 'private'),
        ch('c3', 'release', type: 'joint'),
        ch('c4', 'android-artifacts'),
      ];
    }
    return [];
  }
}

const _files = IncomingShare(
  token: 'fixture',
  files: [
    IncomingSharedFile(
      'content://media/external/images/1',
      'IMG_2041.jpg',
      'image/jpeg',
      2400000,
    ),
    IncomingSharedFile(
      'content://media/external/images/2',
      'screenshot-release.png',
      'image/png',
      880000,
    ),
    IncomingSharedFile(
      'content://media/external/file/3',
      'Q3-visual-review.pdf',
      'application/pdf',
      5100000,
    ),
  ],
);
const _text = IncomingShare(
  token: 'fixture',
  text:
      'Release gates are green for the Android capture. Please compare the '
      'forwarded card, the reaction picker and the hover toolbar before merge.',
);

void main() {
  RaftTestBinding.showShadows();
  final out = Platform.environment['SHARE_SHEET_OUT'];
  if (out == null) {
    test('share capture (set SHARE_SHEET_OUT)', () {}, skip: true);
    return;
  }
  const themes = {'elegant': (false), 'elegant-dark': (true)};
  for (final MapEntry(key: name, value: (dark)) in themes.entries) {
    for (final locale in const ['en', 'zh']) {
      for (final share in const ['files', 'text']) {
        testWidgets('$name $locale $share', (t) async {
          final loadedFonts = await t.runAsync(loadParityFonts);
          if (name == 'brutal' && locale == 'en' && share == 'files') {
            stderr.writeln('FONTS $loadedFonts');
          }
          t.view.physicalSize = const Size(390, 844) * 3;
          t.view.devicePixelRatio = 3;
          addTearDown(t.view.reset);
          final key = GlobalKey();
          final client = _Client();
          final staging = IncomingShareStaging(
            share == 'files' ? _files : _text,
          );
          final raft = raftTheme(dark: dark);
          await t.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: locale == 'zh'
                  ? const Locale('zh', 'CN')
                  : const Locale('en'),
              supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: raft.copyWith(
                textSelectionTheme: raft.textSelectionTheme.copyWith(
                  cursorColor: const Color(0x00000000),
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: RepaintBoundary(
                  key: key,
                  child: RaftTooltipProvider(child: child!),
                ),
              ),
              home: IncomingSharePicker(
                client: client,
                staging: staging,
                servers: [
                  RaftRecord({'id': 'a', 'name': 'Myoland', 'role': 'owner'}),
                  RaftRecord({
                    'id': 'b',
                    'name': 'Raft Community',
                    'role': 'member',
                  }),
                ],
                valid: () => true,
                onContinue: (server, target) async {},
              ),
            ),
          );
          Future<void> shot(String state) async {
            await t.pump(const Duration(milliseconds: 400));
            await t.pump(const Duration(milliseconds: 400));
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await t.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 3);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('$out/$name-$locale-$share-$state.png')
                ..createSync(recursive: true);
              file.writeAsBytesSync(bytes!.buffer.asUint8List());
            });
          }

          for (var i = 0; i < 20; i++) {
            await t.pump(const Duration(milliseconds: 50));
          }
          await shot('initial');
          if (share == 'files' && locale == 'en') {
            await t.enterText(find.byType(TextField), 'de');
            await t.pump(const Duration(milliseconds: 300));
            await shot('search');
            await t.enterText(find.byType(TextField), '');
            await t.pump(const Duration(milliseconds: 300));
            await t.enterText(find.byType(TextField), 'zzzz');
            await t.pump(const Duration(milliseconds: 300));
            await shot('search-empty');
            await t.enterText(find.byType(TextField), '');
            await t.pump(const Duration(milliseconds: 300));
          }
          await t.tap(find.byKey(const ValueKey('incoming-target-d2')));
          for (var i = 0; i < 10; i++) {
            await t.pump(const Duration(milliseconds: 50));
          }
          await shot('selected');
          await t.pumpWidget(const SizedBox());
          await client.dispose();
        });
      }
    }
  }
}
