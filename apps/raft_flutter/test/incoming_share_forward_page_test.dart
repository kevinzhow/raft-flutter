// The incoming-share picker is the Web phone forward page in share mode:
// same header / search / rows / bottom bar as the forward page, the header
// and preview show what is shared, one target, Continue hands off unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/incoming_share_targets.dart';
import 'package:raft_flutter/features/incoming_share_picker.dart';
import 'package:raft_flutter/platform/incoming_share_staging.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';
import 'flutter_test_config.dart' show leakDebt;

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://example.test', sessionStore: MemorySessionStore());
  final calls = <String>[];
  bool empty = false;
  @override
  Future<dynamic> getForServer(
    String server,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    calls.add('$server:$path');
    if (empty) return [];
    if (path == '/channels/dm') {
      return [
        {
          'id': 'dm1',
          'name': 'Grok',
          'type': 'dm',
          'joined': true,
          'peerType': 'agent',
          'peerDisplayName': 'Grok',
        },
      ];
    }
    if (path == '/channels') {
      return [
        {'id': 'c1', 'name': 'general', 'type': 'channel', 'joined': true},
        {'id': 'c2', 'name': 'lobby', 'type': 'channel', 'joined': false},
      ];
    }
    return [];
  }
}

const _both = IncomingShare(
  token: 't',
  text: 'Release gates are green',
  files: [
    IncomingSharedFile(
      'content://fixture/a',
      'IMG_2041.jpg',
      'image/jpeg',
      2400000,
    ),
    IncomingSharedFile(
      'content://fixture/b',
      'review.pdf',
      'application/pdf',
      5100000,
    ),
  ],
);

Future<_Client> _pump(
  WidgetTester t, {
  IncomingShare share = _both,
  bool dark = false,
  Locale locale = const Locale('en'),
  int servers = 2,
  List<RaftRecord>? serverRows,
  Future<void> Function(RaftRecord, IncomingShareTarget)? onContinue,
  bool empty = false,
}) async {
  t.view.physicalSize = const Size(390, 844) * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final client = _Client()..empty = empty;
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: raftTheme(dark: dark),
      home: IncomingSharePicker(
        client: client,
        staging: IncomingShareStaging(share),
        servers:
            serverRows ??
            [
              for (var i = 0; i < servers; i++)
                RaftRecord({
                  'id': 'srv$i',
                  'name': 'Server $i',
                  'role': 'owner',
                }),
            ],
        valid: () => true,
        onContinue: onContinue ?? (server, target) async {},
      ),
    ),
  );
  await t.pumpAndSettle();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    await client.dispose();
  });
  return client;
}

void main() {
  // Leak debt (share flow): see docs/development.md, Leak tracking.
  leakDebt(const ['IncomingShareStaging', 'ValueNotifier<RaftTransferProgress?>']);
  for (final (name, dark) in [
    ('light', false),
    ('dark', true),
  ]) {
    group(name, () {
      testWidgets(
        'targets page: header describes the share; rows are plain, no checkbox or chevron',
        (t) async {
          await _pump(t, dark: dark);
          expect(find.text('Select destinations'), findsOneWidget);
          expect(find.text('Sharing 2 files and text'), findsOneWidget);
          // Not the forward copy: no "selected from", no message count.
          expect(find.textContaining('selected'), findsNothing);
          expect(find.text('Forward'), findsNothing);
          // The Web label of the list; the old "Server" caption is a semantic
          // label only.
          expect(find.text('Recent'), findsOneWidget);
          expect(find.text('Server'), findsNothing);
          expect(find.text('Server 0'), findsOneWidget);
          expect(find.text('Server 1'), findsOneWidget);
          expect(find.byType(RaftCheckbox), findsNothing);
          expect(find.byIcon(Icons.chevron_right), findsNothing);
          // Channels show the bare name (Web targetPickerLabel), DMs @name.
          expect(find.text('general'), findsOneWidget);
          expect(find.text('@Grok'), findsOneWidget);
          expect(find.text('Not joined'), findsOneWidget);
          // No selection bar before a choice is made.
          expect(
            find.byKey(const Key('incoming-share-continue')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'choosing a row opens "Add shared content" with the preview; Continue hands off once',
        (t) async {
          final received = <String>[];
          final c = await _pump(
            t,
            dark: dark,
            onContinue: (server, target) async =>
                received.add('${server.id}:${target.key}'),
          );
          await t.tap(find.byKey(const ValueKey('incoming-target-c1')));
          await t.pumpAndSettle();
          expect(find.text('Add shared content'), findsOneWidget);
          expect(find.text('Add to #general'), findsOneWidget);
          expect(find.text('Shared content'), findsOneWidget);
          expect(find.text('2 files'), findsOneWidget);
          expect(find.text('Release gates are green'), findsOneWidget);
          expect(find.text('IMG_2041.jpg'), findsOneWidget);
          expect(find.text('review.pdf'), findsOneWidget);
          expect(received, isEmpty);
          await t.tap(find.byKey(const Key('incoming-share-continue')));
          await t.pumpAndSettle();
          expect(received, ['srv0:c1']);
          expect(
            c.calls.where((s) => s.contains('upload') || s.contains('forward')),
            isEmpty,
          );
        },
      );
    });
  }

  testWidgets('text-only share: summary and snippet, no file hint', (t) async {
    await _pump(
      t,
      share: const IncomingShare(token: 't', text: 'Just a note'),
      servers: 1,
    );
    expect(find.text('Sharing text'), findsOneWidget);
    // One server: Web's page has no server switch, so no chip row.
    expect(find.byType(RaftForwardServerChips), findsNothing);
    await t.tap(find.byKey(const ValueKey('incoming-target-c1')));
    await t.pumpAndSettle();
    expect(find.text('Just a note'), findsOneWidget);
    expect(
      find.text('Files are added to the composer. Review them before sending.'),
      findsNothing,
    );
  });

  testWidgets('files-only share: file count in the summary and the hint', (
    t,
  ) async {
    await _pump(
      t,
      share: const IncomingShare(
        token: 't',
        files: [
          IncomingSharedFile('content://f/a', 'one.pdf', 'application/pdf', 10),
        ],
      ),
    );
    expect(find.text('Sharing 1 file'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('incoming-target-c1')));
    await t.pumpAndSettle();
    expect(find.text('1 file'), findsOneWidget);
    expect(
      find.text('Files are added to the composer. Review them before sending.'),
      findsOneWidget,
    );
  });

  testWidgets('search: no match shows the Web empty state', (t) async {
    await _pump(t);
    await t.enterText(find.byType(TextField), 'zzzz');
    await t.pumpAndSettle();
    expect(find.text('No destinations match your search.'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'gen');
    await t.pumpAndSettle();
    expect(find.text('general'), findsOneWidget);
    expect(find.text('@Grok'), findsNothing);
  });

  testWidgets('empty directory: a message instead of a blank page', (t) async {
    await _pump(t, empty: true);
    expect(find.text('No destinations available.'), findsOneWidget);
    expect(find.byType(RaftForwardTargetRow), findsNothing);
  });

  testWidgets('zh: every string of both pages is Chinese', (t) async {
    await _pump(t, locale: const Locale('zh', 'CN'));
    expect(find.text('选择目标'), findsOneWidget);
    expect(find.text('正在分享 2 个文件和文字'), findsOneWidget);
    expect(find.text('最近'), findsOneWidget);
    expect(find.text('Server'), findsNothing);
    expect(find.text('未加入'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('incoming-target-c1')));
    await t.pumpAndSettle();
    expect(find.text('添加分享内容'), findsOneWidget);
    expect(find.text('添加到 #general'), findsOneWidget);
    expect(find.text('分享内容'), findsOneWidget);
    expect(find.text('2 个文件'), findsOneWidget);
    expect(find.text('继续'), findsOneWidget);
    expect(find.text('文件将添加到消息输入框，请检查后再发送。'), findsOneWidget);
    for (final english in [
      'Add shared content',
      'Shared content',
      'Continue',
      'Sharing 2 files and text',
      'Select destinations',
      'Recent',
    ]) {
      expect(find.text(english), findsNothing, reason: english);
    }
  });
}
