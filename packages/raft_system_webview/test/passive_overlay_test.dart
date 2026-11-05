import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_system_webview/raft_system_webview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('app.raft/system_webview/19');
  final layouts = <Map>[];
  setUp(() {
    layouts.clear();
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      (_) async => {
        'id': 19,
        'protocol': 1,
        'ephemeral': true,
        'sandboxed': true,
        'snapshot': true,
      },
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'layout') layouts.add(call.arguments as Map);
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      null,
    );
    messenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('passive fade never withdraws the original native input frame', (
    tester,
  ) async {
    final controller = await SystemWebViewController.create();
    final overlays = ValueNotifier(0);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 200,
            child: SystemWebView(
              controller: controller,
              visible: true,
              occlusion: overlays,
              isOccluded: (_) => overlays.value == 2,
              isPaintOccluded: (_) => overlays.value != 0,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final originalFrame = layouts.last['frame'];
    final originalClip = layouts.last['clip'];
    overlays.value = 1;
    await tester.pump();
    expect(layouts.last['visible'], true);
    expect(layouts.last['paintOccluded'], true);
    expect(layouts.last['frame'], originalFrame);
    expect(layouts.last['clip'], originalClip);
    // No pumpAndSettle: the passive popup may still be fading when input
    // arrives. Its layout must already retain the same mapped native surface.
    overlays.value = 0;
    await tester.pump();
    expect(layouts.every((layout) => layout['visible'] == true), true);
    expect(layouts.last['paintOccluded'], false);

    overlays.value = 2;
    await tester.pump();
    expect(layouts.last['visible'], false);
    overlays.value = 1;
    await tester.pump();
    expect(layouts.last['visible'], true);
    expect(layouts.last['paintOccluded'], true);
    await tester.pumpWidget(const SizedBox());
    expect(layouts.last['visible'], false);
    await controller.dispose();
    overlays.dispose();
  });

  test(
    'passive visual occlusion changes paint without changing coordinates',
    () {
      Rect? observed;
      final result = SystemWebViewLayout.resolve(
        local: const Rect.fromLTWH(0, 0, 100, 80),
        transform: Matrix4.translationValues(30, 40, 0),
        viewport: const Rect.fromLTWH(0, 0, 800, 600),
        clips: const [],
        scale: 2,
        isPaintOccluded: (rect) {
          observed = rect;
          return true;
        },
      );
      expect(observed, const Rect.fromLTWH(30, 40, 100, 80));
      expect(result.visible, true);
      expect(result.paintOccluded, true);
      expect(result.frame, const Rect.fromLTWH(60, 80, 200, 160));
      expect(result.viewFrame, observed);
      expect(result.data.containsKey('viewFrame'), false);
      expect(result, isNot(SystemWebViewLayout(result.frame, result.clip)));
      expect(result.data['paintOccluded'], true);
    },
  );
}
