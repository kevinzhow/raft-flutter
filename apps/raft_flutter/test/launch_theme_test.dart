import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus_platform_interface.dart';
import 'package:raft_flutter/platform/app_icon.dart';
import 'package:raft_flutter/platform/launch_theme.dart';
import 'package:raft_ui/raft_ui.dart';

class _IconApi extends FlutterDynamicIconPlusPlatform {
  String? actual = 'app.raft.raft_flutter.IconYellow';
  bool fail = false;
  @override
  Future<bool> get supportsAlternateIcons async => true;
  @override
  Future<String?> get alternateIconName async => actual;
  @override
  Future<void> setAlternateIconName({
    String? iconName,
    List<String> blacklistBrands = const [],
    List<String> blacklistManufactures = const [],
    List<String> blacklistModels = const [],
    bool isSilent = false,
  }) async {
    if (fail) throw PlatformException(code: 'rejected');
    actual = iconName;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.raft/launch-theme');
  final calls = <MethodCall>[];
  Future<Object?> Function(MethodCall)? handler;

  setUp(() {
    calls.clear();
    handler = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return handler?.call(call);
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'Android receives the stored mode; the retired family is null',
    () async {
      final launch = NativeLaunchTheme(
        platformOverride: TargetPlatform.android,
      );
      await launch.set(const RaftAppearance(mode: ThemeMode.dark));
      await launch.set(const RaftAppearance());
      expect(calls.map((c) => c.method), ['set', 'set']);
      expect(calls[0].arguments, {'mode': 'dark', 'light': null});
      expect(calls[1].arguments, {'mode': 'system', 'light': null});
    },
  );

  test('other platforms never touch the channel', () async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      final launch = NativeLaunchTheme(platformOverride: platform);
      await launch.set(const RaftAppearance());
      await launch.refresh();
    }
    expect(calls, isEmpty);
  });

  test('a native failure or missing plugin never breaks the caller', () async {
    final launch = NativeLaunchTheme(platformOverride: TargetPlatform.android);
    handler = (_) async => throw PlatformException(code: 'boom');
    await launch.set(const RaftAppearance());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await launch.refresh();
  });

  group('icon changes refresh the native splash theme', () {
    late _IconApi api;
    late NativeAppIcon icons;
    setUp(() {
      api = _IconApi();
      icons = NativeAppIcon(
        api: api,
        platformOverride: TargetPlatform.android,
        launchTheme: NativeLaunchTheme(platformOverride: TargetPlatform.android),
      );
    });
    tearDown(() => icons.dispose());

    test('after a confirmed change, not after a rejected one', () async {
      await icons.refresh();
      api.fail = true;
      await icons.select(RaftAppIconPalette.pink);
      expect(calls, isEmpty);
      expect(icons.selected, RaftAppIconPalette.yellow);
      api.fail = false;
      await icons.select(RaftAppIconPalette.pink);
      expect(icons.selected, RaftAppIconPalette.pink);
      expect(calls.map((c) => c.method), ['refresh']);
    });
  });
}
