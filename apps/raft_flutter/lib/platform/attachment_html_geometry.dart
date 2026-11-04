import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'attachment_html_geometry_script.dart';

/// No injected channels or persistent listeners: each bounded request is a
/// native host evaluation and a bounded JSON result. Result data is hostile.
class AttachmentHtmlGeometryController implements RaftHtmlRegionController {
  AttachmentHtmlGeometryController({
    required this.uri,
    required this.evaluate,
    required this.currentUri,
    required this.allowed,
    this.timeout = const Duration(milliseconds: 800),
  });
  final Uri uri;
  final Future<Object?> Function(String source) evaluate;
  final Future<Uri?> Function() currentUri;
  final bool Function() allowed;
  final Duration timeout;
  bool closed = false;
  int requests = 0, pending = 0;
  @override
  bool get active => !closed && allowed();
  void dispose() => closed = true;

  Future<bool> owns() async {
    if (!active) return false;
    try {
      final current = await currentUri().timeout(timeout);
      return active &&
          current?.replace(fragment: '') == uri.replace(fragment: '');
    } catch (_) {
      return false;
    }
  }

  Future<Map?> invoke(
    String operation,
    Size host, {
    Map<String, dynamic> arguments = const {},
  }) async {
    if (!active ||
        pending >= 2 ||
        !host.width.isFinite ||
        !host.height.isFinite ||
        host.isEmpty) {
      return null;
    }
    final request = ++requests;
    pending++;
    Future<Object?>? running;
    try {
      if (!await owns()) return null;
      final command = {
        'operation': operation,
        'request': request,
        'host': [host.width, host.height],
        ...arguments,
      };
      running = evaluate(attachmentHtmlGeometryScript(command));
      // A timeout does not free the native evaluation slot: at most two
      // outstanding operations can survive a hostile renderer that hangs.
      final result = await running.timeout(timeout);
      if (!await owns()) return null;
      if (result is! String) return null;
      Object? value = result;
      for (var i = 0; i < 2 && value is String; i++) {
        if (value.length > 16384) return null;
        value = jsonDecode(value);
      }
      return value is Map &&
              value['version'] == 1 &&
              value['request'] == request
          ? value
          : null;
    } catch (_) {
      return null;
    } finally {
      if (running == null) {
        pending--;
      } else {
        unawaited(
          running.then(
            (_) {
              pending--;
            },
            onError: (Object _) {
              pending--;
            },
          ),
        );
      }
    }
  }

  RaftHtmlRegionLocation? location(Map? value) {
    final geometry = RaftHtmlGeometry.parse(value?['geometry']);
    final region = RaftHtmlRegion.parse(value?['region']);
    return geometry == null || region == null
        ? null
        : RaftHtmlRegionLocation(geometry, region);
  }

  @override
  Future<RaftHtmlGeometry?> measure(Size host) async =>
      RaftHtmlGeometry.parse((await invoke('measure', host))?['geometry']);
  @override
  Future<RaftHtmlRegionLocation?> capture(Rect local, Size host) async {
    if (![
          local.left,
          local.top,
          local.width,
          local.height,
        ].every((v) => v.isFinite && v.abs() <= raftHtmlCoordinateLimit) ||
        local.width < 0 ||
        local.height < 0) {
      return null;
    }
    return location(
      await invoke(
        'capture',
        host,
        arguments: {
          'rect': [local.left, local.top, local.width, local.height],
        },
      ),
    );
  }

  @override
  Future<RaftHtmlRegionLocation?> jump(
    RaftHtmlRegion region,
    Size host,
  ) async =>
      location(await invoke('jump', host, arguments: {'region': region.data}));
  @override
  Future<RaftHtmlGeometry?> scrollBy(Offset delta, Size host) async {
    if (!delta.dx.isFinite || !delta.dy.isFinite) return null;
    return RaftHtmlGeometry.parse(
      (await invoke(
        'scroll',
        host,
        arguments: {
          'delta': [
            delta.dx.clamp(-100000, 100000),
            delta.dy.clamp(-100000, 100000),
          ],
        },
      ))?['geometry'],
    );
  }
}
