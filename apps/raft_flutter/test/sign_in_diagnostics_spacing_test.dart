// Settings › Account sections each keep their own bottom margin (Web `mb-6`):
// the Flutter-only sign-in diagnostics card follows the same rhythm, so it
// sits 24px above the Session section and adds no extra gap above itself.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/sign_in_diagnostics_card.dart';
import 'package:raft_flutter/platform/auth_audit_log.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('the diagnostics card has mb-6, not a top gap', (t) async {
    final log = AuthAuditLog.memory()
      ..record(
        SessionAuditEvent('session_end', 'refresh_rejected', status: 401),
      );
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SignInDiagnosticsCard(log: log),
              const SizedBox(key: ValueKey('next-section'), height: 10),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final card = t.getRect(find.byType(RaftSettingsActionCard));
    final next = t.getRect(find.byKey(const ValueKey('next-section')));
    expect(card.top, 0);
    expect(next.top - card.bottom, RaftSpace.x6);
  });
}
