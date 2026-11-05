import 'dart:async';

import 'package:flutter/services.dart';

import 'geometry.dart';
import 'snapshot.dart';

/// The host owns all methods. Uploaded HTML receives no message channel or
/// callable application object. Browser events contain no credentials.
class SystemWebViewController {
  SystemWebViewController._(this._channel, this.supportsSnapshots);
  final bool supportsSnapshots;
  static const rootChannel = MethodChannel('app.raft/system_webview');
  final MethodChannel _channel;
  final _events = StreamController<Map<Object?, Object?>>.broadcast(sync: true);
  Stream<Map<Object?, Object?>> get events => _events.stream;
  bool _closed = false;
  Future<void>? _disposing;
  int _layoutSequence = 0;
  bool get closed => _closed;

  static Future<SystemWebViewController> create() async {
    final value = await rootChannel.invokeMapMethod<String, Object?>('create');
    if (value?['id'] is! int ||
        (value!['id'] as int) <= 0 ||
        value['protocol'] != 1 ||
        value['ephemeral'] != true ||
        value['sandboxed'] != true) {
      if (value?['id'] case final int id when id > 0) {
        try {
          await MethodChannel('app.raft/system_webview/$id')
              .invokeMethod<void>('dispose');
        } catch (_) {
          /* Refuse the renderer even if its cleanup also failed. */
        }
      }
      throw StateError('The system renderer could not isolate this preview.');
    }
    final result = SystemWebViewController._(
      MethodChannel('app.raft/system_webview/${value['id']}'),
      value['snapshot'] == true,
    );
    result._channel.setMethodCallHandler((call) async {
      if (!result._closed && call.method == 'event' && call.arguments is Map) {
        result._events.add(Map<Object?, Object?>.from(call.arguments as Map));
      }
    });
    return result;
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (_closed) throw StateError('The system renderer is closed.');
    final value = await _channel.invokeMethod<T>(method, arguments);
    if (_closed) throw StateError('The system renderer is closed.');
    return value;
  }

  /// An accepted host scroll/jump changed document pixels without a GTK event.
  /// Uploaded pages receive no reference to this host controller.
  void markSnapshotDirty() {
    if (!_closed) _events.add({'type': 'snapshotDirty'});
  }

  Future<Map<Object?, Object?>?> inspect() =>
      _invoke<Map<Object?, Object?>>('inspect');

  /// Confirms current GTK focus without treating a queued event as ownership.
  Future<bool> hasNativeFocus() async =>
      await _invoke<bool>('hasFocus') == true;

  Future<void> updateRegionOverlay(Map<String, Object?> frame) =>
      _invoke<void>('regionOverlay', frame);

  Future<SystemWebViewSnapshot?> snapshot() async {
    if (!supportsSnapshots || _closed) return null;
    final sequence = _layoutSequence;
    final frame = await _invoke<Object?>('snapshot');
    return sequence == _layoutSequence
        ? SystemWebViewSnapshot.parse(frame, sequence)
        : null;
  }

  Future<void> load(Uri uri) => _invoke<void>('load', {'url': uri.toString()});
  Future<Object?> evaluate(String source) =>
      _invoke<Object?>('evaluate', {'source': source});
  Future<Uri?> currentUri() async =>
      Uri.tryParse(await _invoke<String>('currentUri') ?? '');
  Future<void> layout(SystemWebViewLayout value) => _invoke<void>('layout', {
    ...value.data,
    'sequence': ++_layoutSequence,
    'visible': value.visible,
  });

  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    _closed = true;
    _events.add({'type': 'closed'});
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod<void>('dispose');
    } finally {
      await _events.close();
    }
  }
}
