import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/artifact_viewer.dart';
import 'package:raft_flutter/features/custom_protocol_link.dart';
import 'package:raft_flutter/features/human_login.dart';
import 'package:raft_flutter/features/human_login_sheet.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'close_dialogs_test.dart'
    show anyX, openFromButton, registerNoScrimTests;
import 'support/close_registry_links.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'support/fake_webview.dart';
import 'support/human_login_fake.dart';

void main() {
  setUpAll(() => WebViewPlatform.instance = FakeWebView());
  setUp(FakeWebView.reset);
  final harness = <String, OpenSurface>{
    'custom-protocol-link-confirm': (t, size) async {
      await openFromButton(
        t,
        size,
        (context) => unawaited(
          confirmCustomProtocolLink(
            context,
            Uri.parse('obsidian://open?vault=a'),
          ),
        ),
      );
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('custom-protocol-link-confirm'))
            .evaluate()
            .isNotEmpty,
        scrim: const Offset(6, 6),
      );
    },
    'artifact-viewer': (t, size) async {
      await openFromButton(
        t,
        size,
        (context) => unawaited(
          openArtifactLink(
            context,
            Uri.parse('https://raft-artifacts.com/p/acme/report'),
          ),
        ),
      );
      final viewer = find.byKey(const ValueKey('artifact-viewer'));
      return SurfaceProbe(
        isOpen: () => viewer.evaluate().isNotEmpty,
        x: find.descendant(of: find.byType(RaftLightboxHeader), matching: anyX),
        back: find.byKey(const ValueKey('artifact-viewer-close')),
        // The phone page has no scrim; its corner is the Back button.
        scrim: size.width < 768 ? null : const Offset(6, 6),
      );
    },
    'human-login-sheet': (t, size) async {
      await openFromButton(
        t,
        size,
        (context) => unawaited(
          showHumanLoginSheet(
            context,
            api: FakeHumanLoginApi(),
            request: HumanLoginRequest.fromSetupUri(
              Uri.parse(
                'https://app.example.com/login-with-raft/setup?client_id=artifact-share'
                '&return_to=https%3A%2F%2Fartifacts.example.com%2Fcb&scope=openid&server=srv-1',
              ),
            ),
          ),
        ),
      );
      final sheet = find.byKey(const ValueKey('human-login-sheet'));
      return SurfaceProbe(
        isOpen: () => sheet.evaluate().isNotEmpty,
        x: find.descendant(of: sheet, matching: anyX),
        scrim: const Offset(6, 6),
        dragHandle: find.byKey(const ValueKey('raft-sheet-handle')),
      );
    },
  };
  registerCloseTests(linkSurfaces, harness);
  registerNoScrimTests(linkSurfaces, harness);
}
