import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../data/local_error_diagnostics.dart';

typedef DesktopDirectoryIdentity = Future<String?> Function(String path);

Future<String?> _nativeIdentity(String path) =>
    const MethodChannel('app.raft/desktop-window')
        .invokeMethod<String>('directoryIdentity', path);

/// Primary-created lease. A child can use this exact root but cannot submit
/// another path as cleanup authority. Identity uncertainty always retains it.
class DesktopOwnedCache {
  DesktopOwnedCache._(this.root, this.identity, this.marker, this._identify);
  final Directory root;
  final String identity, marker;
  final DesktopDirectoryIdentity _identify;
  String outcome = 'active';

  Map<String, String> get descriptor => {
    'root': root.path,
    'identity': identity,
    'marker': marker,
  };

  static Future<DesktopOwnedCache> create({
    Directory? parent,
    DesktopDirectoryIdentity? identify,
  }) async {
    final probe = identify ?? _nativeIdentity;
    final base = Directory(
      await (parent ?? Directory.systemTemp).resolveSymbolicLinks(),
    );
    final root = await base.createTemp('raft-window-');
    final marker = List.generate(
      4,
      (_) => Random.secure().nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
    ).join();
    try {
      final id = await probe(root.path);
      if (id == null) {
        throw StateError('Desktop cache identity is unavailable.');
      }
      await File(p.join(root.path, '.raft-owner'))
          .writeAsString(marker, flush: true);
      return DesktopOwnedCache._(root, id, marker, probe);
    } catch (error, stack) {
      // No authority is guessed after an incomplete creation/identity check.
      // Keep the exact owned candidate and record a diagnostic for inspection.
      LocalErrorDiagnostics.shared.capture(error, stack);
      rethrow;
    }
  }

  bool _retain(String reason) {
    outcome = reason;
    LocalErrorDiagnostics.shared.capture(
      StateError('Desktop child cache retained ($reason).'),
      StackTrace.current,
    );
    return false;
  }

  Future<bool>? _removing;
  Directory? _retainedRoot;
  String get retainedPath => (_retainedRoot ?? root).path;

  Future<bool> remove() => _removing ??= _remove();

  Future<bool> _matches(Directory candidate) async {
    if (await FileSystemEntity.type(candidate.path, followLinks: false) !=
            FileSystemEntityType.directory ||
        await candidate.resolveSymbolicLinks() != candidate.path ||
        await _identify(candidate.path) != identity) {
      return false;
    }
    final file = File(p.join(candidate.path, '.raft-owner'));
    return await FileSystemEntity.type(file.path, followLinks: false) ==
            FileSystemEntityType.file &&
        await file.readAsString() == marker;
  }

  Future<bool> _remove() async {
    if (outcome == 'removed') return true;
    Directory? quarantine;
    try {
      if (await FileSystemEntity.type(root.path, followLinks: false) !=
              FileSystemEntityType.directory ||
          await root.resolveSymbolicLinks() != root.path ||
          await _identify(root.path) != identity) {
        return _retain('identity_changed');
      }
      final ownerFile = File(p.join(root.path, '.raft-owner'));
      if (await FileSystemEntity.type(ownerFile.path, followLinks: false) !=
              FileSystemEntityType.file ||
          await ownerFile.readAsString() != marker) {
        return _retain('marker_changed');
      }
      // Move into a new primary-only namespace first. The child never receives
      // this path. A replacement raced at the old name is verified after rename
      // and restored/retained; it cannot become recursive deletion authority.
      quarantine = await Directory(p.dirname(root.path))
          .createTemp('raft-cache-retired-');
      final moved = await root.rename(p.join(quarantine.path, 'cache'));
      _retainedRoot = moved;
      if (!await _matches(moved)) {
        if (await FileSystemEntity.type(root.path, followLinks: false) ==
            FileSystemEntityType.notFound) {
          _retainedRoot = await moved.rename(root.path);
          await quarantine.delete();
        }
        return _retain('identity_changed');
      }
      // Native removal is confirmed before the broker calls this. Directory
      // recursion unlinks contained symlinks and never follows their targets.
      await moved.delete(recursive: true);
      await quarantine.delete();
      _retainedRoot = null;
      outcome = 'removed';
      return true;
    } catch (error, stack) {
      outcome = 'cleanup_failed';
      LocalErrorDiagnostics.shared.capture(error, stack);
      return false;
    }
  }
}

/// Engine-local directory access. Retiring never falls back to primary paths.
class DesktopChildCache {
  DesktopChildCache(this.root);
  final Directory root;
  bool _retired = false;
  Future<Directory> directory(String name) {
    if (_retired) throw StateError('Desktop cache is retired.');
    if (!{'staging', 'attachments', 'media', 'legacy'}.contains(name)) {
      throw ArgumentError.value(name);
    }
    return Directory(p.join(root.path, name)).create(recursive: true);
  }

  void retire() => _retired = true;
  void resume() => _retired = false;
}

class DesktopCacheScope {
  DesktopCacheScope._();
  static DesktopChildCache? _scope;
  static bool get isChild => _scope != null;
  static Future<void> initializeChild(Map<dynamic, dynamic> descriptor) async {
    final path = descriptor['root'],
        identity = descriptor['identity'],
        marker = descriptor['marker'];
    if (path is! String ||
        identity is! String ||
        marker is! String ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(marker)) {
      throw const FormatException('Invalid desktop cache lease.');
    }
    final root = Directory(path);
    if (await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.directory ||
        await root.resolveSymbolicLinks() != path ||
        await _nativeIdentity(path) != identity ||
        await File(p.join(path, '.raft-owner')).readAsString() != marker) {
      throw const FormatException('Desktop cache lease changed.');
    }
    _scope = DesktopChildCache(root);
  }

  static void retire() => _scope?.retire();
  static void resume() => _scope?.resume();
  static Future<Directory>? directory(String name) => _scope?.directory(name);
}
