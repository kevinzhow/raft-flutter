import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/announcement_host.dart';
import 'package:raft_ui/raft_ui.dart';

typedef Route = FutureOr<dynamic> Function(
  String method,
  String path,
  Map<String, dynamic>? query,
);

class FixtureClient extends RaftClient {
  FixtureClient(this.route)
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'u1', 'name': 'Kevin', 'displayName': 'Kevin'});
    selectServer('s1');
  }
  Route route;
  final requests = <String>[];
  final _events = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => _events.stream;
  @override
  void connect() {}
  @override
  Future<void> dispose() async => _events.close();
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
    requests.add('$method $path${query == null ? '' : ' $query'}');
    return route(method, path, query);
  }
}

Map<String, dynamic> announcement(String id, {int pages = 2}) => {
  'id': id,
  'title': 'What is new $id',
  'pages': [
    for (var i = 0; i < pages; i++)
      {
        'title': i == 0 ? 'Welcome' : null,
        'body': 'Page ${i + 1} body with `code` and **bold**.',
      },
  ],
  'publishedAt': '2026-10-01T00:00:00.000Z',
  'startsAt': '2026-10-01T00:00:00.000Z',
  'endsAt': null,
  'locale': 'en',
};

class Fixture {
  Fixture({this.projection = const {'phase': null}}) {
    client = FixtureClient(handle);
    w = WorkspaceController(client);
    addTearDown(w.dispose);
    final server = RaftRecord({
      'id': 's1',
      'slug': 'visual',
      'name': 'Visual',
      'role': 'owner',
    });
    w
      ..servers = [server]
      ..server = server;
  }
  late final FixtureClient client;
  late final WorkspaceController w;
  Map<String, dynamic>? projection;
  bool failProjection = false, failDismiss = false;
  List<Map<String, dynamic>> active = [announcement('a1')];

  FutureOr<dynamic> handle(
    String method,
    String path,
    Map<String, dynamic>? query,
  ) {
    if (method == 'GET' && path == '/announcements/active') {
      return {'announcements': active};
    }
    if (method == 'GET' && path == '/servers/s1/setup-projection') {
      if (failProjection) throw const RaftApiException('unavailable');
      return projection;
    }
    if (method == 'POST' && path.startsWith('/announcements/')) {
      if (failDismiss) throw const RaftApiException('failed');
      return {'ok': true};
    }
    return null;
  }

  int count(String request) =>
      client.requests.where((r) => r.startsWith(request)).length;
}

Widget app(Fixture f, {String deployment = 'production', Widget? home}) =>
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      // The error notice is the app-wide toast (Web `toast.error`).
      builder: (context, child) => RaftToastHost(child: child!),
      home: AnnouncementHost(
        controller: f.w,
        deployment: deployment,
        child: home ?? const Scaffold(body: Text('workspace')),
      ),
    );

Future<void> settle(WidgetTester t) async {
  // The dialog route fades in and out over 150 ms.
  for (var i = 0; i < 14; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

final modal = find.byKey(const ValueKey('announcement-modal'));

void main() {
  testWidgets(
    'entry read shows the oldest row, page one only; Got it dismisses',
    (t) async {
      final f = Fixture();
      await t.pumpWidget(app(f));
      await settle(t);
      expect(f.count('GET /announcements/active'), 1);
      expect(modal, findsOneWidget);
      expect(find.text('What is new a1'), findsOneWidget);
      expect(find.text('Latest updates'), findsOneWidget);
      // The first page only: no page title, no second page, no pager.
      expect(find.textContaining('Page 1 body'), findsOneWidget);
      expect(find.textContaining('Page 2 body'), findsNothing);
      expect(find.text('Welcome'), findsNothing);
      expect(find.byKey(const ValueKey('announcement-next')), findsNothing);
      expect(find.byKey(const ValueKey('announcement-dismiss')), findsNothing);
      // Showing it never writes.
      expect(f.count('POST'), 0);
      await t.tap(find.byKey(const ValueKey('announcement-ok')));
      await settle(t);
      expect(modal, findsNothing);
      expect(f.client.requests.where((r) => r.startsWith('POST')), [
        'POST /announcements/a1/dismiss',
      ]);
      // Foreground return: a fresh read, the row is gone locally.
      f.active = [];
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
      expect(f.count('GET /announcements/active'), 2);
      expect(modal, findsNothing);
    },
  );

  testWidgets('Enter dismisses once, whatever holds focus', (t) async {
    final f = Fixture();
    await t.pumpWidget(app(f));
    await settle(t);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(t);
    expect(modal, findsNothing);
    expect(f.count('POST /announcements/a1/dismiss'), 1);
  });

  testWidgets(
    'X, Escape and the backdrop all record the dismissal (closing counts as read)',
    (t) async {
      final f = Fixture();
      await t.pumpWidget(app(f));
      await settle(t);
      await t.tap(find.byType(RaftDialogClose));
      await settle(t);
      expect(modal, findsNothing);
      expect(f.count('POST /announcements/a1/dismiss'), 1);

      f.active = [announcement('a2')];
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
      expect(find.text('What is new a2'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(t);
      expect(modal, findsNothing);
      expect(f.count('POST /announcements/a2/dismiss'), 1);

      f.active = [announcement('a3')];
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
      // A press inside the card does not close it; one on the backdrop does.
      await t.tap(find.text('What is new a3'));
      await settle(t);
      expect(modal, findsOneWidget);
      await t.tapAt(const Offset(4, 4));
      await settle(t);
      expect(modal, findsNothing);
      expect(f.count('POST /announcements/a3/dismiss'), 1);
    },
  );

  testWidgets(
    'suppressed while onboarding is in progress, and for the rest of the session after it',
    (t) async {
      final f = Fixture(
        projection: {'phase': 'computer_runtime', 'blocksChat': true},
      );
      await t.pumpWidget(app(f));
      await settle(t);
      expect(f.count('GET /servers/s1/setup-projection'), 1);
      expect(f.w.announcements.current?.id, 'a1');
      expect(modal, findsNothing);
      // Setup completes: still suppressed (next entry rule).
      f.w.announcementGate.report('s1', {'phase': 'complete'});
      await settle(t);
      expect(modal, findsNothing);
    },
  );

  testWidgets('a failed first setup read counts as blocked', (t) async {
    final f = Fixture()..failProjection = true;
    await t.pumpWidget(app(f));
    await settle(t);
    expect(modal, findsNothing);
  });

  testWidgets('a mounted setup gate owns the reading (no extra read)', (
    t,
  ) async {
    final f = Fixture();
    f.w.announcementGate.attach('s1');
    await t.pumpWidget(app(f));
    await settle(t);
    expect(f.count('GET /servers/s1/setup-projection'), 0);
    expect(modal, findsNothing);
    f.w.announcementGate.report('s1', {'phase': null});
    await settle(t);
    expect(modal, findsOneWidget);
  });

  testWidgets('a failed read-complete write raises one error notice', (
    t,
  ) async {
    final f = Fixture()..failDismiss = true;
    f.active = [announcement('a1', pages: 1)];
    await t.pumpWidget(app(f));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('announcement-ok')));
    await settle(t);
    expect(modal, findsNothing);
    expect(
      find.text(
        "Couldn't save that you've read this announcement. It'll show again next time.",
      ),
      findsOneWidget,
    );
    expect(f.w.announcements.writeFailedIds, ['a1']);
  });

  testWidgets('presents above a dialog already open', (t) async {
    final f = Fixture();
    f.w.announcementGate.attach('s1');
    await t.pumpWidget(app(f));
    await settle(t);
    final context = t.element(find.text('workspace'));
    unawaited(
      showRaftModal<void>(
        context,
        builder: (_) => const Center(child: Text('open dialog')),
      ),
    );
    await settle(t);
    f.w.announcementGate.report('s1', {'phase': null});
    await settle(t);
    expect(modal, findsOneWidget);
    expect(ModalRoute.of(t.element(modal))!.isCurrent, isTrue);
    await t.tap(find.byType(RaftDialogClose));
    await settle(t);
    expect(find.text('open dialog'), findsOneWidget);
  });

  testWidgets('slockdev shows the popup, then confirms it like OK', (t) async {
    final f = Fixture();
    await t.pumpWidget(app(f, deployment: 'slockdev'));
    await settle(t);
    expect(modal, findsNothing);
    expect(f.count('POST /announcements/a1/dismiss'), 1);
  });

  testWidgets('a row with no pages renders nothing', (t) async {
    final f = Fixture();
    f.active = [announcement('a1', pages: 0)];
    await t.pumpWidget(app(f));
    await settle(t);
    expect(f.w.announcements.current?.id, 'a1');
    expect(modal, findsNothing);
  });
}
