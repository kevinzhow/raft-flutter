import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _invokePlatformMethod(MethodCall call) async {
  final codec = const StandardMethodCodec();
  final completer = Completer<ByteData?>();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'desktop_drop',
    codec.encodeMethodCall(call),
    completer.complete,
  );
  await completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DesktopDrop.instance.init();
    // Never reach for the real session bus unless a test opts in.
    DesktopDrop.instance.portalResolver = (key) async => const [];
    DesktopDrop.instance.inFlatpak = () => false;
    DesktopDrop.instance.pathExists = (_) => true;
  });

  test('linux drop keeps non-file uri path', () async {
    final events = <DropEvent>[];
    void listener(DropEvent event) => events.add(event);
    DesktopDrop.instance.addRawDropEventListener(listener);
    addTearDown(
        () => DesktopDrop.instance.removeRawDropEventListener(listener));

    await _invokePlatformMethod(const MethodCall('performOperation_linux', [
      'smb://server/share/file.txt',
      [1.0, 2.0]
    ]));

    final event = events.single as DropDoneEvent;
    expect(event.files.single.path, 'smb://server/share/file.txt');
  });

  test('linux drop still converts file uri to local path', () async {
    final events = <DropEvent>[];
    void listener(DropEvent event) => events.add(event);
    DesktopDrop.instance.addRawDropEventListener(listener);
    addTearDown(
        () => DesktopDrop.instance.removeRawDropEventListener(listener));

    await _invokePlatformMethod(const MethodCall('performOperation_linux', [
      'file:///tmp/file.txt',
      [3.0, 4.0]
    ]));

    final event = events.single as DropDoneEvent;
    expect(event.files.single.path, '/tmp/file.txt');
  });

  test('linux drop includes rawText for multiple files with portal key',
      () async {
    final events = <DropEvent>[];
    void listener(DropEvent event) => events.add(event);
    DesktopDrop.instance.addRawDropEventListener(listener);
    addTearDown(
        () => DesktopDrop.instance.removeRawDropEventListener(listener));

    // Multiple files delivered via text/uri-list (no portal key)
    await _invokePlatformMethod(const MethodCall('performOperation_linux', [
      'file:///home/user/Documents/file1.txt\nfile:///home/user/Pictures/photo.png',
      [150.0, 250.0]
    ]));

    final event = events.single as DropDoneEvent;
    expect(event.files.length, 2);
    expect(event.files[0].path, '/home/user/Documents/file1.txt');
    expect(event.files[1].path, '/home/user/Pictures/photo.png');
    expect(event.rawText,
        'file:///home/user/Documents/file1.txt\nfile:///home/user/Pictures/photo.png');
  });

  test('linux drop rawText contains only file URIs (no portal key)', () async {
    final events = <DropEvent>[];
    void listener(DropEvent event) => events.add(event);
    DesktopDrop.instance.addRawDropEventListener(listener);
    addTearDown(
        () => DesktopDrop.instance.removeRawDropEventListener(listener));

    // Normal drag from non-sandboxed app (no portal)
    await _invokePlatformMethod(const MethodCall('performOperation_linux', [
      'file:///home/user/Downloads/normal.txt\nfile:///home/user/Downloads/another.txt',
      [50.0, 60.0]
    ]));

    final event = events.single as DropDoneEvent;
    expect(event.files.length, 2);
    expect(event.files[0].path, '/home/user/Downloads/normal.txt');
    expect(event.files[1].path, '/home/user/Downloads/another.txt');
    // rawText still captured (may be used by consumers)
    expect(event.rawText,
        'file:///home/user/Downloads/normal.txt\nfile:///home/user/Downloads/another.txt');
  });

  test('linux drop with non-file URI (SMB) still works and rawText captured',
      () async {
    final events = <DropEvent>[];
    void listener(DropEvent event) => events.add(event);
    DesktopDrop.instance.addRawDropEventListener(listener);
    addTearDown(
        () => DesktopDrop.instance.removeRawDropEventListener(listener));

    await _invokePlatformMethod(const MethodCall('performOperation_linux', [
      'smb://server/share/document.pdf',
      [10.0, 20.0]
    ]));

    final event = events.single as DropDoneEvent;
    expect(event.files.single.path, 'smb://server/share/document.pdf');
    expect(event.rawText, 'smb://server/share/document.pdf');
  });

  test('linux drop decodes percent-encoded filenames', () async {
    final events = <DropEvent>[];
    void listener(DropEvent event) => events.add(event);
    DesktopDrop.instance.addRawDropEventListener(listener);
    addTearDown(
        () => DesktopDrop.instance.removeRawDropEventListener(listener));

    await _invokePlatformMethod(const MethodCall('performOperation_linux', [
      'file:///home/user/my%20file.txt',
      [5.0, 5.0]
    ]));

    final event = events.single as DropDoneEvent;
    expect(event.files.single.path, '/home/user/my file.txt');
    expect(event.rawText, 'file:///home/user/my%20file.txt');
  });

  test('linux drop tolerates trailing blank line in payload', () async {
    final events = <DropEvent>[];
    void listener(DropEvent event) => events.add(event);
    DesktopDrop.instance.addRawDropEventListener(listener);
    addTearDown(
        () => DesktopDrop.instance.removeRawDropEventListener(listener));

    await _invokePlatformMethod(const MethodCall('performOperation_linux', [
      'file:///home/user/a.txt\nfile:///home/user/b.txt\n',
      [1.0, 1.0]
    ]));

    final event = events.single as DropDoneEvent;
    expect(event.files.length, 2);
    expect(event.files[0].path, '/home/user/a.txt');
    expect(event.files[1].path, '/home/user/b.txt');
    expect(event.rawText, 'file:///home/user/a.txt\nfile:///home/user/b.txt\n');
  });

  test('linux portal drop returns portal key in rawText with no files',
      () async {
    final events = <DropEvent>[];
    void listener(DropEvent event) => events.add(event);
    DesktopDrop.instance.addRawDropEventListener(listener);
    addTearDown(
        () => DesktopDrop.instance.removeRawDropEventListener(listener));

    // Portal key delivered via application/vnd.portal.filetransfer target
    await _invokePlatformMethod(const MethodCall('performOperation_portal', [
      'abc123portalkey456',
      [100.0, 200.0]
    ]));

    final event = events.single as DropDoneEvent;
    expect(event.files, isEmpty);
    expect(event.rawText, 'abc123portalkey456');
    expect(event.location.dx, 100.0);
    expect(event.location.dy, 200.0);
  });

  group('resolveLinuxDrop (RAFT PATCH)', () {
    final calls = <String>[];
    setUp(() {
      calls.clear();
    });

    void portal(List<String> paths) {
      DesktopDrop.instance.portalResolver = (key) async {
        calls.add(key);
        return paths;
      };
    }

    void failingPortal() {
      DesktopDrop.instance.portalResolver = (key) async {
        calls.add(key);
        throw DBusMethodResponseException(DBusMethodErrorResponse(
            'org.freedesktop.DBus.Error.AccessDenied',
            [const DBusString('Invalid transfer')]));
      };
    }

    Future<DropDoneEvent> drop(String uris, String key) async {
      final events = <DropEvent>[];
      void listener(DropEvent event) => events.add(event);
      DesktopDrop.instance.addRawDropEventListener(listener);
      addTearDown(
          () => DesktopDrop.instance.removeRawDropEventListener(listener));
      await _invokePlatformMethod(MethodCall(
          'performOperation_linux_sources', [uris, key, [1.0, 2.0]]));
      return events.single as DropDoneEvent;
    }

    test('file manager offering only uri-list never touches the portal',
        () async {
      portal(['/run/user/1000/doc/x/a.txt']);
      final event = await drop('file:///home/u/a.txt\r\n', '');
      expect(event.files.map((e) => e.path), ['/home/u/a.txt']);
      expect(event.error, isNull);
      expect(calls, isEmpty);
    });

    test('portal key plus readable uri-list prefers the real paths', () async {
      portal(['/run/user/1000/doc/x/a.txt']);
      final event = await drop('file:///home/u/a.txt', 'key-1');
      expect(event.files.map((e) => e.path), ['/home/u/a.txt']);
      expect(event.error, isNull);
      expect(calls, isEmpty);
    });

    test('failing portal (Invalid transfer) falls back to the uri-list in a '
        'Flatpak', () async {
      DesktopDrop.instance.inFlatpak = () => true;
      failingPortal();
      final event = await drop('file:///home/u/a.txt', 'dead-key');
      expect(calls, ['dead-key']);
      expect(event.files.map((e) => e.path), ['/home/u/a.txt']);
      expect(event.error, isNull);
    });

    test('Flatpak prefers the portal when it works', () async {
      DesktopDrop.instance.inFlatpak = () => true;
      portal(['/run/user/1000/doc/x/a.txt']);
      final event = await drop('file:///home/u/a.txt', 'key');
      expect(event.files.map((e) => e.path), ['/run/user/1000/doc/x/a.txt']);
    });

    test('portal only drop resolves through the portal', () async {
      portal(['/run/user/1000/doc/x/a.txt', '/run/user/1000/doc/y/b.txt']);
      final event = await drop('', 'key');
      expect(event.files.length, 2);
      expect(event.error, isNull);
      expect(event.rawText, 'key');
    });

    test('unreadable uri paths ask the portal, outside a Flatpak too',
        () async {
      DesktopDrop.instance.pathExists = (_) => false;
      portal(['/run/user/1000/doc/x/a.txt']);
      final event = await drop('file:///host/only/a.txt', 'key');
      expect(calls, ['key']);
      expect(event.files.map((e) => e.path), ['/run/user/1000/doc/x/a.txt']);
    });

    test('portal-only drop with a failing portal reports an error', () async {
      failingPortal();
      final event = await drop('', 'dead-key');
      expect(event.files, isEmpty);
      expect(event.error, "Couldn't read dropped files");
    });

    test('an empty portal answer is a failure too', () async {
      portal(const []);
      final event = await drop('', 'key');
      expect(event.files, isEmpty);
      expect(event.error, isNotNull);
    });

    test('legacy portal message reports the failure', () async {
      failingPortal();
      final events = <DropEvent>[];
      void listener(DropEvent event) => events.add(event);
      DesktopDrop.instance.addRawDropEventListener(listener);
      addTearDown(
          () => DesktopDrop.instance.removeRawDropEventListener(listener));
      await _invokePlatformMethod(const MethodCall('performOperation_portal', [
        'dead-key',
        [1.0, 1.0]
      ]));
      expect((events.single as DropDoneEvent).error, isNotNull);
    });
  });

  // The real DBus client against a fake document portal on a private session
  // bus. It claims org.freedesktop.portal.Documents, so it must never run on
  // the user's real session bus; opt in from a throwaway bus:
  //   DESKTOP_DROP_PRIVATE_BUS=1 dbus-run-session -- flutter test test/channel_linux_test.dart
  final privateBus = Platform.environment['DESKTOP_DROP_PRIVATE_BUS'] == '1' &&
      Platform.environment['DBUS_SESSION_BUS_ADDRESS'] != null;
  group('portal over a real (private) session bus', () {
    late DBusClient portalBus;
    late _FakeFileTransfer object;

    setUp(() async {
      portalBus = DBusClient.session();
      object = _FakeFileTransfer();
      await portalBus.registerObject(object);
      await portalBus.requestName('org.freedesktop.portal.Documents');
      // The real, unmocked resolver.
      DesktopDrop.instance.portalResolver = DesktopDrop.realPortalResolver;
    });
    tearDown(() async => portalBus.close());

    Future<LinuxDropResolution> resolve(String uris, String key) =>
        DesktopDrop.instance.resolveLinuxDrop(uriText: uris, portalKey: key);

    test('retrieves a live key', () async {
      object.keys['live'] = ['/run/user/1000/doc/ab/f.txt'];
      final r = await resolve('', 'live');
      expect(r.paths, ['/run/user/1000/doc/ab/f.txt']);
      expect(r.error, isNull);
    });

    test('a key is one-shot: the second RetrieveFiles is Invalid transfer; '
        'the uri-list still saves the drop in a Flatpak', () async {
      DesktopDrop.instance.inFlatpak = () => true;
      object.keys['once'] = ['/run/user/1000/doc/ab/f.txt'];
      expect((await resolve('', 'once')).error, isNull);
      expect(object.invalid, 0);
      final second = await resolve('file:///home/u/f.txt', 'once');
      expect(object.invalid, 1);
      expect(second.paths, ['/home/u/f.txt']);
      expect(second.error, isNull);
      final third = await resolve('', 'once');
      expect(third.paths, isEmpty);
      expect(third.error, "Couldn't read dropped files");
    });

    test('a bogus key plus a uri-list outside a Flatpak never needs the bus',
        () async {
      final r = await resolve('file:///home/u/f.txt', 'bogus');
      expect(r.paths, ['/home/u/f.txt']);
      expect(object.invalid, 0);
    });
  }, skip: privateBus ? null : 'needs DESKTOP_DROP_PRIVATE_BUS=1 on a dbus-run-session bus');
}

class _FakeFileTransfer extends DBusObject {
  _FakeFileTransfer()
      : super(DBusObjectPath('/org/freedesktop/portal/documents'));

  /// key -> paths RetrieveFiles hands out once (autostop semantics).
  final keys = <String, List<String>>{};
  var invalid = 0;

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface != 'org.freedesktop.portal.FileTransfer' ||
        call.name != 'RetrieveFiles') {
      return DBusMethodErrorResponse.unknownMethod();
    }
    final paths = keys.remove(call.values.first.asString());
    if (paths == null) {
      invalid++;
      return DBusMethodErrorResponse(
          'org.freedesktop.DBus.Error.AccessDenied',
          [const DBusString('Invalid transfer')]);
    }
    return DBusMethodSuccessResponse([DBusArray.string(paths)]);
  }
}
