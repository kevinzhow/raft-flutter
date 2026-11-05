// GTK owns actual pointer/focus dispatch. These widget cases guard publication
// and retirement of its native input rectangle; they do not synthesize GTK
// events or claim a real first click. html_attachment_qa_main.dart retains the
// native DOM Down/Up/click trusted-order readback for actual runtime acceptance.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/attachment_html_linux.dart';
import 'package:raft_flutter/platform/attachment_html_webview_events.dart';
import 'package:raft_system_webview/raft_system_webview.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const native = MethodChannel('app.raft/system_webview/7');
  const codec = StandardMethodCodec();
  final calls = <MethodCall>[];
  final failures = <String>[];
  final geometry = <RaftHtmlRegionController>[];
  final navigation = <String>[];
  var loads = 0;
  Completer<Map<String, Object?>>? creating;
  var metadata = <String, Object?>{};
  final uri = Uri.parse(
    'http://127.0.0.1:17821/api/attachments/qa/html-preview?previewToken=synthetic',
  );

  setUp(() {
    calls.clear();
    failures.clear();
    geometry.clear();
    navigation.clear();
    loads = 0;
    creating = null;
    metadata = {'id': 7, 'protocol': 1, 'ephemeral': true, 'sandboxed': true};
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      (_) async => creating == null ? metadata : await creating!.future,
    );
    messenger.setMockMethodCallHandler(native, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      null,
    );
    messenger.setMockMethodCallHandler(native, null);
  });
  Future<void> event(
    String type, [
    Map<String, Object?> fields = const {},
  ]) async {
    await messenger.handlePlatformMessage(
      native.name,
      codec.encodeMethodCall(MethodCall('event', {'type': type, ...fields})),
      (_) {},
    );
  }

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: SizedBox(
          width: 300,
          height: 200,
          child: LinuxAttachmentHtmlWebView(
            uri: uri,
            events: AttachmentHtmlWebViewEvents(
              onNavigation: (url) {
                navigation.add(url);
                return false;
              },
              onLoaded: () => loads++,
              onFailed: failures.add,
              onGeometryReady: geometry.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> remove(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'first document and native input publication wait for isolation and load',
    (tester) async {
      await show(tester);
      expect(calls.where((c) => c.method == 'load').single.arguments, {
        'url': uri.toString(),
      });
      expect(
        tester.widget<SystemWebView>(find.byType(SystemWebView)).visible,
        false,
      );
      expect(geometry, isEmpty);
      await event('loaded');
      await tester.pump();
      expect(
        tester.widget<SystemWebView>(find.byType(SystemWebView)).visible,
        true,
      );
      expect(geometry.single.active, true);
      expect(loads, 1);
      await event('loaded');
      await tester.pump();
      expect(loads, 1);
      await remove(tester);
      expect(geometry.single.active, false);
      expect(calls.where((c) => c.method == 'dispose').length, 1);
    },
  );

  testWidgets(
    'first fast mouse gesture is never duplicated through Dart forwarding',
    (tester) async {
      await show(tester);
      await event('loaded');
      await tester.pump();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.down(tester.getCenter(find.byType(SystemWebView)));
      await mouse.moveBy(const Offset(2, 0));
      await mouse.up();
      await tester.pump();
      expect(
        calls.where(
          (c) => [
            'setFocused',
            'setCursorPos',
            'setPointerButton',
            'sendTouchEvent',
          ].contains(c.method),
        ),
        isEmpty,
      );
      expect(calls.where((c) => c.method == 'load').length, 1);
      await remove(tester);
    },
  );

  testWidgets(
    'touch cancellation while loading cannot queue a later native gesture',
    (tester) async {
      await show(tester);
      final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
      await touch.down(tester.getCenter(find.byType(SystemWebView)));
      await touch.moveBy(const Offset(2, 0));
      await touch.cancel();
      await event('loaded');
      await tester.pump();
      expect(
        calls.where(
          (c) => c.method == 'sendTouchEvent' || c.method == 'setPointerButton',
        ),
        isEmpty,
      );
      await remove(tester);
    },
  );

  testWidgets(
    'missing isolation refuses the first request and closes native state',
    (tester) async {
      metadata.remove('sandboxed');
      await show(tester);
      expect(calls.where((c) => c.method == 'load'), isEmpty);
      expect(calls.where((c) => c.method == 'dispose').length, 1);
      expect(failures, ['the system preview could not be isolated']);
      await remove(tester);
    },
  );

  testWidgets(
    'late creation after removal only disposes, without input or fetch',
    (tester) async {
      creating = Completer<Map<String, Object?>>();
      await show(tester);
      await remove(tester);
      creating!.complete(metadata);
      await tester.pump();
      expect(calls.map((c) => c.method), ['dispose']);
      expect(failures, isEmpty);
      expect(loads, 0);
    },
  );

  testWidgets(
    'native failure retires pixels and only current loaded links reach the owner',
    (tester) async {
      await show(tester);
      await event('navigation', {'url': 'https://example.com/'});
      expect(navigation, isEmpty);
      await event('loaded');
      await tester.pump();
      await event('navigation', {'url': 'https://example.com/'});
      expect(navigation, ['https://example.com/']);
      await event('failed');
      await tester.pump();
      expect(
        tester.widget<SystemWebView>(find.byType(SystemWebView)).visible,
        false,
      );
      await event('navigation', {'url': 'https://example.com/late'});
      await event('loaded');
      expect(navigation, ['https://example.com/']);
      expect(loads, 1);
      expect(failures.length, 1);
      await remove(tester);
    },
  );

  testWidgets(
    'late native events after dispose cannot revive readiness or dispatch a link',
    (tester) async {
      await show(tester);
      await event('loaded');
      await tester.pump();
      await remove(tester);
      await event('failed');
      await event('loaded');
      await event('navigation', {'url': 'https://example.com/late'});
      expect(loads, 1);
      expect(failures, isEmpty);
      expect(navigation, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
