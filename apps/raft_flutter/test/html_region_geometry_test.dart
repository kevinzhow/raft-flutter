import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/attachment_html_geometry.dart';
import 'package:raft_ui/raft_ui.dart';

const host = Size(500, 400);
final uri = Uri.parse(
  'https://example.invalid/api/attachments/a/html-preview?previewToken=test',
);
Map command(String source) {
  final start = source.indexOf('const command = ') + 'const command = '.length;
  return jsonDecode(source.substring(start, source.indexOf(';\n', start)))
      as Map;
}

Map<String, Object> geometry({double y = 100}) => {
  'viewportWidth': 1000,
  'viewportHeight': 800,
  'visibleWidth': 500,
  'visibleHeight': 400,
  'scrollX': 0,
  'scrollY': y,
  'documentWidth': 1000,
  'documentHeight': 3000,
};
Map<String, Object> region() => {
  'x': 20,
  'y': 130,
  'w': 120,
  'h': 80,
  'viewportWidth': 1000,
  'documentWidth': 1000,
  'documentHeight': 3000,
  'quote': 'Actual quote',
};
String packet(String source, {Object? shape, Object? location}) => jsonEncode({
  'version': 1,
  'request': command(source)['request'],
  'geometry': shape ?? geometry(),
  'region': location ?? region(),
});

void main() {
  test(
    'host evaluation returns only validated geometry and closed API fields',
    () async {
      final sources = <String>[];
      final controller = AttachmentHtmlGeometryController(
        uri: uri,
        currentUri: () async => uri,
        allowed: () => true,
        evaluate: (source) async {
          sources.add(source);
          return packet(
            source,
            location: {...region(), 'url': 'evil', 'script': 'evil'},
          );
        },
      );
      final found = (await controller.capture(
        const Rect.fromLTWH(20, 30, 120, 80),
        host,
      ))!;
      expect(found.region.anchor, {'type': 'html-region', 'data': region()});
      expect(
        found.geometry.local(found.region, host),
        const Rect.fromLTWH(20, 30, 120, 80),
      );
      expect(sources.single, isNot(contains('postMessage')));
      expect(sources.single, isNot(contains('addJavaScriptHandler')));
      expect(sources.single, isNot(contains('appBridge')));
      final jump = (await controller.jump(found.region, host))!;
      expect(jump.region.rect, found.region.rect);
      expect(command(sources.last)['region'], region());
      expect(await controller.scrollBy(const Offset(0, 40), host), isNotNull);
      expect(command(sources.last)['delta'], [0, 40]);
    },
  );
  test(
    'wrong page, permission loss and disposed owner reject before evaluation',
    () async {
      var allowed = true, calls = 0;
      var shown = uri;
      final c = AttachmentHtmlGeometryController(
        uri: uri,
        currentUri: () async => shown,
        allowed: () => allowed,
        evaluate: (s) async {
          calls++;
          return packet(s);
        },
      );
      shown = uri.replace(path: '/other');
      expect(await c.measure(host), isNull);
      expect(calls, 0);
      shown = uri;
      allowed = false;
      expect(await c.measure(host), isNull);
      expect(calls, 0);
      allowed = true;
      c.dispose();
      expect(await c.measure(host), isNull);
      expect(calls, 0);
    },
  );
  test(
    'late result is rejected after permission or native URL changes',
    () async {
      for (final change in ['permission', 'url', 'dispose']) {
        var allowed = true;
        var shown = uri;
        String? script;
        final pending = Completer<Object?>();
        final c = AttachmentHtmlGeometryController(
          uri: uri,
          currentUri: () async => shown,
          allowed: () => allowed,
          evaluate: (s) {
            script = s;
            return pending.future;
          },
        );
        final call = c.capture(const Rect.fromLTWH(0, 0, 0, 0), host);
        await Future<void>.delayed(Duration.zero);
        if (change == 'permission') allowed = false;
        if (change == 'url') shown = Uri.parse('about:blank');
        if (change == 'dispose') c.dispose();
        pending.complete(packet(script!));
        expect(await call, isNull, reason: change);
      }
    },
  );
  test('malformed, giant, wrong serial, NaN, negative and nonnumeric values fail closed', () async {
    for (final invalid in <Object>[
      'invalid',
      'x' * 17000,
      jsonEncode(jsonEncode('x' * 17000)),
      {},
      jsonEncode({'version': 1, 'request': -1, 'geometry': geometry()}),
      jsonEncode({
        'version': 1,
        'request': 1,
        'geometry': {...geometry(), 'scrollX': -1},
      }),
      jsonEncode({
        'version': 1,
        'request': 1,
        'geometry': {...geometry(), 'viewportWidth': '500'},
      }),
    ]) {
      final c = AttachmentHtmlGeometryController(
        uri: uri,
        currentUri: () async => uri,
        allowed: () => true,
        evaluate: (_) async => invalid,
      );
      expect(await c.measure(host), isNull, reason: '$invalid');
    }
    for (final bad in [double.nan, double.infinity, -1, '1', null]) {
      expect(RaftHtmlRegion.parse({...region(), 'x': bad}), isNull);
    }
    expect(RaftHtmlRegion.parse({...region(), 'viewportWidth': 0}), isNull);
    expect(RaftHtmlRegion.parse({...region(), 'x': 10000001}), isNull);
    expect(RaftHtmlRegion.parse({...region(), 'quote': []}), isNull);
    expect(RaftHtmlRegion.parse({...region(), 'w': 0, 'h': 0}), isNotNull);
    expect(
      RaftHtmlRegion.parse({...region(), 'quote': 'a' * 400})!.quote!.length,
      200,
    );
  });
  test('bounded native outstanding operations survive timeouts without growing a queue', () async {
    var calls = 0;
    final pending = <Completer<Object?>>[];
    final c = AttachmentHtmlGeometryController(
      uri: uri,
      currentUri: () async => uri,
      allowed: () => true,
      timeout: const Duration(milliseconds: 5),
      evaluate: (_) {
        calls++;
        final p = Completer<Object?>();
        pending.add(p);
        return p.future;
      },
    );
    expect(await c.measure(host), isNull);
    expect(await c.measure(host), isNull);
    expect(await c.measure(host), isNull);
    expect(calls, 2);
    for (final p in pending) {
      p.complete(null);
    }
    await Future<void>.delayed(Duration.zero);
    expect(c.pending, 0);
  });
  test('native double-encoded JSON is decoded, fractional and invalid host sizes are bounded', () async {
    final c = AttachmentHtmlGeometryController(
      uri: uri,
      currentUri: () async => uri,
      allowed: () => true,
      evaluate: (s) async => jsonEncode(packet(s)),
    );
    expect(await c.measure(host), isNotNull);
    expect(await c.measure(Size.zero), isNull);
    expect(await c.measure(const Size(double.infinity, 100)), isNull);
    // Pointer capture can finish outside the pane; content coordinates are
    // clamped at zero by the script, exactly as the existing API normalizes.
    expect(
      await c.capture(const Rect.fromLTWH(-1, 0, 10, 10), host),
      isNotNull,
    );
    expect(await c.capture(const Rect.fromLTWH(0, 0, -1, 10), host), isNull);
    expect(await c.scrollBy(const Offset(double.nan, 1), host), isNull);
  });
}
