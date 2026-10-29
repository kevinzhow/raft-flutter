import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/migration_error.dart';
import 'package:raft_flutter/data/runtime_error.dart';
import 'package:raft_flutter/data/web_error.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/agent_scopes_view.dart';
import 'package:raft_flutter/features/runtime_form_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;
import 'panel_revisit_cache_test.dart' show settle;

/// Fleet-area error presentation (Web parity): the server's own `error` text or
/// the surface's Web fallback, never exception text.
RaftApiException _api(int status, {String? error, String? code}) =>
    RaftApiException.response(
      error ?? 'Request failed',
      status: status,
      body: {'error': ?error, 'code': ?code},
    );

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: child),
);

void main() {
  group('migration errors map the server code to catalog copy', () {
    test('a known code ignores the server sentence', () {
      final text = migrationErrorText(
        _api(
          409,
          error: 'plan gate: internal words',
          code: 'MIGRATION_PRO_PLAN_REQUIRED',
        ),
        MigrationErrorContext.start,
      );
      expect(text, contains('requires the Pro plan'));
      expect(text, isNot(contains('internal words')));
    });

    test('an unknown code falls back to the context line', () {
      expect(
        migrationErrorText(
          _api(500, error: 'boom'),
          MigrationErrorContext.start,
        ),
        'The migration could not be started. Check both computers and try again.',
      );
      expect(
        migrationErrorText(
          _api(500, error: 'boom'),
          MigrationErrorContext.status,
        ),
        'Migration status could not be loaded. Refresh and try again.',
      );
      expect(
        migrationErrorText(StateError('x'), MigrationErrorContext.start),
        isNot(contains('x')),
      );
    });

    test('cancel copy depends on staleness and appends a safe code', () {
      expect(
        migrationCancelErrorText(_api(409, code: 'MIGRATION_REVISION_STALE')),
        startsWith('The migration moved on before your request went through.'),
      );
      expect(
        migrationCancelErrorText(_api(500, code: 'MIGRATION_CANCEL_FAILED')),
        endsWith('(MIGRATION_CANCEL_FAILED)'),
      );
    });
  });

  group('runtime error classification', () {
    test('matches only the enumerable patterns', () {
      expect(
        classifyRuntimeError('claude is not logged in'),
        RuntimeErrorKind.notLoggedIn,
      );
      expect(
        classifyRuntimeError('codex not installed'),
        RuntimeErrorKind.notInstalled,
      );
      expect(
        classifyRuntimeError('Authentication failed'),
        RuntimeErrorKind.authFailed,
      );
      expect(
        classifyRuntimeError('invalid API key'),
        RuntimeErrorKind.authFailed,
      );
      expect(classifyRuntimeError('some other failure'), isNull);
    });

    test('toolArgsInvalid is reachable only from the typed carrier', () {
      expect(
        classifyTypedRuntimeError({
          'errorClass': 'ToolArgumentParseError',
          'errorReason': 'model_tool_args_invalid',
        }),
        RuntimeErrorKind.toolArgsInvalid,
      );
      expect(classifyRuntimeError('model_tool_args_invalid'), isNull);
      expect(classifyTypedRuntimeError({'errorClass': 'X'}), isNull);
    });
  });

  group('runtime form errors', () {
    test('the definition read failure picks Built-in copy by code', () {
      expect(
        runtimeFormLoadErrorText(_api(409, code: 'builtin_catalog_stale')),
        startsWith('Built-in models cannot be verified right now.'),
      );
      expect(
        runtimeFormLoadErrorText(_api(500, error: 'private words')),
        'Runtime configuration is unavailable. Refresh and try again.',
      );
    });

    test('issues point at fields with the server text', () {
      final e = RaftApiException.response(
        'Base URL is invalid',
        status: 422,
        body: {
          'error': 'Base URL is invalid',
          'issues': [
            {'code': 'invalid_url', 'pointer': '/formValues/baseUrl'},
            {'code': 'x', 'pointer': '/other/field'},
          ],
        },
      );
      expect(runtimeFormIssueErrors(e), {'baseUrl': 'Base URL is invalid'});
      expect(runtimeFormIssueErrors(StateError('x')), isEmpty);
    });
  });

  group('withWebError', () {
    test('server text, fallback, user errors and 401/403', () async {
      Future<Object> run(Object error, {bool serverText = true}) async {
        try {
          await withWebError<void>(
            'Failed to grant access',
            () async => throw error,
            serverText: serverText,
          );
        } catch (e) {
          return e;
        }
        throw StateError('did not throw');
      }

      expect(
        (await run(_api(400, error: 'Scope not allowed')) as RaftUserError)
            .message,
        'Scope not allowed',
      );
      expect(
        (await run(const RaftApiException('socket closed', status: 500))
                as RaftUserError)
            .message,
        'Failed to grant access',
      );
      expect(
        (await run(_api(400, error: 'Scope not allowed'), serverText: false)
                as RaftUserError)
            .message,
        'Failed to grant access',
      );
      expect(await run(_api(403, error: 'No')), isA<RaftApiException>());
      expect(await run(const RaftUserError('mine')), isA<RaftUserError>());
    });
  });

  group('agent detail error widgets', () {
    testWidgets('the start-error strip shows the message and dismisses', (
      t,
    ) async {
      var dismissed = 0;
      await t.pumpWidget(
        _host(
          RaftPanelErrorStrip(
            'Failed to stop agent',
            onDismiss: () => dismissed++,
          ),
        ),
      );
      expect(find.text('Failed to stop agent'), findsOneWidget);
      await t.tap(find.byType(RaftInlineIconButton));
      expect(dismissed, 1);
    });

    testWidgets('the reminders list shows a small bold banner with Retry', (
      t,
    ) async {
      var retried = 0;
      await t.pumpWidget(
        _host(
          RaftReminderListView(
            reminders: const [],
            error: 'Failed to load reminders',
            onRetry: () => retried++,
          ),
        ),
      );
      expect(find.byType(RaftErrorBanner), findsOneWidget);
      expect(find.text('Failed to load reminders'), findsOneWidget);
      await t.tap(find.text('Retry'));
      expect(retried, 1);
    });

    testWidgets('the skills section failure is a load-error column', (t) async {
      var retried = 0;
      await t.pumpWidget(
        _host(
          RaftSkillsSection(
            global: const [],
            workspace: const [],
            error: 'Failed to load skills',
            onRetry: () => retried++,
          ),
        ),
      );
      expect(find.byType(RaftLoadError), findsOneWidget);
      await t.tap(find.text('Retry'));
      expect(retried, 1);
    });

    testWidgets('a failed file read replaces the preview with the message', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          const RaftWorkspaceFilePreview(
            embedded: true,
            path: 'a.txt',
            content: 'stale',
            error: 'Failed to load file',
          ),
        ),
      );
      expect(find.text('Failed to load file'), findsOneWidget);
      expect(find.text('stale'), findsNothing);
    });

    testWidgets('agent chat shows each section failure as its own banner', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          const RaftAgentChatView(
            channels: [],
            dms: [],
            channelsError: 'Failed to load agent channels',
            dmsError: 'Failed to load agent DMs',
          ),
        ),
      );
      expect(find.byType(RaftErrorBanner), findsNWidgets(2));
      expect(find.text('Failed to load agent channels'), findsOneWidget);
      expect(find.text('Failed to load agent DMs'), findsOneWidget);
    });

    testWidgets('the chat tab keeps working when only the DMs read fails', (
      t,
    ) async {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      api.routes['GET /agents/a1/channels'] = (_) => {'channels': []};
      api.routes['GET /agents/a1/agent-dms'] = (_) =>
          throw StateError('socket');
      await t.pumpWidget(_host(AgentChatTab(controller: w, agentId: 'a1')));
      await settle(t);
      expect(find.text('Failed to load agent DMs'), findsOneWidget);
      expect(find.text('Failed to load agent channels'), findsNothing);
      expect(find.textContaining('socket'), findsNothing);
    });

    testWidgets(
      'the workspace tab shows the fixed Web message for a failed list',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        // No route: the fixture answers 404 {"error":"Unexpected endpoint"}.
        await t.pumpWidget(
          _host(AgentWorkspaceTab(controller: w, agentId: 'a1')),
        );
        await settle(t);
        // Web `loadError` is a flag: one fixed message, never the server text.
        expect(find.text('Failed to load files'), findsOneWidget);
        expect(find.text('Unexpected endpoint'), findsNothing);
        expect(find.text('Retry'), findsOneWidget);
        // A route that dies without a body shows the same message.
        api.routes['GET /agents/a1/workspace-files'] = (_) =>
            throw StateError('socket');
        await t.tap(find.text('Retry'));
        await settle(t);
        expect(find.text('Failed to load files'), findsOneWidget);
        expect(find.textContaining('socket'), findsNothing);
      },
    );
  });

  group('agent permissions', () {
    testWidgets(
      'a save shows a success toast; a failure shows the server text',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        api.routes['GET /agents/a1/scopes'] = (_) => {
          'granted': ['message:read'],
          'mode': 'custom',
        };
        api.routes['PUT /agents/a1/scopes'] = (_) => {};
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: RaftToastHost(
              child: AgentScopesView(controller: w, agentId: 'a1'),
            ),
          ),
        );
        await settle(t);
        await t.scrollUntilVisible(
          find.text('Save Permissions'),
          200,
          scrollable: find.descendant(
            of: find.byKey(const Key('agent-scope-list')),
            matching: find.byType(Scrollable),
          ),
        );
        await t.tap(find.text('Save Permissions'));
        await settle(t);
        expect(find.text('Agent permissions saved'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);

        // No PUT route: the fixture answers 404 {"error":"Unexpected endpoint"}.
        api.routes.remove('PUT /agents/a1/scopes');
        await t.tap(find.text('Save Permissions'));
        await settle(t);
        await t.scrollUntilVisible(
          find.byType(RaftErrorBanner),
          -200,
          scrollable: find.descendant(
            of: find.byKey(const Key('agent-scope-list')),
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.byType(RaftErrorBanner), findsOneWidget);
        expect(find.text('Unexpected endpoint'), findsOneWidget);
      },
    );

    testWidgets('a failed first read is a load-error column with Retry', (
      t,
    ) async {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      api.routes['GET /agents/a1/scopes'] = (_) => throw StateError('socket');
      await t.pumpWidget(_host(AgentScopesView(controller: w, agentId: 'a1')));
      await settle(t);
      expect(find.byType(RaftLoadError), findsOneWidget);
      expect(find.text('Failed to load agent permissions'), findsOneWidget);
      expect(find.textContaining('socket'), findsNothing);
      api.routes['GET /agents/a1/scopes'] = (_) => {
        'granted': <String>[],
        'mode': 'default',
      };
      await t.tap(find.text('Retry'));
      await settle(t);
      expect(find.byType(RaftLoadError), findsNothing);
      expect(find.text('Default permissions'), findsOneWidget);
    });
  });
}
