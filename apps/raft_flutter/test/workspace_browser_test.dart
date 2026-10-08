import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/workspace_browser.dart';

import 'message_presentation_test.dart' show fixture, host;

void main() {
  test('workspace browser needs an explicit frontend bound to this API', () {
    const api = 'http://localhost:13041', web = 'http://localhost:15213';
    expect(workspaceBrowserOrigin(api), isNull);
    expect(
      workspaceBrowserOrigin(api, frontend: web, api: api).toString(),
      web,
    );
    for (final value in [
      'http://remote.example.com',
      'https://user:password@example.com',
      'https://example.com/?token=secret',
      'https://example.com/#fragment',
      'https://example.com/path',
    ]) {
      expect(workspaceBrowserOrigin(api, frontend: value, api: api), isNull);
    }
    expect(
      workspaceBrowserOrigin(api, frontend: web, api: 'http://localhost:99'),
      isNull,
    );
  });

  testWidgets(
    'workspace browser uses fresh membership slug and no session URL',
    (tester) async {
      final (w, adapter) = (await tester.runAsync(() => fixture('owner')))!;
      adapter.routes['GET /servers'] = (_) => [
        {'id': 's2', 'slug': 'fresh-slug'},
      ];
      Uri? opened;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => openWorkspaceInBrowser(
                context,
                w,
                RaftRecord({'id': 's2', 'slug': 'stale-slug'}),
                frontendOrigin: Uri.parse('https://web.example.com'),
                open: (uri) async {
                  opened = uri;
                  return true;
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(opened.toString(), 'https://web.example.com/s/fresh-slug');
      expect(opened!.query, isEmpty);
      expect(w.client.serverId, 's1');
      await tester.pumpWidget(const SizedBox());
      w.dispose();
      w.client.dispose();
    },
  );

  testWidgets(
    'late membership receipt after role change cannot launch browser',
    (tester) async {
      final (w, adapter) = (await tester.runAsync(() => fixture('owner')))!;
      final response = Completer<Object>();
      adapter.routes['GET /servers'] = (_) => response.future;
      var opened = false;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => openWorkspaceInBrowser(
                context,
                w,
                RaftRecord({'id': 's2'}),
                frontendOrigin: Uri.parse('https://web.example.com'),
                open: (_) async {
                  opened = true;
                  return true;
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      w.server = RaftRecord({'id': 's1', 'role': 'guest'});
      response.complete([
        {'id': 's2', 'slug': 'fresh'},
      ]);
      await tester.pumpAndSettle();
      expect(opened, isFalse);
      await tester.pumpWidget(const SizedBox());
      w.dispose();
      w.client.dispose();
    },
  );
}
