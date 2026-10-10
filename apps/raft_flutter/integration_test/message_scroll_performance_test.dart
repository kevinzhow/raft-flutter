// P01: real Linux profile engine, deterministic mixed messages, unchanged across revisions.
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/message_presentation_test.dart' show fixture;

final out = Platform.environment['RAFT_PERF_OUT'] ?? const String.fromEnvironment('RAFT_PERF_OUT');
final revision = Platform.environment['RAFT_PERF_REVISION'] ?? const String.fromEnvironment('RAFT_PERF_REVISION');
final only = Platform.environment['RAFT_PERF_ONLY'] ?? const String.fromEnvironment('RAFT_PERF_ONLY');
final semanticsEnabled = Platform.environment['RAFT_PERF_SEMANTICS'] == 'true';
const seconds = int.fromEnvironment('RAFT_PERF_SECONDS', defaultValue: 10);
final trace = Platform.environment['RAFT_PERF_TRACE'] == 'true';

int cpuTicks() {
  final raw = File('/proc/self/stat').readAsStringSync();
  final fields = raw.substring(raw.lastIndexOf(')') + 2).split(' ');
  return int.parse(fields[11]) + int.parse(fields[12]);
}

String longMessage(int i) => '''## 第 $i 条固定性能消息

这是用于复现真实频道滚动卡顿的中文长消息。我们必须保留同一份输入和原始测量结果，不能用短消息或空列表替代用户正在阅读的内容。一次完整的回归应覆盖长段落、内联格式、链接、列表、代码以及附件，检查真实构建和布局成本。

这里继续说明产品的实现约束。界面显示的资料来自当前工作区，频道和线程分别保留自己的滚动位置，长内容在需要的时候折叠。**同样的文字**应该在不同主题下保持可读，*文字选择*和鼠标菜单应当持续可用，不能为了测量而关闭产品原本的功能。查看 [来源资料](https://example.invalid/reference/$i) 了解固定输入。

- 第一项：这是一段包含中文、English、日本語和多个标点的长列表内容，用于测量换行、内联解析、选择区域和约束变化时的实际布局。
- 第二项：固定消息的内容不随版本更改，页面结构和绘制成本才能进行比较；任何测量失败都必须保留，不能仅汇总成功的最后一次运行。
- 第三项：当前频道含有几百条不同类型的消息，我们连续滚动十秒，再在消息上下文内重复滚动，最后调整真实桌面窗口大小。

> 引用的一段讨论：外观对齐需要保留交互和滚动流畅度，真实平台的证据必须覆盖显示、绘制、输入和状态变化。

```dart
Future<String> processMessage(int value) async {
  final values = List.generate(8, (index) => index + value);
  final total = values.fold<int>(0, (a, b) => a + b);
  return "fixed message $i: \$total";
}
```

''';

class NativeSizeObserver with WidgetsBindingObserver {
  final changes = <Map<String, dynamic>>[];
  final rawEngineChanges = <Map<String, dynamic>>[];
  void captureRawEngineSize() {
    final size = ui.PlatformDispatcher.instance.views.first.physicalSize;
    if (rawEngineChanges.isEmpty || rawEngineChanges.last['width'] != size.width || rawEngineChanges.last['height'] != size.height) {
      rawEngineChanges.add({'timestampUs': developer.Timeline.now, 'width': size.width, 'height': size.height});
    }
  }
  @override
  void didChangeMetrics() {
    final size = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    changes.add({'timestampUs': developer.Timeline.now, 'width': size.width, 'height': size.height});
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('[P01a][P01b][P01c] brutal-light elegant-light elegant-dark profile scrolling and native resize', (t) async {
    binding.reportData = {'perfSuite': 'integration_test/message_scroll_performance_test.dart', 'perfTestName': '[P01a][P01b][P01c] brutal-light elegant-light elegant-dark profile scrolling and native resize'};
    expect(kProfileMode, true, reason: 'Debug timings cannot gate performance.');
    expect(Platform.isLinux, true);
    Directory(out).createSync(recursive: true);
    final ticksPerSecond = int.parse((await Process.run('getconf', ['CLK_TCK'])).stdout.toString().trim());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 240, 120), Paint()..color = const Color(0xff99bbdd));
    final png = (await (await recorder.endRecording().toImage(240, 120)).toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    final images = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var imageReads = 0;
    images.listen((request) async {
      imageReads++;
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.add(png);
      await request.response.close();
    });
    addTearDown(() => images.close(force: true));
    final results = <Map<String, dynamic>>[];
    final violations = <String>[];
    final sizes = NativeSizeObserver();
    binding.addObserver(sizes);
    addTearDown(() => binding.removeObserver(sizes));
    for (final (name, family, dark) in [
      ('brutal-light', RaftFamily.brutal, false),
      ('elegant-light', RaftFamily.elegant, false),
      ('elegant-dark', RaftFamily.elegant, true),
    ]) {
      if (only.isNotEmpty && only != name) continue;
      await Process.run('python3', [Platform.environment['RAFT_PERF_RESIZER']!, '$pid', '0']);
      await t.pump(const Duration(milliseconds: 50));
      SharedPreferences.setMockInitialValues({});
      final (w, api) = await fixture('member');
      final rows = <Map<String, dynamic>>[
        for (var i = 0; i < 500; i++) {
          'id': 'perf-$i', 'channelId': 'c1', 'seq': '${i + 1}',
          'senderId': i.isEven ? 'alice' : 'bob', 'senderType': 'user',
          'senderName': i.isEven ? 'Alice' : 'Bob', 'messageType': 'chat',
          'createdAt': DateTime.utc(2026, 10, 1).add(Duration(minutes: i)).toIso8601String(),
          'content': i == 300 ? 'Fixed visible context anchor 300.' : longMessage(i) + switch (i % 4) {
            0 => 'Message $i: plain text with 中文、日本語 and a short reply.',
            1 => '### Update $i\n\n**Bold** and *italic* text.\n\n- First point\n- Second point\n\n> Quoted response with [a link](https://example.invalid).',
            2 => 'Code $i\n\n```dart\nFuture<String> reply(int value) async {\n  return "message \$value";\n}\n```',
            _ => 'Image $i with a caption and reactions.',
          },
          if (i % 4 == 3) 'attachments': [{
            'id': 'image-$i', 'channelId': 'c1', 'filename': 'fixture.png',
            'mimeType': 'image/png', 'width': 240, 'height': 120, 'sizeBytes': png.length,
          }],
          'reactions': [{'emoji': '👍', 'count': 2, 'userIds': ['alice', 'bob']}],
        },
      ];
      for (var i = 3; i < 500; i += 4) {
        api.routes['GET /attachments/image-$i/url'] = (_) => {'url': 'http://127.0.0.1:${images.port}/image.png'};
      }
      api.routes['GET /agents'] = (_) => [];
      api.routes['GET /servers/s1/members'] = (_) => [];
      api.routes['GET /tasks'] = (_) => [];
      api.routes['POST /channels/c1/read'] = (_) => {};
      api.routes['GET /messages/context/perf-300'] = (_) => {
        'messages': rows.sublist(250, 350), 'hasOlder': false, 'hasNewer': false,
      };
      w.ledger.switchServer('s1');
      w.ledger.ingest(rows, expectedGeneration: w.ledger.generation);
      w.visibleIds['c1'] = rows.map((r) => r['id'] as String).toSet();
      final shot = GlobalKey();
      final setupClock = Stopwatch()..start();
      await t.pumpWidget(MaterialApp(
        theme: raftTheme(family, dark: dark),
        home: Scaffold(body: RepaintBoundary(key: shot, child: RaftChatView(controller: w))),
      ));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
      dynamic state = t.state(find.byType(RaftChatView));
      final ScrollController scroll = state.viewport;
      expect(scroll.hasClients, true);
      expect(w.messages.length, 500);
      // Wait for the latest end: maximum offset for a top-anchored list,
      // minimum for a bottom-anchored (reversed) one.
      double latest() => scroll.position.axisDirection == AxisDirection.up ? scroll.position.minScrollExtent : scroll.position.maxScrollExtent;
      for (var i = 0; i < 100 && (latest() - scroll.offset).abs() > 1; i++) {
        await t.pump(const Duration(milliseconds: 20));
      }
      // Load ends when the channel is actually published (visible, hit-testable
      // text), not when the hidden staged list reaches its end offset.
      final published = find.descendant(of: find.byType(RaftMessageTile), matching: find.byType(RichText)).hitTestable();
      for (var i = 0; i < 1500 && published.evaluate().isEmpty; i++) {
        await t.pump(const Duration(milliseconds: 20));
      }
      File('$out/$name-load.json').writeAsStringSync(jsonEncode({'elapsedSeconds': setupClock.elapsedMicroseconds / 1e6, 'mountedRows': find.byType(RaftMessageTile, skipOffstage: false).evaluate().length, 'rssBytes': ProcessInfo.currentRss}));
      Future<void> initialPublicationDiagnostic() async {
        final visibleText = find.descendant(of: find.byType(RaftMessageTile), matching: find.byType(RichText)).hitTestable();
        final copies = <Map<String, dynamic>>[];
        for (final element in find.byType(RaftMessageTile, skipOffstage: false).evaluate()) {
          final box = element.renderObject;
          if (box is! RenderBox || !box.hasSize) continue;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          if (rect.bottom < 0 || rect.top > ui.PlatformDispatcher.instance.views.first.physicalSize.height) continue;
          final layers = <Map<String, dynamic>>[];
          element.visitAncestorElements((ancestor) {
            if (ancestor.widget case final Opacity opacity) layers.add({'opacity':opacity.opacity});
            if (ancestor.widget case final IgnorePointer ignore) layers.add({'ignorePointer':ignore.ignoring});
            return true;
          });
          copies.add({'x':rect.left,'y':rect.top,'width':rect.width,'height':rect.height,'layers':layers});
        }
        final optional = <String, dynamic>{};
        try { optional['focusStaging'] = state.focusStaging; } on NoSuchMethodError { optional['focusStaging'] = 'absent'; }
        try { optional['initialEndPending'] = state.initialEndPending; } on NoSuchMethodError { optional['initialEndPending'] = 'absent'; }
        try { optional['measuredWindowExtent'] = state.measuredWindowExtent; } on NoSuchMethodError { optional['measuredWindowExtent'] = 'absent'; }
        final size = ui.PlatformDispatcher.instance.views.first.physicalSize;
        File('$out/$name-initial-publication.json').writeAsStringSync(jsonEncode({'visibleRichText':visibleText.evaluate().length,'targetCopies':copies,'state':optional,'offset':scroll.offset,'maxScrollExtent':scroll.position.maxScrollExtent,'rawEngineWidth':size.width,'rawEngineHeight':size.height}));
        final initialBoundary = shot.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final initialImage = await initialBoundary.toImage(pixelRatio: 1);
        File('$out/$name-initial.png').writeAsBytesSync((await initialImage.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
        initialImage.dispose();
      }
      await initialPublicationDiagnostic();
      expect(find.descendant(of: find.byType(RaftMessageTile), matching: find.byType(RichText)).hitTestable(), findsWidgets, reason: 'Initial channel must actually publish visible text before a scrolling measurement.');
      Future<void> sample(String action, Future<void> Function() run) async {
        final frames = <ui.FrameTiming>[];
        void timing(List<ui.FrameTiming> values) {
          sizes.captureRawEngineSize();
          frames.addAll(values);
        }
        binding.addTimingsCallback(timing);
        var startCpu = 0, cpu = 0.0, elapsed = 0.0, actionStart = 0, actionEnd = 0;
        final clock = Stopwatch();
        final startOffset = (state.viewport as ScrollController).offset;
        sizes.captureRawEngineSize();
        final sizeChangesStart = sizes.changes.length;
        final rawSizesStart = sizes.rawEngineChanges.length;
        final mountedAllBefore = find.byType(RaftMessageTile, skipOffstage: false).evaluate().length;
        final mountedBefore = find.byType(RaftMessageTile).evaluate().length;
        // Scrollbar stability: sample the thumb fraction/position each frame.
        final thumb = <Map<String, double>>[];
        var sampling = true;
        void sampleThumb(Duration _) {
          if (!sampling) return;
          final p = (state.viewport as ScrollController).position;
          final total = p.maxScrollExtent - p.minScrollExtent + p.viewportDimension;
          if (total > 0) {
            thumb.add({'length': p.viewportDimension / total, 'top': (p.pixels - p.minScrollExtent) / total});
          }
          SchedulerBinding.instance.addPostFrameCallback(sampleThumb);
        }
        SchedulerBinding.instance.addPostFrameCallback(sampleThumb);
        File('$out/$name-$action.start').writeAsStringSync('');
        await binding.watchPerformance(() async {
          startCpu = cpuTicks(); clock.start(); actionStart = developer.Timeline.now;
          await run();
          actionEnd = developer.Timeline.now; clock.stop();
          elapsed = clock.elapsedMicroseconds / 1e6;
          cpu = (cpuTicks() - startCpu) / ticksPerSecond;
        }, reportKey: '$name-$action');
        binding.removeTimingsCallback(timing);
        sampling = false;
        double thumbLengthSpread = 0;
        var thumbReversals = 0;
        if (thumb.length > 2) {
          final lengths = [for (final v in thumb) v['length']!];
          final mean = lengths.reduce((a, b) => a + b) / lengths.length;
          thumbLengthSpread = (lengths.reduce((a, b) => a > b ? a : b) - lengths.reduce((a, b) => a < b ? a : b)) / mean;
          // The action scrolls one way; a thumb step the other way is a jump.
          final direction = (thumb.last['top']! - thumb.first['top']!).sign;
          for (var i = 1; i < thumb.length; i++) {
            final step = thumb[i]['top']! - thumb[i - 1]['top']!;
            if (direction != 0 && step * direction < -0.002) thumbReversals++;
          }
        }
        frames.removeWhere((f) => f.timestampInMicroseconds(ui.FramePhase.buildStart) < actionStart || f.timestampInMicroseconds(ui.FramePhase.buildStart) > actionEnd);
        final record = <String, dynamic>{
          'revision': revision, 'theme': name, 'action': action, 'profile': kProfileMode, 'semanticsEnabled': semanticsEnabled, 'engineSemantics': SemanticsBinding.instance.semanticsEnabled, 'instrumented': false,
          'displayRefreshRate': binding.renderViews.first.flutterView.display.refreshRate, 'pid': pid, 'fixtureMessages': 500, 'viewportWidth': binding.renderViews.first.flutterView.physicalSize.width, 'viewportHeight': binding.renderViews.first.flutterView.physicalSize.height,
          'actionElapsedSeconds': elapsed, 'actionStartUs': actionStart, 'actionEndUs': actionEnd, 'rawEngineSizeChanges': sizes.rawEngineChanges.skip(rawSizesStart).where((s) => (s['timestampUs'] as int) >= actionStart && (s['timestampUs'] as int) <= actionEnd).toList(),
          'nativeSizeChanges': sizes.changes.skip(sizeChangesStart).where((s) => (s['timestampUs'] as int) >= actionStart && (s['timestampUs'] as int) <= actionEnd).toList(), 'cpuSeconds': cpu,
          'cpuPercentOneCore': 100 * cpu / elapsed, 'frameCount': frames.length,
          'startOffset': startOffset, 'endOffset': (state.viewport as ScrollController).offset,
          'mountedVisibleBefore': mountedBefore, 'mountedVisibleAfter': find.byType(RaftMessageTile).evaluate().length,
          'mountedBefore': mountedAllBefore, 'mountedAfter': find.byType(RaftMessageTile, skipOffstage: false).evaluate().length,
          'imageReads': imageReads, 'rssBytes': ProcessInfo.currentRss,
          'thumbSamples': thumb.length, 'thumbLengthSpread': thumbLengthSpread, 'thumbReversals': thumbReversals,
          'frames': [for (final f in frames) {'buildStartUs': f.timestampInMicroseconds(ui.FramePhase.buildStart), 'buildUs': f.buildDuration.inMicroseconds, 'rasterUs': f.rasterDuration.inMicroseconds, 'totalUs': f.totalSpan.inMicroseconds}],
          'summary': binding.reportData!['$name-$action'],
        };
        results.add(record);
        File('$out/$name-$action.json').writeAsStringSync(jsonEncode(record));
        File('$out/results.json').writeAsStringSync(jsonEncode(results));
        if (frames.length < seconds * 5) violations.add('$name/$action: fewer than 50 real frames');
        if (frames.isEmpty || frames.last.timestampInMicroseconds(ui.FramePhase.buildStart) - frames.first.timestampInMicroseconds(ui.FramePhase.buildStart) < 9000000) violations.add('$name/$action: real frame span below nine seconds');
        if (elapsed < 9.5 || elapsed > 15) violations.add('$name/$action: incorrect real action duration');
        if (action.endsWith('scroll') && ((state.viewport as ScrollController).offset - startOffset).abs() < 1000) violations.add('$name/$action: real content did not move');
        final sizesDuringAction = sizes.changes.sublist(sizeChangesStart);
        // The GTK embedder under the benchmark's X11 session does not forward
        // external window-manager resizes to the engine (also seen with an
        // interactive drag). native-resize stays recorded as a diagnostic;
        // view-resize gates the Flutter-side relayout cost instead.
        if (action == 'view-resize' && (sizesDuringAction.length < 10 || sizesDuringAction.map((s) => s['width']).toSet().length < 6)) violations.add('$name/$action: view dimensions did not resize');

      }
      Future<void> scrollForTenSeconds() async {
        final ScrollController current = state.viewport;
        // Scroll toward older history: down in offset for a top-anchored list,
        // up in offset for a bottom-anchored (reversed) one.
        final older = current.position.axisDirection == AxisDirection.up ? 12000 : -12000;
        final end = (current.offset + older).clamp(current.position.minScrollExtent, current.position.maxScrollExtent);
        await current.animateTo(end, duration: const Duration(seconds: seconds), curve: Curves.linear);
      }
      await sample('channel-scroll', scrollForTenSeconds);
      final contextClock = Stopwatch()..start();
      await w.jumpToMessage('c1', 'perf-300');
      await t.pump(const Duration(milliseconds: 100));
      final target = find.byKey(const ValueKey('message-perf-300'));
      final targetText = find.descendant(of: target, matching: find.byType(RichText)).hitTestable();
      for (var i = 0; i < 100 && targetText.evaluate().isEmpty; i++) {
        await t.pump(const Duration(milliseconds: 20));
      }
      final contexts = <Map<String, dynamic>>[];
      for (final element in find.byKey(const ValueKey('message-perf-300'), skipOffstage: false).evaluate()) {
        final box = element.findRenderObject();
        if (box is! RenderBox || !box.hasSize) continue;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        final layers = <Map<String, dynamic>>[];
        element.visitAncestorElements((ancestor) {
          if (ancestor.widget case final Opacity opacity) layers.add({'opacity':opacity.opacity});
          if (ancestor.widget case final IgnorePointer ignore) layers.add({'ignorePointer':ignore.ignoring});
          return true;
        });
        contexts.add({'x':rect.left,'y':rect.top,'width':rect.width,'height':rect.height,'layers':layers});
      }
      File('$out/$name-context-diagnostic.json').writeAsStringSync(jsonEncode({'targetCopies':contexts,'visibleRichText':targetText.evaluate().length,'controllerRows':w.messages.length,'error':w.error,'offset':(state.viewport as ScrollController).offset,'maxScrollExtent':(state.viewport as ScrollController).position.maxScrollExtent}));
      expect(targetText.evaluate(), isNotEmpty, reason: 'A real text node in the accepted context target must be visible before sampling.');
      File('$out/$name-context-load.json').writeAsStringSync(jsonEncode({'elapsedSeconds': contextClock.elapsedMicroseconds / 1e6, 'contextMessages': w.messages.length, 'mountedRows': find.byType(RaftMessageTile, skipOffstage: false).evaluate().length, 'rssBytes': ProcessInfo.currentRss}));
      await sample('context-scroll', scrollForTenSeconds);
      // Resize the same content in every build: the latest messages.
      {
        final ScrollController current = state.viewport;
        final p = current.position;
        current.jumpTo(p.axisDirection == AxisDirection.up ? p.minScrollExtent : p.maxScrollExtent);
        for (var i = 0; i < 30; i++) {
          await t.pump(const Duration(milliseconds: 16));
        }
      }
      await sample('view-resize', () async {
        // Drive the real engine view's logical size every frame (profile mode,
        // real FrameTimings). This measures the app's own relayout on resize;
        // it does not include compositor or GTK surface reallocation.
        final view = t.view;
        final base = view.physicalSize;
        final ratio = view.devicePixelRatio;
        final resizeClock = Stopwatch()..start();
        var step = 0;
        while (resizeClock.elapsedMilliseconds < seconds * 1000) {
          final phase = step % 40;
          final width = 700 + 240 * (phase < 20 ? phase : 40 - phase) / 20;
          view.physicalSize = Size(width * ratio, base.height - (phase % 10) * 4 * ratio);
          await t.pump();
          step++;
        }
        view.resetPhysicalSize();
        await t.pump();
      });
      await sample('native-resize', () async {
        final resize = await Process.run('python3', [
          Platform.environment['RAFT_PERF_RESIZER']!, '$pid', '$seconds',
        ]);
        expect(resize.exitCode, 0, reason: resize.stderr.toString());
        expect(int.parse(resize.stdout.toString().trim()), greaterThan(seconds * 50));
      });
      if (trace) {
        debugProfileBuildsEnabled = true;
        debugProfileLayoutsEnabled = true;
        debugProfilePaintsEnabled = true;
        await binding.traceAction(scrollForTenSeconds, streams: ['Dart', 'Embedder', 'GC'], reportKey: 'hotspots');
        File('$out/$name-timeline.json').writeAsStringSync(jsonEncode(binding.reportData!['hotspots']));
        await binding.traceAction(() async {
          final view = t.view;
          final base = view.physicalSize;
          for (var step = 0; step < 120; step++) {
            final phase = step % 40;
            view.physicalSize = Size((700 + 240 * (phase < 20 ? phase : 40 - phase) / 20) * view.devicePixelRatio, base.height);
            await t.pump();
          }
          view.resetPhysicalSize();
          await t.pump();
        }, streams: ['Dart', 'Embedder', 'GC'], reportKey: 'resize-hotspots');
        File('$out/$name-resize-timeline.json').writeAsStringSync(jsonEncode(binding.reportData!['resize-hotspots']));
        debugProfileBuildsEnabled = debugProfileLayoutsEnabled = debugProfilePaintsEnabled = false;
      }
      final boundary = shot.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      File('$out/$name.png').writeAsBytesSync((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      image.dispose();
      await t.pumpWidget(const SizedBox());
      w.dispose();
      await t.pump();
    }
    File('$out/results.json').writeAsStringSync(jsonEncode(results));
    // Performance acceptance uses every raw sample, including missed vsyncs.
    for (final result in results) {
      final values = result['frames'] as List;
      if (values.isEmpty) continue;
      final sorted = [for (final f in values) (f['buildUs'] as int) + (f['rasterUs'] as int)]..sort();
      final p95 = sorted[((sorted.length - 1) * .95).ceil()];
      final rate = result['displayRefreshRate'] as double;
      final budget = rate >= 100 ? 8000 : 16000;
      final expectedFrames = (result['actionElapsedSeconds'] as double) * rate;
      final dropped = (1 - values.length / expectedFrames).clamp(0.0, 1.0);
      if (p95 >= budget) violations.add('${result['theme']}/${result['action']}: build+raster p95 $p95 exceeds budget $budget');
      if (dropped >= .05) violations.add('${result['theme']}/${result['action']}: missed-vsync fraction $dropped exceeds 5%');
      if ((result['cpuPercentOneCore'] as double) >= 80) violations.add('${result['theme']}/${result['action']}: CPU exceeds 80% of one core');
    }
    File('$out/violations.json').writeAsStringSync(jsonEncode(violations));
    expect(violations, isEmpty);
  }, semanticsEnabled: semanticsEnabled);
}
