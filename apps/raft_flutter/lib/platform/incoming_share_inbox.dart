import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show PlatformException;
import 'package:path/path.dart' as p;

import '../data/shared_draft_attachment.dart';
import 'native_sharing.dart';

/// Why a shared file could not be staged. The share page shows the reason
/// next to the file instead of a generic failure.
enum IncomingShareFailureReason {
  /// One file is over [IncomingShareInbox.maxItemBytes].
  tooLarge,

  /// More files than the inbox takes.
  tooMany,

  /// All files together are over [IncomingShareInbox.maxTotalBytes].
  totalTooLarge,

  /// The provider could not open or read the file.
  unreadable,

  /// The read grant was revoked or never covered the file.
  permission,
  empty,
  cancelled,
}

class IncomingShareFailure extends FormatException {
  IncomingShareFailure(this.reason, {this.index}) : super(reason.name);

  /// Index of the failing file in the share, when one file is to blame.
  final int? index;
  final IncomingShareFailureReason reason;
}

/// Files live outside Android backups. Only opaque references enter the draft
/// cache; paths and ownership are checked here before opening a file.
class IncomingShareInbox {
  IncomingShareInbox(this.directory, this.readContent, {this.copyContent});
  final Future<int> Function(
    Uri uri,
    File destination,
    int limit,
    void Function(int bytes) onBytes,
  )?
  copyContent;
  final Future<Directory> Function() directory;
  final Stream<List<int>> Function(Uri) readContent;
  Future<void> _writes = Future.value();
  Future<T> _serial<T>(Future<T> Function() work) {
    final result = _writes.then((_) => work());
    _writes = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  static const maxItemBytes = 25 * 1024 * 1024;
  static const maxTotalBytes = 100 * 1024 * 1024;
  static final _tokenPattern = RegExp(r'^[a-f0-9]{32}$');
  Future<Directory> _folder(String token) async {
    if (!_tokenPattern.hasMatch(token)) {
      throw const FormatException('Share token');
    }
    final root = await directory();
    await root.create(recursive: true);
    final folder = Directory(p.join(root.path, token));
    if (await FileSystemEntity.type(folder.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FormatException('Invalid inbox folder');
    }
    return folder;
  }

  Future<Map<String, dynamic>?> _record(String token) async {
    final file = File(p.join((await _folder(token)).path, 'envelope.json'));
    if (!await file.exists()) return null;
    final value = jsonDecode(await file.readAsString());
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  Future<void> _write(String token, Map<String, dynamic> record) async {
    final folder = await _folder(token);
    final tmp = File(p.join(folder.path, 'envelope.tmp'));
    await tmp.writeAsString(jsonEncode(record), flush: true);
    await tmp.rename(p.join(folder.path, 'envelope.json'));
  }

  /// The hand-off reads and stamps one already-copied envelope. Doing that
  /// with a chain of async file calls costs one scheduler turn per call, so
  /// a busy device misses the composer's on-device landing. One directory
  /// lookup, then the stat and the write stay on this turn.
  Directory _folderSync(Directory root, String token) {
    if (!_tokenPattern.hasMatch(token)) {
      throw const FormatException('Share token');
    }
    root.createSync(recursive: true);
    final folder = Directory(p.join(root.path, token));
    if (FileSystemEntity.typeSync(folder.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FormatException('Invalid inbox folder');
    }
    return folder;
  }

  Map<String, dynamic>? _recordSync(Directory root, String token) {
    final file = File(p.join(_folderSync(root, token).path, 'envelope.json'));
    if (!file.existsSync()) return null;
    final value = jsonDecode(file.readAsStringSync());
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  void _writeSync(Directory root, String token, Map<String, dynamic> record) {
    final folder = _folderSync(root, token);
    final tmp = File(p.join(folder.path, 'envelope.tmp'));
    tmp.writeAsStringSync(jsonEncode(record), flush: true);
    tmp.renameSync(p.join(folder.path, 'envelope.json'));
  }

  void _discardSync(Directory root, String token) {
    final folder = _folderSync(root, token);
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  }

  /// Copies [share] into the private inbox. [onProgress] reports the number of
  /// files already safely copied (after each item) and [onBytes] the bytes of
  /// the file being copied, so a caller can show progress while the picker is
  /// already on screen. Failures are [IncomingShareFailure]s.
  Future<IncomingShare> stage(
    IncomingShare share, {
    bool Function()? current,
    void Function(int copied)? onProgress,
    void Function(int index, int bytes)? onBytes,
  }) => _serial(() async {
    if (share.token != null) return share;
    if (share.files.length > 9) {
      throw IncomingShareFailure(IncomingShareFailureReason.tooMany);
    }
    // The sizes the provider declares are checked before a single byte is
    // copied: a share that can never fit fails at once, not after the copy.
    var declared = 0;
    for (final (index, source) in share.files.indexed) {
      final size = source.sizeBytes ?? 0;
      if (size > maxItemBytes) {
        throw IncomingShareFailure(
          IncomingShareFailureReason.tooLarge,
          index: index,
        );
      }
      declared += size;
    }
    if (declared > maxTotalBytes) {
      throw IncomingShareFailure(IncomingShareFailureReason.totalTooLarge);
    }
    final random = Random.secure();
    final token = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final folder = await _folder(token);
    await folder.create();
    final files = <Map<String, dynamic>>[];
    var total = 0;
    bool cancelled() => current?.call() == false;
    try {
      for (final (index, source) in share.files.indexed) {
        if (cancelled()) {
          throw IncomingShareFailure(IncomingShareFailureReason.cancelled);
        }
        final name = 'item-${files.length}';
        var size = 0;
        try {
          if (copyContent != null) {
            size = await copyContent!(
              Uri.parse(source.uri),
              File(p.join(folder.path, name)),
              min(maxItemBytes, maxTotalBytes - total),
              (bytes) => onBytes?.call(index, bytes),
            );
            total += size;
            if (size > maxItemBytes || total > maxTotalBytes) {
              throw IncomingShareFailure(
                size > maxItemBytes
                    ? IncomingShareFailureReason.tooLarge
                    : IncomingShareFailureReason.totalTooLarge,
                index: index,
              );
            }
            if (size <= 0) {
              throw IncomingShareFailure(
                IncomingShareFailureReason.empty,
                index: index,
              );
            }
          } else {
            final file = await File(p.join(folder.path, name))
                .open(mode: FileMode.write);
            final reader = StreamIterator(readContent(Uri.parse(source.uri)));
            try {
              while (await reader.moveNext()) {
                if (cancelled()) {
                  throw IncomingShareFailure(
                    IncomingShareFailureReason.cancelled,
                  );
                }
                size += reader.current.length;
                total += reader.current.length;
                if (size > maxItemBytes || total > maxTotalBytes) {
                  throw IncomingShareFailure(
                    size > maxItemBytes
                        ? IncomingShareFailureReason.tooLarge
                        : IncomingShareFailureReason.totalTooLarge,
                    index: index,
                  );
                }
                // Await each write: provider chunks cannot accumulate in memory.
                await file.writeFrom(reader.current);
                onBytes?.call(index, size);
              }
              if (size == 0) {
                throw IncomingShareFailure(
                  IncomingShareFailureReason.empty,
                  index: index,
                );
              }
            } finally {
              await reader.cancel();
              await file.close();
            }
          }
          if (cancelled()) {
            throw IncomingShareFailure(IncomingShareFailureReason.cancelled);
          }
        } on IncomingShareFailure {
          rethrow;
        } on PlatformException catch (error) {
          throw IncomingShareFailure(switch (error.code) {
            'too_large' => IncomingShareFailureReason.tooLarge,
            'permission' => IncomingShareFailureReason.permission,
            'empty' => IncomingShareFailureReason.empty,
            _ => IncomingShareFailureReason.unreadable,
          }, index: index);
        } on FormatException {
          throw IncomingShareFailure(
            IncomingShareFailureReason.unreadable,
            index: index,
          );
        } catch (_) {
          // A provider that fails mid-read (closed pipe, revoked grant).
          throw IncomingShareFailure(
            IncomingShareFailureReason.unreadable,
            index: index,
          );
        }
        files.add({
          'file': name,
          'filename': source.filename,
          'mimeType': source.mimeType,
          'sizeBytes': size,
        });
        onProgress?.call(files.length);
      }
      if (cancelled()) {
        throw IncomingShareFailure(IncomingShareFailureReason.cancelled);
      }
      final record = <String, dynamic>{
        'token': token,
        'created': DateTime.now().millisecondsSinceEpoch,
        'pending': true,
        'text': share.text,
        'files': files,
      };
      await _write(token, record);
      return _share(record);
    } catch (_) {
      await folder.delete(recursive: true);
      rethrow;
    }
  });

  IncomingShare _share(Map<String, dynamic> record) => IncomingShare(
    token: record['token'] as String,
    text: record['text'] as String?,
    files: [
      for (final file in (record['files'] as List).cast<Map>())
        IncomingSharedFile(
          file['file'] as String,
          file['filename'] as String,
          file['mimeType'] as String,
          file['sizeBytes'] as int,
        ),
    ],
  );

  Future<List<IncomingShare>> pending() => _serial(() async {
    final root = await directory();
    if (!await root.exists()) return [];
    final records = <Map<String, dynamic>>[];
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory ||
          !_tokenPattern.hasMatch(p.basename(entry.path))) {
        continue;
      }
      try {
        final record = await _record(p.basename(entry.path));
        if (record == null ||
            record['created'] is! int ||
            record['pending'] == true &&
                DateTime.now().millisecondsSinceEpoch -
                        (record['created'] as int) >
                    const Duration(days: 1).inMilliseconds) {
          await entry.delete(recursive: true);
        } else if (record['pending'] == true) {
          records.add(record);
        }
      } catch (_) {
        await entry.delete(recursive: true);
      }
    }
    records.sort(
      (a, b) => (a['created'] as int).compareTo(b['created'] as int),
    );
    return records.map(_share).toList();
  });

  Future<bool> claim(String token, String origin, String principal) =>
      _serial(() async {
        // Continue awaits this stamp before it can open the composer. One
        // directory lookup, then the stat and the write stay on this turn.
        final root = await directory();
        final record = _recordSync(root, token);
        if (record == null ||
            record['principal'] != null &&
                (record['principal'] != principal ||
                    record['origin'] != origin)) {
          return false;
        }
        record.addAll({'origin': origin, 'principal': principal});
        _writeSync(root, token, record);
        return true;
      });

  Future<SharedDraftAttachment?> restore(
    Map<String, dynamic> ref,
    String origin,
    String principal,
  ) async {
    final token = ref['token'], name = ref['file'];
    if (token is! String ||
        name is! String ||
        !RegExp(r'^item-[0-8]$').hasMatch(name)) {
      return null;
    }
    try {
      final root = await directory();
      final record = _recordSync(root, token);
      if (record == null ||
          record['origin'] != origin ||
          record['principal'] != principal) {
        return null;
      }
      final metadata = (record['files'] as List)
          .cast<Map>()
          .where((f) => f['file'] == name)
          .firstOrNull;
      if (metadata == null) return null;
      final file = File(p.join(_folderSync(root, token).path, name));
      if (!file.existsSync() || file.lengthSync() != metadata['sizeBytes']) {
        return null;
      }
      if (!p.isWithin(
        root.resolveSymbolicLinksSync(),
        file.resolveSymbolicLinksSync(),
      )) {
        return null;
      }
      return SharedDraftAttachment(
        reference: {'token': token, 'file': name},
        filename: metadata['filename'] as String,
        mimeType: metadata['mimeType'] as String,
        sizeBytes: metadata['sizeBytes'] as int,
        previewPath: file.path,
        openRead: () async* {
          if (await restore(ref, origin, principal) == null) {
            throw const FormatException('Shared file unavailable');
          }
          yield* file.openRead();
        },
        release: () => release(token, name),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> bindDestination(String token, String server, String channel) =>
      _serial(() async {
        final root = await directory();
        final record = _recordSync(root, token);
        if (record == null) {
          throw const FormatException('Shared content unavailable');
        }
        record.addAll({'server': server, 'channel': channel});
        _writeSync(root, token, record);
      });

  Future<void> clearScope(
    String origin,
    String principal,
    String server,
    String? channel,
  ) => _serial(() async {
    final root = await directory();
    if (!await root.exists()) return;
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory ||
          !_tokenPattern.hasMatch(p.basename(entry.path))) {
        continue;
      }
      final record = await _record(p.basename(entry.path));
      if (record?['origin'] == origin &&
          record?['principal'] == principal &&
          record?['server'] == server &&
          (channel == null || record?['channel'] == channel)) {
        await entry.delete(recursive: true);
      }
    }
  });

  Future<void> complete(String token) => _serial(() async {
    final root = await directory();
    final record = _recordSync(root, token);
    if (record == null) return;
    record['pending'] = false;
    if ((record['files'] as List).isEmpty) {
      _discardSync(root, token);
    } else {
      _writeSync(root, token, record);
    }
  });

  Future<void> release(String token, String name) => _serial(() async {
    final record = await _record(token);
    if (record == null) return;
    final files = (record['files'] as List)
      ..removeWhere((f) => f['file'] == name);
    final file = File(p.join((await _folder(token)).path, name));
    if (await file.exists()) await file.delete();
    if (files.isEmpty) {
      await _discard(token);
    } else {
      await _write(token, record);
    }
  });

  Future<void> discard(String token) => _serial(() => _discard(token));
  Future<void> _discard(String token) async {
    final folder = await _folder(token);
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  Future<void> clearAccount(String origin, String principal) =>
      _serial(() async {
        final root = await directory();
        if (!await root.exists()) return;
        await for (final entry in root.list(followLinks: false)) {
          if (entry is! Directory ||
              !_tokenPattern.hasMatch(p.basename(entry.path))) {
            continue;
          }
          final record = await _record(p.basename(entry.path));
          if (record != null &&
              (record['principal'] == null ||
                  record['principal'] == principal &&
                      record['origin'] == origin)) {
            await entry.delete(recursive: true);
          }
        }
      });
}
