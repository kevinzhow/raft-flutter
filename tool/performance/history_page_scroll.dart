// macOS Profile probe: continuous scrolling while real history pages land.
// Uses the shared perf-lab fixture, production RaftChatView and normal binding.
// Build with a separate app identity and a new RAFT_HISTORY_SCROLL_OUT path.
// Synthetic data only; native input delivery and disk-cache writes excluded.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' show FramePhase;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../apps/raft_flutter/integration_test/perf_lab/fixtures.dart';

const output = String.fromEnvironment('RAFT_HISTORY_SCROLL_OUT');
const revision = String.fromEnvironment('RAFT_HISTORY_SCROLL_REVISION');
Object? semanticsOwner;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kProfileMode || output.isEmpty || File(output).existsSync()) {
    throw StateError('Requires Profile mode and a new output path');
  }
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  await initializeSourceTimeFormatting();
  runApp(
    MaterialApp(
      theme: raftTheme().copyWith(platform: TargetPlatform.macOS),
      home: _HistoryLab(),
    ),
  );
}

class _HistoryLab extends StatefulWidget {
  @override
  State<_HistoryLab> createState() => _HistoryLabState();
}

class _HistoryLabState extends State<_HistoryLab> {
  final pane = GlobalKey();
  WorkspaceController? workspace;
  final frames = <Map<String, int>>[];
  final rounds = <Map<String, dynamic>>[];
  final pageArrivals = <int>[];
  bool busy = false, collecting = false;
  String status = 'Ready';
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(timings);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 1), () async {
        if (!mounted) return;
        semanticsOwner = WidgetsBinding.instance.ensureSemantics();
        await nextFrame();
        if (mounted) run();
      });
    });
  }

  void timings(List<FrameTiming> values) {
    if (!collecting) return;
    for (final f in values) {
      frames.add({
        'startUs': f.timestampInMicroseconds(FramePhase.buildStart),
        'ui': f.buildDuration.inMicroseconds,
        'r': f.rasterDuration.inMicroseconds,
      });
    }
  }

  Future<void> nextFrame() => WidgetsBinding.instance.endOfFrame;
  ScrollPosition position() {
    ScrollPosition? found;
    void visit(Element e) {
      if (e case StatefulElement(state: final ScrollableState state)) {
        if (state.position is RaftTimelinePosition) {
          found ??= state.position;
        }
      }
      e.visitChildren(visit);
    }

    visit(pane.currentContext! as Element);
    return found!;
  }

  Future<void> run() async {
    if (busy || rounds.isNotEmpty) return;
    setState(() {
      busy = true;
      status = 'Running';
    });
    final images = await LabImages.start();
    try {
      for (final kind in ['mixed']) {
        for (var round = 0; round < 2; round++) {
          final retired = workspace;
          setState(() => workspace = null);
          await nextFrame();
          retired?.dispose();
          final c = LabChannel(
            'history-$kind-$round',
            kind == 'plain' ? List.filled(2000, 'plain') : mixKinds(2000),
            pageDelay: const Duration(milliseconds: 250),
            firstPage: 50,
          );
          // Warm glyphs/grammars, but never reuse the previous round's body
          // parse cache for newly fetched history.
          for (final row in c.rows) {
            row['content'] =
                '${row['content']}\n\nHistory body namespace $round';
          }
          final (w, api, _) = await labWorkspace([c], images);
          final pageRoute = 'GET /messages/channel/${c.id}';
          final serve = api.routes[pageRoute]!;
          api.routes[pageRoute] = (request) async {
            final result = await serve(request);
            if (request.queryParameters['before'] != null)
              pageArrivals.add(developer.Timeline.now);
            return result;
          };
          await w.selectChannel(c.record, navigate: false);
          for (var page = 0; page < 7; page++) {
            await w.messageDomain.older();
          }
          setState(() => workspace = w);
          await nextFrame();
          await nextFrame();
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          final p = position();
          var settled = false;
          for (var attempt = 0; attempt < 12; attempt++) {
            p.jumpTo(p.minScrollExtent + p.viewportDimension * 1.5);
            await nextFrame();
            final before = p.pixels - p.minScrollExtent;
            if (before >= 0 && before <= p.viewportDimension * 2) {
              settled = true;
              break;
            }
          }
          if (!settled) throw StateError('Initial estimates did not settle');
          final from = p.pixels, served = c.olderPagesServed;
          final initialGeometry = [
            p.pixels,
            p.minScrollExtent,
            p.maxScrollExtent,
          ];
          final rowsBefore = w.messageDomain.messages.length;
          final start = developer.Timeline.now;
          collecting = true;
          final drag = p.drag(
            DragStartDetails(globalPosition: const Offset(24, 400)),
            () {},
          );
          final clock = Stopwatch()..start();
          var dragUpdates = 0, boundaryWaitFrames = 0;
          final forcedPage = Future<void>.delayed(
            const Duration(milliseconds: 250),
            () => w.messageDomain.older(),
          );
          try {
            while (dragUpdates < 960) {
              await nextFrame();
              if (clock.elapsed.inSeconds > 60)
                throw StateError(
                  'Scroll exceeded 60 seconds: updates=$dragUpdates, wait=$boundaryWaitFrames, px=${p.pixels}, min=${p.minScrollExtent}, max=${p.maxScrollExtent}, loading=${w.messageDomain.state.loadingOlder}',
                );
              if (!identical(position(), p))
                throw StateError('Timeline replaced during drag');
              final now = clock.elapsedMicroseconds;
              const delta = 10.0;
              if (p.pixels < p.minScrollExtent - 80) {
                boundaryWaitFrames++;
                continue;
              }
              if (!p.pixels.isFinite || p.pixels.abs() > 1e7) {
                throw StateError('Invalid scroll geometry: ${p.pixels}');
              }
              dragUpdates++;
              drag.update(
                DragUpdateDetails(
                  delta: Offset(0, delta),
                  primaryDelta: delta,
                  globalPosition: const Offset(24, 400),
                  sourceTimeStamp: Duration(microseconds: now),
                ),
              );
            }
          } finally {
            drag.end(DragEndDetails(primaryVelocity: 0));
          }
          await forcedPage;
          final end = developer.Timeline.now;
          await Future<void>.delayed(const Duration(milliseconds: 300));
          collecting = false;
          if (c.olderPagesServed <= served ||
              dragUpdates < 120 ||
              (p.pixels - from).abs() < 1000) {
            throw StateError(
              'No continuous scrolling + page: pages=${c.olderPagesServed - served}, updates=$dragUpdates, moved=${p.pixels - from}',
            );
          }
          rounds.add({
            'kind': kind,
            'round': round,
            'warmup': round == 0,
            'startUs': start,
            'endUs': end,
            'pages': c.olderPagesServed - served,
            'pageArrivalUs': pageArrivals
                .where((at) => at >= start && at <= end)
                .toList(),
            'rowsBefore': rowsBefore,
            'rowsAfter': w.messageDomain.messages.length,
            'movedPx': p.pixels - from,
            'semantics':
                WidgetsBinding.instance.platformDispatcher.semanticsEnabled,
            'positionType': '${p.runtimeType}',
            'initialGeometry': initialGeometry,
            'dragUpdates': dragUpdates,
            'boundaryWaitFrames': boundaryWaitFrames,
          });
        }
      }
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      await File(output).writeAsString(
        jsonEncode({
          'revision': revision,
          'mode': 'profile',
          'binding': 'normal WidgetsFlutterBinding',
          'input':
              'production ScrollPosition.drag; native event delivery excluded',
          'fixture': '$fixtureVersion / per-round body namespace',
          'semanticsMode': 'enabled after first frame',
          'semanticsOwnerHeld': semanticsOwner != null,
          'semantics':
              WidgetsBinding.instance.platformDispatcher.semanticsEnabled,
          'physicalSize': [view.physicalSize.width, view.physicalSize.height],
          'dpr': view.devicePixelRatio,
          'refreshRate': view.display.refreshRate,
          'rounds': rounds,
          'frames': frames,
          'rss': ProcessInfo.currentRss,
        }),
      );
      setState(() => status = 'Complete');
    } catch (e, st) {
      await File(output).writeAsString(
        jsonEncode({
          'error': '$e',
          'stack': '$st',
          'rounds': rounds,
          'frames': frames,
        }),
      );
      setState(() => status = 'Failed: $e');
    } finally {
      collecting = false;
      busy = false;
      await images.server.close(force: true);
    }
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(timings);
    workspace?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Row(
          children: [
            TextButton(
              onPressed: busy ? null : run,
              child: const Text('Run history probe'),
            ),
            Text('$revision / $status'),
          ],
        ),
        Expanded(
          child: workspace == null
              ? const SizedBox()
              : SizedBox(
                  width: 900,
                  child: RaftChatView(key: pane, controller: workspace!),
                ),
        ),
      ],
    ),
  );
}
