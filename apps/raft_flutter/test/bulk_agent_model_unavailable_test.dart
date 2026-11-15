// Web 1.24 BulkChangeModelDialog.tsx:311-327: models the Computer's runtime
// listed as disabled come after the usable ones, greyed and not selectable,
// under "Not available on this computer", with the runtime's own reason.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/computer_detail_view.dart';
import 'package:raft_flutter/features/management_support.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bulk_agent_model_test.dart' show ModelClient, machine;

class _Client extends ModelClient {
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    if (path.endsWith('/runtime-models/codex')) {
      return {
        'kind': 'live',
        'value': {
          'models': [
            {'id': 'gpt-6-astra', 'label': 'GPT-6-Astra'},
          ],
          'default': 'gpt-6-astra',
          'unavailable': [
            {
              'id': 'gpt-locked',
              'label': 'GPT Locked',
              'reason': 'Plan does not include it',
            },
          ],
        },
      };
    }
    return super.request(
      method,
      path,
      data: data,
      query: query,
      authorized: authorized,
      retried: retried,
    );
  }
}

void main() {
  for (final (name, size, platform) in <(String, Size, TargetPlatform)>[
    ('fold portrait', const Size(856, 944), TargetPlatform.android),
    ('fold landscape', const Size(944, 856), TargetPlatform.android),
    ('narrow desktop', const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets(
      '$name: unavailable models are a disabled group with the reason',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final client = _Client();
        final w = WorkspaceController(client)
          ..server = RaftRecord({'id': 's', 'role': 'owner'});
        rememberServerFlag(
          w,
          'bulk_change_model_web_v0',
          true,
          pageIdentity(w),
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          w.dispose();
          await client.stream.close();
          await client.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: platform),
            home: Scaffold(
              body: ComputerDetailPanel(controller: w, machine: machine),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final key in [
          'computer-agents-select',
          'computer-agent-a1',
          'computer-bulk-change-model',
        ]) {
          final f = find.byKey(ValueKey(key));
          await tester.ensureVisible(f);
          await tester.tap(f);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const ValueKey('bulk-model-model')));
        await tester.pumpAndSettle();
        expect(find.text('Not available on this computer'), findsOneWidget);
        expect(find.text('Plan does not include it'), findsOneWidget);
        // The disabled row never becomes the value.
        await tester.tap(find.text('GPT Locked'));
        await tester.pumpAndSettle();
        expect(find.text('Not available on this computer'), findsOneWidget);
        await tester.tap(find.text('GPT-6-Astra').last);
        await tester.pumpAndSettle();
        expect(find.text('GPT Locked'), findsNothing);
      },
    );
  }
}
