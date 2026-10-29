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
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_driver/flutter_driver.dart' show FlutterDriver;
import 'package:integration_test/common.dart';
import 'package:vm_service/vm_service.dart' hide Response;

final class _Timespec extends Struct {
  @Int64()
  external int tvSec;

  @Int64()
  external int tvNsec;
}

final _clockGettime = DynamicLibrary.open('libc.so.6')
    .lookupFunction<
      Int32 Function(Int32 clockId, Pointer<_Timespec> tp),
      int Function(int clockId, Pointer<_Timespec> tp)
    >('clock_gettime');

/// Linux CLOCK_MONOTONIC. The same timeline in every process on this host.
int hostMonotonicNs() {
  if (!Platform.isLinux) {
    throw UnsupportedError('Host counter timing requires Linux.');
  }
  final tp = calloc<_Timespec>();
  try {
    if (_clockGettime(1, tp) != 0) {
      throw StateError('clock_gettime(CLOCK_MONOTONIC) failed');
    }
    return tp.ref.tvSec * 1000000000 + tp.ref.tvNsec;
  } finally {
    calloc.free(tp);
  }
}

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

  bool? cpuProfiling;
  Future<void> ack(String token) => service.callServiceExtension('ext.raft.lab.ack', isolateId: isolateId,
    args: {'token': token, if (cpuProfiling != null) 'cpuProfiling': '$cpuProfiling'});

  Map<int, ({String comm, int ns})>? procAtStart;
  int? procPid;
  String? procStartError;
  _ProcRead? procAtEnd;
  _ProcRead? procOpened;
  DateTime? procStartWall;
  DateTime? procEndWall;
  // One process launch is one batch. Rounds in that process share a cache,
  // so the independent sample is the batch, not the round. The host sets
  // the pair and order when it alternates an old launch with a new launch.
  final launchBatch = Platform.environment['RAFT_LAB_BATCH'] ?? '${DateTime.now().toUtc().toIso8601String()}-$pid';
  final launchPair = Platform.environment['RAFT_LAB_PAIR'];
  final launchOrder = Platform.environment['RAFT_LAB_ORDER'];
  var launchRound = 0;
  int? openRound;
  var openWarmup = false;
  String? loadAtStart;
  String? loadAtEnd;
  int? syncStartNs;
  int? syncEndNs;
  var samplerFailed = false;

  /// Both launches report ready, then this returns so the ack can release
  /// them together. No sync directory means a single launch, and it does not wait.
  Future<void> waitForPeer(int round) async {
    final dir = Platform.environment['RAFT_LAB_SYNC_DIR'];
    if (dir == null || dir.isEmpty) return;
    if (!Platform.isLinux || _androidDevice() || launchPair == null || !const {'old', 'new'}.contains(launchOrder)) {
      throw StateError('Concurrent sampling requires Linux, a pair ID and an old/new side.');
    }
    final root = Directory('$dir/$launchPair/round-$round')..createSync(recursive: true);
    final own = File('${root.path}/ready-$launchOrder');
    if (own.existsSync()) throw StateError('Round $round already has this side; use a new pair directory.');
    final pending = File('${own.path}.pending-$pid');
    pending.writeAsStringSync(jsonEncode({'batch': launchBatch, 'round': round, 'pair': launchPair, 'order': launchOrder}), flush: true);
    pending.renameSync(own.path);
    // The app stops waiting for this ack after 60 seconds and would start alone.
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (true) {
      final ready = root.listSync().whereType<File>().map((file) => file.uri.pathSegments.last).toSet();
      if (ready.contains('ready-old') && ready.contains('ready-new')) {
        final peer = jsonDecode(File('${root.path}/ready-${launchOrder == 'old' ? 'new' : 'old'}').readAsStringSync()) as Map;
        if (peer['round'] != round || peer['pair'] != launchPair || peer['batch'] == launchBatch ||
            peer['order'] != (launchOrder == 'old' ? 'new' : 'old')) {
          throw StateError('Peer identity does not match this independent launch pair.');
        }
        File('${out.path}/barrier-rounds.jsonl').writeAsStringSync('${jsonEncode({
          'batch': launchBatch, 'peerBatch': peer['batch'], 'round': round,
        })}\n', mode: FileMode.append);
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Sync barrier timed out for pair $launchPair round $round.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

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
        if (Platform.environment['RAFT_LAB_DETECT'] == 'true') {
          await service.setFlag('profiler', '$trace');
          final observed = (await service.getFlagList()).flags!.firstWhere((flag) => flag.name == 'profiler').valueAsString;
          if (observed != '$trace') throw StateError('CPU profiler state could not be verified.');
          cpuProfiling = observed == 'true';
        }
        File('${out.path}/lab-hello.json').writeAsStringSync(_encoder.convert({
          ...data,
          'timelineStreamsBefore': streams,
          'timelineStreams': recorded,
          'cpuProfiling': cpuProfiling,
          'vmFlags': {
            for (final f in flags)
              if (const {'profile_period', 'max_profile_depth', 'profiler', 'timeline_recorder', 'timeline_streams'}.contains(f.name)) f.name: f.valueAsString,
          },
        }));
      case 'start':
        openRound = launchRound;
        launchRound += 1;
        openWarmup = data['warmup'] == true;
        loadAtStart = _loadAvg();
        loadAtEnd = null;
        if (cpuProfiling != false) await service.clearCpuSamples(isolateId);
        if (trace) await service.clearVMTimeline();
        gcCount = 0;
        gcActive = true;
        procAtEnd = null;
        procEndWall = null;
        syncEndNs = null;
        // Resolve the pid before the barrier so the wait stays outside the
        // counter window and the snapshot itself is only file reads.
        final localLinux = Platform.isLinux && !_androidDevice();
        final linuxPid = localLinux ? (await service.getVM()).pid : null;
        await waitForPeer(openRound!);
        final opened = localLinux ? _readLocalSchedstat(linuxPid) : await _readProcThreads(service);
        procOpened = opened;
        syncStartNs = opened.sampleNs;
        procStartWall = DateTime.now();
        procPid = opened.pid;
        procAtStart = opened.threads;
        procStartError = opened.error;
      case 'cpu':
        // Scene clock has stopped and timeline collection has not started.
        // The end stamp is the counter sample, not an earlier event time.
        final endSample = Platform.isLinux && !_androidDevice() ? _readLocalSchedstat(procPid) : await _readProcThreads(service);
        syncEndNs = endSample.sampleNs;
        procAtEnd = endSample;
        procEndWall = DateTime.now();
        loadAtEnd = _loadAvg();
      case 'end':
        gcActive = false;
        final attribution = await attribute(service, isolateId, data, root: root, trace: trace,
          tracePath: Platform.environment['RAFT_LAB_DETECT'] == 'true' && trace ? '${out.path}/$label.trace.json' : null);
        attribution['gcCount'] = gcCount;
        final endRead = procAtEnd ?? await _readProcThreads(service);
        attribution['procThreadCpu'] = _procSceneCpu(
          startThreads: procAtStart,
          startPid: procPid,
          startError: procStartError,
          end: endRead,
          opened: procOpened,
          window: procAtEnd == null ? 'scenario-start-to-sampler-end' : 'scenario-clock',
          windowMs: procStartWall == null || procEndWall == null ? null : procEndWall!.difference(procStartWall!).inMilliseconds,
        );
        procAtStart = null;
        procAtEnd = null;
        File('${out.path}/$label.attribution.json').writeAsStringSync(_encoder.convert(attribution));
        final proc = attribution['procThreadCpu'];
        if (proc is Map) {
          proc['batch'] = launchBatch;
          proc['round'] = openRound;
          proc['warmup'] = openWarmup;
          proc['fixtureReset'] = false;
          proc['theme'] = data['theme'];
          proc['scenario'] = data['scenario'];
          if (launchPair != null) proc['pair'] = launchPair;
          if (launchOrder != null) proc['order'] = launchOrder;
          if (loadAtStart != null) proc['load'] = loadAtStart;
          if (loadAtEnd != null) proc['loadEnd'] = loadAtEnd;
          if (syncStartNs != null) proc['syncStartNs'] = syncStartNs;
          if (syncEndNs != null) proc['syncEndNs'] = syncEndNs;
          if (syncStartNs != null && syncEndNs != null) proc['syncTimedBy'] = 'counter-sample';
          File('${out.path}/proc-rounds.jsonl').writeAsStringSync('${jsonEncode(proc)}\n', mode: FileMode.append);
        }
      case 'result':
        final record = jsonDecode(data['record'] as String) as Map<String, dynamic>;
        File('${out.path}/${record['theme']}-${record['scenario']}.json').writeAsStringSync(jsonEncode(record));
        if (record['detection'] != null && record['frameworkBlocks'] is List) {
          File('${out.path}/${record['theme']}-${record['scenario']}.framework-trace.json').writeAsStringSync(jsonEncode({
            'traceEvents': [for (final raw in record['frameworkBlocks'] as List) {...raw as Map, 'pid': 1, 'tid': 1}],
            'displayTimeUnit': 'ms', 'instrumented': true,
          }));
        }
        // Keep every round's Flutter frames. The legacy per-scenario file is
        // still written for summarize/compare, which keep their old meaning.
        File('${out.path}/frame-rounds.jsonl').writeAsStringSync('${jsonEncode({
          'batch': launchBatch, 'round': openRound, 'warmup': openWarmup, 'record': record,
        })}\n', mode: FileMode.append);
        _appendKeyboardCounts(out, record, batch: launchBatch, round: openRound, warmup: openWarmup);
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
      samplerFailed = true;
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
  if (response.allTestsPassed && !(samplerFailed && Platform.environment['RAFT_LAB_SYNC_DIR'] != null)) {
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

Future<Map<String, Object?>> attribute(VmService service, String isolateId, Map<String, dynamic> data, {required String root, required bool trace, String? tracePath}) async {
  final start = data['startUs'] as int, end = data['endUs'] as int;
  final uiWindows = [for (final w in data['uiWindows'] as List) [(w as List)[0] as int, w[1] as int]];
  final rasterWindows = [for (final w in data['rasterWindows'] as List) [(w as List)[0] as int, w[1] as int]];
  final result = <String, Object?>{'theme': data['theme'], 'scenario': data['scenario'], 'startUs': start, 'endUs': end};
  if (!trace && Platform.environment['RAFT_LAB_DETECT'] == 'true') {
    return {...result, 'cpuSamplesCollected': false, 'timelineCollected': false};
  }

  // UI thread: Dart CPU samples of the main isolate.
  final cpu = await service.getCpuSamples(isolateId, start, end - start);
  if (tracePath != null) {
    File(tracePath.replaceFirst('.trace.json', '.cpu-samples.json')).writeAsStringSync(jsonEncode(cpu.toJson()));
  }
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
    final deep = Platform.environment['RAFT_LAB_DEEP'] == '1';
    return {
      'samples': total,
      'categories': category,
      'self': _top(self, deep ? 120 : 25),
      'inclusive': _top(inclusive, deep ? 400 : 40),
      'appInclusive': _top(app, deep ? 150 : 25),
    };
  }

  if (Platform.environment['RAFT_LAB_DEEP'] == '1') {
    // Top-down call tree of all samples, pruned below 0.3 %.
    final root = <String, dynamic>{'n': 0, 'c': <String, dynamic>{}};
    for (final s in samples) {
      final stack = s.stack;
      if (stack == null || stack.isEmpty) continue;
      var node = root;
      node['n'] = (node['n'] as int) + 1;
      for (final i in stack.reversed) {
        final children = node['c'] as Map<String, dynamic>;
        node = children.putIfAbsent(name(i), () => <String, dynamic>{'n': 0, 'c': <String, dynamic>{}}) as Map<String, dynamic>;
        node['n'] = (node['n'] as int) + 1;
      }
    }
    final floor = (root['n'] as int) * 0.003;
    Map<String, dynamic> prune(Map<String, dynamic> n) => {
      'n': n['n'],
      'c': {
        for (final e in (n['c'] as Map<String, dynamic>).entries)
          if ((e.value['n'] as int) >= floor) e.key: prune(e.value as Map<String, dynamic>),
      },
    };
    result['callTree'] = prune(root);
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

  if (!trace) {
    result['threadTime'] = {'collected': false};
    return result;
  }
  // Raster thread and GC: VM timeline (engine Embedder + GC streams).
  final timeline = await service.getVMTimeline(timeOriginMicros: start, timeExtentMicros: end - start);
  final events = [for (final e in timeline.traceEvents ?? const <TimelineEvent>[]) e.json!];
  if (tracePath != null) {
    File(tracePath).writeAsStringSync(jsonEncode({'traceEvents': events, 'displayTimeUnit': 'ms', 'instrumented': true}));
  }
  final threads = <Object, String>{};
  for (final e in events) {
    if (e['ph'] == 'M' && e['name'] == 'thread_name') threads[e['tid']] = '${(e['args'] as Map?)?['name']}';
  }
  final spans = <(Object, String, String, int, int, int?)>[]; // tid, cat, name, start, end, tdur
  final open = <Object, List<Map>>{};
  var earliest = 1 << 62;
  for (final e in events) {
    final ts = e['ts'];
    if (ts is! int) continue;
    if (ts < earliest) earliest = ts;
    final Object tid = e['tid'] ?? 0;
    switch (e['ph']) {
      case 'X':
        final dur = (e['dur'] as num?)?.toInt() ?? 0;
        spans.add((tid, '${e['cat']}', '${e['name']}', ts, ts + dur, _tdur(e)));
      case 'B':
        open.putIfAbsent(tid, () => []).add(e);
      case 'E':
        final stack = open[tid];
        if (stack != null && stack.isNotEmpty) {
          final b = stack.removeLast();
          spans.add((tid, '${b['cat']}', '${b['name']}', b['ts'] as int, ts, _pairTdur(b, e)));
        }
    }
  }
  final uiTids = {for (final e in threads.entries) if (_isUiThread(e.value)) e.key};
  final rasterTids = {for (final e in threads.entries) if (_isRasterThread(e.value)) e.key};
  int spansOn(Set<Object> tids, {bool withTdur = false}) => spans
      .where((span) => tids.contains(span.$1) && (!withTdur || span.$6 != null))
      .length;
  int withTts(Set<Object> tids) =>
      events.where((e) => e['ph'] != 'M' && tids.contains(e['tid']) && e['tts'] is num).length;
  result['threadTime'] = {
    'collected': true,
    'uiThreads': [for (final id in uiTids) threads[id]].whereType<String>().toList(),
    'rasterThreads': [for (final id in rasterTids) threads[id]].whereType<String>().toList(),
    'uiEvents': spansOn(uiTids),
    'uiEventsWithTdur': spansOn(uiTids, withTdur: true),
    'uiEventsWithTts': withTts(uiTids),
    'rasterEvents': spansOn(rasterTids),
    'rasterEventsWithTdur': spansOn(rasterTids, withTdur: true),
    'rasterEventsWithTts': withTts(rasterTids),
  };
  final frameThreadTime = <Map<String, Object?>>[];
  for (final raw in data['frames'] as List? ?? const []) {
    final span = (raw as List).cast<num>();
    if (span.length < 4) continue;
    final b = span[0].toInt();
    final rs = span[2].toInt();
    final uiMatch = _outerSpan(spans, uiTids, b);
    final rasterMatch = _outerSpan(spans, rasterTids, rs);
    frameThreadTime.add({
      'b': b,
      if (uiMatch != null && uiMatch.$6 != null) 'uiCpuUs': uiMatch.$6,
      if (uiMatch != null) 'uiEvent': uiMatch.$3,
      if (rasterMatch != null && rasterMatch.$6 != null) 'rasterCpuUs': rasterMatch.$6,
      if (rasterMatch != null) 'rasterEvent': rasterMatch.$3,
    });
  }
  result['frameThreadTime'] = frameThreadTime;
  result['timelineEvents'] = events.length;
  result['timelineCoversStart'] = earliest <= start + 50000;
  result['threads'] = threads.values.toSet().toList();
  final rasterByName = <String, int>{};
  for (final (tid, _, n, s, e, _) in spans) {
    if (rasterTids.isNotEmpty && !rasterTids.contains(tid)) continue;
    for (final w in rasterWindows) {
      final overlap = (e < w[1] ? e : w[1]) - (s > w[0] ? s : w[0]);
      if (overlap > 0) rasterByName.update(n, (v) => v + overlap, ifAbsent: () => overlap);
    }
  }
  result['rasterWorstFrames'] = {'windows': rasterWindows, 'inclusiveUs': _top(rasterByName, 30)};
  final gc = <String, Map<String, num>>{};
  for (final (_, cat, n, s, e, _) in spans) {
    if (cat != 'GC') continue;
    final entry = gc.putIfAbsent(n, () => {'count': 0, 'totalUs': 0, 'maxUs': 0});
    entry['count'] = entry['count']! + 1;
    entry['totalUs'] = entry['totalUs']! + (e - s);
    if (e - s > entry['maxUs']!) entry['maxUs'] = e - s;
  }
  result['gcEvents'] = gc;
  result['gcInWorstUiFrames'] = [
    for (final (_, cat, n, s, e, _) in spans)
      if (cat == 'GC' && uiWindows.any((w) => s <= w[1] && e >= w[0])) {'name': n, 'us': e - s},
  ];
  return result;
}

bool _isRasterThread(String name) => name.toLowerCase().contains('raster');

bool _isUiThread(String name) {
  final n = name.toLowerCase();
  if (_isRasterThread(n)) return false;
  // Android names the engine UI thread `1.ui (tid)`. The id suffix is not part
  // of the thread name the matcher should see.
  final bare = n.replaceAll(RegExp(r'\s*\(\d+\)\s*$'), '');
  return bare == 'ui' || bare.endsWith('.ui') || bare.endsWith(' ui');
}

int? _tdur(Map event) {
  final value = event['tdur'];
  return value is num ? value.toInt() : null;
}

/// Thread CPU of a begin/end pair. `tts` on both ends is the thread clock.
int? _pairTdur(Map begin, Map end) {
  final b = begin['tts'];
  final e = end['tts'];
  if (b is num && e is num) return e.toInt() - b.toInt();
  return _tdur(end);
}

typedef _Span = (Object, String, String, int, int, int?);

/// The longest event on [tids] that starts within 2 ms of [start].
/// Its `tdur` is that frame's thread CPU time when the timeline recorded one.
const _desktopDevices = {'linux', 'macos', 'windows', 'chrome', 'edge', 'web-server'};

/// utime+stime for one thread, from `/proc/<pid>/task/<tid>/stat`.
class _ProcRead {
  const _ProcRead({
    this.pid,
    this.threads = const {},
    this.error,
    this.sampleNs,
    this.reads = const {},
    this.processStartTicks,
    this.executable,
    this.mappedAot = const [],
  });
  final int? pid;
  final Map<int, ({String comm, int ns})> threads;
  final String? error;
  final int? sampleNs;
  final Map<int, Map<String, Object?>> reads;
  final int? processStartTicks;
  final String? executable;
  final List<String> mappedAot;
}

int _startTicks(String path) {
  final stat = File('$path/stat').readAsStringSync();
  return int.parse(
    stat.substring(stat.lastIndexOf(')') + 2).split(RegExp(r'\s+'))[19],
  );
}

List<int> _allowedCpus(String path) {
  final text = File('$path/status').readAsStringSync();
  final value = RegExp(
    r'^Cpus_allowed_list:\s*(.+)$',
    multiLine: true,
  ).firstMatch(text)!.group(1)!;
  final cpus = <int>{};
  for (final part in value.trim().split(',')) {
    final limits = part.split('-').map(int.parse).toList();
    for (var i = limits.first; i <= limits.last; i++) {
      cpus.add(i);
    }
  }
  return cpus.toList()..sort();
}

/// Bracket each actual counter read, and read the same TID's affinity and
/// start time. A process-level affinity snapshot cannot prove either role.
_ProcRead _readLocalSchedstat(int? pid) {
  if (pid == null) return const _ProcRead(error: 'vm pid missing');
  try {
    final root = Directory('/proc/$pid/task');
    if (!root.existsSync()) {
      return _ProcRead(pid: pid, error: '/proc/$pid/task missing');
    }
    final entries = root.listSync();
    // After the directory listing, so this stamp sits on the schedstat reads.
    final sampleNs = hostMonotonicNs();
    final threads = <int, ({String comm, int ns})>{};
    final reads = <int, Map<String, Object?>>{};
    for (final entry in entries) {
      final tid = int.tryParse(
        entry.uri.pathSegments.where((s) => s.isNotEmpty).last,
      );
      if (tid == null) continue;
      final schedFile = File('${entry.path}/schedstat');
      final commFile = File('${entry.path}/comm');
      if (!schedFile.existsSync() || !commFile.existsSync()) continue;
      final comm = commFile.readAsStringSync().trim();
      final cpus = _allowedCpus(entry.path);
      final startTicks = _startTicks(entry.path);
      final before = hostMonotonicNs();
      final raw = schedFile.readAsStringSync();
      final after = hostMonotonicNs();
      final ns = int.tryParse(raw.trim().split(RegExp(r'\s+')).first);
      if (ns == null) continue;
      threads[tid] = (comm: comm, ns: ns);
      reads[tid] = {
        'beforeNs': before,
        'afterNs': after,
        'cpus': cpus,
        'startTicks': startTicks,
      };
    }
    return _ProcRead(
      pid: pid,
      threads: threads,
      sampleNs: sampleNs,
      reads: reads,
      processStartTicks: _startTicks('/proc/$pid'),
      executable: File('/proc/$pid/exe').resolveSymbolicLinksSync(),
      mappedAot: File('/proc/$pid/maps')
          .readAsLinesSync()
          .where((line) => line.contains('/lib/libapp.so'))
          .map((line) => line.substring(line.indexOf('/')))
          .toSet()
          .toList(),
    );
  } catch (error) {
    return _ProcRead(pid: pid, error: '$error');
  }
}

bool _androidDevice() {
  final device = Platform.environment['RAFT_LAB_DEVICE'] ?? '';
  return device.isNotEmpty && !_desktopDevices.contains(device);
}

/// Scene CPU from `schedstat` field 0, nanoseconds on CPU. `utime`/`stime`
/// move in 10 ms steps, which is too coarse for a short scene. The VM
/// timeline on this build has no `tts` or `tdur`. Linux desktop names the
/// engine threads `io.flutter.ui` and `io.flutter.raster`. The kernel keeps
/// 15 characters, so the raster name arrives as `io.flutter.rast`. Android
/// merges the UI task onto the platform thread, so a missing UI name falls
/// back to the main thread.
Map<String, Object?> _procSceneCpu({
  required Map<int, ({String comm, int ns})>? startThreads,
  required int? startPid,
  required String? startError,
  required _ProcRead end,
  _ProcRead? opened,
  required String window,
  required int? windowMs,
}) {
  if (startError != null || startThreads == null || startPid == null) {
    return {
      'source': 'proc-schedstat',
      'collected': false,
      'error': startError ?? 'no start snapshot',
    };
  }
  if (end.error != null || end.threads.isEmpty || end.pid == null) {
    return {
      'source': 'proc-schedstat',
      'collected': false,
      'error': end.error ?? 'no end snapshot',
    };
  }
  if (opened?.processStartTicks != null &&
      (opened!.pid != end.pid ||
          opened.processStartTicks != end.processStartTicks ||
          opened.executable != end.executable)) {
    return {
      'source': 'proc-schedstat',
      'collected': false,
      'error': 'process identity changed',
    };
  }
  Map<String, Object?> role(
    bool Function(String comm) match, {
    required bool mainThreadFallback,
  }) {
    var named = [
      for (final entry in end.threads.entries)
        if (match(entry.value.comm) && startThreads.containsKey(entry.key))
          entry.key,
    ];
    var matchedBy = 'name';
    if (named.isEmpty &&
        mainThreadFallback &&
        startThreads.containsKey(end.pid) &&
        end.threads.containsKey(end.pid)) {
      named = [end.pid!];
      matchedBy = 'main-thread';
    }
    if (named.isEmpty) return {'missing': true};
    return {
      ..._procDelta(startThreads, end.threads, named, matchedBy),
      if (named.length == 1 && opened?.reads[named.single] != null)
        'start': opened!.reads[named.single],
      if (named.length == 1 && end.reads[named.single] != null)
        'end': end.reads[named.single],
    };
  }

  return {
    'source': 'proc-schedstat',
    'collected': true,
    'pid': end.pid,
    if (end.processStartTicks != null)
      'processStartTicks': end.processStartTicks,
    if (end.executable != null) 'executable': end.executable,
    if (end.mappedAot.isNotEmpty) 'mappedAot': end.mappedAot,
    'window': window,
    'windowMs': ?windowMs,
    'ui': role(_commIsUi, mainThreadFallback: true),
    'raster': role(_commIsRaster, mainThreadFallback: false),
  };
}

Map<String, Object?> _procDelta(
  Map<int, ({String comm, int ns})> start,
  Map<int, ({String comm, int ns})> end,
  List<int> tids,
  String matchedBy,
) {
  var ns = 0;
  for (final tid in tids) {
    ns += end[tid]!.ns - start[tid]!.ns;
  }
  return {
    'tid': tids.length == 1 ? tids.single : tids,
    'comm': tids.map((tid) => end[tid]!.comm).join(','),
    'matchedBy': matchedBy,
    'ns': ns,
    'ms': ns / 1000000,
  };
}

/// Keyboard-window build, layout and paint counts for one round.
///
/// The scenario JSON is overwritten every round, so the series has to be
/// appended here. Frame selection matches `frames_in`: `t0 <= begin < t1`.
void _appendKeyboardCounts(
  Directory out,
  Map<String, dynamic> record, {
  required String batch,
  required int? round,
  required bool warmup,
}) {
  final episodes = record['keyboard'];
  final frames = record['frames'];
  if (episodes is! List || frames is! List) {
    return;
  }
  final selected = <Map<dynamic, dynamic>>[];
  for (final episode in episodes) {
    if (episode is! Map) {
      continue;
    }
    final t0 = episode['t0'];
    final t1 = episode['t1'];
    if (t0 is! num || t1 is! num) {
      continue;
    }
    for (final frame in frames) {
      if (frame is! Map) {
        continue;
      }
      final begin = frame['b'];
      if (begin is! num || begin < t0 || begin >= t1) {
        continue;
      }
      selected.add(frame);
    }
  }
  List<int>? series(String key) {
    final values = <int>[];
    for (final frame in selected) {
      final value = frame[key];
      if (value is! num) {
        return null;
      }
      values.add(value.toInt());
    }
    return values;
  }

  final line = <String, Object?>{
    'batch': batch,
    'round': round,
    'warmup': warmup,
    'fixtureReset': false,
    'frames': selected.length,
    'builds': series('builds'),
    'layouts': series('layouts'),
    'paints': series('paints'),
  };
  File('${out.path}/count-rounds.jsonl').writeAsStringSync('${jsonEncode(line)}\n', mode: FileMode.append);
}

/// The first three fields of `/proc/loadavg`, or null when the host has none.
String? _loadAvg() {
  final file = File('/proc/loadavg');
  if (!file.existsSync()) return null;
  final parts = file.readAsStringSync().trim().split(RegExp(r'\s+'));
  if (parts.length < 3) return null;
  return '${parts[0]} ${parts[1]} ${parts[2]}';
}

bool _commIsRaster(String comm) {
  final name = comm.toLowerCase();
  // TASK_COMM_LEN keeps 15 characters, so io.flutter.raster is io.flutter.rast.
  return name == '1.raster' || name.endsWith('.raster') || name == 'io.flutter.rast';
}

bool _commIsUi(String comm) {
  final name = comm.toLowerCase();
  if (_commIsRaster(name)) return false;
  return name == '1.ui' || name.endsWith('.ui');
}

Future<_ProcRead> _readProcThreads(VmService service) async {
  final vm = await service.getVM();
  final pid = vm.pid;
  if (pid == null) return const _ProcRead(error: 'vm pid missing');
  try {
    if (_androidDevice()) {
      final serial = Platform.environment['RAFT_LAB_DEVICE']!;
      final package = await _androidPackage(serial, pid);
      if (package == null) {
        return _ProcRead(pid: pid, error: 'run-as package for pid $pid not found');
      }
      final script = 'for d in /proc/$pid/task/*; do comm=\$(cat \$d/comm | tr -d "\\n"); ns=\$(cut -d" " -f1 \$d/schedstat); echo "\$(basename \$d) \$comm \$ns"; done';
      final raw = await _adbShell(serial, "run-as $package sh -c '$script'");
      return _ProcRead(pid: pid, threads: _parseSchedDump(raw));
    }
    final threads = <int, ({String comm, int ns})>{};
    final root = Directory('/proc/$pid/task');
    if (!root.existsSync()) return _ProcRead(pid: pid, error: '/proc/$pid/task missing');
    for (final entry in root.listSync()) {
      final tid = int.tryParse(entry.uri.pathSegments.where((s) => s.isNotEmpty).last);
      if (tid == null) continue;
      final commFile = File('${entry.path}/comm');
      final schedFile = File('${entry.path}/schedstat');
      if (!commFile.existsSync() || !schedFile.existsSync()) continue;
      final ns = int.tryParse(schedFile.readAsStringSync().trim().split(RegExp(r'\s+')).first);
      if (ns == null) continue;
      threads[tid] = (comm: commFile.readAsStringSync().trim(), ns: ns);
    }
    return _ProcRead(pid: pid, threads: threads);
  } catch (error) {
    return _ProcRead(pid: pid, error: '$error');
  }
}

Future<String?> _androidPackage(String serial, int pid) async {
  final preferred = Platform.environment['RAFT_LAB_APP_ID'];
  final names = <String>[
    if (preferred != null && preferred.isNotEmpty) preferred,
    'app.raft.raft_flutter.linkperf',
    'app.raft.raft_flutter',
  ];
  for (final name in names.toSet()) {
    // pidof exits 1 when the package is not running. That is not a read failure.
    final result = await Process.run('adb', ['-s', serial, 'shell', 'pidof', name]);
    final text = result.stdout.toString().replaceAll('\r', ' ');
    if (text.split(RegExp(r'\s+')).contains('$pid')) return name;
  }
  return null;
}

Future<String> _adbShell(String serial, String command) async {
  final result = await Process.run('adb', ['-s', serial, 'shell', command]);
  final out = result.stdout.toString().replaceAll('\r', '');
  if (result.exitCode != 0) {
    throw StateError(result.stderr.toString().trim().isEmpty ? out.trim() : result.stderr.toString().trim());
  }
  return out;
}

Map<int, ({String comm, int ns})> _parseSchedDump(String raw) {
  final threads = <int, ({String comm, int ns})>{};
  for (final line in raw.split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 3) continue;
    final tid = int.tryParse(parts[0]);
    final ns = int.tryParse(parts[2]);
    if (tid == null || ns == null || parts[1].isEmpty) continue;
    threads[tid] = (comm: parts[1], ns: ns);
  }
  return threads;
}

_Span? _outerSpan(List<_Span> spans, Set<Object> tids, int start) {
  _Span? best;
  var bestDur = -1;
  for (final span in spans) {
    if (!tids.contains(span.$1)) continue;
    if (span.$4 < start - 2000 || span.$4 > start + 2000) continue;
    final dur = span.$5 - span.$4;
    if (dur > bestDur) {
      bestDur = dur;
      best = span;
    }
  }
  return best;
}
