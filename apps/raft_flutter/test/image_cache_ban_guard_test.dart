// One image pipeline: sized images / avatars / attachment images go through
// RaftSizedImage, RaftAvatarImageProvider and AttachmentImageRepository, whose
// memory is budgeted (RaftMemoryBudgets) and whose disk side is the single
// AttachmentDiskCache (counted, cleared and expired from Settings > Storage).
//
// flutter_chat_ui's own image and avatar path loads through `cross_cache`: a
// second, unbounded disk directory (application cache dir) that no setting
// lists or clears, plus decoded bitmaps that bypass the budgets. `Chat` still
// constructs a CrossCache (chat.dart) but never touches the disk until
// something downloads through it, so the app must never use that path.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/repo_root.dart';

void main() {
  final root = repoRoot();

  /// Dart sources shipped in the app: every lib/ except the vendored
  /// flutter_chat_ui itself.
  List<File> appSources() => [
    for (final dir in [
      'apps/raft_flutter/lib',
      'packages/raft_ui/lib',
      'packages/raft_client/lib',
      'packages/raft_sync/lib',
      'packages/raft_updater/lib',
    ])
      if (Directory('${root.path}/$dir').existsSync())
        ...Directory('${root.path}/$dir')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
  ];

  final banned = <String, RegExp>{
    'package:cross_cache import': RegExp(r'''['"]package:cross_cache/'''),
    'CrossCache': RegExp(r'\bCrossCache\b'),
    'CachedNetworkImage (flutter_chat_ui image provider)': RegExp(
      r'\bCachedNetworkImage\b',
    ),
    'Chat(crossCache: ...)': RegExp(r'\bcrossCache\s*:'),
    'flutter_chat_ui avatar builder': RegExp(r'\bavatarBuilder\s*:'),
    'flutter_chat_ui image message builder': RegExp(
      r'\b(imageMessageBuilder|linkPreviewBuilder)\s*:',
    ),
    // Avatar / AvatarContent exported by flutter_chat_ui (RaftAvatar* and
    // RaftAvatarContent are the app's; the lookbehind skips them).
    'flutter_chat_ui Avatar widget': RegExp(
      r'(?<![A-Za-z0-9_])(Avatar|AvatarContent)\(',
    ),
  };

  test(
    'the scan reads the app sources (an empty scan would pass anything)',
    () {
      // Windows paths can mix both slashes; compare in one form.
      final sources = [
        for (final f in appSources())
          if (f.path.replaceAll(r'\', '/').contains('/lib/')) f,
      ];
      expect(sources, hasLength(greaterThan(100)));
    },
  );

  test('the app never uses flutter_chat_ui / cross_cache image loading', () {
    final hits = <String>[];
    for (final file in appSources()) {
      final text = file.readAsStringSync();
      for (final entry in banned.entries) {
        for (final match in entry.value.allMatches(text)) {
          final line =
              '\n'.allMatches(text.substring(0, match.start)).length + 1;
          final lineText = text.split('\n')[line - 1].trimLeft();
          if (lineText.startsWith('//')) continue;
          hits.add('${file.path}:$line: ${entry.key}');
        }
      }
    }
    expect(
      hits,
      isEmpty,
      reason:
          'Use RaftSizedImage / RaftAvatarContent / AttachmentImageRepository '
          '(memory in RaftMemoryBudgets, disk in AttachmentDiskCache).',
    );
  });

  test('no pubspec of the app side depends on cross_cache directly', () {
    for (final pubspec in [
      'apps/raft_flutter/pubspec.yaml',
      'packages/raft_ui/pubspec.yaml',
      'packages/raft_client/pubspec.yaml',
      'packages/raft_sync/pubspec.yaml',
      'packages/raft_updater/pubspec.yaml',
    ]) {
      final file = File('${root.path}/$pubspec');
      if (!file.existsSync()) continue;
      expect(
        file.readAsStringSync(),
        isNot(contains('cross_cache')),
        reason: pubspec,
      );
    }
  });

  test('the guard sees the vendored chat.dart that creates a CrossCache', () {
    // If flutter_chat_ui stops using cross_cache this guard can be retired.
    final chat = File(
      '${root.path}/packages/flutter_chat_ui/lib/src/chat.dart',
    );
    expect(chat.readAsStringSync(), contains('CrossCache()'));
    expect(banned['CrossCache']!.hasMatch(chat.readAsStringSync()), isTrue);
  });
}
