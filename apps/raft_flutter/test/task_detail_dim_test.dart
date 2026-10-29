import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'task_surface_test.dart' show modernTask, taskRoutes, flush;
import 'workspace_source_location_contract_test.dart' show pageFixture;
import 'support/app_services_fixture.dart';

/// Regression: the task modal painted its box shadow in a *foreground*
/// decoration, i.e. over the whole surface. The summed alpha (about 13% black
/// for elegant light) greyed the header, properties, replies and composer, so
/// the modal looked dimmed under its own backdrop. The surface must show the
/// theme panel colour exactly, with the scrim only behind it.
void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'task modal surface paints the theme panel colour, no scrim above it ${dark ? 'dark' : 'light'}',
      (t) async {
        t.view.physicalSize = const Size(1280, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, api) = await pageFixture(t, section: 'tasks');
        taskRoutes(api, modernTask);
        api.routes['GET /tasks/channel/c1'] = (_) => {
          'tasks': [modernTask],
        };
        api.routes['GET /channels/c1/threads/task-parent'] = (_) => {
          'threadChannelId': 'task-thread',
        };
        w.navigation.navigateTask(
          w.location.withQuery({'task': 'c1:task-parent'}),
          kind: RaftNavigationKind.replace,
        );
        final root = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: root,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: raftTheme(dark: dark),
              home: withAppServices(
                WorkspaceView(
                  controller: w,
                  appearance: RaftAppearance(
                    mode: dark ? ThemeMode.dark : ThemeMode.light,
                  ),
                  onAppearance: (_) async {},
                  onLogout: () async {},
                ),
              ),
            ),
          ),
        );
        await flush(t);
        expect(find.byType(SourceTaskSurface), findsOneWidget);
        expect(find.byType(RaftModalBackdrop), findsOneWidget);
        final tokens = RaftTokens.of(t.element(find.byType(SourceTaskSurface)));

        final boundary =
            root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = (await t.runAsync(boundary.toImage))!;
        addTearDown(image.dispose);
        final bytes = (await t.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        Color pixel(Offset p) {
          final i = (p.dy.round() * image.width + p.dx.round()) * 4;
          return Color.fromARGB(
            bytes.getUint8(i + 3),
            bytes.getUint8(i),
            bytes.getUint8(i + 1),
            bytes.getUint8(i + 2),
          );
        }

        void expectPanel(String where, Offset p) {
          final got = pixel(p), want = tokens.panel;
          int c(double v) => (v * 255).round();
          expect(
            [c(got.r), c(got.g), c(got.b)],
            [c(want.r), c(want.g), c(want.b)],
            reason: '$where at $p must be the panel colour, not dimmed',
          );
        }

        final modal = t.getRect(
          find.byKey(const ValueKey('task-thread-modal')),
        );
        final bar = t.getRect(find.byKey(const ValueKey('task-modal-bar')));
        // Empty header strip and a corner just inside the frame.
        expectPanel('header bar', Offset(bar.center.dx + 120, bar.center.dy));
        expectPanel('inner corner', modal.topLeft + const Offset(3, 3));
        expectPanel(
          'header bar near close',
          Offset(bar.left + 8, bar.bottom - 8),
        );
        // Nothing may paint a shadow/scrim over the surface: no foreground
        // decoration with box shadows inside the surface.
        final overPainters = find
            .descendant(
              of: find.byType(RaftTaskSurface),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is DecoratedBox &&
                    w.position == DecorationPosition.foreground &&
                    ((w.decoration as BoxDecoration).boxShadow?.isNotEmpty ??
                        false),
              ),
            )
            .evaluate();
        expect(overPainters, isEmpty);
        // The backdrop is behind the modal: the page outside it is dimmed.
        final outside = pixel(const Offset(1240, 800));
        expect(
          outside.computeLuminance(),
          lessThan(tokens.panel.computeLuminance()),
          reason: 'backdrop dims the page behind the modal',
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
