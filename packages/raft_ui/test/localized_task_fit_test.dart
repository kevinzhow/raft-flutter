import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../../tool/testing/text_scale_audit.dart';

void main() {
  for (final id in ['en', 'pt-br', 'ru']) {
    final locale = raftDisplayLanguages[id]!.$1;
    testWidgets('$id task board labels fit at 2x', (tester) async {
      await loadAuditFonts(tester, AuditFonts.real);
      for (final dark in [false, true]) {
        for (final status in raftTaskStatuses) {
          final report = await auditSurface(
            tester,
            surface: 'localized-task-board',
            theme: raftTheme(
              dark: dark,
              locale: locale,
              textLocale: locale,
              platform: TargetPlatform.linux,
            ),
            mode: AuditMode('$id-2x', locale: locale, textScale: 2),
            size: const Size(232, 800),
            truncationBaseline: {},
            build: () => RaftTaskBoardColumn(
              status: status,
              count: '1',
              collapsed: false,
              onToggle: () {},
              body: RaftTaskCard(
                title: 'Task',
                number: '1',
                status: status,
                footerEnd: const Text('12:00'),
              ),
            ),
          );
          expect(report.failures, isEmpty, reason: report.failures.join('\n'));
        }
      }
    });
  }
}
