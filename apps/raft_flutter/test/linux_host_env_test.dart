import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/linux_host_env.dart';

void main() {
  const image = '/tmp/.mount_RaftAbc';
  final polluted = <String, String>{
    'HOME': '/home/a',
    'DISPLAY': ':0',
    'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/run/user/1000/bus',
    'XDG_CURRENT_DESKTOP': 'KDE',
    'APPDIR': image,
    'APPIMAGE': '/home/a/Raft.AppImage',
    'ARGV0': 'Raft.AppImage',
    'OWD': '/home/a',
    'PATH': '$image/raft/bin:/usr/bin:/bin',
    'LD_LIBRARY_PATH': '$image/raft/lib:/opt/host/lib',
    'GIO_MODULE_DIR': '$image/raft/lib/gio/modules',
    'GSETTINGS_SCHEMA_DIR': '$image/usr/share/glib-2.0/schemas',
    'GIO_LAUNCH_DESKTOP': '$image/raft/bin/raft-gio-launch-desktop',
    'GTK_IM_MODULE_FILE': '/usr/lib64/gtk-3.0/3.0.0/immodules.cache',
  };

  test('AppRun contract restores host values and unsets absent ones', () {
    final env = linuxHostEnvironment({
      ...polluted,
      'RAFT_APPIMAGE_HOST_PATH_SET': 'x',
      'RAFT_APPIMAGE_HOST_PATH': '/usr/local/bin:/usr/bin',
      // Existed on the host with an empty value: stays set, empty.
      'RAFT_APPIMAGE_HOST_LD_LIBRARY_PATH_SET': 'x',
      'RAFT_APPIMAGE_HOST_LD_LIBRARY_PATH': '',
      // Unset on the host.
      'RAFT_APPIMAGE_HOST_GIO_MODULE_DIR_SET': '',
      'RAFT_APPIMAGE_HOST_GIO_MODULE_DIR': '',
      'RAFT_APPIMAGE_HOST_GSETTINGS_SCHEMA_DIR_SET': '',
      'RAFT_APPIMAGE_HOST_GSETTINGS_SCHEMA_DIR': '',
      'RAFT_APPIMAGE_HOST_GIO_LAUNCH_DESKTOP_SET': '',
      'RAFT_APPIMAGE_HOST_GIO_LAUNCH_DESKTOP': '',
      'RAFT_APPIMAGE_HOST_GTK_IM_MODULE_FILE_SET': 'x',
      'RAFT_APPIMAGE_HOST_GTK_IM_MODULE_FILE': '/host/immodules.cache',
    });
    expect(env['PATH'], '/usr/local/bin:/usr/bin');
    expect(env.containsKey('LD_LIBRARY_PATH'), isTrue);
    expect(env['LD_LIBRARY_PATH'], '');
    expect(env.containsKey('GIO_MODULE_DIR'), isFalse);
    expect(env.containsKey('GSETTINGS_SCHEMA_DIR'), isFalse);
    expect(env.containsKey('GIO_LAUNCH_DESKTOP'), isFalse);
    expect(env['GTK_IM_MODULE_FILE'], '/host/immodules.cache');
    expect(env['HOME'], '/home/a');
    expect(env['DISPLAY'], ':0');
    expect(env['DBUS_SESSION_BUS_ADDRESS'], startsWith('unix:path='));
    expect(env['XDG_CURRENT_DESKTOP'], 'KDE');
    for (final key in ['APPDIR', 'APPIMAGE', 'ARGV0', 'OWD']) {
      expect(env.containsKey(key), isFalse, reason: key);
    }
    expect(env.keys.where((k) => k.startsWith('RAFT_')), isEmpty);
  });

  test('a variable the contract does not mention is left to the fallback', () {
    final env = linuxHostEnvironment({
      ...polluted,
      'RAFT_APPIMAGE_HOST_PATH_SET': 'x',
      'RAFT_APPIMAGE_HOST_PATH': '/usr/bin',
    });
    expect(env['PATH'], '/usr/bin');
    // Not captured by this AppRun: dropped rather than inherited.
    expect(env.containsKey('LD_LIBRARY_PATH'), isFalse);
    expect(env.containsKey('GIO_MODULE_DIR'), isFalse);
  });

  test('older AppRun without exports drops image variables', () {
    final env = linuxHostEnvironment({
      ...polluted,
      'XDG_DATA_DIRS': '$image/usr/share:/usr/share',
    });
    expect(env['PATH'], '/usr/bin:/bin');
    expect(env['XDG_DATA_DIRS'], '/usr/share');
    for (final key in [
      'LD_LIBRARY_PATH',
      'GIO_MODULE_DIR',
      'GSETTINGS_SCHEMA_DIR',
      'GIO_LAUNCH_DESKTOP',
      'GTK_IM_MODULE_FILE',
      'APPDIR',
      'APPIMAGE',
      'ARGV0',
      'OWD',
    ]) {
      expect(env.containsKey(key), isFalse, reason: key);
    }
    expect(env['HOME'], '/home/a');
  });

  test('plain RAFT_HOST_* values are restored as well', () {
    final env = linuxHostEnvironment({
      ...polluted,
      'RAFT_HOST_LD_LIBRARY_PATH': '/host/lib',
      'RAFT_HOST_GIO_MODULE_DIR': '',
    });
    expect(env['LD_LIBRARY_PATH'], '/host/lib');
    expect(env.containsKey('GIO_MODULE_DIR'), isFalse);
    expect(env.keys.where((k) => k.startsWith('RAFT_')), isEmpty);
  });

  test(
    'only entries under APPDIR leave a path list, an empty list is unset',
    () {
      final env = linuxHostEnvironment({
        'APPDIR': '$image/',
        'PATH': '$image/raft/bin:/tmp/.mount_RaftAbcd/bin:/usr/bin',
        'XDG_CONFIG_DIRS': '$image/etc',
      });
      expect(env['PATH'], '/tmp/.mount_RaftAbcd/bin:/usr/bin');
      expect(env.containsKey('XDG_CONFIG_DIRS'), isFalse);
    },
  );

  test('a normal (non-AppImage) environment is unchanged', () {
    const plain = {
      'HOME': '/home/a',
      'PATH': '/usr/bin',
      'LD_LIBRARY_PATH': '/opt/lib',
    };
    final env = linuxHostEnvironment(plain);
    // No AppRun markers: only the image-pointing variables are dropped, which
    // is the safe default for a process we spawn from an unknown launcher.
    expect(env['PATH'], '/usr/bin');
    expect(env['HOME'], '/home/a');
  });
}
