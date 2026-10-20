import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

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
      // Web v1.21.12 (MessageItem protectMessageMarkdownLinks) protects an
      // authored link as a whole: no reference chip inside its label (Web
      // v1.21.2 chipped them).
      expect(value, contains('`@Mona task #27` [@Mona](https://example.org)'));
      expect(value, contains('```txt\n@Mona #team\n```'));
    },
  );
  test('linked-only task is not a known bare task inside a link', () {
    const source =
        'Review [#1487 feat(search)](https://github.com/botiverse/mobile/pull/1487) '
        'then follow task #1487. '
        '[notes in #visual-testing](https://raft.build/visual-testing) '
        '[ping @artin](https://raft.build/mentions)';
    final result = raftMessageReferences(
      source,
      taskHref: (n) => 'raft-ref://task/$n',
      knownTaskNumber: (_) => false,
      references: const [
        RaftTextReference(
          text: '#visual-testing',
          href: 'raft-ref://channel/visual',
        ),
        RaftTextReference(
          text: '@artin',
          href: 'raft-ref://mention/user/artin',
        ),
      ],
    );
    expect(
      result,
      startsWith(
        'Review [#1487 feat(search)](https://github.com/botiverse/mobile/pull/1487)',
      ),
    );
    expect(
      result,
      contains('then follow task [#1487](<raft-ref://task/1487>)'),
    );
    // Web v1.21.12: a link label is never chipped (v1.21.2 chipped it).
    expect(
      result,
      contains('[notes in #visual-testing](https://raft.build/visual-testing)'),
    );
    expect(result, contains('[ping @artin](https://raft.build/mentions)'));
    final known = raftMessageReferences(
      '[#1487](https://example.org)',
      taskHref: (n) => 'raft-ref://task/$n',
      knownTaskNumber: (n) => n == 1487,
    );
    expect(known, '[#1487](https://example.org)');
  });
  test('authored links protect labels with escapes, nested parentheses and images', () {
    const refs = [
      RaftTextReference(text: '@Mona', href: 'raft-ref://mention/user/known'),
    ];
    String run(String source) =>
        raftMessageReferences(source, references: refs);
    // Balanced parentheses stay inside the destination.
    expect(
      run('[a @Mona](https://x.org/a_(b)) @Mona'),
      '[a @Mona](https://x.org/a_(b)) [@Mona](<raft-ref://mention/user/known>)',
    );
    // An escaped bracket does not end the label.
    expect(
      run(r'[a \] @Mona](https://x.org) @Mona'),
      r'[a \] @Mona](https://x.org) [@Mona](<raft-ref://mention/user/known>)',
    );
    // Images are protected like links.
    expect(
      run('![@Mona](https://x.org/i.png) @Mona'),
      '![@Mona](https://x.org/i.png) [@Mona](<raft-ref://mention/user/known>)',
    );
    // A bracket that does not open an inline link is plain text.
    expect(
      run('[@Mona] and [x] (@Mona)'),
      '[[@Mona](<raft-ref://mention/user/known>)] and [x] ([@Mona](<raft-ref://mention/user/known>))',
    );
    // A bare URL with balanced parentheses is protected up to the next space.
    expect(
      run('https://x.org/a_(b)@Mona @Mona'),
      'https://x.org/a_(b)@Mona [@Mona](<raft-ref://mention/user/known>)',
    );
  });
  for (final theme in raftThemeMatrix([
    raftTheme(RaftFamily.brutal),
    raftTheme(RaftFamily.elegant),
    raftTheme(RaftFamily.elegant, dark: true),
  ])) {
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
        expect(find.byKey(const Key('mermaid-fullscreen')), findsOneWidget);
        await tester.tap(find.byTooltip('Close fullscreen'));
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
      await tester.tap(find.byTooltip('Close fullscreen'));
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
    // Web v1.21.12: a selected mention may be followed by Han, kana or hangul
    // (`@Mona继续`), never by Latin letters, digits, `_` or `-`.
    expect(
      value,
      contains(
        '[@Mona](<raft-ref://mention/user/known>)继续 dm:@Mona:abcdef #team:abcdef',
      ),
    );
    for (final tail in ['的方案', 'さん', '와', ' 확인']) {
      expect(
        raftMessageReferences('@Mona$tail', references: refs),
        '[@Mona](<raft-ref://mention/user/known>)$tail',
      );
    }
    for (final tail in ['ica', '2', '_x', '-x']) {
      expect(
        raftMessageReferences('@Mona$tail', references: refs),
        '@Mona$tail',
      );
    }
  });
  test('free-text mentions split only where Latin meets CJK', () {
    const refs = [
      RaftTextReference(text: '@ops', href: 'raft-ref://mention/user/ops'),
    ];
    String run(String text) => raftMessageReferences(text, references: refs);
    expect(run('@ops的方案'), '[@ops](<raft-ref://mention/user/ops>)的方案');
    expect(run('@opsさん'), '[@ops](<raft-ref://mention/user/ops>)さん');
    expect(run('@ops와'), '[@ops](<raft-ref://mention/user/ops>)와');
    expect(run('@ops.'), '[@ops](<raft-ref://mention/user/ops>).');
    // Same-script continuations are never guessed.
    expect(run('@opsteam'), '@opsteam');
    expect(run('@ops2'), '@ops2');
    expect(run('@ops_bot'), '@ops_bot');
    expect(run('@opsx的'), '@opsx的');
    // A member that is literally named `ops的` wins over the split.
    expect(
      raftMessageReferences(
        '@ops的',
        references: const [
          RaftTextReference(text: '@ops', href: 'raft-ref://mention/user/ops'),
          RaftTextReference(
            text: '@ops的',
            href: 'raft-ref://mention/user/ops2',
          ),
        ],
      ),
      '[@ops的](<raft-ref://mention/user/ops2>)',
    );
  });
  test('raftResolveMentionHandle matches Web resolveRaftMentionHandle', () {
    bool Function(String) known(List<String> names) => names.contains;
    expect(raftResolveMentionHandle('ops', known(['ops'])), (
      handle: 'ops',
      suffix: '',
    ));
    expect(raftResolveMentionHandle('ops와', known(['ops'])), (
      handle: 'ops',
      suffix: '와',
    ));
    expect(raftResolveMentionHandle('opsテスト', known(['ops'])), (
      handle: 'ops',
      suffix: 'テスト',
    ));
    expect(raftResolveMentionHandle('ops-2的', known(['ops-2'])), (
      handle: 'ops-2',
      suffix: '的',
    ));
    expect(raftResolveMentionHandle('ops的', known(['ops', 'ops的'])), (
      handle: 'ops的',
      suffix: '',
    ));
    expect(raftResolveMentionHandle('opsteam', known(['ops'])), isNull);
    expect(raftResolveMentionHandle('Kaiwen', known(['Kai'])), isNull);
    expect(raftResolveMentionHandle('ops2', known(['ops'])), isNull);
    expect(raftResolveMentionHandle('민수가', known(['민', '민수'])), isNull);
    expect(raftResolveMentionHandle('张三的', known(['张三'])), isNull);
    expect(raftResolveMentionHandle('ops的', known(['other'])), isNull);
    expect(raftResolveMentionHandle('opsx的', known(['ops'])), isNull);
    expect(raftResolveMentionHandle('ops君', known(['ops', 'ops君'])), (
      handle: 'ops君',
      suffix: '',
    ));
    expect(raftResolveMentionHandle('ops君', known(['ops'])), (
      handle: 'ops',
      suffix: '君',
    ));
    // Two valid splits, or a longer member that also fits, are guesses.
    expect(raftResolveMentionHandle('ops君的', known(['ops', 'ops君'])), isNull);
    expect(raftResolveMentionHandle('ops君a的', known(['ops', 'ops君a'])), isNull);
    expect(raftResolveMentionHandle('ops君a的', known(['ops君a'])), (
      handle: 'ops君a',
      suffix: '的',
    ));
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
