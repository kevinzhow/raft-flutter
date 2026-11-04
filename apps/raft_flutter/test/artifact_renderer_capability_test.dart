import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/custom_protocol_link.dart';
import 'package:raft_flutter/platform/attachment_html_webview.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

// The isolated HTML plugin is registered on desktop. It does not implement
// the authenticated webview_flutter controller used by ArtifactViewer.
class _IsolatedHtmlPlatform extends InAppWebViewPlatform {}

void main() {
  // This test file owns its isolate. Leave the authenticated plugin unset:
  // its interface deliberately disallows assigning null after registration.
  setUpAll(() => InAppWebViewPlatform.instance = _IsolatedHtmlPlatform());
  testWidgets(
    'isolated HTML does not claim authenticated Artifact support',
    (t) async {
      expect(WebViewPlatform.instance, isNull);
      expect(attachmentHtmlWebViewSupported, isTrue);
      expect(debugArtifactViewerSupported, isNull);
      const url = 'https://raft-artifacts.com/p/isolated-fixture/report';
      final launches = <String>[];
      final messenger = t.binding.defaultBinaryMessenger;
      const launcher = MethodChannel('plugins.flutter.io/url_launcher');
      messenger.setMockMethodCallHandler(launcher, (call) async {
        if (call.method == 'launch') {
          launches.add((call.arguments as Map)['url'] as String);
        }
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(launcher, null));
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(openMessageLink(context, url)),
              child: const Text('Open report'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open report'));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(launches, [url]);
      expect(find.byKey(const ValueKey('artifact-viewer')), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.linux,
      TargetPlatform.windows,
    }),
  );
}
