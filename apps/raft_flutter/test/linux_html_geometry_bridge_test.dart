import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/attachment_html_linux_geometry.dart';
import 'package:raft_system_webview/raft_system_webview.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const native = MethodChannel('app.raft/system_webview/7');
  const codec = StandardMethodCodec();
  final calls = <MethodCall>[];
  late SystemWebViewController system;
  late LinuxAttachmentHtmlGeometryController geometry;
  var allowed = true;
  setUp(() async {
    calls.clear();
    allowed = true;
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      (_) async => {
        'id': 7,
        'protocol': 1,
        'ephemeral': true,
        'sandboxed': true,
      },
    );
    messenger.setMockMethodCallHandler(native, (call) async {
      calls.add(call);
      return null;
    });
    system = await SystemWebViewController.create();
    geometry = LinuxAttachmentHtmlGeometryController(
      uri: Uri.parse('https://fixture.invalid/preview'),
      system: system,
      allowed: () => allowed,
    );
  });
  tearDown(() async {
    geometry.dispose();
    await system.dispose();
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      null,
    );
    messenger.setMockMethodCallHandler(native, null);
  });
  Future<void> event(Map<String, Object?> fields) =>
      messenger.handlePlatformMessage(
        native.name,
        codec.encodeMethodCall(MethodCall('event', fields)),
        (_) {},
      );
  Map<String, Object?> input() => {
    'type': 'regionInput',
    'generation': 3,
    'sequence': 8,
    'phase': 'up',
    'position': [0.25, 0.5],
    'delta': [0, 0],
    'viewport': [400, 300],
  };

  test('real native input keeps SDK generation, sequence, viewport and normalized coordinates', () async {
    final events = <RaftHtmlNativeRegionInput>[];
    final subscription = geometry.nativeRegionInputs.listen(events.add);
    await event(input());
    expect(events.single.generation, 3);
    expect(events.single.sequence, 8);
    expect(events.single.viewport, const Size(400, 300));
    expect(events.single.position, const Offset(.25, .5));
    expect(events.single.phase, RaftHtmlNativeRegionPhase.up);
    await subscription.cancel();
  });

  test('hostile shape, stale retired adapter and page-like events never cross the typed boundary', () async {
    final events = <RaftHtmlNativeRegionInput>[];
    final subscription = geometry.nativeRegionInputs.listen(events.add);
    for (final change in <Map<String, Object?>>[
      {'type': 'pageMessage'},
      {'generation': 0},
      {'sequence': -1},
      {'phase': 'tap'},
      {
        'position': [1.1, .2],
      },
      {
        'position': [double.nan, .2],
      },
      {
        'viewport': [0, 300],
      },
      {
        'delta': ['0', 0],
      },
      {'position': []},
    ]) {
      await event({...input(), ...change});
    }
    allowed = false;
    await event(input());
    geometry.dispose();
    allowed = true;
    await event(input());
    expect(events, isEmpty);
    await subscription.cancel();
  });

  test('canonical paint bytes and recipe fields cross unchanged, without native styling', () async {
    final png = Uint8List.fromList([1, 2, 3, 4]);
    geometry.updateNativeRegionOverlay(
      RaftHtmlNativeRegionOverlay(
        generation: 4,
        sequence: 9,
        viewport: const Size(400, 300),
        captureEnabled: true,
        markers: const [
          RaftHtmlNativeRegionMarker(
            rect: Rect.fromLTWH(.1, .2, .3, .4),
            fill: Color(0x80112233),
            border: Color(0xff445566),
            strokeWidth: 1,
            radius: 2,
            dashed: true,
            borderSegments: [Rect.fromLTWH(.1, .2, .02, .01)],
            progress: .25,
          ),
        ],
        hint: RaftHtmlNativeRegionHint(
          png: png,
          logicalSize: const Size(120, 32),
          logicalOffset: const Offset(140, 12),
        ),
      ),
    );
    await Future<void>.value();
    final call = calls.singleWhere((call) => call.method == 'regionOverlay');
    final data = call.arguments as Map;
    expect(data['generation'], 4);
    expect(data['sequence'], 9);
    expect(data['viewport'], [400.0, 300.0]);
    final marker = (data['markers'] as List).single as Map;
    expect(
      marker['rect'],
      orderedEquals([
        closeTo(.1, 1e-12),
        closeTo(.2, 1e-12),
        closeTo(.3, 1e-12),
        closeTo(.4, 1e-12),
      ]),
    );
    expect(marker['fillARGB'], 0x80112233);
    expect(marker['borderARGB'], 0xff445566);
    expect(
      (marker['borderSegments'] as List).single,
      orderedEquals([
        closeTo(.1, 1e-12),
        closeTo(.2, 1e-12),
        closeTo(.02, 1e-12),
        closeTo(.01, 1e-12),
      ]),
    );
    expect((data['hint'] as Map)['png'], png);
    expect((data['hint'] as Map)['logicalSize'], [120.0, 32.0]);
    expect(calls.map((call) => call.method), ['regionOverlay']);
  });

  test('an inactive zero-size retirement is transported and a disposed renderer receives nothing', () async {
    const clear = RaftHtmlNativeRegionOverlay(
      generation: 5,
      sequence: 1,
      viewport: Size.zero,
      captureEnabled: false,
    );
    geometry.updateNativeRegionOverlay(clear);
    await Future<void>.value();
    expect((calls.single.arguments as Map)['markers'], isEmpty);
    expect((calls.single.arguments as Map)['hint'], isNull);
    await system.dispose();
    final count = calls.length;
    geometry.updateNativeRegionOverlay(clear);
    await Future<void>.value();
    expect(calls.length, count);
  });
}
