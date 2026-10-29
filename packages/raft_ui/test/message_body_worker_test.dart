import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('worker warms the exact message parser and code caches', (
    tester,
  ) async {
    final tokens = RaftTokens.theme();
    const content =
        '**Worker body** @Bob task #7\n\n```dart\nfinal number = 7;\n```';
    const refs = [
      RaftTextReference(
        text: '@Bob',
        href: 'raft-ref://mention/user/bob',
        identityBacked: true,
        label: '@Bob Li',
      ),
    ];
    String href(int n) => 'raft-ref://task/$n';
    final worker = RaftMessageBodyWorker();
    addTearDown(worker.dispose);
    raftMarkdownAstCache.clear();
    raftCodeSpanCache.clear();
    await tester.runAsync(() async {
      worker.replace([
        RaftMessageBodyRequest(
          content: content,
          tokens: tokens,
          references: refs,
          taskHref: href,
          knownTaskNumber: (_) => true,
        ),
      ], current: () => true);
      await worker.completion;
    });
    expect(
      raftMarkdownAstCache.length,
      1,
      reason: 'Real background worker results reached the UI cache',
    );
    expect(raftCodeSpanCache.length, 1);
    final treeMisses = raftMarkdownAstCache.misses,
        codeMisses = raftCodeSpanCache.misses;
    RaftMessageBody.prepareCache(
      content: content,
      tokens: tokens,
      references: refs,
      taskHref: href,
      knownTaskNumber: (_) => true,
      messagePipeline: true,
    );
    expect(raftMarkdownAstCache.misses, treeMisses);
    expect(raftCodeSpanCache.misses, codeMisses);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftMessageBody(
            content: content,
            references: refs,
            taskHref: href,
            knownTaskNumber: (_) => true,
            mountedMessage: true,
            messagePipeline: true,
            fontSize: 14,
          ),
        ),
      ),
    );
    expect(
      find.textContaining('Worker body', findRichText: true),
      findsWidgets,
    );
    expect(raftMarkdownAstCache.misses, treeMisses);
    expect(raftCodeSpanCache.misses, codeMisses);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('retired and disposed workers cannot publish cached bodies', (
    tester,
  ) async {
    final tokens = RaftTokens.theme();
    final worker = RaftMessageBodyWorker();
    addTearDown(worker.dispose);
    raftMarkdownAstCache.clear();
    raftCodeSpanCache.clear();
    await tester.runAsync(() async {
      worker.replace([
        RaftMessageBodyRequest(content: '**Retired**', tokens: tokens),
      ], current: () => false);
      await worker.completion;
      expect(raftMarkdownAstCache.length, 0);
      worker.replace([
        RaftMessageBodyRequest(content: '**Disposed**', tokens: tokens),
      ], current: () => true);
      worker.dispose();
      await worker.completion;
    });
    expect(raftMarkdownAstCache.length, 0);
  });
  testWidgets('only the newest pending batch is adopted', (tester) async {
    final tokens = RaftTokens.theme(), worker = RaftMessageBodyWorker();
    addTearDown(worker.dispose);
    raftMarkdownAstCache.clear();
    await tester.runAsync(() async {
      worker.replace([
        RaftMessageBodyRequest(content: '**old**', tokens: tokens),
      ], current: () => true);
      worker.replace([
        RaftMessageBodyRequest(content: '**intermediate**', tokens: tokens),
      ], current: () => true);
      worker.replace([
        RaftMessageBodyRequest(content: '**new**', tokens: tokens),
      ], current: () => true);
      await worker.completion;
    });
    expect(raftMarkdownAstCache.length, 1);
    final misses = raftMarkdownAstCache.misses;
    RaftMessageBody.prepareCache(
      content: '**new**',
      tokens: tokens,
      messagePipeline: true,
    );
    expect(raftMarkdownAstCache.misses, misses);
  });
  testWidgets('oversized text is skipped without blocking the bounded batch', (
    tester,
  ) async {
    final tokens = RaftTokens.theme(), worker = RaftMessageBodyWorker();
    addTearDown(worker.dispose);
    raftMarkdownAstCache.clear();
    await tester.runAsync(() async {
      worker.replace([
        RaftMessageBodyRequest(content: 'x' * (300 * 1024), tokens: tokens),
        for (var i = 0; i < 100; i++)
          RaftMessageBodyRequest(content: '**bounded $i**', tokens: tokens),
      ], current: () => true);
      await worker.completion;
    });
    // The first 64 requests include one oversized source, leaving 63 bodies.
    expect(raftMarkdownAstCache.length, 63);
  });
  testWidgets('warm messages do not start another parser batch', (
    tester,
  ) async {
    final tokens = RaftTokens.theme(), worker = RaftMessageBodyWorker();
    addTearDown(worker.dispose);
    raftMarkdownAstCache.clear();
    await tester.runAsync(() async {
      worker.replace([
        RaftMessageBodyRequest(content: '**already parsed**', tokens: tokens),
      ], current: () => true);
      await worker.completion;
    });
    final completed = worker.completion, misses = raftMarkdownAstCache.misses;
    worker.replace([
      RaftMessageBodyRequest(content: '**already parsed**', tokens: tokens),
    ], current: () => true);
    expect(identical(worker.completion, completed), isTrue);
    expect(raftMarkdownAstCache.misses, misses);
  });
  testWidgets(
    'request resolution yields to publication and stops on retirement',
    (tester) async {
      final tokens = RaftTokens.theme(), worker = RaftMessageBodyWorker();
      addTearDown(worker.dispose);
      raftMarkdownAstCache.clear();
      var resolved = 0;
      await tester.runAsync(() async {
        worker.prepare([
          for (var i = 0; i < 100; i++)
            () {
              resolved++;
              worker.cancel();
              return RaftMessageBodyRequest(
                content: '**retired $i**',
                tokens: tokens,
              );
            },
        ], current: () => true);
        expect(
          resolved,
          0,
          reason: 'Publishing a page resolves no body references',
        );
        await worker.completion;
        expect(
          resolved,
          1,
          reason: 'Retired work stops before resolving more rows',
        );
        expect(raftMarkdownAstCache.length, 0);
        worker.prepare([
          for (var i = 0; i < 9; i++)
            () {
              resolved++;
              return RaftMessageBodyRequest(
                content: '**current $i**',
                tokens: tokens,
              );
            },
        ], current: () => true);
        await worker.completion;
      });
      expect(resolved, 10);
      expect(raftMarkdownAstCache.length, 9);
    },
  );
}
