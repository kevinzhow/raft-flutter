import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'linux_desktop_identity.dart';
import 'linux_host_env.dart';

const _mime = 'x-scheme-handler/raft';
const _choiceKey = 'raft.linux.uriScheme.choice';
const _promptedKey = 'raft.linux.uriScheme.prompted';

/// Where Raft stands as the handler of `raft://` links.
enum LinuxSchemeStatus {
  /// Not an AppImage (or not Linux): the packaged launcher owns the scheme.
  unsupported,

  /// Not looked at yet.
  unknown,

  /// This AppImage's launcher is the default handler.
  registered,

  /// No handler is set, or the member switched it off.
  notRegistered,

  /// Another program is the default handler; Raft never takes it silently.
  otherHandler,

  /// The desktop tools failed or are missing.
  error,
}

/// A finished host program.
typedef HostResult = ({int exitCode, String stdout});

/// Starts [executable] with exactly [environment] (never the parent's).
typedef HostProcess =
    Future<HostResult> Function(
      String executable,
      List<String> arguments,
      Map<String, String> environment,
    );

Future<HostResult> runHostProcess(
  String executable,
  List<String> arguments,
  Map<String, String> environment,
) async {
  final process = await Process.start(
    executable,
    arguments,
    environment: environment,
    includeParentEnvironment: false,
    runInShell: false,
  );
  final out = process.stdout.transform(utf8.decoder).join();
  unawaited(process.stderr.drain<void>());
  try {
    final code = await process.exitCode.timeout(const Duration(seconds: 15));
    return (exitCode: code, stdout: await out);
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    return (exitCode: -1, stdout: '');
  }
}

/// The member's explicit choice and whether the one-time prompt was answered.
class LinuxSchemeStore {
  Future<String?> choice() async =>
      (await SharedPreferences.getInstance()).getString(_choiceKey);
  Future<void> setChoice(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_choiceKey);
    } else {
      await prefs.setString(_choiceKey, value);
    }
  }

  Future<bool> prompted() async =>
      (await SharedPreferences.getInstance()).getBool(_promptedKey) ?? false;
  Future<void> setPrompted() async =>
      (await SharedPreferences.getInstance()).setBool(_promptedKey, true);
}

/// Registers the running AppImage as the `raft://` handler.
///
/// An AppImage installs nothing, so `xdg-open raft://...` cannot find it. On
/// start (and when the member asks) this writes
/// `~/.local/share/applications/app.raft.raft_flutter-appimage.desktop` with
/// the current image path, installs the icon, and makes it the default for
/// `x-scheme-handler/raft` with `xdg-mime`. It only takes over when no handler
/// is set or the handler is already this launcher (any image path); another
/// program is left alone until the member agrees in Settings. A packaged
/// install (no `APPIMAGE`) is never touched.
class LinuxUriSchemeRegistration extends ChangeNotifier {
  LinuxUriSchemeRegistration({
    Map<String, String>? environment,
    bool? linux,
    HostProcess? run,
    LinuxSchemeStore? store,
    String? executable,
    this.toolExists,
    bool? isolated,
  }) : _isolated = isolated ?? linuxIsolatedBuild,
       _env = environment ?? Platform.environment,
       _linux = linux ?? Platform.isLinux,
       _run = run ?? runHostProcess,
       _store = store ?? LinuxSchemeStore(),
       _executable = executable ?? Platform.resolvedExecutable;

  /// The app-wide instance Settings and startup share.
  static LinuxUriSchemeRegistration instance = LinuxUriSchemeRegistration();

  final Map<String, String> _env;
  final bool _linux;
  final HostProcess _run;
  final LinuxSchemeStore _store;
  final String _executable;

  /// An isolated test build never registers a handler (see
  /// [linuxIsolatedBuild]).
  final bool _isolated;

  /// Overrides the executable-file check used to find host tools (tests).
  final bool Function(String path)? toolExists;
  Future<void> _tail = Future.value();

  LinuxSchemeStatus status = LinuxSchemeStatus.unknown;

  /// The desktop file of the program that currently owns the scheme.
  String? otherHandler;
  // ignore: raft_lints/avoid_imperative_notice_state -- Clears whenever the registration is re-inspected, registered or removed (_inspect/_register/unregister).
  String? error;
  bool busy = false;

  /// Another handler exists and the member has not been asked yet.
  bool promptPending = false;

  /// The AppImage file the runtime is executing.
  String get appImage => _env['APPIMAGE'] ?? '';
  String? get _dataHome => linuxDataHome(_env);
  bool get supported =>
      !_isolated && _linux && runningFromAppImage(_env) && _dataHome != null;

  String get applicationsDirectory => p.join(_dataHome!, 'applications');
  String get desktopFile =>
      p.join(applicationsDirectory, '$linuxAppImageDesktopId.desktop');
  String get installedIcon => p.join(_dataHome!, linuxIconRelative);
  String get mimeAppsList {
    final configured = _env['XDG_CONFIG_HOME'] ?? '';
    final base = configured.isNotEmpty && p.isAbsolute(configured)
        ? configured
        : p.join(_env['HOME'] ?? '', '.config');
    return p.join(base, 'mimeapps.list');
  }

  bool get registered => status == LinuxSchemeStatus.registered;

  /// Startup: claim an unclaimed scheme, repair a stale launcher, never
  /// override another handler or a member's "off".
  Future<void> ensure() => _serial(() async {
    if (!supported) {
      status = LinuxSchemeStatus.unsupported;
      return;
    }
    final choice = await _store.choice();
    final handler = await _inspect();
    if (choice == 'disabled' || status == LinuxSchemeStatus.error) return;
    if (handler == null || handler == '$linuxAppImageDesktopId.desktop') {
      await _register();
      if (status == LinuxSchemeStatus.registered) {
        await _store.setChoice('enabled');
      }
    }
  });

  /// Re-read the default handler, for example when Settings opens.
  Future<void> refresh() => _serial(() async {
    if (supported) await _inspect();
  });

  /// The member agrees: this launcher becomes the handler.
  Future<void> register() => _serial(() async {
    if (!supported) return;
    await _register();
    await _store.setPrompted();
    if (status == LinuxSchemeStatus.registered) {
      await _store.setChoice('enabled');
    }
    promptPending = false;
  });

  /// Remove this launcher and its entries from the member's handler lists.
  Future<void> unregister() => _serial(() async {
    if (!supported) return;
    error = null;
    try {
      final file = File(desktopFile);
      if (file.existsSync()) file.deleteSync();
      final list = File(mimeAppsList);
      if (list.existsSync()) {
        final before = list.readAsStringSync();
        final after = removeMimeHandler(
          before,
          _mime,
          '$linuxAppImageDesktopId.desktop',
        );
        if (after != before) list.writeAsStringSync(after);
      }
      await _updateDatabase();
      await _store.setChoice('disabled');
      await _store.setPrompted();
    } catch (e) {
      error = 'Could not remove the raft:// registration.';
      status = LinuxSchemeStatus.error;
      notifyListeners();
      return;
    }
    await _inspect();
  });

  /// The member kept the other program: ask no more.
  Future<void> keepOtherHandler() => _serial(() async {
    await _store.setPrompted();
    promptPending = false;
  });

  Future<void> _serial(Future<void> Function() action) {
    final next = _tail.catchError((Object _) {}).then((_) async {
      busy = true;
      notifyListeners();
      try {
        await action();
      } catch (_) {
        status = LinuxSchemeStatus.error;
        error ??= 'The desktop could not be updated.';
      } finally {
        busy = false;
        notifyListeners();
      }
    });
    _tail = next;
    return next;
  }

  Map<String, String> get _hostEnv => linuxHostEnvironment(_env);

  String? _which(String name) {
    final path = _hostEnv['PATH'];
    final dirs =
        (path == null || path.isEmpty ? '/usr/local/bin:/usr/bin:/bin' : path)
            .split(':');
    for (final dir in dirs) {
      if (dir.isEmpty) continue;
      final candidate = p.join(dir, name);
      final present = toolExists?.call(candidate) ?? _isExecutable(candidate);
      if (present) return candidate;
    }
    return null;
  }

  static bool _isExecutable(String path) {
    final stat = FileStat.statSync(path);
    return stat.type == FileSystemEntityType.file && stat.mode & 0x49 != 0;
  }

  /// Reads the default handler and sets [status]; returns its desktop file id
  /// (null when none).
  Future<String?> _inspect() async {
    error = null;
    otherHandler = null;
    final xdgMime = _which('xdg-mime');
    if (xdgMime == null) {
      status = LinuxSchemeStatus.error;
      error = 'xdg-utils is not installed, so raft:// links cannot be set up.';
      return null;
    }
    final result = await _run(xdgMime, ['query', 'default', _mime], _hostEnv);
    if (result.exitCode != 0) {
      status = LinuxSchemeStatus.error;
      error = 'The default handler for raft:// links could not be read.';
      return null;
    }
    final handler = result.stdout.trim().split('\n').first.trim();
    if (handler.isEmpty) {
      status = LinuxSchemeStatus.notRegistered;
      promptPending = false;
      return null;
    }
    if (handler == '$linuxAppImageDesktopId.desktop') {
      status = LinuxSchemeStatus.registered;
      promptPending = false;
    } else {
      status = LinuxSchemeStatus.otherHandler;
      otherHandler = handler;
      promptPending = !await _store.prompted();
    }
    return handler;
  }

  Future<void> _register() async {
    error = null;
    final xdgMime = _which('xdg-mime');
    if (xdgMime == null) {
      status = LinuxSchemeStatus.error;
      error = 'xdg-utils is not installed, so raft:// links cannot be set up.';
      return;
    }
    final changed = _writeLauncher();
    if (changed) await _updateDatabase();
    final current = await _run(xdgMime, ['query', 'default', _mime], _hostEnv);
    // A launcher that declares the scheme already answers `query default` as
    // the only candidate, so an explicit entry is what makes it stick.
    if (current.stdout.trim().split('\n').first.trim() !=
            '$linuxAppImageDesktopId.desktop' ||
        !_hasExplicitDefault()) {
      // xdg-mime touches the list before it creates a missing config
      // directory and still exits 0 when that fails.
      Directory(p.dirname(mimeAppsList)).createSync(recursive: true);
      final result = await _run(xdgMime, [
        'default',
        '$linuxAppImageDesktopId.desktop',
        _mime,
      ], _hostEnv);
      if (result.exitCode != 0) {
        status = LinuxSchemeStatus.error;
        error = 'The desktop did not accept Raft as the raft:// handler.';
        return;
      }
    }
    await _inspect();
    if (status != LinuxSchemeStatus.registered && error == null) {
      error = 'The desktop kept another handler for raft:// links.';
    }
  }

  bool _hasExplicitDefault() {
    try {
      final list = File(mimeAppsList);
      return list.existsSync() &&
          hasDefaultMimeHandler(
            list.readAsStringSync(),
            _mime,
            '$linuxAppImageDesktopId.desktop',
          );
    } catch (_) {
      return false;
    }
  }

  /// Writes the desktop file and icon; true when anything changed.
  bool _writeLauncher() {
    var changed = false;
    String icon = 'application-x-executable';
    final bundled = bundledLinuxIconPath(executable: _executable);
    if (bundled != null) {
      final target = File(installedIcon);
      final source = File(bundled);
      if (!target.existsSync() || target.lengthSync() != source.lengthSync()) {
        target.parent.createSync(recursive: true);
        _replace(target, source.readAsBytesSync());
        changed = true;
      }
      icon = installedIcon;
    } else if (File(installedIcon).existsSync()) {
      icon = installedIcon;
    }
    final content = linuxAppImageDesktopEntry(appImage: appImage, icon: icon);
    if (content == null) throw StateError('Unsupported AppImage path.');
    final file = File(desktopFile);
    if (!file.existsSync() || file.readAsStringSync() != content) {
      file.parent.createSync(recursive: true);
      _replace(file, utf8.encode(content));
      changed = true;
    }
    return changed;
  }

  static void _replace(File target, List<int> bytes) {
    final temporary = File('${target.path}.tmp$pid');
    temporary.writeAsBytesSync(bytes, flush: true);
    temporary.renameSync(target.path);
  }

  Future<void> _updateDatabase() async {
    final tool = _which('update-desktop-database');
    if (tool == null) return;
    try {
      await _run(tool, [applicationsDirectory], _hostEnv);
    } catch (_) {
      // Best effort: the database only speeds up lookups.
    }
  }
}

/// The desktop file for [appImage]; null for a path a launcher cannot carry.
String? linuxAppImageDesktopEntry({
  required String appImage,
  required String icon,
}) {
  final exec = desktopExecArgument(appImage);
  if (exec == null || icon.contains(RegExp(r'[\n\r]'))) return null;
  return [
    '[Desktop Entry]',
    'Type=Application',
    'Name=Raft',
    'Comment=Raft collaboration client',
    'Exec=$exec %u',
    'Icon=$icon',
    'Terminal=false',
    'NoDisplay=false',
    'Categories=Network;Chat;',
    'MimeType=x-scheme-handler/raft;',
    'StartupNotify=true',
    'StartupWMClass=$linuxApplicationId',
    // Marks the file as written by the AppImage, whatever its path.
    'X-Raft-AppImage=true',
    '',
  ].join('\n');
}

/// One Exec argument. A path of plain characters is written bare, which every
/// opener (including generic `xdg-open`, whose parser cannot read quotes)
/// understands; anything else is double-quoted as the Desktop Entry spec asks:
/// `"`, `` ` ``, `$` and `\` get a backslash, then backslashes are escaped
/// again as a key-file string. `%` is a field code and is doubled either way.
/// Null for control characters.
String? desktopExecArgument(String path) {
  if (path.isEmpty || path.contains(RegExp(r'[\x00-\x1f\x7f]'))) return null;
  final bare = !path.contains(RegExp(r'[^A-Za-z0-9_./:+@=,%-]'));
  final argument = StringBuffer(bare ? '' : '"');
  for (final rune in path.runes) {
    final c = String.fromCharCode(rune);
    if (!bare && (c == '"' || c == '`' || c == r'$' || c == r'\')) {
      argument.write(r'\');
    }
    if (c == '%') argument.write('%');
    argument.write(c);
  }
  if (!bare) argument.write('"');
  return argument.toString().replaceAll(r'\', r'\\');
}

/// Removes [desktopId] from the `[Default Applications]` and
/// `[Added Associations]` entries of [mime] in a mimeapps.list; every other
/// line is kept byte for byte.
String removeMimeHandler(String content, String mime, String desktopId) {
  var section = '';
  final lines = content.split('\n');
  final out = <String>[];
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) section = trimmed;
    final owned =
        section == '[Default Applications]' ||
        section == '[Added Associations]';
    if (owned && line.startsWith('$mime=')) {
      final kept = line
          .substring(mime.length + 1)
          .split(';')
          .where((id) => id.isNotEmpty && id != desktopId)
          .toList();
      final before = line
          .substring(mime.length + 1)
          .split(';')
          .where((id) => id.isNotEmpty)
          .length;
      if (kept.length == before) {
        out.add(line);
      } else if (kept.isNotEmpty) {
        out.add('$mime=${kept.join(';')};');
      }
      continue;
    }
    out.add(line);
  }
  return out.join('\n');
}

/// True when `[Default Applications]` names [desktopId] first for [mime].
bool hasDefaultMimeHandler(String content, String mime, String desktopId) {
  var section = '';
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) section = trimmed;
    if (section == '[Default Applications]' && line.startsWith('$mime=')) {
      return line.substring(mime.length + 1).split(';').firstOrNull ==
          desktopId;
    }
  }
  return false;
}
