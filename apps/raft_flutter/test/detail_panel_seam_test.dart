// The seam between a list and the detail opened beside it, as painted pixels.
//
// Web v1.24 draws one 1px `--line-seam` line there in every host: the profile
// panel's own left border (raft-ui `Panel edge="attached"`: `border-l
// border-line-seam`; index.css re-adds it beside a neighbour, ProfilePanel.tsx
// 304-385), the task slot's (TaskContentSlot), and the Search / Activity list
// column's right border (ShellSidebarColumn `ownBorder`: `border-r
// border-line-seam`). Its ColumnResizeHandle shows a 1px foreground-muted line
// on hover (SEAM_CLASS) that lies on that border.
//
// The earlier tests of these hosts measured rects and widths, so a border that
// was laid out but painted under the panel's opaque Scaffold (or not drawn at
// all) passed. These read the rendered image.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_master_detail.dart';
import 'package:raft_flutter/features/member_profile_view.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_context_transition_test.dart' show row;
import 'support/app_services_fixture.dart';
import 'support/panel_edge_registry.dart';
import 'task_content_slot_test.dart' show v2Task, card, settle;
import 'task_surface_test.dart' show taskRoutes, flush;
import 'workspace_source_location_contract_test.dart' show pageFixture;

const _shot = Key('seam-shot');

class SeamShot {
  SeamShot(this.data, this.width);
  final ByteData data;
  final int width;
  Color at(int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  }
}

Future<SeamShot> shoot(WidgetTester t) async {
  final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  return (await t.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final shot = SeamShot(data!, image.width);
    image.dispose();
    return shot;
  }))!;
}

bool same(Color a, Color b) =>
    ((a.r - b.r) * 255).abs() <= 2 &&
    ((a.g - b.g) * 255).abs() <= 2 &&
    ((a.b - b.b) * 255).abs() <= 2;

String hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';

/// The 1px [line] is painted at column [x] over the background beside it
/// ([inward] is the side the line's own box lies on: +1 for a detail's left
/// border, -1 for a list's right border), on every row of [ys], and only there:
/// the pixels either side are the background.
void expectSeam(
  SeamShot s,
  int x,
  Iterable<int> ys,
  Color line, {
  int inward = 1,
  required String host,
}) {
  for (final y in ys) {
    final bg = s.at(x + 4 * inward, y);
    final want = Color.alphaBlend(line, bg);
    final got = s.at(x, y);
    expect(
      same(got, want),
      isTrue,
      reason: '$host: seam at ($x, $y) is ${hex(got)}, want ${hex(want)}',
    );
    expect(
      same(s.at(x + inward, y), bg),
      isTrue,
      reason: '$host: the seam is 1px (x ${x + inward} is the background)',
    );
    final outside = s.at(x - 4 * inward, y);
    expect(
      same(s.at(x - inward, y), outside),
      isTrue,
      reason:
          '$host: one line, not two (x ${x - inward} is '
          '${hex(s.at(x - inward, y))}, its column ${hex(outside)})',
    );
  }
}

/// Hovering the handle lights a 1px foreground-muted line on the seam pixel
/// (Web SEAM_CLASS), and nowhere beside it.
Future<void> expectHoverLine(
  WidgetTester t,
  Finder handle,
  int x,
  int y,
  RaftTokens tokens, {
  required String host,
}) async {
  final before = await shoot(t);
  final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(t.getCenter(handle));
  await t.pump();
  final after = await shoot(t);
  final want = Color.alphaBlend(
    tokens.colors['foreground-muted']!,
    before.at(x, y),
  );
  expect(
    same(after.at(x, y), want),
    isTrue,
    reason:
        '$host: hover line at ($x, $y) is ${hex(after.at(x, y))}, '
        'want ${hex(want)}',
  );
  for (final dx in const [-1, 1]) {
    expect(
      same(after.at(x + dx, y), before.at(x + dx, y)),
      isTrue,
      reason: '$host: the hover line is on the seam, not beside it (x+$dx)',
    );
  }
  await mouse.moveTo(Offset.zero);
  await t.pump();
}

Widget frame(Widget child, bool dark) => RepaintBoundary(
  key: _shot,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: raftTheme(dark: dark),
    home: child,
  ),
);

RaftTokens tokensOf(WidgetTester t, Finder at) =>
    RaftTokens.of(t.element(at.first));

Future<void> mountWorkspace(
  WidgetTester t,
  WorkspaceController w,
  bool dark,
) async {
  await t.pumpWidget(
    frame(
      withAppServices(
        WorkspaceView(
          controller: w,
          appearance: RaftAppearance(),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
      ),
      dark,
    ),
  );
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  tearDown(DevicePreferences.reset);
  const window = Size(1280, 800);
  void size(WidgetTester t) {
    t.view.physicalSize = window;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  test('every registered detail beside a list has a pixel case here', () {
    expect(
      {
        for (final s in panelEdgeSurfaces)
          if (s.pixels) s.id,
      },
      {'list-profile-detail', 'computers-rack-panel', 'tasks-route-slot'},
      reason: 'a new pixels surface needs its case in this file',
    );
  });

  for (final dark in const [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('$mode: Computers rack, the computer panel draws its seam', (
      t,
    ) async {
      size(t);
      await t.pumpWidget(
        frame(
          Scaffold(
            body: RaftRackSidePanelLayout(
              width: 380,
              onResize: (_) {},
              rack: const SizedBox.expand(),
              // FleetDetail is a Scaffold: an opaque panel.
              panel: const Scaffold(body: SizedBox.expand()),
            ),
          ),
          dark,
        ),
      );
      final panel = find.byKey(const ValueKey('computers-rack-side-panel'));
      final x = t.getRect(panel).left.round();
      final tokens = tokensOf(t, panel);
      expectSeam(
        await shoot(t),
        x,
        const [100, 400, 700],
        tokens.ui.lineSeam,
        host: 'rack',
      );
      await expectHoverLine(
        t,
        find.byKey(const ValueKey('rack-side-panel-resize-handle')),
        x,
        400,
        tokens,
        host: 'rack',
      );
    });

    testWidgets('$mode: Search / Activity, the list column draws its seam', (
      t,
    ) async {
      size(t);
      await t.pumpWidget(
        frame(
          const Scaffold(
            body: DesktopMasterDetail(
              masterEdge: true,
              master: SizedBox.expand(),
              detail: Scaffold(body: SizedBox.expand()),
            ),
          ),
          dark,
        ),
      );
      final list = find.byKey(const Key('desktop-master-panel'));
      // ShellSidebarColumn `border-r`: the list's own last pixel.
      final x = t.getRect(list).right.round() - 1;
      final tokens = tokensOf(t, list);
      expectSeam(
        await shoot(t),
        x,
        const [100, 400, 700],
        tokens.ui.lineSeam,
        inward: -1,
        host: 'search/activity',
      );
      await expectHoverLine(
        t,
        find.byKey(const Key('desktop-master-resize-handle')),
        x,
        400,
        tokens,
        host: 'search/activity',
      );
    });

    for (final section in const ['members', 'agents']) {
      testWidgets('$mode: $section, the profile beside the list draws its '
          'seam', (t) async {
        size(t);
        final (w, api) = await pageFixture(t, section: section);
        addTearDown(() async {
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 3));
        });
        final prefs = await t.runAsync(SharedPreferences.getInstance);
        DevicePreferences.adopt(prefs!);
        api.routes['GET /agents'] = (_) => [
          if (section == 'agents')
            {'id': 'a1', 'name': 'Public agent', 'status': 'active'},
        ];
        api.routes['GET /servers/s1/members'] = (_) => [
          {'userId': 'h1', 'name': 'Public human', 'role': 'member'},
        ];
        api.routes['GET /servers/s1/members/h1/profile'] = (_) => {
          'userId': 'h1',
          'name': 'Public human',
        };
        await mountWorkspace(t, w, dark);
        await t.tap(
          find
              .text(section == 'members' ? 'Public human' : 'Public agent')
              .first,
        );
        for (var i = 0; i < 12; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        if (section == 'members') {
          expect(find.byType(MemberProfileView), findsOneWidget);
        }
        final detail = find.byKey(const Key('desktop-content-detail'));
        final x = t.getRect(detail).left.round();
        final tokens = tokensOf(t, detail);
        expectSeam(
          await shoot(t),
          x,
          const [300, 500, 700],
          tokens.ui.lineSeam,
          host: section,
        );
        await expectHoverLine(
          t,
          find.byKey(const Key('desktop-master-resize-handle')),
          x,
          500,
          tokens,
          host: section,
        );
      });
    }

    testWidgets('$mode: Tasks, the task slot beside the list draws its seam', (
      t,
    ) async {
      size(t);
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!'${details.exception}'.contains('overflowed')) {
          previous?.call(details);
        }
      };
      addTearDown(() => FlutterError.onError = previous);
      final (w, api) = await pageFixture(t, section: 'tasks');
      taskRoutes(api, v2Task);
      api.routes['GET /tasks/channel/c1'] = (_) => {
        'tasks': [v2Task],
      };
      api.routes['GET /messages/channel/task-conv'] = (_) => {
        'messages': <dynamic>[],
      };
      api.routes['POST /channels/task-conv/read'] = (_) => {};
      api.routes['GET /tasks/task-1'] = (_) => {'task': v2Task};
      TaskV2ConversationsFlag.of(w).markEnabled();
      w.messageDomain.ledger.ingest([
        row('accepted-main', 'c1', 1),
      ], expectedGeneration: w.messageDomain.ledger.generation);
      await mountWorkspace(t, w, dark);
      await flush(t);
      await t.tap(card);
      await settle(t);
      expect(find.byType(SourceTaskSurface), findsOneWidget);
      final slot = find.byKey(const ValueKey('task-content-slot'));
      final x = t.getRect(slot).left.round();
      final tokens = tokensOf(t, slot);
      expectSeam(
        await shoot(t),
        x,
        const [300, 500, 700],
        tokens.ui.lineSeam,
        host: 'tasks',
      );
      await expectHoverLine(
        t,
        find.byKey(const ValueKey('tasks-route-detail-resize')),
        x,
        500,
        tokens,
        host: 'tasks',
      );
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });
  }
}
