import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus_platform_interface.dart';
import 'package:raft_flutter/platform/app_icon.dart';
import 'package:raft_ui/raft_ui.dart';

class IconApi extends FlutterDynamicIconPlusPlatform {
  bool supported = true;
  String? actual = 'app.raft.raft_flutter.IconYellow';
  Future<String?> Function()? read;
  Future<void> Function(String?)? write;
  int writes = 0;
  @override
  Future<bool> get supportsAlternateIcons async => supported;
  @override
  Future<String?> get alternateIconName => read?.call() ?? Future.value(actual);
  @override
  Future<void> setAlternateIconName({
    String? iconName,
    List<String> blacklistBrands = const [],
    List<String> blacklistManufactures = const [],
    List<String> blacklistModels = const [],
    bool isSilent = false,
  }) async {
    expect(isSilent, isFalse);
    writes++;
    if (write != null) {
      await write!(iconName);
    } else {
      actual = iconName;
    }
  }
}

void main() {
  late IconApi api;
  late NativeAppIcon service;
  setUp(() {
    api = IconApi();
    service = NativeAppIcon(api: api, platformOverride: TargetPlatform.android);
  });
  tearDown(() => service.dispose());

  test(
    'reads OS choice and restores packaged default without account state',
    () async {
      api.actual = 'app.raft.raft_flutter.IconPink';
      await service.refresh();
      expect(service.selected, RaftAppIconPalette.pink);
      await service.select(RaftAppIconPalette.yellow);
      expect(api.actual, 'app.raft.raft_flutter.IconYellow');
      expect(service.error, isNull);
    },
  );
  test(
    'held native change disables concurrent writes and keeps current selection',
    () async {
      final pending = Completer<void>();
      api.write = (name) async {
        await pending.future;
        api.actual = name;
      };
      await service.refresh();
      final change = service.select(RaftAppIconPalette.blue);
      await Future<void>.delayed(Duration.zero);
      expect(service.busy, isTrue);
      expect(service.selected, RaftAppIconPalette.yellow);
      await service.select(RaftAppIconPalette.green);
      expect(api.writes, 1);
      pending.complete();
      await change;
      expect(service.selected, RaftAppIconPalette.blue);
      expect(service.busy, isFalse);
    },
  );
  test(
    'OS rejection preserves selection and exposes retryable error',
    () async {
      api.write = (_) async => throw PlatformException(code: 'denied');
      await service.refresh();
      await service.select(RaftAppIconPalette.green);
      expect(service.selected, RaftAppIconPalette.yellow);
      expect(service.error, isNotNull);
      expect(service.busy, isFalse);
    },
  );
  test(
    'readback after partial native failure adopts actual OS state',
    () async {
      api.write = (name) async {
        api.actual = name;
        throw PlatformException(code: 'late_failure');
      };
      await service.refresh();
      await service.select(RaftAppIconPalette.green);
      expect(service.selected, RaftAppIconPalette.green);
      expect(service.error, isNotNull);
    },
  );
  test('late refresh cannot overwrite a successful newer change', () async {
    final stale = Completer<String?>();
    var reads = 0;
    api.read = () async {
      if (++reads == 2) return stale.future;
      return api.actual;
    };
    await service.refresh();
    final refresh = service.refresh();
    await Future<void>.delayed(Duration.zero);
    await service.select(RaftAppIconPalette.white);
    stale.complete('app.raft.raft_flutter.IconYellow');
    await refresh;
    expect(service.selected, RaftAppIconPalette.white);
  });
  test('unsupported host never calls platform API', () async {
    service.dispose();
    service = NativeAppIcon(api: api, platformOverride: TargetPlatform.macOS);
    api.read = () async => fail('Unexpected native call');
    await service.refresh();
    await service.select(RaftAppIconPalette.blue);
    expect(service.mobile, isFalse);
    expect(api.writes, 0);
  });
  test('unknown OS icon cannot commit an unknown palette', () async {
    api.actual = 'unknown';
    await service.refresh();
    expect(service.selected, RaftAppIconPalette.yellow);
    expect(service.supported, isFalse);
    expect(service.error, isNotNull);
  });
  test('iOS default maps to nil and preserves native system alert', () async {
    service.dispose();
    service = NativeAppIcon(api: api, platformOverride: TargetPlatform.iOS);
    api.actual = 'AppIconBlue';
    await service.refresh();
    expect(service.selected, RaftAppIconPalette.blue);
    await service.select(RaftAppIconPalette.yellow);
    expect(api.actual, isNull);
    expect(service.error, isNull);
  });
  test('a native no-op cannot falsely mark a new choice as applied', () async {
    api.write = (_) async {};
    await service.refresh();
    await service.select(RaftAppIconPalette.blue);
    expect(service.selected, RaftAppIconPalette.yellow);
    expect(service.error, isNotNull);
  });
}
