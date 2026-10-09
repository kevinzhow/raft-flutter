// Real WorkspaceView / real client HTTP against the same gated fixture server
// that renders pinned Source App. No real account, transport/socket or seed.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/features/page_layout.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProcessFixtureClient extends RaftClient {
  ProcessFixtureClient(String base, Map<String, dynamic> fixture)
    : super(origin: base, sessionStore: MemorySessionStore()) {
    user = RaftRecord(Map<String, dynamic>.from(fixture['context']['user']));
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'actual Activity target keeps accepted rows while gated context waits',
    (t) async {
      const fixturePath = String.fromEnvironment('RAFT_PROCESS_FIXTURE');
      const outPath = String.fromEnvironment('RAFT_PROCESS_OUT');
      const base = String.fromEnvironment(
        'RAFT_PROCESS_BASE',
        defaultValue: 'http://127.0.0.1:15413',
      );
      const theme = String.fromEnvironment(
        'RAFT_PROCESS_THEME',
        defaultValue: 'brutal',
      );
      const form = String.fromEnvironment(
        'RAFT_PROCESS_FORM',
        defaultValue: 'desktop',
      );
      if (fixturePath.isEmpty || outPath.isEmpty) {
        throw StateError('Process fixture and output required.');
      }
      final out = Directory(outPath);
      if (out.existsSync()) {
        throw StateError('Refusing to overwrite process evidence: $outPath');
      }
      out.createSync(recursive: true);
      final bytes = File(fixturePath).readAsBytesSync();
      final fixture = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final flow = Map<String, dynamic>.from(fixture['process']);
      final fixtureSha = sha256.convert(bytes).toString();
      final size = form == 'mobile'
          ? const Size(390, 844)
          : const Size(1440, 900);
      final client = ProcessFixtureClient(base, fixture);
      final w = WorkspaceController(client, mobileNavigation: form == 'mobile');
      final frames = <Map<String, dynamic>>[];
      final renderFrames = <Map<String, dynamic>>[];
      final renderJobs = <Future<void>>[];
      final renderDir = Directory('$outPath/renderer-frames')..createSync();
      var lastRenderedState = '';
      final inputFiles =
          Process.runSync('git', [
                'ls-files',
                '-z',
                '--',
                'apps/raft_flutter/lib',
                'packages',
                'pubspec.yaml',
                'pubspec.lock',
              ], workingDirectory: '../..').stdout
              .toString()
              .split('\x00')
              .where((path) => path.isNotEmpty)
              .toList()
            ..sort();
      final productBytes = BytesBuilder(copy: false);
      for (final path in inputFiles) {
        productBytes.add(utf8.encode('$path\x00'));
        productBytes.add(File('../../$path').readAsBytesSync());
      }
      final productSha = sha256.convert(productBytes.takeBytes()).toString();
      final stages = <Map<String, dynamic>>[];
      final failures = <String>[];
      void check(dynamic actual, dynamic matcher, String label) {
        try {
          expect(actual, matcher, reason: label);
        } catch (error) {
          failures.add('$label: $error');
        }
      }

      var stageName = 'bootstrap', capturing = true;
      final shotKey = GlobalKey();
      final clock = Stopwatch()..start();
      SharedPreferences.setMockInitialValues({});
      Future<Map<String, dynamic>> state() async {
        final io = HttpClient();
        try {
          final response = await (await io.getUrl(
            Uri.parse('$base/__process/state'),
          )).close();
          return jsonDecode(await utf8.decoder.bind(response).join())
              as Map<String, dynamic>;
        } finally {
          io.close(force: true);
        }
      }

      Future<void> control(String action) async {
        final io = HttpClient();
        try {
          final uri = Uri.parse('$base/__process/$action')
              .replace(queryParameters: {'key': flow['hold'] as String});
          final response = await (await io.getUrl(uri)).close();
          if (response.statusCode != 200) {
            throw StateError('Fixture control failed: $action');
          }
          await response.drain<void>();
        } finally {
          io.close(force: true);
        }
      }

      final initial = await state();
      if (initial['fixtureSha'] != fixtureSha) {
        throw StateError('Source runtime and Flutter input hashes differ.');
      }
      final requestStart =
          (initial['requests'] as List).lastOrNull?['seq'] as int? ?? 0;
      Rect? visibleRect(Finder finder) {
        for (final element in finder.evaluate()) {
          final box = element.findRenderObject();
          if (box is! RenderBox || !box.hasSize || !box.attached) continue;
          RenderObject? ancestor = box;
          var visible = true;
          while (ancestor != null) {
            if (ancestor is RenderOpacity && ancestor.opacity == 0 ||
                ancestor is RenderOffstage && ancestor.offstage) {
              visible = false;
              break;
            }
            ancestor = ancestor.parent;
          }
          if (!visible) continue;
          return box.localToGlobal(Offset.zero) & box.size;
        }
        return null;
      }

      Map<String, double> rect(Rect value) => {
        'x': value.left,
        'y': value.top,
        'width': value.width,
        'height': value.height,
      };
      Map<String, dynamic>? message(String id) {
        final card = visibleRect(find.byKey(ValueKey('message-$id')));
        if (card == null) return null;
        final focus = visibleRect(find.byKey(ValueKey('message-wrapper-$id')));
        final view = visibleRect(
          find.byKey(const ValueKey('chat-list-channel')),
        );
        return {
          'rect': rect(card),
          'focusRect': focus == null ? null : rect(focus),
          'view': view == null ? null : rect(view),
          'inView': view?.overlaps(card) == true,
          'highlighted': w.highlightedMessageId == id,
        };
      }

      Map<String, dynamic> observe() => {
        'frame': frames.length,
        'at': clock.elapsedMicroseconds / 1000,
        'wallTime': DateTime.now().microsecondsSinceEpoch / 1000,
        'stage': stageName,
        'url': '${w.location.uri}',
        'channelId': w.channel?.id,
        'loading': w.channelLoading,
        'pendingChannelId': w.pendingMessageContextChannelId,
        'acceptedIds': w.messages.map((row) => row.id).toList(),
        'highlight': w.highlightedMessageId,
        'older': w.hasMore,
        'newer': w.hasNewer,
        'headers': [
          find.byType(RaftChannelHeader),
          find.byType(RaftPageHeader),
          find.byType(RaftPanelHeaderBar),
        ].where((finder) => visibleRect(finder) != null).length,
        'tabs': visibleRect(find.byType(RaftConversationTabs)) == null ? 0 : 1,
        'composer': visibleRect(find.byType(RaftComposer)) == null ? 0 : 1,
        'accepted': message(flow['acceptedMessageId'] as String),
        'target': message(flow['targetMessageId'] as String),
      };
      void record(Duration _) {
        if (!capturing) return;
        final frame = observe();
        frames.add(frame);
        File('$outPath/frames.jsonl')
            .writeAsStringSync('${jsonEncode(frame)}\n', mode: FileMode.append);
        final signature = jsonEncode(
          Map<String, dynamic>.from(frame)
            ..remove('frame')
            ..remove('at')
            ..remove('stage')
            ..remove('wallTime'),
        );
        if (signature == lastRenderedState) return;
        lastRenderedState = signature;
        final boundary = shotKey.currentContext?.findRenderObject();
        if (boundary is! RenderRepaintBoundary || boundary.debugNeedsPaint) {
          return;
        }
        final index = renderFrames.length;
        final file = '${index.toString().padLeft(4, '0')}.png';
        final entry = <String, dynamic>{
          'index': index,
          'file': file,
          'frame': frame,
        };
        renderFrames.add(entry);
        File('$outPath/renderer-frames.json')
            .writeAsStringSync(jsonEncode(renderFrames));
        // Snapshot this frame's Flutter display-list layer before later state changes.
        renderJobs.add(
          boundary
              .toImage(pixelRatio: 1)
              .then((image) async {
                try {
                  final data = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  File('${renderDir.path}/$file')
                      .writeAsBytesSync(data!.buffer.asUint8List());
                } finally {
                  image.dispose();
                }
              })
              .catchError((Object error) {
                entry['error'] = '$error';
              }),
        );
      }

      // Capture after real layout/paint scheduling, rather than controller final state.
      binding.addPersistentFrameCallback((_) {
        if (capturing) binding.addPostFrameCallback(record);
      });
      Future<void> until(bool Function() ready, String name) async {
        for (var i = 0; i < 150; i++) {
          if (ready()) return;
          await t.pump(const Duration(milliseconds: 50));
        }
        throw StateError('Timed out waiting for $name');
      }

      Future<void> snapshot(String name) async {
        stageName = name;
        await t.pump();
        final frame = observe();
        stages.add({'name': name, 'frame': frame});
        File('$outPath/progress.json').writeAsStringSync(
          jsonEncode({
            'provider': 'Flutter real WorkspaceView / Linux',
            'fixtureSha': fixtureSha,
            'productSha': productSha,
            'sourceHead': initial['sourceHead'],
            'sourceInputSha': initial['sourceInputSha'],
            'runtimeSha': initial['runtimeSha'],
            'theme': theme,
            'form': form,
            'viewport': {'width': size.width, 'height': size.height},
            'stages': stages,
            'failures': failures,
            'rendererFrameCount': renderFrames.length,
            'result': 'STARTED',
          }),
        );
        final boundary =
            shotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$outPath/${stages.length.toString().padLeft(2, '0')}-$name.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      }

      try {
        await t.binding.setSurfaceSize(size);
        final elegant = theme != 'brutal', dark = theme == 'elegant-dark';
        await t.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
            theme: raftTheme(elegant ? RaftFamily.elegant : RaftFamily.brutal),
            darkTheme: raftTheme(RaftFamily.elegant, dark: true),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) => Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: shotKey,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(size: size, devicePixelRatio: 1),
                    child: RaftTooltipProvider(child: child!),
                  ),
                ),
              ),
            ),
            home: WorkspaceView(
              controller: w,
              appearance: RaftAppearance(
                mode: dark ? ThemeMode.dark : ThemeMode.light,
                light: elegant ? RaftFamily.elegant : RaftFamily.brutal,
              ),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        );
        unawaited(w.bootstrap());
        await until(
          () => w.server != null && w.channels.isNotEmpty && !w.loading,
          'authorized bootstrap',
        );
        if (form == 'mobile') {
          w.section = 'home';
          w.notifyListeners();
          await t.pump();
        }
        await t.tap(
          find.byKey(ValueKey('sidebar-channel-${flow['channelId']}')),
        );
        await until(
          () => message(flow['acceptedMessageId'] as String)?['inView'] == true,
          'accepted tail',
        );
        await snapshot('accepted-tail');
        if (form == 'mobile') {
          await t.tap(find.byTooltip('Back').first);
          await t.pump();
          await t.tap(find.byKey(const ValueKey('nav-activity')));
        } else {
          await t.tap(find.byKey(const ValueKey('rail-activity')));
        }
        final activity = find.byKey(
          ValueKey('activity-channel-${flow['channelId']}'),
        );
        await until(
          () => activity.evaluate().isNotEmpty,
          'actual Activity row',
        );
        await snapshot('activity');
        await control('arm');
        await t.tap(activity);
        await until(
          () =>
              w.channelLoading &&
              w.pendingMessageContextChannelId == flow['channelId'],
          'owned pending context',
        );
        await snapshot('pending-context');
        final pending = stages.last['frame'] as Map;
        check(
          (pending['accepted'] as Map?)?['inView'],
          true,
          'pending old accepted row retained',
        );
        check(pending['target'], isNull, 'pending target not exposed');
        check(pending['headers'], greaterThan(0), 'pending header mounted');
        check(pending['tabs'], 1, 'pending tabs mounted');
        check(pending['composer'], 1, 'pending composer mounted');
        final beforeRelease = await state();
        final heldRequest = (beforeRelease['requests'] as List)
            .cast<Map>()
            .where(
              (row) =>
                  row['kind'] == 'request' &&
                  row['key'] == flow['hold'] &&
                  row['seq'] > requestStart,
            )
            .last;
        final earlyReads = (beforeRelease['requests'] as List)
            .cast<Map>()
            .where(
              (row) =>
                  row['kind'] == 'request' &&
                  row['key'] == 'POST /channels/${flow['channelId']}/read' &&
                  row['seq'] > heldRequest['seq'],
            );
        check(
          earlyReads.every(
            (row) => (row['body']?['seq'] ?? 0) <= flow['acceptedSeq'],
          ),
          true,
          'read frontier does not exceed accepted rows before response',
        );
        await control('release');
        await until(
          () => message(flow['targetMessageId'] as String)?['inView'] == true,
          'visible accepted target',
        );
        await snapshot('accepted-context');
        final target = (stages.last['frame'] as Map)['target'] as Map;
        check(target['highlighted'], true, 'accepted target highlighted');
        final focus = target['focusRect'] as Map, view = target['view'] as Map;
        final centerError =
            ((focus['y'] as num) +
                    (focus['height'] as num) / 2 -
                    (view['y'] as num) -
                    (view['height'] as num) / 2)
                .abs();
        check(centerError, lessThanOrEqualTo(1), 'accepted target centered');
        await t.pump(const Duration(milliseconds: 2100));
        await snapshot('highlight-expired');
        check(
          w.highlightedMessageId,
          isNull,
          'highlight expires after two seconds',
        );
      } catch (error, stack) {
        failures.add('$error\n$stack');
        if (shotKey.currentContext != null) await snapshot('failure');
      } finally {
        capturing = false;
        await Future.wait(renderJobs);
        if (renderFrames.any((entry) => entry.containsKey('error'))) {
          failures.add('Renderer capture failed; see renderer-frames.json');
        }
        File('$outPath/renderer-frames.json')
            .writeAsStringSync(jsonEncode(renderFrames));
        final finalState = await state();
        final requests = (finalState['requests'] as List)
            .cast<Map>()
            .where((row) => row['seq'] > requestStart)
            .toList();
        File('$outPath/result.json').writeAsStringSync(
          jsonEncode({
            'provider': 'Flutter real WorkspaceView / Linux',
            'fixtureSha': fixtureSha,
            'productSha': productSha,
            'sourceHead': initial['sourceHead'],
            'sourceInputSha': initial['sourceInputSha'],
            'runtimeSha': initial['runtimeSha'],
            'rendererFrameCount': renderFrames.length,
            'theme': theme,
            'form': form,
            'viewport': {'width': size.width, 'height': size.height},
            'stages': stages,
            'requests': requests,
            'failures': failures,
            'result': failures.isEmpty ? 'PASS' : 'FAIL',
          }),
        );
        await t.pumpWidget(const SizedBox.shrink());
        w.dispose();
        await client.stream.close();
        await t.binding.setSurfaceSize(null);
      }
      expect(
        failures,
        isEmpty,
        reason: 'Process failures preserved in $outPath/result.json',
      );
    },
  );
}
