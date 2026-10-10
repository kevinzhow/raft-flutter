// Host side of the perf lab (integration_test/perf_lab_test.dart).
//
// Drives the integration test and, over the same VM service connection,
// acts as the sampler: per scenario it clears CPU samples and the VM
// timeline, counts GCs, and when the scenario ends attributes the worst UI
// frames (Dart CPU samples) and worst raster frames (engine timeline events).
// All files are written on the host into RAFT_PERF_OUT, so the app needs no
// file system access (macOS sandbox safe).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' show FlutterDriver;
import 'package:integration_test/common.dart';
import 'package:vm_service/vm_service.dart' hide Response;

const _encoder = JsonEncoder.withIndent(' ');

Future<void> main() async {
  final out = Directory(Platform.environment['RAFT_PERF_OUT']!)..createSync(recursive: true);
  final root = Platform.environment['RAFT_LAB_ROOT'] ?? '';
  final trace = Platform.environment['RAFT_LAB_PHASES'] != 'false';
  final driver = await FlutterDriver.connect();
  final service = driver.serviceClient;
  final isolateId = driver.appIsolate.id!;
  for (final stream in [EventStreams.kExtension, EventStreams.kGC]) {
    try {
      await service.streamListen(stream);
    } on RPCError catch (e) {
      if (e.code != 103) rethrow; // already subscribed
    }
  }
  var gcActive = false, gcCount = 0;
  service.onGCEvent.listen((e) {
    if (gcActive && e.isolate?.id == isolateId) gcCount++;
  });

  Future<void> ack(String token) => service.callServiceExtension('ext.raft.lab.ack', isolateId: isolateId, args: {'token': token});

  Future<void> handle(Map<String, dynamic> data) async {
    final kind = data['kind'] as String;
    final label = '${data['theme']}-${data['scenario']}';
    switch (kind) {
      case 'hello':
        final flags = (await service.getFlagList()).flags ?? const <Flag>[];
        final streams = (await service.getVMTimelineFlags()).recordedStreams ?? const <String>[];
        // Only the engine (raster attribution) and GC streams: the Dart and
        // Microtask streams would overflow the ring buffer within seconds.
        final recorded = trace ? ['Embedder', 'GC'] : <String>[];
        await service.setVMTimelineFlags(recorded);
        File('${out.path}/lab-hello.json').writeAsStringSync(_encoder.convert({
          ...data,
          'timelineStreamsBefore': streams,
          'timelineStreams': recorded,
          'vmFlags': {
            for (final f in flags)
              if (const {'profile_period', 'max_profile_depth', 'profiler', 'timeline_recorder', 'timeline_streams'}.contains(f.name)) f.name: f.valueAsString,
          },
        }));
      case 'start':
        await service.clearCpuSamples(isolateId);
        if (trace) await service.clearVMTimeline();
        gcCount = 0;
        gcActive = true;
      case 'end':
        gcActive = false;
        final attribution = await attribute(service, isolateId, data, root: root, trace: trace);
        attribution['gcCount'] = gcCount;
        File('${out.path}/$label.attribution.json').writeAsStringSync(_encoder.convert(attribution));
      case 'result':
        final record = jsonDecode(data['record'] as String) as Map<String, dynamic>;
        File('${out.path}/${record['theme']}-${record['scenario']}.json').writeAsStringSync(jsonEncode(record));
      case 'note':
        final notes = File('${out.path}/lab-notes.jsonl');
        notes.writeAsStringSync('${jsonEncode(data)}\n', mode: FileMode.append);
      case 'done':
        File('${out.path}/lab-done.json').writeAsStringSync(_encoder.convert(data));
    }
    await ack(data['token'] as String);
  }

  var queue = Future<void>.value();
  service.onExtensionEvent.listen((e) {
    if (e.extensionKind != 'raft.lab') return;
    final data = Map<String, dynamic>.from(e.extensionData!.data);
    queue = queue.then((_) => handle(data)).catchError((Object error, StackTrace stack) {
      stderr.writeln('perf lab sampler error on ${data['kind']}: $error\n$stack');
      File('${out.path}/lab-sampler-errors.txt').writeAsStringSync('${data['kind']}: $error\n$stack\n', mode: FileMode.append);
      return ack(data['token'] as String);
    });
  });

  final raw = await driver.requestData(null, timeout: const Duration(minutes: 60));
  await queue;
  File('${out.path}/driver-result.json').writeAsStringSync(raw);
  final response = Response.fromJson(raw);
  await driver.close();
  if (response.allTestsPassed) {
    stdout.writeln('All tests passed.');
    exit(0);
  }
  stdout.writeln('Failure Details:\n${response.formattedFailureDetails}');
  exit(1);
}

List<Map<String, Object>> _top(Map<String, num> m, int n) => (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
    .take(n)
    .map((e) => {'name': e.key, 'value': e.value is double ? (e.value as double).round() : e.value})
    .toList();

Future<Map<String, Object?>> attribute(VmService service, String isolateId, Map<String, dynamic> data, {required String root, required bool trace}) async {
  final start = data['startUs'] as int, end = data['endUs'] as int;
  final uiWindows = [for (final w in data['uiWindows'] as List) [(w as List)[0] as int, w[1] as int]];
  final rasterWindows = [for (final w in data['rasterWindows'] as List) [(w as List)[0] as int, w[1] as int]];
  final result = <String, Object?>{'theme': data['theme'], 'scenario': data['scenario'], 'startUs': start, 'endUs': end};

  // UI thread: Dart CPU samples of the main isolate.
  final cpu = await service.getCpuSamples(isolateId, start, end - start);
  final functions = cpu.functions ?? const <ProfileFunction>[];
  final names = List<String?>.filled(functions.length, null);
  String name(int i) => names[i] ??= () {
    final f = functions[i];
    final fn = f.function;
    final n = (fn is FuncRef ? fn.name : (fn is NativeFunction ? fn.name : '$fn')) ?? '?';
    final owner = fn is FuncRef && fn.owner is ClassRef ? '${(fn.owner as ClassRef).name}.' : '';
    // Native frames carry an absolute library path and offset; fold them
    // per library so one hot native library reads as one entry.
    final native = RegExp(r'^\[Native\] (?:.*/)?([^/+]+)\+0x[0-9a-f]+$').firstMatch(n);
    if (native != null) return '${native.group(1)} (native)';
    final url = (f.resolvedUrl ?? '').split('/').last;
    return url.isEmpty ? '$owner$n' : '$owner$n ($url)';
  }();

  // Inclusive cost categories (a sample may count in several).
  const categories = <String, List<String>>{
    // System font fallback: fontconfig (Linux), CoreText (macOS).
    'fontFallback': ['libfontconfig', 'Fc', 'CTFont', 'FontParser', 'TDescriptorSource', 'SkFontMgr'],
    'textLayout': ['Paragraph._layout', 'Paragraph.layout', 'TextPainter.layout', '_NativeParagraph', 'ParagraphBuilder.build'],
    'semantics': ['flushSemantics', 'SemanticsOwner.sendSemanticsUpdate'],
    'build': ['BuildOwner.buildScope'],
    'layout': ['PipelineOwner.flushLayout'],
    'paint': ['PipelineOwner.flushPaint'],
    'composite': ['RenderView.compositeFrame'],
    'imageDecode': ['instantiateImageCodec', 'ImageDescriptor', 'decodeImageFromList'],
    'markdown': ['markdown.dart', 'MarkdownBody', 'md.Document', 'InlineParser', 'BlockParser'],
  };
  bool ours(int i) {
    final url = functions[i].resolvedUrl ?? '';
    if (url.contains('/.pub-cache/') || url.contains('flutter-sdks') || url.contains('/flutter/packages/') || url.contains('/.dart_tool/')) return false;
    return root.isNotEmpty ? url.contains(root) : url.startsWith('file://');
  }

  final samples = cpu.samples ?? const <CpuSample>[];
  Map<String, Object?> aggregate(bool Function(int ts) include) {
    final self = <String, int>{}, inclusive = <String, int>{}, app = <String, int>{}, category = <String, int>{};
    var total = 0;
    for (final s in samples) {
      final stack = s.stack;
      if (stack == null || stack.isEmpty || !include(s.timestamp ?? 0)) continue;
      total++;
      final names = [for (final i in stack) name(i)];
      for (final MapEntry(:key, :value) in categories.entries) {
        if (names.any((n) => value.any((v) => v == 'Fc' ? n.startsWith('Fc') : n.contains(v)))) {
          category.update(key, (v) => v + 1, ifAbsent: () => 1);
        }
      }
      self.update(name(stack.first), (v) => v + 1, ifAbsent: () => 1);
      for (final f in {for (final i in stack) name(i)}) {
        inclusive.update(f, (v) => v + 1, ifAbsent: () => 1);
      }
      for (final f in {for (final i in stack) if (ours(i)) name(i)}) {
        app.update(f, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    return {'samples': total, 'categories': category, 'self': _top(self, 25), 'inclusive': _top(inclusive, 40), 'appInclusive': _top(app, 25)};
  }

  bool inUi(int ts) => uiWindows.any((w) => ts >= w[0] - 1000 && ts <= w[1] + 1000);
  result['samplePeriodUs'] = cpu.samplePeriod;
  result['cpuAll'] = aggregate((ts) => true);
  result['cpuWorstUiFrames'] = aggregate(inUi);
  result['cpuPerWorstUiFrame'] = [
    for (final w in uiWindows)
      {
        'window': w,
        ...(aggregate((ts) => ts >= w[0] - 1000 && ts <= w[1] + 1000)..remove('self')),
      }..update('inclusive', (v) => (v as List).take(12).toList())..update('appInclusive', (v) => (v as List).take(10).toList()),
  ];

  if (!trace) return result;
  // Raster thread and GC: VM timeline (engine Embedder + GC streams).
  final timeline = await service.getVMTimeline(timeOriginMicros: start, timeExtentMicros: end - start);
  final events = [for (final e in timeline.traceEvents ?? const <TimelineEvent>[]) e.json!];
  final threads = <Object, String>{};
  for (final e in events) {
    if (e['ph'] == 'M' && e['name'] == 'thread_name') threads[e['tid']] = '${(e['args'] as Map?)?['name']}';
  }
  final spans = <(Object, String, String, int, int)>[]; // tid, cat, name, start, end
  final open = <Object, List<Map>>{};
  var earliest = 1 << 62;
  for (final e in events) {
    final ts = e['ts'];
    if (ts is! int) continue;
    if (ts < earliest) earliest = ts;
    final Object tid = e['tid'] ?? 0;
    switch (e['ph']) {
      case 'X':
        spans.add((tid, '${e['cat']}', '${e['name']}', ts, ts + ((e['dur'] as num?)?.toInt() ?? 0)));
      case 'B':
        open.putIfAbsent(tid, () => []).add(e);
      case 'E':
        final stack = open[tid];
        if (stack != null && stack.isNotEmpty) {
          final b = stack.removeLast();
          spans.add((tid, '${b['cat']}', '${b['name']}', b['ts'] as int, ts));
        }
    }
  }
  final rasterTids = {for (final e in threads.entries) if (e.value.toLowerCase().contains('raster')) e.key};
  result['timelineEvents'] = events.length;
  result['timelineCoversStart'] = earliest <= start + 50000;
  result['threads'] = threads.values.toSet().toList();
  final rasterByName = <String, int>{};
  for (final (tid, _, n, s, e) in spans) {
    if (rasterTids.isNotEmpty && !rasterTids.contains(tid)) continue;
    for (final w in rasterWindows) {
      final overlap = (e < w[1] ? e : w[1]) - (s > w[0] ? s : w[0]);
      if (overlap > 0) rasterByName.update(n, (v) => v + overlap, ifAbsent: () => overlap);
    }
  }
  result['rasterWorstFrames'] = {'windows': rasterWindows, 'inclusiveUs': _top(rasterByName, 30)};
  final gc = <String, Map<String, num>>{};
  for (final (_, cat, n, s, e) in spans) {
    if (cat != 'GC') continue;
    final entry = gc.putIfAbsent(n, () => {'count': 0, 'totalUs': 0, 'maxUs': 0});
    entry['count'] = entry['count']! + 1;
    entry['totalUs'] = entry['totalUs']! + (e - s);
    if (e - s > entry['maxUs']!) entry['maxUs'] = e - s;
  }
  result['gcEvents'] = gc;
  result['gcInWorstUiFrames'] = [
    for (final (_, cat, n, s, e) in spans)
      if (cat == 'GC' && uiWindows.any((w) => s <= w[1] && e >= w[0])) {'name': n, 'us': e - s},
  ];
  return result;
}
