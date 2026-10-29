import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/server_setup_gate.dart';
import 'package:raft_ui/raft_ui.dart';

import 'fallback_text_style.dart';

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  late Future<dynamic> Function(String path) getFn;
  late Future<dynamic> Function(String path, dynamic data) postFn;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      getFn(path);
  @override
  Future<dynamic> post(String path, {dynamic data}) => postFn(path, data);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

const _deferred = {
  'phase': 'deferred',
  'surface': 'computer_runtime',
  'blocksChat': false,
  'allowedExits': <String>[],
  'sideEffectState': {'transitions': 'enabled', 'completion': 'enabled'},
};

/// The setup step animates (spinners); a few frames are enough.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late _Client c;
  late WorkspaceController w;
  late Map<String, dynamic> projection;
  final posts = <String>[];
  Completer<dynamic>? heldStart;
  Object? startError;

  setUp(() {
    posts.clear();
    heldStart = null;
    startError = null;
    projection = Map<String, dynamic>.from(_deferred);
    c = _Client()..user = RaftRecord({'id': 'owner'});
    c.selectServer('s');
    w = WorkspaceController(c)
      ..server = RaftRecord({'id': 's', 'slug': 'raft', 'role': 'owner'});
    c.getFn = (path) async {
      if (path == '/servers/s/setup-projection') return projection;
      if (path == '/servers/s/machines') return {'machines': <dynamic>[]};
      return <dynamic>[];
    };
    c.postFn = (path, data) async {
      posts.add('$path ${data is Map ? data['action'] : ''}');
      if (heldStart != null) return heldStart!.future;
      if (startError != null) throw startError!;
      return projection = {
        'phase': 'in_progress',
        'surface': 'computer_runtime',
        'blocksChat': true,
        'allowedExits': <String>[],
        'sideEffectState': {'transitions': 'enabled', 'completion': 'enabled'},
      };
    };
  });
  tearDown(() async {
    w.dispose();
    await c.stream.close();
    await c.dispose();
  });

  Future<void> host(
    WidgetTester t, {
    Locale locale = const Locale('en'),
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 800);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: ServerSetupGate(
            controller: w,
            child: const Center(child: Text('Conversation')),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'a deferred setup keeps the conversation and floats the resume bar',
    (t) async {
      await host(t);
      expect(find.text('Conversation'), findsOneWidget);
      expect(find.text('Your server is not set up yet.'), findsOneWidget);
      expect(find.text('Resume Setup'), findsOneWidget);
      // At the bottom of the area, 16px from the edge, never wider than 560.
      final bar = t.getRect(
        find.byKey(const ValueKey('server-setup-resume-bar')),
      );
      expect(bar.bottom, 800 - 16);
      expect(bar.left, 16);
      expectNoFallbackTextStyle('setup resume bar');
    },
  );

  testWidgets('no bar when setup is complete, not started or blocking', (
    t,
  ) async {
    projection = {...projection, 'phase': 'complete', 'surface': 'complete'};
    await host(t);
    expect(find.byType(RaftSetupResumeBar), findsNothing);
    expect(find.text('Conversation'), findsOneWidget);
  });

  testWidgets(
    'Resume Setup starts setup and the setup step replaces the conversation',
    (t) async {
      await host(t);
      await t.tap(find.text('Resume Setup'));
      await _settle(t);
      expect(posts, ['/servers/s/setup-transition start']);
      expect(find.byType(RaftSetupResumeBar), findsNothing);
      expect(find.text('Conversation'), findsNothing);
      expectNoFallbackTextStyle('setup step');
    },
  );

  testWidgets(
    'the button reads Opening… and is disabled while the request runs',
    (t) async {
      heldStart = Completer<dynamic>();
      await host(t);
      await t.tap(find.text('Resume Setup'));
      await t.pump();
      expect(find.text('Opening…'), findsOneWidget);
      expect(
        t
            .widget<RaftButton>(
              find.byKey(const ValueKey('server-setup-resume')),
            )
            .onPressed,
        isNull,
      );
      await t.tap(find.text('Opening…'), warnIfMissed: false);
      expect(posts, hasLength(1));
      heldStart!.complete({
        'phase': 'in_progress',
        'surface': 'computer_runtime',
        'blocksChat': true,
      });
      await _settle(t);
      expect(find.text('Conversation'), findsNothing);
    },
  );

  testWidgets('a failed start keeps the bar and the conversation', (t) async {
    startError = const RaftApiException('Setup is locked', status: 409);
    await host(t);
    await t.tap(find.text('Resume Setup'));
    await t.pumpAndSettle();
    expect(find.text('Resume Setup'), findsOneWidget);
    expect(find.text('Conversation'), findsOneWidget);
    expect(
      t
          .widget<RaftButton>(find.byKey(const ValueKey('server-setup-resume')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Chinese copy comes from the Web catalog', (t) async {
    await host(t, locale: const Locale('zh', 'CN'));
    expect(find.text('你的服务器尚未设置完成。'), findsOneWidget);
    expect(find.text('继续设置'), findsOneWidget);
  });
}
