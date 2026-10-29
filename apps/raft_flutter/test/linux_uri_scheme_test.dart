import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/platform/linux_desktop_identity.dart';
import 'package:raft_flutter/platform/linux_uri_scheme.dart';

const _ours = '$linuxAppImageDesktopId.desktop';

class _Store extends LinuxSchemeStore {
  String? stored;
  bool asked = false;
  @override
  Future<String?> choice() async => stored;
  @override
  Future<void> setChoice(String? value) async => stored = value;
  @override
  Future<bool> prompted() async => asked;
  @override
  Future<void> setPrompted() async => asked = true;
}

/// A desktop whose default-handler table and tools are scripted.
class _Desktop {
  String handler = '';
  File? mimeList;
  bool failDefault = false;
  final calls = <List<String>>[];
  final environments = <Map<String, String>>[];

  Future<HostResult> run(
    String executable,
    List<String> arguments,
    Map<String, String> environment,
  ) async {
    calls.add([p.basename(executable), ...arguments]);
    environments.add(environment);
    switch (p.basename(executable)) {
      case 'xdg-mime':
        if (arguments.first == 'query') {
          return (exitCode: 0, stdout: handler.isEmpty ? '' : '$handler\n');
        }
        if (failDefault) return (exitCode: 1, stdout: '');
        handler = arguments[1];
        mimeList!
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(
            '[Default Applications]\nx-scheme-handler/raft=$handler;\n',
          );
        return (exitCode: 0, stdout: '');
      default:
        return (exitCode: 0, stdout: '');
    }
  }

  int count(String tool, [String? first]) => calls
      .where((c) => c.first == tool && (first == null || c[1] == first))
      .length;
}

void main() {
  late Directory root;
  late String data, config, exeDir;
  late _Desktop desktop;
  late _Store store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('raft-scheme');
    data = p.join(root.path, 'data');
    config = p.join(root.path, 'config');
    exeDir = p.join(root.path, 'mount', 'raft');
    Directory(
      p.join(exeDir, 'data', 'icons/hicolor/256x256/apps'),
    ).createSync(recursive: true);
    File(
      p.join(exeDir, 'data', linuxIconRelative),
    ).writeAsBytesSync(List.filled(64, 7));
    desktop = _Desktop()..mimeList = File(p.join(config, 'mimeapps.list'));
    store = _Store();
  });
  tearDown(() => root.deleteSync(recursive: true));

  LinuxUriSchemeRegistration make({
    String? appImage,
    bool linux = true,
    Map<String, String> extra = const {},
    bool tools = true,
    bool? isolated,
  }) => LinuxUriSchemeRegistration(
    isolated: isolated,
    environment: {
      'HOME': p.join(root.path, 'home'),
      'XDG_DATA_HOME': data,
      'XDG_CONFIG_HOME': config,
      'PATH': '/usr/bin:/bin',
      'APPIMAGE': ?appImage,
      ...extra,
    },
    linux: linux,
    run: desktop.run,
    store: store,
    executable: p.join(exeDir, 'raft_flutter'),
    toolExists: (path) => tools,
  );

  File launcher() => File(
    p.join(data, 'applications', 'app.raft.raft_flutter-appimage.desktop'),
  );

  test('does nothing outside an AppImage or off Linux', () async {
    for (final scheme in [
      make(),
      make(appImage: '/x/Raft.AppImage', linux: false),
    ]) {
      await scheme.ensure();
      expect(scheme.supported, isFalse);
      expect(scheme.status, LinuxSchemeStatus.unsupported);
    }
    expect(desktop.calls, isEmpty);
    expect(Directory(data).existsSync(), isFalse);
  });

  test(
    'an isolated build never touches the host handler or mime lists',
    () async {
      // Even inside an AppImage with no handler set (the case where a normal
      // build would claim raft://), an isolated build must change nothing.
      final scheme = make(
        appImage: '/home/a/Apps/Raft.AppImage',
        isolated: true,
      );
      await scheme.ensure();
      await scheme.register();
      await scheme.unregister();
      expect(scheme.supported, isFalse);
      expect(scheme.status, LinuxSchemeStatus.unsupported);
      expect(desktop.calls, isEmpty);
      expect(desktop.handler, isEmpty);
      expect(store.stored, isNull);
      expect(Directory(data).existsSync(), isFalse);
      expect(Directory(config).existsSync(), isFalse);
    },
  );

  test('a default build keeps the real application id', () {
    expect(linuxIsolatedBuild, isFalse);
    expect(linuxApplicationId, 'app.raft.raft_flutter');
    expect(linuxAppImageDesktopId, 'app.raft.raft_flutter-appimage');
  }, skip: linuxIsolatedBuild);

  test('the application id follows the build suffix everywhere', () {
    expect(
      linuxApplicationId,
      'app.raft.raft_flutter$linuxApplicationIdSuffix',
    );
    expect(linuxAppImageDesktopId, startsWith(linuxApplicationId));
    expect(linuxIconRelative, contains('$linuxApplicationId.png'));
    // Notifications name the launcher that exists for this build's id.
    expect(linuxDesktopEntryId(environment: const {}), linuxApplicationId);
  });

  test('registers an unclaimed scheme with a clean host environment', () async {
    final scheme = make(
      appImage: '/home/a/Apps/Raft x86_64.AppImage',
      extra: {
        'APPDIR': '/tmp/.mount_Raft',
        'ARGV0': 'Raft',
        'OWD': '/home/a',
        'LD_LIBRARY_PATH': '/tmp/.mount_Raft/raft/lib',
        'RAFT_APPIMAGE_HOST_LD_LIBRARY_PATH_SET': 'x',
        'RAFT_APPIMAGE_HOST_LD_LIBRARY_PATH': '/opt/host/lib',
        'GIO_MODULE_DIR': '/tmp/.mount_Raft/raft/lib/gio/modules',
        'RAFT_APPIMAGE_HOST_GIO_MODULE_DIR_SET': '',
        'RAFT_APPIMAGE_HOST_GIO_MODULE_DIR': '',
      },
    );
    await scheme.ensure();
    expect(scheme.status, LinuxSchemeStatus.registered);
    expect(scheme.error, isNull);
    expect(desktop.handler, _ours);
    expect(store.stored, 'enabled');
    expect(
      launcher().readAsStringSync(),
      '[Desktop Entry]\n'
      'Type=Application\n'
      'Name=Raft\n'
      'Comment=Raft collaboration client\n'
      'Exec="/home/a/Apps/Raft x86_64.AppImage" %u\n'
      'Icon=${p.join(data, linuxIconRelative)}\n'
      'Terminal=false\n'
      'NoDisplay=false\n'
      'Categories=Network;Chat;\n'
      'MimeType=x-scheme-handler/raft;\n'
      'StartupNotify=true\n'
      'StartupWMClass=app.raft.raft_flutter\n'
      'X-Raft-AppImage=true\n',
    );
    expect(
      File(p.join(data, linuxIconRelative)).readAsBytesSync(),
      List.filled(64, 7),
    );
    expect(
      desktop.calls.firstWhere(
        (c) => c.first == 'xdg-mime' && c[1] == 'default',
      ),
      ['xdg-mime', 'default', _ours, 'x-scheme-handler/raft'],
    );
    expect(desktop.count('update-desktop-database'), 1);
    expect(desktop.calls.last.first, 'xdg-mime');
    for (final env in desktop.environments) {
      expect(env['HOME'], isNotEmpty);
      expect(env['LD_LIBRARY_PATH'], '/opt/host/lib');
      for (final key in [
        'APPDIR',
        'APPIMAGE',
        'ARGV0',
        'OWD',
        'GIO_MODULE_DIR',
      ]) {
        expect(env.containsKey(key), isFalse, reason: key);
      }
    }
  });

  test('an unchanged registration writes and runs nothing more', () async {
    final scheme = make(appImage: '/a/Raft.AppImage');
    await scheme.ensure();
    final stamp = launcher().lastModifiedSync();
    final updates = desktop.count('update-desktop-database');
    final defaults = desktop.count('xdg-mime', 'default');
    await make(appImage: '/a/Raft.AppImage').ensure();
    expect(launcher().lastModifiedSync(), stamp);
    expect(desktop.count('update-desktop-database'), updates);
    expect(desktop.count('xdg-mime', 'default'), defaults);
  });

  test('a moved AppImage rewrites our own launcher', () async {
    await make(appImage: '/old/Raft.AppImage').ensure();
    expect(
      launcher().readAsStringSync(),
      contains('Exec=/old/Raft.AppImage %u'),
    );
    final updates = desktop.count('update-desktop-database');
    final defaults = desktop.count('xdg-mime', 'default');
    final moved = make(appImage: '/new place/Raft.AppImage');
    await moved.ensure();
    expect(
      launcher().readAsStringSync(),
      contains('Exec="/new place/Raft.AppImage" %u'),
    );
    expect(moved.status, LinuxSchemeStatus.registered);
    expect(desktop.count('update-desktop-database'), updates + 1);
    expect(desktop.count('xdg-mime', 'default'), defaults);
  });

  test('another handler is never replaced without consent', () async {
    desktop.handler = 'org.example.Chat.desktop';
    final scheme = make(appImage: '/a/Raft.AppImage');
    await scheme.ensure();
    expect(scheme.status, LinuxSchemeStatus.otherHandler);
    expect(scheme.otherHandler, 'org.example.Chat.desktop');
    expect(scheme.promptPending, isTrue);
    expect(desktop.handler, 'org.example.Chat.desktop');
    expect(desktop.count('xdg-mime', 'default'), 0);
    expect(launcher().existsSync(), isFalse);
    expect(store.stored, isNull);

    // Asked once: the answer is remembered and nothing changes.
    await scheme.keepOtherHandler();
    expect(scheme.promptPending, isFalse);
    final next = make(appImage: '/a/Raft.AppImage');
    await next.ensure();
    expect(next.promptPending, isFalse);
    expect(desktop.handler, 'org.example.Chat.desktop');
    expect(launcher().existsSync(), isFalse);

    // The member's toggle is the consent.
    await next.register();
    expect(next.status, LinuxSchemeStatus.registered);
    expect(desktop.handler, _ours);
    expect(launcher().existsSync(), isTrue);
    expect(store.stored, 'enabled');
  });

  test('a packaged launcher as handler is another handler too', () async {
    desktop.handler = 'app.raft.raft_flutter.desktop';
    final scheme = make(appImage: '/a/Raft.AppImage');
    await scheme.ensure();
    expect(scheme.status, LinuxSchemeStatus.otherHandler);
    expect(desktop.count('xdg-mime', 'default'), 0);
  });

  test('switching off removes the launcher and stays off', () async {
    final scheme = make(appImage: '/a/Raft.AppImage');
    await scheme.ensure();
    Directory(config).createSync(recursive: true);
    File(p.join(config, 'mimeapps.list')).writeAsStringSync(
      '[Default Applications]\n'
      'text/html=firefox.desktop;\n'
      'x-scheme-handler/raft=$_ours;\n'
      '\n'
      '[Added Associations]\n'
      'x-scheme-handler/raft=other.desktop;$_ours;\n',
    );
    desktop.handler = _ours;
    await scheme.unregister();
    expect(launcher().existsSync(), isFalse);
    expect(store.stored, 'disabled');
    expect(
      File(p.join(config, 'mimeapps.list')).readAsStringSync(),
      '[Default Applications]\n'
      'text/html=firefox.desktop;\n'
      '\n'
      '[Added Associations]\n'
      'x-scheme-handler/raft=other.desktop;\n',
    );
    desktop.handler = '';
    await make(appImage: '/a/Raft.AppImage').ensure();
    expect(launcher().existsSync(), isFalse, reason: 'a member choice sticks');
    // Switching back on registers again.
    final back = make(appImage: '/a/Raft.AppImage');
    await back.register();
    expect(back.status, LinuxSchemeStatus.registered);
    expect(store.stored, 'enabled');
  });

  test(
    'missing xdg-utils or a refused change is reported, not thrown',
    () async {
      final none = make(appImage: '/a/Raft.AppImage', tools: false);
      await none.ensure();
      expect(none.status, LinuxSchemeStatus.error);
      expect(none.error, contains('xdg-utils'));
      expect(launcher().existsSync(), isFalse);

      desktop.failDefault = true;
      final refused = make(appImage: '/a/Raft.AppImage');
      await refused.ensure();
      expect(refused.status, LinuxSchemeStatus.error);
      expect(refused.error, isNotNull);
      expect(store.stored, isNot('enabled'));
    },
  );

  group('desktop file text', () {
    String? roundTrip(String path) {
      final entry = linuxAppImageDesktopEntry(appImage: path, icon: 'i');
      if (entry == null) return null;
      var exec = entry
          .split('\n')
          .firstWhere((l) => l.startsWith('Exec='))
          .substring(5);
      expect(exec, endsWith(' %u'));
      exec = exec.substring(0, exec.length - 3);
      // Key-file string unescape, then Exec quoting.
      exec = exec.replaceAll(r'\\', r'\');
      final quoted = exec.startsWith('"');
      expect(quoted, path.contains(RegExp(r'[^A-Za-z0-9_./:+@=,%-]')));
      final out = StringBuffer();
      final inner = quoted ? exec.substring(1, exec.length - 1) : exec;
      for (var i = 0; i < inner.length; i++) {
        if (inner[i] == r'\') {
          i++;
        } else if (inner[i] == '%' && inner[i + 1] == '%') {
          i++;
        }
        out.write(inner[i]);
      }
      return out.toString();
    }

    test('any ordinary path survives quoting', () {
      for (final path in [
        '/home/a/Raft.AppImage',
        '/home/a/My Apps/Raft x86_64.AppImage',
        r'/home/a/$HOME/`id`/Raft.AppImage',
        '/home/a/100%/Raft.AppImage',
        r'/home/a/back\slash/"quoted"/Raft.AppImage',
        '/home/用户/Raft.AppImage',
      ]) {
        expect(roundTrip(path), path);
      }
    });

    test('only a first-listed default counts as explicit', () {
      expect(
        hasDefaultMimeHandler(
          '[Default Applications]\nx-scheme-handler/raft=$_ours;a.desktop;\n',
          'x-scheme-handler/raft',
          _ours,
        ),
        isTrue,
      );
      for (final list in [
        '',
        '[Default Applications]\nx-scheme-handler/raft=a.desktop;$_ours;\n',
        '[Added Associations]\nx-scheme-handler/raft=$_ours;\n',
      ]) {
        expect(
          hasDefaultMimeHandler(list, 'x-scheme-handler/raft', _ours),
          isFalse,
        );
      }
    });

    test('control characters and empty paths are refused', () {
      expect(desktopExecArgument(''), isNull);
      expect(desktopExecArgument('/a\nb'), isNull);
      expect(linuxAppImageDesktopEntry(appImage: '/a\nb', icon: 'i'), isNull);
    });

    test('mimeapps edits keep unrelated lines untouched', () {
      const list =
          '# comment\n[Default Applications]\nx-scheme-handler/raft=$_ours\n'
          'x-scheme-handler/other=$_ours;\n[Removed Associations]\n'
          'x-scheme-handler/raft=$_ours;\n';
      expect(
        removeMimeHandler(list, 'x-scheme-handler/raft', _ours),
        '# comment\n[Default Applications]\n'
        'x-scheme-handler/other=$_ours;\n[Removed Associations]\n'
        'x-scheme-handler/raft=$_ours;\n',
      );
      const untouched =
          '[Default Applications]\nx-scheme-handler/raft=a.desktop\n';
      expect(
        removeMimeHandler(untouched, 'x-scheme-handler/raft', _ours),
        untouched,
      );
    });
  });

  // Runs the real xdg-mime and update-desktop-database against a throwaway
  // HOME/XDG tree; the member's own configuration is never involved.
  group('real xdg-utils', () {
    final xdg = File('/usr/bin/xdg-mime').existsSync();
    test(
      'registers, repairs and unregisters',
      () async {
        final realList = File(
          p.join(
            Platform.environment['HOME'] ?? '/nonexistent',
            '.config/mimeapps.list',
          ),
        );
        final realBefore = realList.existsSync()
            ? realList.readAsBytesSync()
            : null;
        final home = Directory(p.join(root.path, 'home'))..createSync();
        final env = {
          'HOME': home.path,
          'XDG_DATA_HOME': data,
          'XDG_CONFIG_HOME': config,
          'PATH': '/usr/local/bin:/usr/bin:/bin',
          'APPIMAGE': '/opt/Raft Chat/Raft.AppImage',
          // What AppRun would leave behind.
          'APPDIR': '/tmp/.mount_Raft',
          'LD_LIBRARY_PATH': '/tmp/.mount_Raft/raft/lib',
          'RAFT_APPIMAGE_HOST_LD_LIBRARY_PATH_SET': '',
          'RAFT_APPIMAGE_HOST_LD_LIBRARY_PATH': '',
        };
        LinuxUriSchemeRegistration real() => LinuxUriSchemeRegistration(
          environment: env,
          linux: true,
          store: store,
          executable: p.join(exeDir, 'raft_flutter'),
        );
        Future<String> query() async => (await Process.run(
          'xdg-mime',
          ['query', 'default', 'x-scheme-handler/raft'],
          environment: env,
          includeParentEnvironment: false,
        )).stdout.toString().trim();

        final scheme = real();
        await scheme.ensure();
        expect(scheme.error, isNull);
        expect(scheme.status, LinuxSchemeStatus.registered);
        expect(await query(), _ours);
        expect(
          File(p.join(config, 'mimeapps.list')).readAsStringSync(),
          contains('x-scheme-handler/raft=$_ours'),
        );
        expect(
          launcher().readAsStringSync(),
          contains('Exec="/opt/Raft Chat/Raft.AppImage" %u'),
        );

        final moved = LinuxUriSchemeRegistration(
          environment: {...env, 'APPIMAGE': '/elsewhere/Raft.AppImage'},
          linux: true,
          store: store,
          executable: p.join(exeDir, 'raft_flutter'),
        );
        await moved.ensure();
        expect(
          launcher().readAsStringSync(),
          contains('Exec=/elsewhere/Raft.AppImage %u'),
        );

        await moved.unregister();
        expect(await query(), isEmpty);
        expect(launcher().existsSync(), isFalse);

        // Another default handler survives a startup.
        File(p.join(data, 'applications', 'other.desktop')).writeAsStringSync(
          '[Desktop Entry]\nType=Application\nName=Other\nExec=true %u\n'
          'MimeType=x-scheme-handler/raft;\n',
        );
        await Process.run(
          'xdg-mime',
          ['default', 'other.desktop', 'x-scheme-handler/raft'],
          environment: env,
          includeParentEnvironment: false,
        );
        store.stored = null;
        final guarded = real();
        await guarded.ensure();
        expect(guarded.status, LinuxSchemeStatus.otherHandler);
        expect(await query(), 'other.desktop');
        expect(launcher().existsSync(), isFalse);

        expect(
          realList.existsSync() ? realList.readAsBytesSync() : null,
          realBefore,
          reason: "the member's own handler list is untouched",
        );
      },
      skip: xdg ? false : 'xdg-utils is not installed',
    );
  });
}
