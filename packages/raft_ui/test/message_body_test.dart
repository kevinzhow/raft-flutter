import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  test(
    'unknown mention type and dotted name do not reuse a shorter identity',
    () {
      const refs = [
        RaftTextReference(text: '@Mona', href: 'raft-ref://mention/user/known'),
      ];
      final output = raftMessageReferences(
        '@Mona~unknown @Mona.com @Mona.',
        references: refs,
      );
      expect(
        output,
        '@Mona~unknown @Mona.com [@Mona](<raft-ref://mention/user/known>).',
      );
    },
  );

  test(
    'reference transformation protects code, email, links and unknown names',
    () {
      const refs = [
        RaftTextReference(text: '@Mona', href: 'raft-ref://mention/user/known'),
        RaftTextReference(text: '#team', href: 'raft-ref://channel/team-id'),
      ];
      final value = raftMessageReferences(
        'Hi @Mona #team task #27. x@Mona.com @MonaMore @unknown `@Mona task #27` [@Mona](https://example.org)\n```txt\n@Mona #team\n```',
        references: refs,
        taskHref: (n) => 'raft-ref://task/$n',
      );
      expect(value, contains('[@Mona](<raft-ref://mention/user/known>)'));
      expect(value, contains('task [#27](<raft-ref://task/27>)'));
      expect(value, contains('x@Mona.com @MonaMore @unknown'));
      // Web chips references inside authored link labels too (MessageItem
      // only protects code); the label carries the reference sentinel.
      expect(
        value,
        contains(
          '`@Mona task #27` '
          '[\u{E000}raft-ref://mention/user/known\u{E001}@Mona\u{E002}]'
          '(https://example.org)',
        ),
      );
      expect(value, contains('```txt\n@Mona #team\n```'));
    },
  );
  for (final theme in [
    raftTheme(RaftFamily.brutal),
    raftTheme(RaftFamily.elegant),
    raftTheme(RaftFamily.elegant, dark: true),
  ]) {
    testWidgets(
      'native Mermaid source, copy and fullscreen in ${theme.brightness} ${theme.extension<RaftTokens>()!.family}',
      (tester) async {
        String? clipboard;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData')
              clipboard = (call.arguments as Map)['text'];
            return null;
          },
        );
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: RaftMessageBody(
                  content: '## Plan\nHello **team**\n```mermaid\nflowchart LR\n A[Draft] --> B[Review]\n```',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(RaftMermaidBlock), findsOneWidget);
        expect(find.bySemanticsLabel('Draft'), findsOneWidget);
        await tester.tap(find.byTooltip('Show source'));
        await tester.pump();
        expect(
          find.text('flowchart LR\n A[Draft] --> B[Review]'),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Copy code'));
        await tester.pumpAndSettle();
        expect(clipboard, contains('flowchart LR'));
        await tester.tap(find.byTooltip('Show diagram'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Expand diagram'));

        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsOneWidget);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsNothing);
        semantics.dispose();
      },
    );
  }
  for (final family in RaftFamily.values) {
    testWidgets('narrow touch Mermaid preserves all actions in $family', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'];
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family),
          home: Scaffold(
            body: Center(
              child: RaftDensityScope(
                density: RaftDensity.touch,
                child: SizedBox(
                  width: 227.4,
                  child: RaftMermaidBlock(
                    source: 'flowchart LR\n A[Draft] --> B[Review]',
                    onExport: (_, _) async {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final toolbar = find.byKey(const ValueKey('mermaid-toolbar'));
      final bounds = tester.getRect(toolbar);
      for (final label in [
        'Show diagram',
        'Show source',
        'Copy code',
        'Download Mermaid diagram',
        'Expand diagram',
      ]) {
        final target = find.descendant(
          of: toolbar,
          matching: find.byTooltip(label),
        );
        expect(target, findsOneWidget);
        expect(bounds.contains(tester.getCenter(target)), isTrue);
      }
      await tester.tap(find.byTooltip('Show source'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('flowchart LR\n A[Draft] --> B[Review]'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Copy code'));
      await tester.pumpAndSettle();
      expect(clipboard, 'flowchart LR\n A[Draft] --> B[Review]');
      await tester.tap(find.byTooltip('Show diagram'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Download Mermaid diagram'));
      await tester.pumpAndSettle();
      expect(find.text('Download source'), findsOneWidget);
      expect(find.text('Download PNG'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Expand diagram'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'invalid Mermaid is an error with explicit source tab, never a stale scene',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: const Scaffold(
            body: RaftMermaidBlock(source: 'invalid family hello'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text("Couldn't render this diagram"), findsOneWidget);
      expect(find.text('invalid family hello'), findsNothing);
      await tester.tap(find.byTooltip('Show source'));
      await tester.pump();
      expect(find.text('invalid family hello'), findsOneWidget);
    },
  );
  testWidgets(
    'inline references expose URL semantics and activate from keyboard',
    (tester) async {
      String? opened;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: RaftMessageBody(
              content: 'Ask @Cody.',
              references: const [
                RaftTextReference(
                  text: '@Cody',
                  href: 'raft-ref://mention/agent/demo',
                ),
              ],
              onLink: (href) => opened = href,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('@Cody'), findsOneWidget);
      expect(
        tester
            .widget<Semantics>(
              find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.label == '@Cody',
              ),
            )
            .properties
            .linkUrl,
        Uri.parse('raft-ref://mention/agent/demo'),
      );
      Focus.of(tester.element(find.text('@Cody'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opened, 'raft-ref://mention/agent/demo');
      semantics.dispose();
    },
  );
  test('structured mentions keep identity after adjacent text edits; unknown DM remains literal', () {
    const refs = [
      RaftTextReference(
        text: '@Mona',
        href: 'raft-ref://mention/user/known',
        identityBacked: true,
      ),
      RaftTextReference(text: '#team', href: 'raft-ref://channel/id'),
    ];
    final value = raftMessageReferences(
      '草案@Mona @Mona继续 dm:@Mona:abcdef #team:abcdef',
      references: refs,
    );
    expect(value, contains('草案[@Mona](<raft-ref://mention/user/known>)'));
    expect(value, contains('@Mona继续 dm:@Mona:abcdef #team:abcdef'));
  });
  testWidgets('Mermaid inside a longer literal fence remains code', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: const Scaffold(
          body: RaftMessageBody(
            content: '````text\n```mermaid\nflowchart LR\n A --> B\n```\n````',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RaftMermaidBlock), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
