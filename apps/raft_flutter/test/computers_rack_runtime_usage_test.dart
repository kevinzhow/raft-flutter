// The Computers rack's runtime usage columns (Web v1.24 RackRuntimeUsage.tsx,
// rackRuntimeColumns.ts, RackListHeader.tsx, computersRackSort.ts): a column
// per usage provider in catalog order, a cell per computer with its meter, the
// usage card on hover / focus / click, the headings and the toolbar's remaining
// sort, and a read landing in place.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/runtime_account_usage.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_model.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_preferences.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_runtime_usage.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  List<Map<String, dynamic>> machines = [];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/machines')) {
      return {'machines': machines.map(Map<String, dynamic>.from).toList()};
    }
    return path == '/agents' ? <dynamic>[] : <dynamic>[];
  }
}

final _now = DateTime.utc(2026, 11, 16, 12);

Map<String, dynamic> computer(
  String id,
  List<String> runtimes, [
  Map extra = const {},
]) => {
  'id': id,
  'name': id,
  'status': 'online',
  'isComputer': true,
  'computerVersion': '1.0.60',
  'os': 'linux',
  'osRelease': 'Ubuntu 26.04',
  'runtimes': runtimes,
  'userId': 'bob',
  'computerAttachedByCurrentUser': true,
  ...extra,
};

Map<String, dynamic> window(
  double used, {
  String label = 'Current session',
  String status = 'ok',
  String? resetsAt,
  Map<String, dynamic>? scope,
}) => {
  'id': '$label-$used',
  'label': label,
  'status': status,
  'usedRatio': used,
  'resetsAt': ?resetsAt,
  'scope': ?scope,
};

Map<String, dynamic> read(
  String provider,
  List<Map<String, dynamic>> windows, {
  String health = 'ok',
  String state = 'fresh',
}) => {
  'state': state,
  'snapshot': {
    'protocolVersion': 1,
    'provider': provider,
    'collectedAt': '2026-11-16T11:59:00Z',
    'staleAfter': '2026-11-16T12:30:00Z',
    'accounts': [
      {
        'accountKey': 'a' * 64,
        'planLabel': 'Max',
        'health': health,
        'windows': windows,
      },
    ],
  },
};

void main() {
  late _Client c;
  late _Workspace w;
  late RuntimeAccountUsageClient usage;
  // path -> answer (a Future for a read that lands later).
  final answers = <String, Future<dynamic> Function()>{};
  final paths = <String>[];

  String path(String machine, String provider) =>
      '/servers/s/machines/$machine/runtime-account-usage/$provider';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DevicePreferences.load();
    ComputersRackPreferences.instance.resetForTests();
    answers.clear();
    paths.clear();
    c = _Client();
    w = _Workspace(c)
      ..server = RaftRecord({'id': 's', 'role': 'owner', 'slug': 'fixture'});
    usage = RuntimeAccountUsageClient(
      get: (p) {
        paths.add(p);
        final answer = answers[p];
        return answer == null ? Future.value({'state': 'missing'}) : answer();
      },
      post: (p, body) async => <String, dynamic>{},
      now: () => _now,
    );
    w.agentTabCache.putIfAbsent('runtime-account-usage', () => usage);
  });
  tearDown(() async {
    ComputersRackPreferences.instance.resetForTests();
    DevicePreferences.reset();
  });

  Future<void> open(
    WidgetTester t, {
    double width = 1400,
    double height = 900,
    bool phone = false,
    RackView view = RackView.list,
    bool settle = true,
  }) async {
    ComputersRackPreferences.instance.setView(view);
    t.view.physicalSize = Size(width, height);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      w.dispose();
      await c.stream.close();
      await c.dispose();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ComputersRackView(
            controller: w,
            phone: phone,
            onOpenComputer: (_) {},
          ),
        ),
      ),
    );
    // A pending cell's skeleton pulses for ever.
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  /// A test on [p]: the override must be cleared before the framework's
  /// invariant check, so before any tear-down callback.
  void platformTest(
    String name,
    TargetPlatform p,
    Future<void> Function(WidgetTester t) body,
  ) => testWidgets(name, (t) async {
    debugDefaultTargetPlatformOverride = p;
    try {
      await body(t);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  Finder heading(String shortName) => find.byWidgetPredicate(
    (w) => w is RaftRackRuntimeHeading && w.shortName == shortName,
  );
  Finder cell(String machine, String provider) =>
      find.byKey(ValueKey('rack-usage-$machine-$provider'));
  RaftRackUsage data(WidgetTester t, String machine, String provider) => t
      .widget<RaftRackUsageCell>(
        find.descendant(
          of: cell(machine, provider),
          matching: find.byType(RaftRackUsageCell),
        ),
      )
      .usage;
  double top(WidgetTester t, String id) =>
      t.getTopLeft(find.byKey(ValueKey('rack-row-$id'))).dy;

  testWidgets(
    'a column per usage provider in catalog order (Kimi Code and Kimi CLI share one), then Other; an absent runtime is an empty cell',
    (t) async {
      w.machines = [
        computer('one', ['kimi-sdk', 'codex', 'claude', 'opencode']),
        computer('two', ['kimi', 'grok']),
      ];
      answers[path('one', 'claude')] = () async =>
          read('claude', [window(.62)]);
      await open(t);
      final heads = [
        for (final name in ['Claude', 'Codex', 'Grok', 'Kimi'])
          t.getTopLeft(find.text(name).first).dx,
      ];
      expect([...heads]..sort(), heads, reason: 'catalog order, left to right');
      expect(find.text('Kimi'), findsOneWidget, reason: 'one Kimi column');
      expect(find.text('Other'), findsOneWidget);
      // Cells sit at the same x on both rows.
      expect(
        t.getTopLeft(cell('one', 'kimi')).dx,
        t.getTopLeft(heading('Kimi')).dx,
      );
      expect(data(t, 'one', 'claude').text, '62% used');
      expect(data(t, 'one', 'claude').kind, RaftRackUsageKind.value);
      // Installed, nothing to read: "—"; not installed: nothing at all.
      expect(data(t, 'one', 'codex').kind, RaftRackUsageKind.dash);
      expect(find.text('—'), findsWidgets);
      expect(cell('two', 'claude'), findsNothing);
      expect(find.byType(RaftRackOtherCell), findsNWidgets(2));
    },
  );

  testWidgets(
    'values warn from 80%, a used-up limit says when it is back, a model window is a second line',
    (t) async {
      w.machines = [
        computer('one', ['claude', 'codex', 'grok']),
      ];
      answers[path('one', 'claude')] = () async => read('claude', [
        window(.3),
        window(
          .4,
          label: 'Current week (Opus)',
          scope: {'kind': 'model', 'name': 'Opus'},
        ),
      ]);
      answers[path('one', 'codex')] = () async => read('codex', [window(.85)]);
      answers[path('one', 'grok')] = () async => read('grok', [
        window(
          1,
          status: 'limit_reached',
          resetsAt: _now
              .add(const Duration(hours: 3, minutes: 30))
              .toIso8601String(),
        ),
      ]);
      await open(t);
      final claude = data(t, 'one', 'claude');
      expect((claude.text, claude.used, claude.warn), ('30% used', 30, false));
      expect(claude.model?.name, 'Opus');
      expect(claude.model?.text, '40%');
      expect(
        find.descendant(
          of: cell('one', 'claude'),
          matching: find.byKey(const ValueKey('rack-usage-model')),
        ),
        findsOneWidget,
      );
      expect(data(t, 'one', 'codex').warn, isTrue);
      final grok = data(t, 'one', 'grok');
      expect(grok.text, 'Back in 3h');
      expect(grok.warn, isTrue);
      expect(grok.label, contains('Used up · back in 3 hours'));
    },
  );

  testWidgets(
    'whoever may not read usage sees no meters, an offline row none',
    (t) async {
      w.server = RaftRecord({'id': 's', 'role': 'member', 'slug': 'fixture'});
      w.machines = [
        computer('one', ['claude'], {'computerAttachedByCurrentUser': false}),
        computer('gone', ['claude'], {'status': 'offline'}),
      ];
      answers[path('one', 'claude')] = () async => read('claude', [window(.5)]);
      await open(t);
      expect(paths, isEmpty, reason: 'nothing is read for them');
      expect(data(t, 'one', 'claude').kind, RaftRackUsageKind.dash);
      expect(find.byType(RaftRuntimeUsageChip), findsNothing);
      expect(find.text('50% used'), findsNothing);
      await t.tap(find.byKey(const ValueKey('rack-group-offline')));
      await t.pumpAndSettle();
      expect(cell('gone', 'claude'), findsNothing);
    },
  );

  testWidgets(
    'a heading sorts by remaining usage, again reverses it, no value is last either way; the toolbar sort works too',
    (t) async {
      w.machines = [
        computer('a', ['claude']),
        computer('b', ['claude']),
        computer('c', ['claude']),
      ];
      answers[path('a', 'claude')] = () async => read('claude', [window(.9)]);
      answers[path('b', 'claude')] = () async => read('claude', [window(.2)]);
      await open(t);
      await t.tap(find.byKey(const ValueKey('rack-sort-remaining:claude')));
      await t.pumpAndSettle();
      expect(
        ComputersRackPreferences.instance.sort,
        const RackSort('remaining:claude', RackSortDirection.desc),
      );
      // Most remaining first: b (80% left), a (10%), c (nothing to read).
      expect(top(t, 'b'), lessThan(top(t, 'a')));
      expect(top(t, 'a'), lessThan(top(t, 'c')));
      await t.tap(find.byKey(const ValueKey('rack-sort-remaining:claude')));
      await t.pumpAndSettle();
      expect(top(t, 'a'), lessThan(top(t, 'b')));
      expect(top(t, 'b'), lessThan(top(t, 'c')));
      // The toolbar's choice is the same sort.
      ComputersRackPreferences.instance.setSort(null);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('computers-rack-sort')));
      await t.pumpAndSettle();
      await t.tap(find.text('Claude Code remaining'));
      await t.pumpAndSettle();
      expect(ComputersRackPreferences.instance.sort?.key, 'remaining:claude');
      expect(top(t, 'b'), lessThan(top(t, 'a')));
      expect(top(t, 'a'), lessThan(top(t, 'c')));
    },
  );

  testWidgets('rackRemaining reads the tightest account and window', (t) async {
    RuntimeUsageRead r(Map j) => RuntimeUsageRead.fromJson(j);
    expect(
      rackRemaining(r(read('claude', [window(.25), window(.6)]))),
      closeTo(.4, 1e-9),
    );
    expect(
      rackRemaining(r(read('claude', [window(1, status: 'limit_reached')]))),
      0,
    );
    expect(
      rackRemaining(r(read('claude', [window(.1)], health: 'rate_limited'))),
      0,
    );
    expect(
      rackRemaining(r(read('claude', [window(.1)], health: 'needs_login'))),
      isNull,
    );
    expect(rackRemaining(null), isNull);
  });

  platformTest(
    'hover opens the usage card, click pins it, Esc closes it (desktop)',
    TargetPlatform.linux,
    (t) async {
      w.machines = [
        computer('one', ['claude']),
      ];
      answers[path('one', 'claude')] = () async =>
          read('claude', [window(.62)]);
      await open(t);
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(t.getCenter(cell('one', 'claude')));
      await t.pump(const Duration(milliseconds: 210));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('runtime-usage-card')), findsOneWidget);
      await mouse.moveTo(const Offset(5, 5));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const ValueKey('runtime-usage-card')), findsNothing);
      await mouse.moveTo(t.getCenter(cell('one', 'claude')));
      await t.pump(const Duration(milliseconds: 300));
      await mouse.down(t.getCenter(cell('one', 'claude')));
      await mouse.up();
      await mouse.moveTo(const Offset(5, 5));
      await t.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(const ValueKey('runtime-usage-card')),
        findsOneWidget,
        reason: 'pinned',
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('runtime-usage-card')), findsNothing);
    },
  );

  platformTest(
    'keyboard focus on a cell opens the usage card',
    TargetPlatform.linux,
    (t) async {
      w.machines = [
        computer('one', ['claude']),
      ];
      answers[path('one', 'claude')] = () async =>
          read('claude', [window(.62)]);
      await open(t);
      for (var i = 0; i < 80; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump(const Duration(milliseconds: 300));
        if (find
            .byKey(const ValueKey('runtime-usage-card'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      expect(find.byKey(const ValueKey('runtime-usage-card')), findsOneWidget);
    },
  );

  platformTest(
    'phone (Android 390x844): the header and the blocks carry the runtime columns; a tap opens the usage sheet',
    TargetPlatform.android,
    (t) async {
      w.machines = [
        computer('one', ['claude', 'codex', 'opencode']),
      ];
      answers[path('one', 'claude')] = () async =>
          read('claude', [window(.62)]);
      await open(t, width: 390, height: 844, phone: true);
      expect(find.byType(RaftRackPhoneRuntimeHeader), findsOneWidget);
      expect(
        t.getTopLeft(cell('one', 'claude')).dx,
        t.getTopLeft(heading('Claude')).dx,
      );
      expect(data(t, 'one', 'claude').text, '62% used');
      await t.tap(cell('one', 'claude'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('runtime-usage-sheet')), findsOneWidget);
    },
  );

  testWidgets('cards: a usage line per provider the computer has', (t) async {
    w.machines = [
      computer('one', ['claude', 'codex']),
    ];
    answers[path('one', 'claude')] = () async => read('claude', [window(.62)]);
    await open(t, width: 900, view: RackView.cards);
    expect(data(t, 'one', 'claude').text, '62% used');
    expect(
      t
          .widget<RaftRackUsageCell>(
            find.descendant(
              of: cell('one', 'claude'),
              matching: find.byType(RaftRackUsageCell),
            ),
          )
          .line,
      isTrue,
    );
    expect(cell('one', 'codex'), findsOneWidget);
  });

  testWidgets(
    'a read landing updates its cell in place and leaves the other rows untouched',
    (t) async {
      w.machines = [
        computer('one', ['claude']),
        computer('two', ['claude']),
      ];
      final landing = Completer<dynamic>();
      answers[path('one', 'claude')] = () => landing.future;
      answers[path('two', 'claude')] = () async => read('claude', [window(.1)]);
      await open(t, settle: false);
      expect(data(t, 'one', 'claude').kind, RaftRackUsageKind.pending);
      expect(data(t, 'two', 'claude').text, '10% used');
      final rows = find.byType(RaftRackRow);
      final other = t.widget<RaftRackRow>(rows.last);
      final first = t.widget<RaftRackRow>(rows.first);
      landing.complete(read('claude', [window(.62)]));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(data(t, 'one', 'claude').text, '62% used');
      expect(identical(t.widget<RaftRackRow>(rows.last), other), isTrue);
      expect(identical(t.widget<RaftRackRow>(rows.first), first), isTrue);
      // A card refreshing the cache (the usage client's listener) updates it too.
      usage.storeSnapshot(
        's',
        'one',
        'claude',
        read('claude', [window(.83)])['snapshot'] as Map<String, dynamic>,
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(data(t, 'one', 'claude').text, '83% used');
      expect(data(t, 'one', 'claude').warn, isTrue);
      expect(identical(t.widget<RaftRackRow>(rows.last), other), isTrue);
    },
  );
}
