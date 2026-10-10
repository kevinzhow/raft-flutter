// Samples the benchmark app's main isolate CPU during the channel scroll.
// Usage: dart run test_driver/cpu_profile.dart <runner.log> <outDir> <theme>
import 'dart:convert';
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  final log = File(args[0]), out = Directory(args[1]), theme = args[2];
  final pattern = RegExp(r'Connecting to Flutter application at (http://\S+)');
  String? http;
  while (http == null) {
    if (log.existsSync()) http = pattern.firstMatch(log.readAsStringSync())?.group(1);
    if (http == null) await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  final ws = '${http.replaceFirst('http://', 'ws://')}ws';
  final service = await vmServiceConnectUri(ws);
  final vm = await service.getVM();
  final load = File('${out.path}/$theme-load.json');
  while (!load.existsSync()) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  // Initial publication diagnostic and screenshot precede the scroll sample.
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  final isolate = vm.isolates!.firstWhere((i) => i.name == 'main');
  await service.clearCpuSamples(isolate.id!);
  await Future<void>.delayed(const Duration(seconds: 9));
  final samples = await service.getCpuSamples(isolate.id!, 0, 1 << 62);
  final functions = samples.functions!;
  final self = <String, int>{}, inclusive = <String, int>{}, app = <String, int>{};
  bool ours(int i) {
    final url = functions[i].resolvedUrl ?? '';
    return url.contains('/raft-flutter/') &&
        !url.contains('/build/') &&
        !url.contains('flutter-sdks');
  }

  String name(int i) {
    final f = functions[i];
    final fn = f.function;
    final n = fn is FuncRef ? fn.name : (fn is NativeFunction ? fn.name : '$fn');
    final owner = fn is FuncRef && fn.owner is ClassRef ? '${(fn.owner as ClassRef).name}.' : '';
    final url = (f.resolvedUrl ?? '').split('/').last;
    return '$owner$n ($url)';
  }

  for (final s in samples.samples!) {
    final stack = s.stack!;
    if (stack.isEmpty) continue;
    self.update(name(stack.first), (v) => v + 1, ifAbsent: () => 1);
    for (final f in {for (final i in stack) name(i)}) {
      inclusive.update(f, (v) => v + 1, ifAbsent: () => 1);
    }
    for (final f in {for (final i in stack) if (ours(i)) name(i)}) {
      app.update(f, (v) => v + 1, ifAbsent: () => 1);
    }
  }
  List<Map<String, Object>> top(Map<String, int> m) => (m.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      .take(60)
      .map((e) => {'samples': e.value, 'name': e.key})
      .toList();
  File('${out.path}/$theme-cpu-profile.json').writeAsStringSync(
    const JsonEncoder.withIndent(' ').convert({
      'total': samples.samples!.length,
      'self': top(self),
      'inclusive': top(inclusive),
      'appInclusive': top(app),
    }),
  );
  await service.dispose();
  exit(0);
}
