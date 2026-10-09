// Desktop real-screen parity captures (provider `android`, source
// `flutter-linux`) for docs/desktop-cases.json.
//
// The REAL WorkspaceView is bootstrapped through WorkspaceController.bootstrap()
// against a fixture RaftClient whose every request() is answered from the
// same JSON file the Web runtime serves (tool/desktop-parity/desktop-fixture.json).
// Navigation uses user-level taps/hover on real keys. Output follows the
// official visual-testing provider layout:
//   $RAFT_DESKTOP_OUT/android/<caseId>.png + <caseId>.metadata.json
//
// Run (from apps/raft_flutter): tool/desktop-parity/capture-flutter.sh
// Measurement harness only - no product code is changed by it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/system_notification_center.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fixture client: identical lookup rule to web-runtime.mjs `lookup()`.
class DesktopFixtureClient extends RaftClient {
  DesktopFixtureClient(this.fixture, {this.holds = const []})
    : super(
        origin: 'https://desktop-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord(Map<String, dynamic>.from(fixture['context']['user']));
    selectServer(fixture['context']['server']['id'] as String);
  }
  final Map<String, dynamic> fixture;
  final List<String> holds;
  final misses = <String>{};
  final served = <String>[];
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final _never = Completer<dynamic>();

  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}

  static dynamic lookup(
    Map<String, dynamic> routes,
    String method,
    String path,
    Map<String, dynamic>? query,
  ) {
    final prefix = '$method $path?';
    dynamic best;
    var bestCount = -1;
    for (final entry in routes.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final params = Uri.splitQueryString(entry.key.substring(prefix.length));
      final ok = params.entries.every(
        (p) => query != null && '${query[p.key]}' == p.value,
      );
      if (ok && params.length > bestCount) {
        best = entry.value;
        bestCount = params.length;
      }
    }
    return best ?? routes['$method $path'];
  }

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
    final q = query == null || query.isEmpty
        ? ''
        : '?${Uri(queryParameters: query.map((k, v) => MapEntry(k, '$v'))).query}';
    if (holds.contains('$method $path')) {
      served.add('HELD $method $path$q');
      return _never.future;
    }
    var answer = lookup(
      Map<String, dynamic>.from(fixture['routes']),
      method,
      path,
      query,
    );
    if (answer is Map && answer.containsKey('__status')) {
      final status = answer['__status'] as int;
      if (status >= 400) {
        served.add('$method $path$q -> $status');
        throw RaftApiException('fixture status $status', status: status);
      }
      answer = answer['body'];
    }
    if (answer == null) {
      misses.add('$method $path$q');
      // Same neutral defaults the prior primary-route fixture used.
      if (path.endsWith('/setup-projection')) {
        return {'phase': 'complete', 'surface': 'none', 'blocksChat': false};
      }
      if (method != 'GET') return <String, dynamic>{};
      return <dynamic>[];
    }
    served.add('$method $path$q');
    // Deep copy so the app never mutates the shared fixture.
    return jsonDecode(jsonEncode(answer));
  }
}

const _themes = {
  'brutal': (RaftFamily.brutal, false),
  'elegant-light': (RaftFamily.elegant, false),
  'elegant-dark': (RaftFamily.elegant, true),
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('desktop real-screen parity captures', (t) async {
    const fixturePath = String.fromEnvironment('RAFT_DESKTOP_FIXTURE');
    const casesPath = String.fromEnvironment('RAFT_DESKTOP_CASES');
    const outPath = String.fromEnvironment('RAFT_DESKTOP_OUT');
    const only = String.fromEnvironment('RAFT_DESKTOP_ONLY');
    final fixtureBytes = File(fixturePath).readAsBytesSync();
    final fixtureSha = crypto.sha256.convert(fixtureBytes).toString();
    final fixtureJson = utf8.decode(fixtureBytes);
    final cases = (jsonDecode(File(casesPath).readAsStringSync())['cases'] as List)
        .cast<Map<String, dynamic>>()
        .where(
          (c) =>
              only.isEmpty ||
              only.split(',').any((s) => (c['id'] as String).contains(s)),
        )
        .toList();
    if (cases.isEmpty) {
      throw StateError('Desktop selection matched no cases: $only');
    }
    final outDir = Directory('$outPath/android')..createSync(recursive: true);
    final summary = <Map<String, dynamic>>[];

    for (final visualCase in cases) {
      final id = visualCase['id'] as String;
      final props = Map<String, dynamic>.from(
        (visualCase['variants'] as List).first['props'],
      );
      final flow = props['flutter'] as String;
      final (family, dark) = _themes[visualCase['theme']]!;
      final viewport = Size(
        (visualCase['viewport']['width'] as num).toDouble(),
        (visualCase['viewport']['height'] as num).toDouble(),
      );
      final started = DateTime.now();
      SharedPreferences.setMockInitialValues({});
      await t.binding.setSurfaceSize(viewport);
      final fixture = jsonDecode(fixtureJson) as Map<String, dynamic>;
      final client = DesktopFixtureClient(
        fixture,
        holds: ((props['hold'] as List?) ?? const []).cast<String>(),
      );
      final w = WorkspaceController(client);
      final shotKey = GlobalKey();
      final notifications = NativeNotificationService();
      TestGesture? mouse;

      Future<void> frames([int n = 20]) async {
        for (var i = 0; i < n; i++) {
          await t.pump(const Duration(milliseconds: 16));
        }
      }

      Future<void> until(bool Function() check, String what) async {
        for (var step = 0; step < 200 && !check(); step++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        if (!check()) throw StateError('timeout waiting for $what');
      }

      Future<void> tap(Finder f) async {
        await until(() => f.evaluate().isNotEmpty, '$f');
        await t.tap(f.first, warnIfMissed: false);
        await frames();
      }

      Future<void> hover(Finder f) async {
        await until(() => f.evaluate().isNotEmpty, '$f');
        mouse ??= await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse!.addPointer(location: Offset(viewport.width - 1, viewport.height - 1));
        await mouse!.moveTo(t.getCenter(f.first));
        await frames();
      }

      Finder text(String s) => find.textContaining(s, findRichText: true);
      Future<void> waitText(String s) =>
          until(() => text(s).evaluate().isNotEmpty, 'text "$s"');
      Future<void> chatReady() => until(
        () => find.byKey(const ValueKey('message-msg-agent-reply')).evaluate().isNotEmpty,
        'channel messages',
      );

      try {
        await t.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: raftTheme(family),
            darkTheme: raftTheme(RaftFamily.elegant, dark: true),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) => Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: shotKey,
                child: SizedBox(
                  width: viewport.width,
                  height: viewport.height,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: viewport,
                      devicePixelRatio: 1,
                    ),
                    child: RaftTooltipProvider(
                      delay: const Duration(milliseconds: 600),
                      child: child!,
                    ),
                  ),
                ),
              ),
            ),
            home: WorkspaceView(
              controller: w,
              appearance: RaftAppearance(
                mode: dark ? ThemeMode.dark : ThemeMode.light,
                light: family,
              ),
              onAppearance: (_) async {},
              onLogout: () async {},
              // Production always passes the native service (main.dart:276);
              // it gates the Settings > Notifications tab.
              notifications: notifications,
            ),
          ),
        );
        // Real bootstrap: /servers -> selectServer -> /channels, /channels/dm,
        // sidebar-order, unread -> first joined channel (#design).
        unawaited(w.bootstrap());
        await frames(5);
        if (flow != 'channel-loading') await chatReady();
        await frames();

        Future<void> settings(String tab) async {
          await tap(find.byKey(const Key('rail-settings')));
          await tap(find.byKey(ValueKey('workspace-settings-nav-$tab')));
          await frames(30);
        }

        final msg = find.byKey(const ValueKey('message-msg-agent-reply'));
        switch (flow) {
          case 'channel':
          case 'channel-loading':
            break;
          case 'dm':
            await tap(find.byKey(const ValueKey('sidebar-channel-dm-agent-cindy-artin')));
            await waitText('On it. Desktop tasks');
          case 'thread-open':
            await tap(find.byKey(const ValueKey('inline-thread-msg-agent-reply')));
            await until(() => w.threadParent != null && !w.threadLoading, 'thread');
            await frames(30);
          case 'channel-tasks-tab':
            await tap(find.byKey(const ValueKey('panel-tab-tasks')));
            await frames(30);
          case 'channel-files-tab':
            await tap(find.byKey(const ValueKey('panel-tab-files')));
            await waitText('Android visual notes.pdf');
          case 'saved':
            await tap(find.byKey(const Key('nav-saved')));
            await waitText('Publish preflight is green');
          case 'tasks-board':
            await tap(find.byKey(const ValueKey('rail-tasks')));
            await waitText('Align the tabbar capture crops');
          case 'tasks-list':
            await tap(find.byKey(const ValueKey('rail-tasks')));
            await waitText('Align the tabbar capture crops');
            await tap(find.text('List')); // Source task view buttons expose their label.
            await frames(30);
          case 'search-empty':
            await tap(find.byKey(const ValueKey('rail-search')));
            await frames(30);
          case 'search-results':
            await tap(find.byKey(const ValueKey('rail-search')));
            await until(() => find.byType(TextField).evaluate().isNotEmpty, 'search field');
            await t.enterText(find.byType(TextField).first, 'visual');
            await t.pump(const Duration(milliseconds: 400));
            await frames(40);
          case 'activity':
            await tap(find.byKey(const ValueKey('rail-activity')));
            await waitText('android-artifacts');
            await frames(20);
          case 'members':
            await tap(find.byKey(const ValueKey('rail-members')));
            await waitText('Product UX Designer');
          case 'members-agent':
            await tap(find.byKey(const ValueKey('rail-members')));
            await tap(find.byKey(const ValueKey('desktop-directory-agent-agent-cindy')));
            await frames(40);
          case 'members-human':
            await tap(find.byKey(const ValueKey('rail-members')));
            await tap(find.byKey(const ValueKey('desktop-directory-human-visual-human-designer')));
            await frames(40);
          case 'computers':
            await tap(find.byKey(const ValueKey('rail-computers')));
            await waitText('Studio Test Rig');
          case 'computers-detail':
            await tap(find.byKey(const ValueKey('rail-computers')));
            await tap(find.byKey(const ValueKey('desktop-directory-computer-computer-mbp')));
            await frames(40);
          case 'notification-center':
            await hover(find.byType(SystemNotificationBell));
            await frames(30);
          case 'hover-sidebar-row':
            await hover(find.byKey(const ValueKey('sidebar-channel-channel-android')));
          case 'hover-rail-tasks':
            await hover(find.byKey(const ValueKey('rail-tasks')));
            await t.pump(const Duration(milliseconds: 700));
            await frames(30);
          case 'hover-message':
            await hover(msg);
            await frames(20);
          case 'reaction-picker':
            await hover(msg);
            await frames(10);
            await t.tap(find.byKey(const ValueKey('message-react-msg-agent-reply')));
            await until(
              () => find.byType(RaftQuickReactionPicker).evaluate().isNotEmpty,
              'reaction picker',
            );
            await frames(20);
          case 'composer-focused':
            await tap(find.descendant(of: find.byType(RaftComposer), matching: find.byType(TextField)));
            await frames(20);
          default:
            if (flow.startsWith('settings:')) {
              await settings(flow.substring('settings:'.length));
            } else {
              throw StateError('unknown flow $flow');
            }
        }
        if (flow == 'channel-loading') await frames(60);
        await frames(30);

        // Structural probes (logical px) for the written diff.
        final regions = <String, Map<String, double>>{};
        void probe(String name, Finder f) {
          final hits = f.evaluate().toList();
          if (hits.isEmpty) return;
          final r = t.getRect(f.first);
          regions[name] = {'x': r.left, 'y': r.top, 'width': r.width, 'height': r.height};
        }
        probe('rail.first', find.byKey(const ValueKey('rail-search')));
        probe('sidebar', find.byKey(const Key('workspace-sidebar-panel')));
        probe('thread', find.byKey(const Key('workspace-thread-panel')));
        probe('master', find.byKey(const Key('desktop-master-panel')));
        probe('detail', find.byKey(const Key('desktop-content-detail')));
        probe('notificationCenter', find.byKey(const Key('notification-center-surface')));
        probe('reactionPicker', find.byType(RaftQuickReactionPicker));
        probe('composer', find.byType(RaftComposer));
        probe('message.agent-reply', msg);
        final boundary =
            shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File('${outDir.path}/$id.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        File('${outDir.path}/$id.metadata.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'provider': 'android',
            'providerType': 'flutter-integration-test',
            'source': 'flutter-linux',
            'caseId': id,
            'image': 'visual-testing-results/android/$id.png',
            'viewport': visualCase['viewport'],
            'theme': visualCase['theme'],
            'flow': flow,
            'selector': 'viewport',
            'crop': {
              'mode': 'viewport',
              'contract': 'screen-route',
              'rect': {'x': 0, 'y': 0, 'width': viewport.width, 'height': viewport.height},
              'targetRect': {'x': 0, 'y': 0, 'width': viewport.width, 'height': viewport.height},
              'outset': null,
            },
            'renderer': 'Flutter Linux desktop engine (xvfb), RepaintBoundary.toImage at 1x',
            'regions': regions,
            'fixtureSha256': fixtureSha,
            'fixtureMisses': client.misses.toList()..sort(),
            'capturedAt': DateTime.now().toUtc().toIso8601String(),
          }),
        );
        summary.add({'id': id, 'ok': true, 'ms': DateTime.now().difference(started).inMilliseconds});
        // ignore: avoid_print
        print('ok   $id');
      } catch (error, stack) {
        File('${outDir.path}/$id.failure.json').writeAsStringSync(
          jsonEncode({'caseId': id, 'error': '$error', 'stack': '$stack'.split('\n').take(12).join('\n'), 'misses': client.misses.toList()}),
        );
        summary.add({'id': id, 'ok': false, 'error': '$error'});
        // ignore: avoid_print
        print('FAIL $id: $error');
      }
      // Drain any framework exception so the next case starts clean.
      while (t.takeException() != null) {}
      if (mouse != null) await mouse!.removePointer();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 100));
      w.dispose();
      await client.stream.close();
    }
    File('${outDir.path}/_capture-summary.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'at': DateTime.now().toUtc().toIso8601String(),
        'fixtureSha256': fixtureSha,
        'results': summary,
      }),
    );
    await t.binding.setSurfaceSize(null);
    expect(
      summary.where((result) => result['ok'] != true),
      isEmpty,
      reason: 'Each selected desktop capture must finish its real navigation flow.',
    );
  }, timeout: const Timeout(Duration(minutes: 60)));
}
