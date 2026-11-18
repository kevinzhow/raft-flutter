import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/app_link_models.dart';
import 'package:raft_flutter/features/app_link_store.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'app_link_preview_test.dart' show appLinkTestAnswer;
import 'message_presentation_test.dart' show MessageAdapter, fixture;

const _origin = 'https://example.invalid';
const _url = 'https://tickets.example.org/123';
const _operation = '9cddde84-f69f-4d9e-8de7-b0df120ea843';
final _message = RaftMessage({'id': 'm1', 'channelId': 'c1', 'content': _url});

void _routes(MessageAdapter transport) {
  transport.routes['POST /feature-flags/evaluate'] = (_) => {
    'evaluations': [
      {'key': 'interactive_link_cards', 'enabled': true},
    ],
  };
  transport.routes['POST /messages/m1/link-cards/read'] = (_) =>
      appLinkTestAnswer(confirm: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'old cache opens quietly and an accepted action survives restart',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'raft-link-restart-',
      );
      addTearDown(() => folder.delete(recursive: true));
      final database = File('${folder.path}/workspace.sqlite');
      final old = DriftWorkspaceCache(NativeDatabase(database));
      await old.write(_origin, 'alice', 's1', 'channels', '', {'channels': []});
      await old.close();

      final firstDb = DriftWorkspaceCache(NativeDatabase(database));
      final (first, firstTransport) = await fixture('member', cache: firstDb);
      _routes(firstTransport);
      firstTransport.routes['POST /link-cards/prepare'] = (_) => {
        'prepared_action_id': 'b8ef58e6-a811-4a30-b0a8-6fb24fc7e71a',
        'prepared_digest': 'a' * 64,
        'description': {'title': 'Close ticket?'},
      };
      firstTransport.routes['POST /link-cards/execute'] = (_) => {
        'operation_id': _operation,
        'state': 'accepted',
      };
      final view = AppLinkStore.of(first).message(_message, 'en-US')..attach();
      try {
        expect(await view.read(), true);
        expect(view.operation(_url).busy, false);
        expect(view.operation(_url).notice, isNull);
        final preview = view.links[_url]! as AppLinkPreview;
        final button = preview.buttons.entries.single;
        await view
            .operation(_url)
            .press(preview, button.key, button.value, (_) async => true);
        expect(view.operation(_url).phase, AppLinkPhase.pending);
        await first.deviceStore.settled;
        final saved = await first.deviceStore.read('link-card-operations', '');
        expect(saved, [containsPair('operation_id', _operation)]);
      } finally {
        view.detach();
        first.dispose();
        await firstDb.close();
      }

      final secondDb = DriftWorkspaceCache(NativeDatabase(database));
      final (second, secondTransport) = await fixture(
        'member',
        cache: secondDb,
      );
      addTearDown(secondDb.close);
      addTearDown(second.dispose);
      _routes(secondTransport);
      final status = Completer<void>();
      secondTransport.routes['POST /link-cards/status'] = (request) {
        expect(request.data['operation_id'], _operation);
        status.complete();
        return {
          'operation_id': _operation,
          'state': 'done',
          'receipt_revision': 2,
        };
      };
      final resumed = AppLinkStore.of(second).message(_message, 'en-US')
        ..attach();
      addTearDown(resumed.detach);
      await status.future.timeout(const Duration(seconds: 3));
      expect(
        secondTransport.calls.where(
          (call) => call.path == '/link-cards/execute',
        ),
        isEmpty,
      );
      expect(await secondDb.read(_origin, 'alice', 's1', 'channels', ''), {
        'channels': [],
      });
    },
  );
}
