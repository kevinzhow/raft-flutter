import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/artifact_viewer.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/fake_webview.dart';

class _Picker extends FileSelectorPlatform {
  _Picker(this.destination);
  final File destination;
  var calls = 0;
  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    calls++;
    expect(options.suggestedName, 'report.csv');
    return FileSaveLocation(destination.path);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  testWidgets(
    'default Artifact native callback opens picker and writes the real response before saved',
    (t) async {
      WebViewPlatform.instance = FakeWebView(android: true);
      FakeWebView.reset();
      final root = (await t.runAsync(
        () => Directory.systemTemp.createTemp('raft-artifact-default-'),
      ))!;
      final server = (await t.runAsync(
        () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      ))!;
      final report = Uri.parse('http://127.0.0.1:${server.port}/report');
      final bytes = utf8.encode('name,value\n中文,42\n');
      var requests = 0;
      server.listen((request) async {
        requests++;
        expect(
          request.headers.value(HttpHeaders.cookieHeader),
          'artifact_fixture=private',
        );
        expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
        request.response.add(bytes);
        await request.response.close();
      });
      final file = File('${root.path}/selected.csv');
      final picker = _Picker(file), previous = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = picker;
      const channel = MethodChannel('app.raft/artifact-downloads');
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      final messenger = t.binding.defaultBinaryMessenger;
      Map<dynamic, dynamic>? binding;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'attach') {
          binding = Map<dynamic, dynamic>.from(call.arguments as Map);
        }
        return null;
      });
      messenger.setMockMethodCallHandler(paths, (_) async => root.path);
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await t.pump();
        FileSelectorPlatform.instance = previous;
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(paths, null);
        await server.close(force: true);
        await root.delete(recursive: true);
      });
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: ArtifactViewer(
            uri: report,
            api: null,
            onClose: () {},
            page: true,
            webViewBuilder: (_, _) => const Text('Loaded report'),
          ),
        ),
      );
      for (var frame = 0; frame < 5; frame++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 16));
      }
      FakeWebView.finish(report.toString());
      final delivered = Completer<void>();
      await t.runAsync(() async {
        messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('download', {
              'webViewId': 42,
              'bindingId': binding?['bindingId'] ?? 'native-download-fixture',
              'url': report.resolve('/file').toString(),
              'filename': '../../report.csv',
              'mimeType': 'text/csv',
              'cookie': 'artifact_fixture=private',
            }),
          ),
          (_) => delivered.complete(),
        );
        // The pre-fix viewer has no channel handler, so the framework buffers
        // the event without acknowledging it. The file/picker assertions below
        // must report that missing behavior rather than wait indefinitely.
        await delivered.future.timeout(
          const Duration(milliseconds: 250),
          onTimeout: () {},
        );
      });
      for (var frame = 0; frame < 15 && picker.calls == 0; frame++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(
        picker.calls,
        1,
        reason:
            'a native download response must offer a system save destination',
      );
      final end = DateTime.now().add(const Duration(seconds: 10));
      while (find.text('Saved.').evaluate().isEmpty &&
          DateTime.now().isBefore(end)) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('Saved.'), findsOneWidget);
      expect(requests, 1);
      expect(await t.runAsync(file.readAsBytes), bytes);
      expect(
        await t.runAsync(
          () => Directory('${root.path}/staging').list().toList(),
        ),
        isEmpty,
      );
      expect(find.text('Loaded report'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
