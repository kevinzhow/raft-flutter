import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/sign_in_diagnostics_card.dart';
import 'package:raft_flutter/platform/auth_audit_log.dart';
import 'package:raft_flutter/platform/session_store.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('auth-audit'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('keeps the newest entries within capacity', () {
    final log = AuthAuditLog.memory(capacity: 3);
    for (var i = 0; i < 5; i++) {
      log.record(SessionAuditEvent('session_kept', 'refresh_failed', status: 500 + i));
    }
    expect(log.events.map((e) => e.status), [502, 503, 504]);
  });

  test('persists across processes, trims to capacity, skips torn lines', () async {
    final file = File('${dir.path}/auth-audit.jsonl');
    final first = AuthAuditLog(file: file, capacity: 4);
    for (var i = 0; i < 6; i++) {
      first.record(SessionAuditEvent('session_end', 'refresh_rejected', status: 401, endpoint: '/auth/refresh', at: DateTime.utc(2026, 10, 12, 0, 0, i)));
    }
    await first.export();
    await file.writeAsString('{torn', mode: FileMode.append);
    final second = AuthAuditLog(file: file, capacity: 4);
    await second.open();
    expect(second.events, hasLength(4));
    expect(second.events.last.at, DateTime.utc(2026, 10, 12, 0, 0, 5));
    expect(second.events.first.reason, 'refresh_rejected');
  });

  test('export is plain text with reasons and no credentials', () async {
    final log = AuthAuditLog.memory();
    log.record(SessionAuditEvent('session_end', 'refresh_rejected', status: 401, endpoint: '/auth/refresh'));
    log.note('restore_failed', 'storage', detail: 'bad eyJhbGciOiJIUzI1NiJ9abcdefghijklmnopqrstuv for a@b.example');
    final text = await log.export(appVersion: '1.2.3');
    expect(text, contains('session_end reason=refresh_rejected status=401 endpoint=/auth/refresh'));
    expect(text, contains('restore_failed reason=storage'));
    expect(text, contains('<redacted>'));
    expect(text, isNot(contains('eyJ')));
    expect(text, isNot(contains('a@b.example')));
    expect(text, contains('1.2.3'));
  });

  test('secure storage never wipes credentials on an error (Android resetOnError)', () {
    final store = SecureSessionStore();
    expect(store.storage.aOptions.toMap()['resetOnError'], 'false');
  });

  testWidgets('the diagnostics card appears only when something is worth reporting and copies the log', (t) async {
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    Future<void> pump(AuthAuditLog log) => t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: SignInDiagnosticsCard(key: ValueKey(log), log: log)),
      ),
    );
    final quiet = AuthAuditLog.memory();
    await pump(quiet);
    await t.pump();
    expect(find.byKey(const Key('account-sign-in-diagnostics')), findsNothing);

    final log = AuthAuditLog.memory()..record(SessionAuditEvent('session_end', 'refresh_rejected', status: 401));
    await pump(log);
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 10));
    }
    expect(find.byKey(const Key('account-sign-in-diagnostics')), findsOneWidget);
    await t.tap(find.byKey(const Key('account-sign-in-diagnostics')));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump();
    expect(copied, contains('refresh_rejected'));
    expect(jsonEncode(copied), isNot(contains('token=')));
  });
}
