// Desktop counterpart of resource_release_main.dart: drives the production app
// through the heavy-resource scenario and records the process's own RSS/PSS
// (/proc/self) at each step. With software rendering the GPU textures are in
// the process too, so releases are visible.
//
//   python3 server.py 8792 &
//   xvfb-run -a -s "-screen 0 1440x900x24" tool/flutter test -d linux \
//     integration_test/resource_release_linux_test.dart \
//     --dart-define=RR_BASE=http://127.0.0.1:8792 --dart-define=RR_OUT=/tmp/x.jsonl
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/platform/memory_release.dart';
import 'package:raft_flutter/platform/system_fonts.dart';

import 'resource_release_main.dart';

const _out = String.fromEnvironment('RR_OUT');

Map<String, int> _memory() {
  final status = File('/proc/self/status').readAsStringSync();
  final rollup = File('/proc/self/smaps_rollup').readAsStringSync();
  int kb(String text, String key) {
    final m = RegExp('^$key:\\s+(\\d+) kB', multiLine: true).firstMatch(text);
    return m == null ? -1 : int.parse(m.group(1)!);
  }

  return {
    'rss_kb': kb(status, 'VmRSS'),
    'pss_kb': kb(rollup, 'Pss'),
    'anon_kb': kb(rollup, 'Pss_Anon'),
    'file_kb': kb(rollup, 'Pss_File'),
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('resource release scenario', (tester) async {
    await NativeSystemFonts.instance.initialize();
    await initializeSourceTimeFormatting();
    await DevicePreferences.load();
    Future<void> settle(int seconds) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
    }

    void record(String label) {
      final row = {
        'label': label,
        ..._memory(),
        'snapshot': RaftMemoryRelease.instance.snapshot(),
      };
      // ignore: avoid_print
      print('RRMEM ${jsonEncode(row)}');
      if (_out.isNotEmpty) {
        File(_out).writeAsStringSync('${jsonEncode(row)}\n', mode: FileMode.append);
      }
    }

    Future<void> tapText(String text) async {
      await tester.tap(find.text(text).first);
      await tester.pump();
    }

    await binding.setSurfaceSize(const Size(1440, 900));
    final app = await buildResourceReleaseApp(
      mobile: false,
      location: '/s/lab/channel/img',
    );
    await tester.pumpWidget(app);
    await settle(10);
    record('img-open');
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(AttachmentView).first, const Offset(0, 500));
      await settle(2);
    }
    await settle(3);
    record('img-scrolled');
    await tester.tap(find.byType(AttachmentView).at(1));
    await settle(6);
    record('lightbox-open');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(5);
    record('lightbox-closed');
    await tapText('lab-docs');
    await settle(6);
    record('docs-open');
    await tapText('report-0.pdf');
    await settle(8);
    record('pdf-open');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(5);
    record('pdf-closed');
    await tapText('page-1.html');
    await settle(10);
    record('html-open');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(5);
    record('html-closed');
    await tapText('lab-other');
    await settle(6);
    record('other-open');
    await tapText('lab-more');
    await settle(6);
    record('more-open');
    await tapText('lab-img');
    await settle(8);
    record('img-reopen');
    // No frames run while hidden: wait in real time without pumping.
    Future<void> wait(int seconds) => tester.runAsync(
      () => Future<void>.delayed(Duration(seconds: seconds)),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await wait(10);
    record('hidden-10s');
    await wait(30);
    record('hidden-40s');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(6);
    record('resumed');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
