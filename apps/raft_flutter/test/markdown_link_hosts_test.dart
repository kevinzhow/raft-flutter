import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web renders every untrusted markdown through `MarkdownLink`: http(s) open
/// at once, `obsidian://` asks first. The app's links scope gives the same
/// rule to the hosts that have no handler of their own (forwarded bundles,
/// documents, attachment comments, release notes).
void main() {
  Future<List<String>> mount(WidgetTester t, Widget body) async {
    final launched = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
        }
        return true;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        null,
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: AppServicesHost(
          services: const AppServices.updatesDisabledForTestOrPreview(),
          child: Scaffold(body: SingleChildScrollView(child: body)),
        ),
      ),
    );
    await t.pumpAndSettle();
    return launched;
  }

  Map<String, dynamic> bundle(String content) => {
    'kind': 'forwarded-bundle',
    'version': 1,
    'forwardedItems': [
      {
        'index': 0,
        'contentSnapshot': content,
        'sourceAuthorSnapshot': {'type': 'user', 'uniqueName': 'Author'},
        'provenanceState': 'available',
        'attachmentPolicy': 'excluded',
      },
    ],
  };

  const note = '[note](obsidian://open?vault=work)\n\n[site](https://x.dev)';
  final hosts = <String, Widget Function()>{
    'a forwarded bundle': () => RaftForwardedBundle(metadata: bundle(note)),
    'a document': () =>
        const RaftMessageBody(content: note, documentMode: true),
  };
  for (final entry in hosts.entries) {
    testWidgets('${entry.key} asks before an obsidian link and opens https', (
      t,
    ) async {
      final launched = await mount(t, entry.value());
      await t.tap(find.text('note', findRichText: true));
      await t.pumpAndSettle();
      expect(find.text('Open external link?'), findsOneWidget);
      expect(launched, isEmpty);
      await t.tap(find.text('Open link'));
      await t.pumpAndSettle();
      expect(launched, ['obsidian://open?vault=work']);
      await t.tap(find.text('site', findRichText: true));
      await t.pumpAndSettle();
      expect(launched.last, 'https://x.dev');
      expect(find.text('Open external link?'), findsNothing);
    });
  }

  testWidgets('without the app scope a link stays inert', (t) async {
    final launched = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        launched.add(call.method);
        return true;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        null,
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: const Scaffold(body: RaftMessageBody(content: note)),
      ),
    );
    await t.tap(find.text('site', findRichText: true));
    await t.pumpAndSettle();
    expect(launched, isEmpty);
    expect(find.text('Open external link?'), findsNothing);
  });
}
