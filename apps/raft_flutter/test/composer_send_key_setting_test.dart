import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/composer_send_key_setting.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'user-1'});
  }

  final requests = <(String, Object?)>[];
  bool reject = false;

  @override
  Future<dynamic> patch(String path, {dynamic data}) async {
    requests.add((path, data));
    if (reject) throw StateError('save failed');
    return data;
  }

  @override
  Future<void> replaceUser(Map<String, dynamic> json) async {
    user = RaftRecord(json);
  }
}

void main() {
  testWidgets('saves the account field and rolls back a rejected choice', (
    tester,
  ) async {
    final client = _Client();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: false).copyWith(platform: TargetPlatform.linux),
        home: Scaffold(body: ComposerSendKeySetting(client: client)),
      ),
    );
    await tester.tap(find.text('Ctrl+Enter'));
    await tester.pumpAndSettle();
    expect(client.requests.single.$1, '/auth/me');
    expect(client.requests.single.$2, {'composerSendKey': 'mod_enter'});
    expect(accountComposerSendKey(client), RaftComposerSendKey.modifiedEnter);

    client.reject = true;
    await tester.tap(find.text('Enter'));
    await tester.pumpAndSettle();
    expect(client.requests.last.$2, {'composerSendKey': 'enter'});
    expect(accountComposerSendKey(client), RaftComposerSendKey.modifiedEnter);
    expect(find.byType(RaftSaveStatus), findsOneWidget);
    expect(
      tester
          .widget<RaftSegmentedControl<RaftComposerSendKey>>(
            find.byType(RaftSegmentedControl<RaftComposerSendKey>),
          )
          .value,
      RaftComposerSendKey.modifiedEnter,
    );
  });
}
