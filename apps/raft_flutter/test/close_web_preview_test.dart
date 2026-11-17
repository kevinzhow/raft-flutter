import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/channel_side_web_preview_panel.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'close_dialogs_test.dart' show ignoreOverflow;
import 'support/close_registry_web_link_choice.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'support/fake_webview.dart';
import 'support/web_preview_fixture.dart';

/// The web page beside the conversation, closed by its X, its Back chevron
/// (covering the chat on a phone), Esc and the phone's system Back. Its own
/// file so the panel parts keep their case budget.
void main() {
  setUpAll(() => WebViewPlatform.instance = FakeWebView());
  setUp(FakeWebView.reset);

  final harness = <String, OpenSurface>{
    'web-preview': (t, size) async {
      ignoreOverflow();
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final (w, _) = (await t.runAsync(webPreviewFixture))!;
      addTearDown(w.dispose);
      final store = WebPreviewStore.of(w)
        ..open(
          const WebPreviewPage(
            url: 'https://docs.example.com/',
            conversationId: 'c1',
          ),
        );
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ListenableBuilder(
              listenable: store,
              builder: (context, _) => store.page == null
                  ? const SizedBox.shrink()
                  : WebPreviewPanel(
                      store: store,
                      page: store.page!,
                      // The side area covers the chat below 768.
                      covering: size.width < 768,
                    ),
            ),
          ),
        ),
      );
      await t.pump();
      await t.pump();
      return SurfaceProbe(
        isOpen: () => store.page != null,
        x: find.byKey(const ValueKey('web-preview-close')),
        back: find.byKey(const ValueKey('web-preview-back')),
      );
    },
  };
  registerCloseTests(webPreviewSurfaces, harness);
}
