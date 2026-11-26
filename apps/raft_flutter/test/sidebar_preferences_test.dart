import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/sidebar_preferences_view.dart';
import 'package:raft_ui/raft_ui.dart';

class _SidebarTransport implements HttpClientAdapter {
  int version = 3;
  final writes = <Map>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    dynamic value;
    var status = 200;
    if (o.path == '/auth/login') {
      value = {
        'accessToken': 'fixture',
        'refreshToken': 'fixture',
        'user': {'id': 'alice'},
      };
    } else if (o.path.endsWith('/sidebar-order')) {
      if (o.method == 'PATCH') {
        writes.add(Map.from(o.data));
        version = 4;
        status = 409;
        value = {'error': 'Sidebar changed'};
      } else {
        value = {
          'sectionsVersion': version,
          'customSections': [
            {
              'id': 'sec',
              'name': version == 3 ? 'Original' : 'Other client changed this',
              'sortMode': 'manual',
            },
          ],
          'sectionPlacements': [],
          'channelOrder': [],
          'dmOrder': [],
        };
      }
    } else if (o.path == '/agents') {
      value = [];
    } else {
      value = {'channels': []};
    }
    return ResponseBody.fromString(
      jsonEncode(value),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets(
    'sidebar conflict reloads authoritative list before another write',
    (tester) async {
      final t = _SidebarTransport();
      final client = (await tester.runAsync(() async {
        final c = RaftClient(
          origin: 'https://example.invalid',
          sessionStore: MemorySessionStore(),
          transport: Dio()..httpClientAdapter = t,
        );
        await c.login('fixture', 'fixture');
        return c;
      }))!;
      client.selectServer('s1');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'});
      addTearDown(w.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(body: SidebarPreferencesView(controller: w)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final list = find.byKey(const Key('sidebar-preferences'));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sidebar-custom-section-sec')),
        200,
        scrollable: find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('sidebar-custom-section-sec')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.byKey(const ValueKey('sidebar-custom-section-sec')),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.widgetWithText(RaftButton, 'Save'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(t.writes.single['sectionsVersion'], 3);
      expect(find.textContaining('Review the updated list'), findsOneWidget);
      expect(find.byType(RaftFormDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.textContaining('Other client changed this'),
        findsAtLeastNWidgets(1),
      );
      expect(t.writes.length, 1);
    },
  );

  testWidgets(
    'short reorderable lists stay unclipped and reachable at 2.0x and 3.1x Dynamic Type',
    (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final (platform, scale) in const [
        (TargetPlatform.android, 2.0),
        (TargetPlatform.iOS, 3.1),
      ]) {
        const size = Size(390, 844);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        final t = _SidebarTransport();
        final client = (await tester.runAsync(() async {
          final c = RaftClient(
            origin: 'https://example.invalid',
            sessionStore: MemorySessionStore(),
            transport: Dio()..httpClientAdapter = t,
          );
          await c.login('fixture', 'fixture');
          return c;
        }))!;
        client.selectServer('s1');
        final w = WorkspaceController(client)
          ..server = RaftRecord({'id': 's1', 'role': 'owner'})
          ..dms = [
            RaftChannel({'id': 'dm1', 'name': 'Alex', 'type': 'dm'}),
            RaftChannel({'id': 'dm2', 'name': 'Jordan', 'type': 'dm'}),
          ];
        addTearDown(w.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: platform),
            builder: (context, inner) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(size: size, textScaler: TextScaler.linear(scale)),
              child: RaftTextScaling(child: inner!),
            ),
            home: Scaffold(
              body: SidebarPreferencesView(
                key: ValueKey('prefs-$scale'),
                controller: w,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        final outerScrollable = find
            .descendant(
              of: find.byKey(const Key('sidebar-preferences')),
              matching: find.byType(Scrollable),
            )
            .first;

        for (final key in const [
          ValueKey('sidebar-item-dm2'),
          ValueKey('sidebar-section-system:pinned'),
          ValueKey('sidebar-section-system:channels'),
          ValueKey('sidebar-section-system:dms'),
        ]) {
          await tester.scrollUntilVisible(
            find.byKey(key),
            120,
            scrollable: outerScrollable,
          );
          await tester.ensureVisible(find.byKey(key));
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            find.byKey(key),
            findsOneWidget,
            reason: '$key should be built and reachable at ${scale}x',
          );
          expect(
            find.byKey(key).hitTestable(),
            findsOneWidget,
            reason: '$key should not be clipped at ${scale}x',
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}
