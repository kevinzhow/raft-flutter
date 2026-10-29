import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  test('native HTML strips script, frames, forms, file/network loaders and event attributes', () {
    final safe = raftStaticHtml(
      '''<h1 onclick="evil()">Visible</h1>
<script>secretScript()</script><iframe src="file:///private">Private</iframe>
<img src="https://example.com/beacon" alt="Diagram">
<p style="background-image:url(file:///private)">Body</p>
<form action="https://example.com"><input value="Private value"></form>
<a href="javascript:evil()">Unsafe link</a><a href="https://example.com">Safe link</a>''',
    );
    expect(safe, contains('<h1>Visible</h1>'));
    expect(safe, contains('[Image: Diagram]'));
    expect(safe, contains('https://example.com'));
    for (final value in [
      'secretScript',
      'iframe',
      'file:',
      'src=',
      'style=',
      'onclick',
      'javascript:',
      'Private value',
      'action=',
    ]) {
      expect(safe, isNot(contains(value)));
    }
  });
  test('HTML parser rejects oversized or excessive element input', () {
    expect(
      () => raftStaticHtml('x' * (raftStaticHtmlMaxChars + 1)),
      throwsFormatException,
    );
    // The former 2 MiB cap rejected real reports with inline base64 images.
    final large =
        '<h1>Report</h1><img src="data:image/jpeg;base64,${'A' * (3 * 1024 * 1024)}" alt="Chart">';
    expect(raftStaticHtml(large), contains('[Image: Chart]'));
    expect(() => raftStaticHtml('<p>x</p>' * 4001), throwsFormatException);
  });
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'native HTML controls and links work without overflow: ${dark ? 'dark' : 'light'}',
      (tester) async {
        tester.view.reset();
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var interactive = 0;
        String? opened;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: RaftHtmlPreview(
                html: '<h2>中文と日本語</h2><p><a href="https://example.com">Reference</a></p>',
                onInteractive: () => interactive++,
                onLink: (value) => opened = value,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('中文と日本語', findRichText: true), findsOneWidget);
        await tester.tap(find.text('Open Interactive Preview in Browser'));
        expect(interactive, 1);
        await tester.tap(find.text('Reference', findRichText: true));
        expect(opened, 'https://example.com');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
