import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_navigation.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart';

void main() {
  testWidgets(
    'Early Back retains live stretch pages without raster snapshots',
    (tester) async {
      // --enable-impeller exercises the native shader path. The ordinary widget
      // run still checks that both routes paint live widgets without images.
      if (ui.ImageFilter.isShaderFilterSupported) {
        await tester.runAsync(() async {
          await ui.FragmentProgram.fromAsset('shaders/stretch_effect.frag');
        });
      }
      final navigation = WorkspaceNavigation();
      RaftLocation location(RaftRoute route) => RaftLocation.at(
        serverSlug: 'stretch-snapshot-regression',
        route: route,
        entityId: route == RaftRoute.channel ? 'one' : null,
      );
      navigation.bind('isolated', location(RaftRoute.home));
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return MobileWorkspacePages(
                navigation: navigation,
                onBack: () => rebuild(() => backMobilePage(navigation)),
                pageBuilder: (_, pageLocation) => StretchEffect(
                  axis: Axis.vertical,
                  stretchStrength: 0.05,
                  child: ColoredBox(
                    color: Colors.blue,
                    child: Text(pageLocation.toString()),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var cycle = 0; cycle < 20; cycle++) {
        rebuild(() => navigation.navigate(location(RaftRoute.channel)));
        await tester.pump();
        for (var frame = 0; frame < 4; frame++) {
          rebuild(() {});
          await tester.pump(const Duration(milliseconds: 16));
        }
        final route = ModalRoute.of(
          tester.element(find.byType(StretchEffect).last),
        );
        expect(route?.settings, isA<MaterialPage<void>>());
        expect(
          (route!.settings as MaterialPage<void>).allowSnapshotting,
          isFalse,
        );
        expect(find.byType(RawImage), findsNothing);
        rebuild(() => backMobilePage(navigation));
        await tester.pump();
        for (var frame = 0; frame < 32; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(find.byType(RawImage), findsNothing);
          expect(tester.takeException(), isNull);
        }
        expect(navigation.location.route, RaftRoute.home);
        expect(find.text(location(RaftRoute.home).toString()), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Predictive Back cancellation keeps live stretch and later commits once',
    (tester) async {
      if (ui.ImageFilter.isShaderFilterSupported) {
        await tester.runAsync(() async {
          await ui.FragmentProgram.fromAsset('shaders/stretch_effect.frag');
        });
      }
      final navigation = WorkspaceNavigation();
      final home = RaftLocation.at(
        serverSlug: 'stretch-cancel-regression',
        route: RaftRoute.home,
      );
      navigation.bind('isolated', home);
      late StateSetter rebuild;
      var revision = 0;
      var backs = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return MobileWorkspacePages(
                navigation: navigation,
                onBack: () => rebuild(() {
                  backs++;
                  backMobilePage(navigation);
                }),
                pageBuilder: (_, pageLocation) => StretchEffect(
                  axis: Axis.vertical,
                  stretchStrength: 0.05,
                  child: ColoredBox(
                    color: Colors.blue,
                    child: Text('revision $revision'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      Future<void> gesture(String method, [double? progress]) async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/backgesture',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(
              method,
              progress == null
                  ? null
                  : <String, dynamic>{
                      'touchOffset': <double>[100, 300],
                      'progress': progress,
                      'swipeEdge': 0,
                    },
            ),
          ),
          (_) {},
        );
        await tester.pump();
      }

      for (var cycle = 0; cycle < 10; cycle++) {
        rebuild(
          () => navigation.navigate(home.withQuery({'task': 'one:task'})),
        );
        await tester.pumpAndSettle();
        final route = ModalRoute.of(
          tester.element(find.byType(StretchEffect).last),
        )!;
        await gesture('startBackGesture', 0);
        await gesture('updateBackGestureProgress', 0.35);
        expect(route.navigator!.userGestureInProgress, isTrue);
        await gesture('cancelBackGesture');
        await tester.pumpAndSettle();
        expect(navigation.location.query('task'), 'one:task');
        expect(backs, cycle);
        expect(route.navigator!.userGestureInProgress, isFalse);
        rebuild(() => revision++);
        await tester.pumpAndSettle();
        expect(find.text('revision $revision'), findsOneWidget);
        expect(find.byKey(const ValueKey('entering-snapshot')), findsNothing);
        await gesture('startBackGesture', 0);
        await gesture('updateBackGestureProgress', 0.7);
        await gesture('commitBackGesture');
        await tester.pumpAndSettle();
        expect(navigation.location, home);
        expect(backs, cycle + 1);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
