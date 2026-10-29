import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:desktop_drop/src/drop_item.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:universal_platform/universal_platform.dart';

import 'events.dart';
import 'web_drop_item.dart';

typedef RawDropListener = void Function(DropEvent);

/// Result of [DesktopDrop.resolveLinuxDrop].
class LinuxDropResolution {
  const LinuxDropResolution(this.paths, {this.error});
  final List<String> paths;

  /// Set when the drag offered files but none could be read.
  final String? error;
}

/// Parses a `text/uri-list` payload: `file://` URIs become local paths, other
/// schemes are kept as is, and lines without a scheme (portal keys, plain
/// text) are dropped.
List<String> parseLinuxUriList(String text) {
  return const LineSplitter().convert(text).map((e) {
    try {
      final uri = Uri.tryParse(e);
      if (uri == null || !uri.hasScheme) {
        // No scheme = likely a portal key
        return '';
      }
      if (uri.scheme == 'file') {
        return uri.toFilePath();
      }
      // smb://, http://, etc. - keep as-is (not portal keys)
      return e;
    } catch (error, stacktrace) {
      debugPrint('failed to parse linux path: $error $stacktrace');
    }
    return '';
  }).where((e) => e.isNotEmpty).toList();
}

class DesktopDrop {
  static const MethodChannel _channel = MethodChannel('desktop_drop');

  DesktopDrop._();

  static final instance = DesktopDrop._();

  final _listeners = <RawDropListener>{};

  var _inited = false;

  Offset? _offset;

  void init() {
    if (_inited) {
      return;
    }
    _inited = true;
    _channel.setMethodCallHandler((call) async {
      try {
        return await _handleMethodChannel(call);
      } catch (e, s) {
        debugPrint('_handleMethodChannel: $e $s');
      }
    });
  }

  /// macOS: Attempt to start security-scoped access for a bookmarked URL.
  ///
  /// Pass the [DropItem.extraAppleBookmark] bytes from a dropped file that
  /// originated outside the app container. Returns `true` if access began.
  ///
  /// If [bookmark] is empty, this function returns `false` and does not
  /// invoke the platform call. Promise files written under your container do
  /// not require security-scoped access.
  Future<bool> startAccessingSecurityScopedResource(
      {required Uint8List bookmark}) async {
    if (bookmark.isEmpty) return false;
    Map<String, dynamic> resultMap = {};
    resultMap["apple-bookmark"] = bookmark;
    final bool? result = await _channel.invokeMethod(
        "startAccessingSecurityScopedResource", resultMap);
    if (result == null) return false;
    return result;
  }

  /// macOS: Stop security-scoped access previously started.
  ///
  /// If [bookmark] is empty, this function returns `true` and does not
  /// invoke the platform call, acting as a no-op.
  Future<bool> stopAccessingSecurityScopedResource(
      {required Uint8List bookmark}) async {
    if (bookmark.isEmpty) return true;
    Map<String, dynamic> resultMap = {};
    resultMap["apple-bookmark"] = bookmark;
    final bool result = await _channel.invokeMethod(
        "stopAccessingSecurityScopedResource", resultMap);
    return result;
  }

  Future<void> _handleMethodChannel(MethodCall call) async {
    switch (call.method) {
      case "entered":
        final position = (call.arguments as List).cast<double>();
        _offset = Offset(position[0], position[1]);
        _notifyEvent(DropEnterEvent(location: _offset!));
        break;
      case "updated":
        if (_offset == null && UniversalPlatform.isLinux) {
          final position = (call.arguments as List).cast<double>();
          _offset = Offset(position[0], position[1]);
          _notifyEvent(DropEnterEvent(location: _offset!));
          return;
        }
        final position = (call.arguments as List).cast<double>();
        _offset = Offset(position[0], position[1]);
        _notifyEvent(DropUpdateEvent(location: _offset!));
        break;
      case "exited":
        _notifyEvent(DropExitEvent(location: _offset ?? Offset.zero));
        _offset = null;
        break;
      case "performOperation":
        final paths = (call.arguments as List).cast<String>();
        _notifyEvent(
          DropDoneEvent(
            location: _offset ?? Offset.zero,
            files: paths.map((e) => DropItemFile(e)).toList(),
          ),
        );
        _offset = null;
        break;
      case "performOperation_macos":
        final items = (call.arguments as List).cast<Map>();
        _notifyEvent(
          DropDoneEvent(
            location: _offset ?? Offset.zero,
            files: items.map((raw) {
              final path = raw["path"] as String;
              final bookmark = raw["apple-bookmark"] as Uint8List?;
              final isDir = (raw["isDirectory"] as bool?) ?? false;
              final fromPromise = (raw["fromPromise"] as bool?) ?? false;
              if (isDir) {
                return DropItemDirectory(
                  path,
                  const [],
                  extraAppleBookmark: bookmark,
                  fromPromise: fromPromise,
                );
              }
              return DropItemFile(
                path,
                extraAppleBookmark: bookmark,
                fromPromise: fromPromise,
              );
            }).toList(),
          ),
        );
        _offset = null;
        break;

      case "performOperation_linux":
        // gtk notify 'exit' before 'performOperation'.
        final text = (call.arguments as List<dynamic>)[0] as String;
        final offset = ((call.arguments as List<dynamic>)[1] as List<dynamic>)
            .cast<double>();
        final paths = parseLinuxUriList(text);
        _notifyEvent(DropDoneEvent(
          location: Offset(offset[0], offset[1]),
          files: paths.map((e) => DropItemFile(e)).toList(),
          rawText: text,
        ));
        break;
      case "performOperation_linux_sources":
        // RAFT PATCH: the native side read both `text/uri-list` and the
        // portal key of the same drag. Choose between them here.
        final args = call.arguments as List<dynamic>;
        final uriText = args[0] as String;
        final portalKey = args[1] as String;
        final sourcesOffset = (args[2] as List<dynamic>).cast<double>();
        final resolved = await resolveLinuxDrop(
          uriText: uriText,
          portalKey: portalKey,
        );
        _notifyEvent(DropDoneEvent(
          location: Offset(sourcesOffset[0], sourcesOffset[1]),
          files: resolved.paths.map((e) => DropItemFile(e)).toList(),
          rawText: uriText.isNotEmpty ? uriText : portalKey,
          error: resolved.error,
        ));
        break;
      case "performOperation_portal":
        // The portal target carries a one-time transfer key instead of
        // file paths. Resolve it against org.freedesktop.portal.FileTransfer
        // so consumers receive paths they can open directly.
        final portalText = (call.arguments as List<dynamic>)[0] as String;
        final portalOffset =
            ((call.arguments as List<dynamic>)[1] as List<dynamic>)
                .cast<double>();
        final resolved = await resolveLinuxDrop(
          uriText: '',
          portalKey: portalText,
        );
        final paths = resolved.paths;
        _notifyEvent(DropDoneEvent(
          location: Offset(portalOffset[0], portalOffset[1]),
          files: paths.map((e) => DropItemFile(e)).toList(),
          rawText: portalText,
          error: resolved.error,
        ));
        break;
      case "performOperation_web":
        final results = (call.arguments as List)
            .cast<Map>()
            .map((e) => WebDropItem.fromJson(e.cast<String, dynamic>()))
            .map((e) => e.toDropItem())
            .toList();
        _notifyEvent(
          DropDoneEvent(location: _offset ?? Offset.zero, files: results),
        );
        _offset = null;
        break;
      default:
        throw UnimplementedError('${call.method} not implement.');
    }
  }

  /// The production resolver (a DBus call), for tests that exercise it.
  @visibleForTesting
  static Future<List<String>> realPortalResolver(String key) =>
      _resolvePortalFiles(key);

  /// Portal transfer resolver; replaced in tests.
  @visibleForTesting
  Future<List<String>> Function(String key) portalResolver =
      _resolvePortalFiles;

  /// Whether this process is a Flatpak app, where host `file://` paths from
  /// the drag are not readable and the document portal must be preferred.
  @visibleForTesting
  bool Function() inFlatpak = _defaultInFlatpak;

  /// Whether a path from the URI list can be read by this process.
  @visibleForTesting
  bool Function(String path) pathExists = (path) =>
      FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;

  /// RAFT PATCH: picks the files of a Linux drop that carried a
  /// `text/uri-list` payload, an `application/vnd.portal.filetransfer` key,
  /// or both.
  ///
  /// * Normal (not Flatpak) receivers read the URI list directly when the
  ///   paths exist; the portal is only asked when no readable URI was offered.
  /// * Flatpak receivers ask the portal first.
  /// * A failing or empty portal falls back to the URI list (and the other way
  ///   round); [LinuxDropResolution.error] is set only when nothing was
  ///   resolved although the drag offered something.
  @visibleForTesting
  Future<LinuxDropResolution> resolveLinuxDrop({
    required String uriText,
    required String portalKey,
  }) async {
    final uriPaths = parseLinuxUriList(uriText);
    final readable = uriPaths
        .where((e) => !e.startsWith('/') || pathExists(e))
        .toList();
    Future<List<String>> viaPortal() async {
      if (portalKey.isEmpty) return const [];
      try {
        return await portalResolver(portalKey);
      } catch (error) {
        debugPrint('desktop_drop: portal transfer failed: $error');
        return const [];
      }
    }

    List<String> paths;
    if (inFlatpak()) {
      paths = await viaPortal();
      if (paths.isEmpty) paths = uriPaths;
    } else if (readable.isNotEmpty) {
      paths = readable;
    } else {
      paths = await viaPortal();
      if (paths.isEmpty) paths = uriPaths;
    }
    final offered = uriText.trim().isNotEmpty || portalKey.isNotEmpty;
    return LinuxDropResolution(
      paths,
      error: offered && paths.isEmpty ? "Couldn't read dropped files" : null,
    );
  }

  static bool _defaultInFlatpak() =>
      Platform.environment.containsKey('FLATPAK_ID') ||
      File('/.flatpak-info').existsSync();

  /// Resolves an XDG FileTransfer portal key into document-portal paths.
  ///
  /// RetrieveFiles exports each dropped file for this application and
  /// returns paths under /run/user/$UID/doc that are readable both inside
  /// and outside a Flatpak sandbox. Failures throw (RAFT PATCH; upstream
  /// swallowed them into an empty list).
  static Future<List<String>> _resolvePortalFiles(String key) async {
    DBusClient? client;
    try {
      client = DBusClient.session();
      final result = await client.callMethod(
        destination: 'org.freedesktop.portal.Documents',
        path: DBusObjectPath('/org/freedesktop/portal/documents'),
        interface: 'org.freedesktop.portal.FileTransfer',
        name: 'RetrieveFiles',
        values: [DBusString(key), DBusDict.stringVariant({})],
      );
      if (result.values.isEmpty || result.values.first is! DBusArray) {
        return const [];
      }
      return (result.values.first as DBusArray)
          .children
          .map((value) => value.asString())
          .toList();
    } finally {
      await client?.close();
    }
  }

  void _notifyEvent(DropEvent event) {
    for (final listener in _listeners) {
      listener(event);
    }
  }

  void addRawDropEventListener(RawDropListener listener) {
    assert(!_listeners.contains(listener));
    _listeners.add(listener);
  }

  void removeRawDropEventListener(RawDropListener listener) {
    assert(_listeners.contains(listener));
    _listeners.remove(listener);
  }
}
