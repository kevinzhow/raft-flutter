import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/system_notification_center.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Web v1.21.12 NotificationTrigger: the rail bell is a rail icon (brightening on
// hover) whose unread dot is the shared AppRailItemAttention composite; the
// mobile navbar keeps its 16px muted bell and Status dot.
class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    serverId = 's';
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/servers/s/machines') {
      return {
        'machines': [
          {'id': 'm', 'name': 'Box', 'status': 'offline', 'isComputer': false},
        ],
      };
    }
    if (path == '/agents') return [];
    if (path == '/product-feedback/tickets') return {'unread_total': 0};
    return [];
  }

  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<void> dispose() async {
    await stream.close();
    await super.dispose();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<WorkspaceController> mount(
    WidgetTester t, {
    required bool mobile,
    bool dark = false,
    bool unread = true,
  }) async {
    final client = _Client();
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'});
    await t.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      w.dispose();
      await client.dispose();
      await t.binding.setSurfaceSize(null);
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(
          dark: dark,
          platform: mobile ? TargetPlatform.android : TargetPlatform.linux,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SystemNotificationBell(
              controller: w,
              onBilling: () {},
              mobile: mobile,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    return w;
  }

  RaftIcon bell(WidgetTester t) => t
      .widgetList<RaftIcon>(
        find.descendant(
          of: find.byType(RaftMobileNotificationButton),
          matching: find.byType(RaftIcon),
        ),
      )
      .first;

  testWidgets(
    'rail bell: the rail attention composite replaces the one-off dot',
    (t) async {
      // A machine offline in a scope that can see machines puts one entry up.
      await mount(t, mobile: false);
      expect(find.byType(RaftRailAttention), findsOneWidget);
      expect(find.byType(RaftNotificationAttention), findsNothing);
    },
  );

  testWidgets('mobile bell keeps its Status dot', (t) async {
    await mount(t, mobile: true);
    expect(find.byType(RaftNotificationAttention), findsOneWidget);
    expect(find.byType(RaftRailAttention), findsNothing);
  });

  Color? renderedBellColor(WidgetTester t) {
    final icon = find.byWidget(bell(t));
    return bell(t).color ?? IconTheme.of(t.element(icon)).color;
  }

  for (final (dark, size) in [(false, 20.0), (true, 20.0)]) {
    testWidgets('[$dark] rail bell glyph is the rail icon size', (t) async {
      await mount(t, mobile: false, dark: dark);
      expect(bell(t).size, size);
    });
  }

  testWidgets('mobile bell keeps its 22px navbar glyph', (t) async {
    await mount(t, mobile: true);
    final tokens = RaftTokens.of(
      t.element(find.byType(RaftMobileNotificationButton)),
    );
    expect(bell(t).size, 22);
    expect(renderedBellColor(t), tokens.ui.stickerInk);
  });
}
