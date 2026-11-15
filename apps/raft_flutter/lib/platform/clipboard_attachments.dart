import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:pasteboard/pasteboard.dart';
import 'package:raft_ui/raft_ui.dart' show RaftPasteAttachmentsIntent;

typedef ComposerFile = ({String name, Uint8List bytes});

/// Web `extractClipboardFiles` over the native clipboard: copied files first
/// (desktop file managers through the pasteboard plugin; iOS and Android
/// through `app.raft/clipboard-attachments`), then a copied image. Text-only
/// clipboards yield nothing so the editor's own text paste runs.
class ClipboardAttachments {
  const ClipboardAttachments({
    this._files,
    this._image,
    this._desktop,
    this._native,
    this._ios,
    this._android,
  });
  final Future<List<String>> Function()? _files;
  final Future<Uint8List?> Function()? _image;
  final bool? _desktop;
  final Future<List<ComposerFile>> Function()? _native;
  final bool? _ios;
  final bool? _android;

  static const channel = MethodChannel('app.raft/clipboard-attachments');
  // ignore: raft_lints/avoid_unreleased_resource -- Process-wide clipboard state lives for the lifetime of the app.
  static final ValueNotifier<bool> available = _ClipboardAvailability();
  static bool _watching = false;

  /// Observes attachment availability without reading clipboard contents,
  /// and hands a system Paste of attachments to the focused composer (iOS).
  /// Android only reports availability: its toolbar Paste is the composer's.
  static void watch() {
    if (kIsWeb ||
        _watching ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return;
    }
    _watching = true;
    var changed = false;
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'changed' when call.arguments is bool:
          changed = true;
          available.value = call.arguments as bool;
        case 'paste':
          // The system Paste found attachments; the focused composer takes
          // them through `read`. False lets the native text paste run.
          final context = FocusManager.instance.primaryFocus?.context;
          if (context == null || !context.mounted) return false;
          const intent = RaftPasteAttachmentsIntent();
          final action = Actions.maybeFind<RaftPasteAttachmentsIntent>(context);
          if (action == null || !action.isEnabled(intent)) {
            return false;
          }
          // Reply once the composer is done, so a paste that takes nothing
          // (unreadable file, inactive composer) still pastes its text.
          final taken = Actions.invoke(context, intent);
          return taken is Future<bool> && await taken;
      }
      return null;
    });
    unawaited(() async {
      final value = await _safe(
        () async => await channel.invokeMethod<bool>('available') ?? false,
        false,
      );
      // A change pushed meanwhile is newer than this first answer.
      if (!changed) available.value = value;
    }());
  }

  static Future<List<ComposerFile>> _readNative() async {
    final items = await channel.invokeListMethod<dynamic>('read') ?? [];
    return [
      for (final item in items)
        if ((item['bytes'] as Uint8List).isNotEmpty)
          (name: item['name'] as String, bytes: item['bytes'] as Uint8List),
    ];
  }

  /// Browsers name a pasted bitmap `image.png`; keep the same attachment name.
  static const imageName = 'image.png';

  bool get desktop =>
      _desktop ?? (Platform.isLinux || Platform.isMacOS || Platform.isWindows);

  Future<List<ComposerFile>> read() async {
    // Android copied files are content URIs that Dart cannot open; the
    // native side resolves them (NativeClipboardAttachmentsBridge.kt).
    if ((_ios ?? Platform.isIOS) || (_android ?? Platform.isAndroid)) {
      final files = await _safe(_native ?? _readNative, const <ComposerFile>[]);
      if (files.isNotEmpty) return files;
    } else if (desktop) {
      final paths = await _safe(_files ?? Pasteboard.files, const <String>[]);
      if (paths.isNotEmpty) return readLocalFiles(paths);
    }
    final image = await _safe(_image ?? () => Pasteboard.image, null);
    return image == null || image.isEmpty
        ? const []
        : [(name: imageName, bytes: image)];
  }

  static Future<T> _safe<T>(Future<T> Function() read, T fallback) async {
    try {
      return await read();
    } catch (error) {
      debugPrint('clipboard attachments unavailable: $error');
      return fallback;
    }
  }
}

/// Named so leak tracking can tell this process-wide notifier from others.
class _ClipboardAvailability extends ValueNotifier<bool> {
  _ClipboardAvailability() : super(false);
}

/// Reads local regular files, skipping duplicates, directories and anything
/// unreadable. [folders] counts skipped directories (Web drop notice).
Future<({List<ComposerFile> files, int folders})> readLocalFileEntries(
  Iterable<String> paths,
) async {
  final seen = <String>{};
  final files = <ComposerFile>[];
  var folders = 0;
  for (final path in paths) {
    if (!p.isAbsolute(path) || !seen.add(p.normalize(path))) continue;
    try {
      switch (await FileSystemEntity.type(path)) {
        case FileSystemEntityType.directory:
          folders++;
        case FileSystemEntityType.file:
          files.add((
            name: p.basename(path),
            bytes: await File(path).readAsBytes(),
          ));
        default:
          break;
      }
    } on FileSystemException catch (error) {
      debugPrint('skipped unreadable file: ${error.runtimeType}');
    }
  }
  return (files: files, folders: folders);
}

Future<List<ComposerFile>> readLocalFiles(Iterable<String> paths) async =>
    (await readLocalFileEntries(paths)).files;
