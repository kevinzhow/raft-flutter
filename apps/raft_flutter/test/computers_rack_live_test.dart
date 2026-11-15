// Live acceptance for the Computers rack: a real client against the local
// Raft stack (skipped unless RAFT_LIVE_STACK_FIXTURE names the private fixture
// file). It reads the three seeded states (online, offline, old version) the
// way the app does and, with RAFT_LIVE_EVIDENCE_DIR, writes the rack as a PNG
// for the Web | Flutter comparison. Secrets are never printed.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'mobile_computer_navigation_test.dart' show loadComputerPageFonts;

void main() {
  final fixturePath = Platform.environment['RAFT_LIVE_STACK_FIXTURE'];
  final origin =
      Platform.environment['RAFT_LIVE_STACK_ORIGIN'] ??
      'http://localhost:13022';
  setUpAll(() => HttpOverrides.global = null);

  testWidgets('the rack lists the seeded online, offline and old computers', (
    t,
  ) async {
    final fixture = jsonDecode(File(fixturePath!).readAsStringSync()) as Map;
    final account = (fixture['accounts'] as Map)['owner'] as Map;
    final client = RaftClient(
      origin: origin,
      sessionStore: MemorySessionStore(),
    );
    addTearDown(client.dispose);
    await t.runAsync(() async {
      await client.login('${account['email']}', '${account['password']}');
      client.selectServer('${(fixture['server'] as Map)['id']}');
    });
    final w = WorkspaceController(client);
    addTearDown(w.dispose);
    await t.runAsync(() async {
      final servers = await client.servers();
      w.server = servers.firstWhere(
        (s) => s.id == (fixture['server'] as Map)['id'],
      );
      await w.entityDirectory.preload();
    });
    final rows = w.entityDirectory.rows(WorkspaceEntityKind.computers);
    String? status(String name) =>
        rows.where((m) => m['name'] == name).firstOrNull?['status'] as String?;
    expect(status('studio-online'), 'online');
    expect(status('rack-offline'), 'offline');
    expect(status('old-builder'), 'online');

    await loadComputerPageFonts(t);
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final boundary = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RepaintBoundary(
            key: boundary,
            child: ComputersRackView(controller: w, onOpenComputer: (_) {}),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    for (final name in ['studio-online', 'old-builder']) {
      expect(find.textContaining(name), findsWidgets);
    }
    final dir = Platform.environment['RAFT_LIVE_EVIDENCE_DIR'];
    if (dir != null) {
      await t.runAsync(() async {
        final object =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await object.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$dir/flutter-rack.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await t.pumpWidget(const SizedBox.shrink());
    w.entityDirectory.dispose();
  }, skip: fixturePath == null);
}
