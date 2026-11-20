// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the phone
// forward page. Ids `components.forward-mobile.page.<state>.<theme>`,
// dispatched on props.state like tool/parity-ext/host/ForwardMobileCases.tsx.
//
// The REAL ForwardComposerPage (phone layout) is mounted full-viewport on a
// WorkspaceController seeded from fixtures/forwardmobile.json; the target
// search answers the fixture route `GET /messages/forward/targets/search`
// (routeSets fm-empty / fm-error / fm-loading). The state is reached with the
// same gestures the React case performs.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/forward_composer_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'thread_composer/fake_workspace.dart';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:forwardmobile'] as Map<String, dynamic>;

/// ParityFakeClient plus the fixture's `{"$pending": true}` (never answers) and
/// `{"$status": N, "$body": {...}}` (fails) route bodies.
class _Client extends ParityFakeClient {
  _Client({required super.user, required super.routes});
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
  }) {
    final answer = routes['$method $path'];
    if (answer is Map && answer['\$pending'] == true) {
      return Completer<Never>().future;
    }
    if (answer is Map && answer['\$status'] != null) {
      return Future<Never>.error(
        RaftApiException(
          '${(answer['\$body'] as Map?)?['error'] ?? 'fixture error'}',
          status: (answer['\$status'] as num).toInt(),
        ),
      );
    }
    return super.request(
      method,
      path,
      data: data,
      query: query,
      authorized: authorized,
      retried: retried,
      cancellation: cancellation,
      onSendProgress: onSendProgress,
      headers: headers,
      acceptServerExit: acceptServerExit,
      receiveTimeout: receiveTimeout,
    );
  }
}

class _Host extends StatefulWidget {
  const _Host({required this.ctx});
  final ParityContext ctx;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final WorkspaceController w = () {
    SharedPreferences.setMockInitialValues({});
    final fx = _fx(widget.ctx);
    final base = ParityThreadFixture(widget.ctx.fixtureData);
    final routeSet =
        (fx['routeSets'] as Map)[widget.ctx.props['routeSet']] as Map? ?? {};
    final client = _Client(
      user: base.authUser,
      routes: {
        ...Map<String, dynamic>.from(fx['routes'] as Map),
        ...Map<String, dynamic>.from(routeSet),
      },
    );
    final controller = WorkspaceController(client)
      ..server = RaftRecord({...base.serverRecord})
      ..channels = [
        for (final c in fx['channels'] as List)
          RaftChannel(Map<String, dynamic>.from(c as Map)),
      ]
      ..dms = [
        for (final c in fx['dms'] as List)
          RaftChannel(Map<String, dynamic>.from(c as Map)),
      ];
    controller.messageDomain.ledger.switchServer('visual-server');
    return controller;
  }();

  @override
  Widget build(BuildContext context) => ForwardComposerPage(
    controller: w,
    messages: [
      for (final m in _fx(widget.ctx)['messages'] as List)
        RaftMessage(Map<String, dynamic>.from(m as Map)),
    ],
  );
}

Widget _build(ParityContext ctx) => ctx.frame(
  width: ctx.width,
  height: ctx.height,
  padding: EdgeInsets.zero,
  child: _Host(ctx: ctx),
);

Future<void> _pump(WidgetTester t, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tapRow(WidgetTester t, String id) async {
  await t.tap(find.byKey(ValueKey('forward-target-$id')));
  await _pump(t, 12);
}

ParityCase _case(String state) => ParityCase(
  widgets: const [
    'raft_flutter:ForwardComposerPage',
    'raft_ui:RaftForwardTargetRow',
    'raft_ui:RaftForwardPageHeader',
  ],
  notes:
      'Extension suite (not official). Real ForwardComposerPage, phone layout.',
  settle: const Duration(milliseconds: 600),
  build: _build,
  interact: (t, ctx) async {
    await _pump(t);
    switch (state) {
      case 'search' || 'search-empty' || 'search-error' || 'search-loading':
        await t.enterText(
          find.byType(TextField).first,
          state == 'search-empty' ? 'zzzz' : 'de',
        );
        await _pump(t, 24);
      case 'multi':
        await t.tap(find.text('Select multiple'));
        await _pump(t, 6);
        await _tapRow(t, 'channel-fm-general');
        await _tapRow(t, 'dm-fm-cindy');
      case 'note':
        await _tapRow(t, 'channel-fm-design');
        await _pump(t, 20);
    }
  },
);

/// Every extension forward-mobile case, keyed by id (3 themes each).
final Map<String, ParityCase> extForwardMobileCases = {
  for (final state in const [
    'targets',
    'search',
    'search-empty',
    'search-error',
    'search-loading',
    'multi',
    'note',
  ])
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.forward-mobile.page.$state.$theme': _case(state),
};
