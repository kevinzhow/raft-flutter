import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/attachment_html_desktop_policy.dart';
import 'package:raft_flutter/platform/attachment_html_webview_events.dart';

void main() {
  final preview = Uri.parse(
    'https://api.example/api/attachments/qa/html-preview?previewToken=qa',
  );
  const external = 'https://example.com/';
  final opened = <String>[];
  final failures = <String>[];

  DesktopHtmlPolicy policy() => DesktopHtmlPolicy(
    preview,
    AttachmentHtmlWebViewEvents(
      onNavigation: (url) {
        opened.add(url);
        return false;
      },
      onLoaded: () {},
      onFailed: failures.add,
    ),
  )..started = true;

  NavigationAction action({
    NavigationType? type,
    bool? gesture,
    bool redirect = false,
  }) => NavigationAction(
    request: URLRequest(url: WebUri(external)),
    isForMainFrame: true,
    navigationType: type,
    hasGesture: gesture,
    isRedirect: redirect,
  );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    opened.clear();
    failures.clear();
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'Windows native link activation reaches the owner without hasGesture',
    () {
      expect(
        policy().navigation(action(type: NavigationType.LINK_ACTIVATED)),
        NavigationActionPolicy.CANCEL,
      );
      expect(opened, [external]);
    },
  );

  test('Windows script, redirects and explicit non-gestures stay blocked', () {
    final gate = policy();
    for (final navigation in [
      action(),
      action(type: NavigationType.OTHER),
      action(type: NavigationType.LINK_ACTIVATED, gesture: false),
      action(type: NavigationType.LINK_ACTIVATED, redirect: true),
    ]) {
      expect(gate.navigation(navigation), NavigationActionPolicy.CANCEL);
    }
    expect(opened, isEmpty);
  });

  test(
    'the Windows metadata fallback does not change Linux gesture policy',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      policy().navigation(action(type: NavigationType.LINK_ACTIVATED));
      expect(opened, isEmpty);
      policy().navigation(action(gesture: true));
      expect(opened, [external]);
    },
  );

  test('external cancellation cannot be attributed to the loaded report', () {
    final gate = policy()..loaded = true;
    final params = gate.params(onCreated: (_) {});
    final externalRequest = WebResourceRequest(
      url: WebUri(external),
      isForMainFrame: true,
    );
    // The Windows adapter must supply the attempted request URL, not Source.
    params.onReceivedError!(
      null,
      externalRequest,
      WebResourceError(
        type: WebResourceErrorType.CANCELLED,
        description: 'Expected owner navigation cancellation',
      ),
    );
    expect(failures, isEmpty);
    expect(gate.loaded, isTrue);
  });
}
