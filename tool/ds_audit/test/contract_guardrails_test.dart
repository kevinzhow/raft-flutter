import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:ds_audit/contract_audit.dart';
import 'package:ds_audit/ds_audit.dart';
import 'package:ds_audit/family_audit.dart';
import 'package:test/test.dart';

Directory _repoRoot() {
  var dir = Directory.current.absolute;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !Directory('${dir.path}/packages/raft_ui').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('repository root not found from ${Directory.current}');
    }
    dir = parent;
  }
  return dir;
}

Future<List<Finding>> _scanFiles(
  Directory root,
  List<String> relativePaths, {
  bool contract = true,
  Map<String, DeprecatedDuplicate> duplicates = const {},
}) async {
  final provider = PhysicalResourceProvider.INSTANCE;
  final pathContext = provider.pathContext;
  final rootPath = pathContext.normalize(pathContext.absolute(root.path));
  final absolutePaths = [
    for (final rel in relativePaths)
      pathContext.normalize(pathContext.join(rootPath, rel)),
  ];
  final collection = AnalysisContextCollection(
    includedPaths: absolutePaths,
    resourceProvider: provider,
  );
  final findings = <Finding>[];
  try {
    for (final abs in absolutePaths) {
      final context = collection.contextFor(abs);
      final result = await context.currentSession.getResolvedUnit(abs);
      expect(
        result,
        isA<ResolvedUnitResult>(),
        reason: 'failed to resolve $abs',
      );
      final resolved = result as ResolvedUnitResult;
      final rel = pathContext
          .relative(abs, from: rootPath)
          .replaceAll('\\', '/');
      final AuditVisitorBase visitor = contract
          ? ContractAuditVisitor(rel, resolved)
          : DsAuditVisitor(rel, resolved);
      resolved.unit.accept(visitor);
      findings.addAll(visitor.findings);
      if (duplicates.isNotEmpty) {
        final family = FamilyAuditVisitor(
          rel,
          resolved,
          duplicates,
          absolutePath: resolved.path,
        );
        resolved.unit.accept(family);
        findings.addAll(family.findings);
      }
    }
  } finally {
    await collection.dispose();
  }
  return findings;
}

Future<List<Finding>> _scanSnippet(
  Directory root,
  String source, {
  bool contract = true,
  String fileName = 'guardrails_probe.dart',
}) async {
  final dir = Directory('${root.path}/packages/raft_ui/test/.tmp_ds_audit');
  dir.createSync(recursive: true);
  final file = File('${dir.path}/$fileName');
  try {
    file.writeAsStringSync(source);
    final rel = 'packages/raft_ui/test/.tmp_ds_audit/$fileName';
    return await _scanFiles(root, [rel], contract: contract);
  } finally {
    if (file.existsSync()) file.deleteSync();
    if (dir.existsSync() && dir.listSync().isEmpty) dir.deleteSync();
  }
}

void main() {
  final root = _repoRoot();

  group('contract.sharp_bordered_box', () {
    test('flags omitted borderRadius and BorderRadius.zero with Border.all / fromBorderSide', () async {
      final findings = await _scanSnippet(root, '''
import 'package:flutter/material.dart';

Widget sample(BorderSide side, BorderRadius radius) => Column(
  children: [
    DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.transparent),
      ),
    ),
    DecoratedBox(
      decoration: BoxDecoration(
        border: Border.fromBorderSide(side),
      ),
    ),
    DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.transparent),
        borderRadius: BorderRadius.zero,
      ),
    ),
  ],
);
''');
      final sharp = findings
          .where((f) => f.category == categorySharpBorderedBox)
          .toList();
      expect(sharp, hasLength(3));
    });

    test(
      'does not flag canonical rounded boxes, circles, or single-side dividers',
      () async {
        final findings = await _scanSnippet(root, '''
import 'package:flutter/material.dart';

Widget canonical(BorderSide side, BorderRadius radius) => Column(
  children: [
    DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.transparent),
        borderRadius: radius,
      ),
    ),
    DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.transparent),
      ),
    ),
    DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: side),
      ),
    ),
  ],
);
''');
        final sharp = findings
            .where((f) => f.category == categorySharpBorderedBox)
            .toList();
        expect(sharp, isEmpty);
      },
    );
  });

  group('contract.brutal_token', () {
    test(
      'flags brutal*, shadowBrutal*, brutalPanelHeader, and brutal color keys',
      () async {
        final findings = await _scanSnippet(root, '''
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

Widget legacyBrutal(BuildContext context) {
  final t = RaftTokens.of(context);
  return Container(
    height: RaftMetrics.brutalPanelHeader,
    decoration: BoxDecoration(
      color: t.product.brutalCream,
      borderRadius: BorderRadius.circular(t.radius),
      boxShadow: RaftProductShadows.shadowBrutalSm.outer,
    ),
    child: ColoredBox(
      color: t.colors['color-brutal-red']!,
    ),
  );
}
''');
        final brutal = findings
            .where((f) => f.category == categoryBrutalToken)
            .map((f) => f.name)
            .toList();
        expect(
          brutal,
          containsAll([
            'brutalPanelHeader',
            'brutalCream',
            'shadowBrutalSm',
            "['color-brutal-red']",
          ]),
        );
      },
    );

    test(
      'does not flag canonical semantic tokens or comments/strings',
      () async {
        final findings = await _scanSnippet(root, '''
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

// brutalCream shadowBrutalSm brutalPanelHeader
const note = 'brutalCream shadowBrutalSm';

Widget canonical(BuildContext context) {
  final t = RaftTokens.of(context);
  return ColoredBox(color: t.colors['layer-card']!);
}
''');
        final brutal = findings
            .where((f) => f.category == categoryBrutalToken)
            .toList();
        expect(brutal, isEmpty);
      },
    );
  });

  group('contract.legacy_typography_size', () {
    test(
      'flags RaftTypography.*(size: <num>) and Theme.of(context).textTheme',
      () async {
        final findings = await _scanSnippet(root, '''
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

Widget legacyText(BuildContext context) {
  final t = RaftTokens.of(context);
  return Column(
    children: [
      Text('a', style: RaftTypography.body(t, size: 14, line: 20)),
      Text('b', style: RaftTypography.mono(t, size: 12, line: 16)),
      Text('c', style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}
''');
        final typo = findings
            .where((f) => f.category == categoryLegacyTypographySize)
            .map((f) => f.name)
            .toList();
        expect(
          typo,
          containsAll([
            'RaftTypography.body(size:)',
            'RaftTypography.mono(size:)',
            'ThemeData.textTheme',
          ]),
        );
      },
    );

    test('does not flag semantic RaftTypography.sans(size: RaftSansSize.*) or default calls', () async {
      final findings = await _scanSnippet(root, '''
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

Widget canonicalText(BuildContext context) {
  final t = RaftTokens.of(context);
  return Column(
    children: [
      Text('a', style: RaftTypography.sans(t, size: RaftSansSize.small)),
      Text('b', style: RaftTypography.body(t)),
    ],
  );
}
''');
      final typo = findings
          .where((f) => f.category == categoryLegacyTypographySize)
          .toList();
      expect(typo, isEmpty);
    });
  });

  group('real regression catches on known legacy surfaces', () {
    test('catches task_handoff_card.dart, onboarding_previews.dart, and quoted_message_card.dart', () async {
      final pathContext = PhysicalResourceProvider.INSTANCE.pathContext;
      final rootPath = pathContext.normalize(pathContext.absolute(root.path));
      final duplicates = {
        'ActionSnapshotRecipe': DeprecatedDuplicate(
          'message-action-card',
          pathContext.normalize(
            pathContext.join(
              rootPath,
              'packages/raft_ui/lib/src/rich_card_tokens.dart',
            ),
          ),
        ),
      };
      final findings = await _scanFiles(
        root,
        [
          'packages/raft_ui/lib/src/task_handoff_card.dart',
          'packages/raft_ui/lib/src/onboarding_previews.dart',
          'packages/raft_ui/lib/src/quoted_message_card.dart',
        ],
        contract: true,
        duplicates: duplicates,
      );

      final handoffCats = findings
          .where(
            (f) => f.file == 'packages/raft_ui/lib/src/task_handoff_card.dart',
          )
          .map((f) => f.category)
          .toSet();
      expect(
        handoffCats,
        containsAll([
          categorySharpBorderedBox,
          categoryLegacyTypographySize,
          'duplicate.message-action-card',
        ]),
      );

      final onboardingCats = findings
          .where(
            (f) =>
                f.file == 'packages/raft_ui/lib/src/onboarding_previews.dart',
          )
          .map((f) => f.category)
          .toSet();
      expect(
        onboardingCats,
        containsAll([categorySharpBorderedBox, categoryBrutalToken]),
      );

      final quotedCats = findings
          .where(
            (f) =>
                f.file == 'packages/raft_ui/lib/src/quoted_message_card.dart',
          )
          .map((f) => f.category)
          .toSet();
      expect(quotedCats, contains(categorySharpBorderedBox));
    });
  });
}
