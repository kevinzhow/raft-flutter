import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Classification is semantic, not a numeric baseline. Every public SDK footer
// family must either own the remaining screen edge or name its actual owner.
const _owners = {
  'RaftChannelJoinFooter': 'RaftBottomInsetSurface',
  'RaftChannelBannerFooter': 'RaftBottomInsetSurface',
  'RaftChannelArchivedFooter': 'RaftBottomInsetSurface',
  'RaftbenchServiceDmNotice': 'RaftBottomInsetSurface',
  'RaftPublicBottomBanner': 'RaftBottomInsetSurface',
  'RaftSetupResumeBar': 'RaftBottomInsetSurface',
  'RaftPublicFloatingBanner': 'raftOverlayBottomInset',
};
const _interior = {
  'RaftTimelineFooter': 'The timeline ends above the owning composer/footer.',
  'RaftSearchFooter': 'The containing search scroll surface owns tail padding.',
  'RaftWorkspaceRailFooter': 'The rail root owns its system SafeArea.',
  'RaftAuthSessionFooter': 'The auth-page frame owns safe and keyboard insets.',
  'RaftCindySessionFooter': 'The setup page/card owns its outer safe boundary.',
  'RaftAgentDialogFooter': 'The presented form/dialog frame owns its insets.',
  'RaftDialogFooter': 'The dialog presentation frame owns its insets.',
};

Directory _sourceDirectory() {
  for (var root = Directory.current.absolute; ; root = root.parent) {
    final package = Directory('${root.path}/packages/raft_ui');
    final manifest = File('${package.path}/pubspec.yaml');
    final source = Directory('${package.path}/lib/src');
    if (source.existsSync() &&
        manifest.existsSync() &&
        RegExp(
          r'^name:\s*raft_ui\s*$',
          multiLine: true,
        ).hasMatch(manifest.readAsStringSync())) {
      return source;
    }
    if (root.parent.path == root.path) {
      throw StateError('Cannot locate the checked-out raft_ui/lib/src.');
    }
  }
}

String _withoutCommentLines(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');

Map<String, String> _families() {
  final result = <String, String>{};
  final declaration = RegExp(r'^class\s+(Raft\w+)\b', multiLine: true);
  final footerName = RegExp(r'(?:Footer|BottomBanner|ResumeBar)$');
  for (final file in _sourceDirectory().listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    if (file.path.endsWith('.g.dart')) continue;
    final source = _withoutCommentLines(file.readAsStringSync());
    final classes = declaration.allMatches(source).toList();
    for (var index = 0; index < classes.length; index++) {
      final current = classes[index], name = current.group(1)!;
      if (!footerName.hasMatch(name) && !_owners.containsKey(name)) continue;
      expect(
        result.containsKey(name),
        isFalse,
        reason: 'duplicate family $name',
      );
      result[name] = source.substring(
        current.start,
        index + 1 < classes.length ? classes[index + 1].start : source.length,
      );
    }
  }
  return result;
}

void main() {
  test(
    'public bottom-edge families declare an owner or an interior boundary',
    () {
      final families = _families();
      final classified = {..._owners.keys, ..._interior.keys};
      expect(
        families.keys.toSet(),
        classified,
        reason:
            'Classify new Footer/BottomBanner/ResumeBar families and add their '
            'bottom-edge behavior contract; do not raise a count baseline.',
      );
      expect(_interior.values.every((reason) => reason.isNotEmpty), isTrue);
    },
  );

  test('screen-edge owners use the canonical design-system boundary', () {
    final families = _families();
    final missing = <String>[];
    for (final entry in _owners.entries) {
      final call = RegExp('\\b${entry.value}\\s*\\(');
      if (!call.hasMatch(families[entry.key] ?? '')) missing.add(entry.key);
    }
    expect(
      missing,
      isEmpty,
      reason:
          'Screen-edge families must use the shared remaining-inset boundary; '
          'raw fixed padding is not safe-area ownership.',
    );
  });
}
