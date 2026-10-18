import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/source_feedback_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/add_members_dialog.dart';
import 'package:raft_flutter/features/agent_runtime_editor.dart';
import 'package:raft_flutter/features/agent_avatar_dialog.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/community_join.dart';
import 'package:raft_flutter/features/create_agent_dialog.dart';
import 'package:raft_flutter/features/create_channel_dialog.dart';
import 'package:raft_flutter/features/create_joint_channel_dialog.dart';
import 'package:raft_flutter/features/create_task_dialog.dart';
import 'package:raft_flutter/features/forward_composer_page.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_flutter/features/forward_messages_dialog.dart';
import 'package:raft_flutter/features/managed_agent_launcher.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_flutter/features/provider_edit_dialog.dart';
import 'package:raft_flutter/features/report_issue.dart';
import 'package:raft_flutter/features/source_feedback_view.dart';
import 'package:raft_flutter/features/provider_views.dart';
import 'package:raft_flutter/features/server_views.dart';
import 'package:raft_flutter/features/workspace_menu_invite.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'announcement_host_test.dart' as announcements;
import 'source_feedback_store_test.dart' as fx;
import 'support/close_history_settings.dart';
import 'support/close_bulk_agent_model.dart';
import 'support/close_registry_dialogs.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';
import 'flutter_test_config.dart' show leakDebt;

/// The test font is wider than the shipped one, so dense dialogs report
/// RenderFlex overflows on a phone that the device does not have; the guard
/// is about close affordances, not layout.
void ignoreOverflow() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed by')) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// A small app whose only job is to open one surface from a button, for
/// surfaces that live in raft_ui (no workspace needed).
Future<void> openFromButton(
  WidgetTester t,
  Size size,
  void Function(BuildContext context) open,
) async {
  ignoreOverflow();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('open-surface'),
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.byKey(const Key('open-surface')));
  await frames(t, 25);
}

/// The X of every dialog shell in raft_ui.
final Finder anyX = find.byWidgetPredicate(
  (w) =>
      w is RaftCloseButton ||
      w is RaftAgentCloseButton ||
      w is RaftDialogClose ||
      (w is RaftRecipeButton && w.glyph == RaftGlyph.x) ||
      w.key == const Key('confirm-dialog-close'),
);

const _corner = Offset(6, 6);

/// The drag handle of a bottom sheet (a form below 768).
final _handle = find.byKey(const ValueKey('raft-sheet-handle'));

Future<SurfaceProbe> confirmDialog(WidgetTester t, Size size) async {
  await openFromButton(
    t,
    size,
    (context) => unawaited(
      RaftConfirmDialog.show(
        context,
        const RaftConfirmDialog(
          surfaceKey: ValueKey('probe-dialog'),
          title: 'Delete thing',
          message: 'Delete it?',
        ),
      ),
    ),
  );
  return SurfaceProbe(
    isOpen: () =>
        find.byKey(const ValueKey('probe-dialog')).evaluate().isNotEmpty,
    x: find.byKey(const Key('confirm-dialog-close')),
    scrim: _corner,
  );
}

/// Opens a dialog over the full workspace; [type] is the dialog's widget.
Future<SurfaceProbe> inWorkspace(
  WidgetTester t,
  Size size,
  Type type,
  void Function(BuildContext context, WorkspaceController w) open,
) async {
  ignoreOverflow();
  await t.pumpWidget(const SizedBox.shrink());
  final (w, _) = await mountWorkspace(t, size);
  open(t.element(find.byType(WorkspaceView)), w);
  await frames(t, 30);
  final dialog = find.byType(type);
  return SurfaceProbe(
    isOpen: () => dialog.evaluate().isNotEmpty,
    x: find.descendant(of: dialog, matching: anyX),
    scrim: _corner,
    dragHandle: _handle,
  );
}

/// The channel settings drawer with the key action [label] tapped (its
/// button sits below the fold, so the list scrolls to the bottom first).
Future<SurfaceProbe> fromChannelSettings(
  WidgetTester t,
  Size size,
  String label,
  Key surface,
) async {
  ignoreOverflow();
  await t.pumpWidget(const SizedBox.shrink());
  final (w, api) = await mountWorkspace(t, size);
  api.routes['GET /channels/c1/members'] = (_) => {'humans': [], 'agents': []};
  api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
  api.routes['GET /channels/c1/message-display-settings'] = (_) => {
    'collapseLongMessages': true,
  };
  api.routes['GET /channels'] = (_) => [];
  unawaited(
    ChannelSettings.show(
      t.element(find.byType(WorkspaceView)),
      controller: w,
      channel: w.channels.first,
    ),
  );
  await frames(t, 30);
  final scrollable = find
      .descendant(
        of: find.byType(ChannelSettings),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = t.state<ScrollableState>(scrollable).position;
  for (var i = 0; i < 4; i++) {
    position.jumpTo(position.maxScrollExtent);
    await frames(t, 8);
  }
  final action = find
      .descendant(of: find.byType(ChannelSettings), matching: find.text(label))
      .first;
  await t.ensureVisible(action);
  await frames(t, 10);
  await t.tap(action);
  await frames(t, 25);
  return SurfaceProbe(
    isOpen: () => find.byKey(surface).evaluate().isNotEmpty,
    x: find.descendant(of: find.byKey(surface), matching: anyX),
    scrim: _corner,
  );
}

/// A dirty settings drawer asked to close: the unsaved-changes prompt.
Future<SurfaceProbe> unsavedPrompt(WidgetTester t, Size size) async {
  ignoreOverflow();
  await t.pumpWidget(const SizedBox.shrink());
  final (w, api) = await mountWorkspace(t, size);
  api.routes['GET /channels/c1/members'] = (_) => {'humans': [], 'agents': []};
  api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
  api.routes['GET /channels/c1/message-display-settings'] = (_) => {
    'collapseLongMessages': true,
  };
  api.routes['GET /channels'] = (_) => [];
  unawaited(
    ChannelSettings.show(
      t.element(find.byType(WorkspaceView)),
      controller: w,
      channel: w.channels.first,
    ),
  );
  await frames(t, 30);
  await t.enterText(
    find
        .descendant(
          of: find.byType(ChannelSettings),
          matching: find.byType(EditableText),
        )
        .first,
    'renamed',
  );
  await frames(t, 5);
  await pressEscape(t);
  const prompt = ValueKey('channel-overflow-unsaved-prompt');
  return SurfaceProbe(
    isOpen: () => find.byKey(prompt).evaluate().isNotEmpty,
    scrim: _corner,
  );
}

/// The Applications settings page (marketplace + installed apps) with the
/// control [tap] pressed (after switching to the installed tab if asked).
Future<SurfaceProbe> fromIntegrations(
  WidgetTester t,
  Size size, {
  required Key tap,
  required Key surface,
  bool installedTab = false,
}) async {
  ignoreOverflow();
  await t.pumpWidget(const SizedBox.shrink());
  final (w, api) = await mountWorkspace(t, size);
  Map<String, dynamic> listing(String id, String name, {String? installedAt}) =>
      {
        'id': id,
        'clientId': 'client_$id',
        'name': name,
        'description': '$name description',
        'category': 'Developer Tools',
        'publisherName': 'Raft Labs',
        'homepageUrl': 'https://example.com/$id',
        'returnUrl': 'https://example.com/$id/callback',
        'allowedScopes': ['openid', 'profile'],
        'installedAt': installedAt,
        'privateShared': false,
        'publishStatus': 'published',
        'marketplaceInstallBadge': {'kind': 'none'},
      };
  api.routes['GET /integrations/marketplace'] = (_) => [
    listing('slack', 'Slack Bridge'),
    listing('github', 'GitHub Issues', installedAt: '2026-06-18T00:00:00.000Z'),
  ];
  api.routes['GET /integrations/clients'] = (_) => [];
  api.routes['GET /integrations/overview'] = (_) => [
    {
      'id': 'g1',
      'type': 'active',
      'clientId': 'github',
      'scopes': ['openid'],
      'revokedAt': null,
    },
  ];
  api.routes['GET /integrations/marketplace/github/install/app-notifications'] =
      (_) => {
        'requested_groups': <String>[],
        'approved_groups': <String>[],
        'subscribed_events': <String>[],
        'effective_groups': <String>[],
        'effective_events': <String>[],
        'app_review_pending': false,
        'approval_required': false,
      };
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(body: IntegrationsView(controller: w)),
    ),
  );
  await frames(t, 30);
  if (installedTab) {
    await t.tap(find.byKey(const ValueKey('connected-apps-tab-installed')));
    await frames(t, 20);
  }
  await t.tap(find.byKey(tap));
  await frames(t, 30);
  return SurfaceProbe(
    isOpen: () => find.byKey(surface).evaluate().isNotEmpty,
    x: find.descendant(of: find.byKey(surface), matching: anyX),
    scrim: _corner,
  );
}

/// The provider connections page with the control [tap] pressed.
Future<SurfaceProbe> fromProviders(
  WidgetTester t,
  Size size, {
  required Finder tap,
  required Finder surface,
}) async {
  ignoreOverflow();
  await t.pumpWidget(const SizedBox.shrink());
  final (w, api) = await mountWorkspace(t, size);
  api.routes['POST /feature-flags/evaluate'] = (_) => {
    'evaluations': [
      {'key': 'provider_connections_v0', 'enabled': true},
    ],
  };
  api.routes['GET /provider-connections'] = (_) => {
    'connections': [
      {
        'id': 'p1',
        'name': 'Provider fixture',
        'providerId': 'openai',
        'status': 'configured',
        'enabled': true,
        'assignedAgentCount': 0,
      },
    ],
    'providerOptions': <dynamic>[],
  };
  api.routes['GET /provider-connections/p1/agents'] = (_) => {'agents': []};
  api.routes['GET /provider-connections/p1/probes'] = (_) => {'receipts': []};
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(body: ProviderConnectionsView(controller: w)),
    ),
  );
  await frames(t, 30);
  await t.ensureVisible(tap);
  await t.tap(tap);
  await frames(t, 30);
  return SurfaceProbe(
    isOpen: () => surface.evaluate().isNotEmpty,
    x: find.descendant(of: surface, matching: anyX),
    scrim: _corner,
    dragHandle: _handle,
  );
}

void main() {
  // Leak debt (dialog notifier): see docs/development.md, Leak tracking.
  // Flutter 3.47.6: a modal bottom sheet closed by a drag rebinds its animation
  // to a CurvedAnimation that nothing disposes (the composer's phone sheet).
  leakDebt(const [
    'ValueNotifier<RaftTranscriptRequestState?>',
    'CurvedAnimation',
  ]);
  final harness = <String, OpenSurface>{
    'history-lower-limit-confirm': (t, size) =>
        historySettingsConfirmation(t, size),
    'confirm-dialog': confirmDialog,
    'role-permission-help': (t, size) async {
      await openFromButton(
        t,
        size,
        (context) =>
            unawaited(showRaftRolePermissionHelp(context, agent: false)),
      );
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('role-help-dialog'))
            .evaluate()
            .isNotEmpty,
        x: anyX,
        scrim: _corner,
      );
    },
    'sidebar-section-dialog': (t, size) async {
      await openFromButton(
        t,
        size,
        (context) => unawaited(
          showRaftSidebarSectionDialog(
            context,
            cardKey: const ValueKey('section-dialog'),
            title: 'New section',
            submitLabel: 'Create',
            onSubmit: (_, _) {},
          ),
        ),
      );
      return SurfaceProbe(
        isOpen: () =>
            find.byKey(const ValueKey('section-dialog')).evaluate().isNotEmpty,
        x: anyX,
        scrim: _corner,
        dragHandle: _handle,
      );
    },
    'add-computer-dialog': (t, size) async {
      await openFromButton(
        t,
        size,
        (context) => unawaited(
          RaftAddComputerDialog.show(
            context,
            (_) => RaftAddComputerDialog(
              commandsFor: (_) => null,
              register: () async {},
              cancel: () async {},
              done: (_) async {},
            ),
          ),
        ),
      );
      return SurfaceProbe(
        isOpen: () =>
            find.byKey(const ValueKey('computer-dialog')).evaluate().isNotEmpty,
        x: anyX,
        scrim: _corner,
      );
    },
    'computer-bulk-model': (t, size) async =>
        (await openBulkModelClose(t, size)).probe,
    'computer-bulk-reset': (t, size) async {
      // The bulk reset options dialog is private to the computer detail; it
      // is reached through the multi-select toolbar.
      return openBulkReset(t, size);
    },
    'runtime-usage-sheet': (t, size) async {
      final usageChanges = ValueNotifier(0);
      addTearDown(usageChanges.dispose);
      await openFromButton(
        t,
        size,
        (context) => unawaited(
          showRaftRuntimeUsageSheet(
            context,
            listenable: usageChanges,
            data: (_) => const RaftRuntimeUsageData(
              provider: 'Claude',
              footer: 'Cached',
            ),
            onRefresh: () {},
          ),
        ),
      );
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('runtime-usage-sheet'))
            .evaluate()
            .isNotEmpty,
        x: anyX,
        scrim: _corner,
      );
    },
    'create-channel': (t, size) => inWorkspace(
      t,
      size,
      CreateChannelDialog,
      (context, w) =>
          unawaited(CreateChannelDialog.show(context, controller: w)),
    ),
    'create-task': (t, size) => inWorkspace(
      t,
      size,
      CreateTaskDialog,
      (context, w) => unawaited(
        CreateTaskDialog.show(context, controller: w, channelId: 'c1'),
      ),
    ),
    'create-joint-channel': (t, size) => inWorkspace(
      t,
      size,
      CreateJointChannelDialog,
      (context, w) =>
          unawaited(CreateJointChannelDialog.show(context, controller: w)),
    ),
    'unsaved-changes-prompt': unsavedPrompt,
    'announcement-modal': (t, size) async {
      ignoreOverflow();
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpWidget(announcements.app(announcements.Fixture()));
      await announcements.settle(t);
      final modal = find.byKey(const ValueKey('announcement-modal'));
      return SurfaceProbe(
        isOpen: () => modal.evaluate().isNotEmpty,
        x: find.descendant(of: modal, matching: anyX),
        scrim: _corner,
      );
    },
    'create-agent': (t, size) => inWorkspace(
      t,
      size,
      CreateAgentDialog,
      (context, w) => unawaited(showManagedAgentForm(context, w)),
    ),
    'agent-avatar-dialog': (t, size) async {
      ignoreOverflow();
      await t.pumpWidget(const SizedBox.shrink());
      final (w, _) = await mountWorkspace(t, size);
      w.openProfile(RaftProfileKind.agent, 'a1');
      await frames(t, 30);
      await t.tap(find.byKey(const ValueKey('agent-profile-avatar-trigger')));
      await frames(t, 25);
      final dialog = find.byType(AgentAvatarDialog);
      return SurfaceProbe(
        isOpen: () => dialog.evaluate().isNotEmpty,
        x: find.descendant(of: dialog, matching: anyX),
        scrim: _corner,
      );
    },
    'agent-runtime-editor': (t, size) async {
      ignoreOverflow();
      await t.pumpWidget(const SizedBox.shrink());
      final (w, api) = await mountWorkspace(t, size);
      const agent = {
        'id': 'a1',
        'name': 'cindy',
        'displayName': 'Cindy',
        'status': 'active',
        'runtime': 'codex',
        'model': 'gpt-5',
        'machineId': 'm1',
      };
      api.routes['GET /agents'] = (_) => [agent];
      api.routes['GET /agents/a1'] = (_) => agent;
      w.openProfile(RaftProfileKind.agent, 'a1');
      await frames(t, 30);
      await t.ensureVisible(find.byKey(const ValueKey('agent-edit-runtime')));
      await t.tap(find.byKey(const ValueKey('agent-edit-runtime')));
      await frames(t, 30);
      final dialog = find.byType(AgentRuntimeEditor);
      return SurfaceProbe(
        isOpen: () => dialog.evaluate().isNotEmpty,
        x: find.descendant(of: dialog, matching: anyX),
        scrim: _corner,
        dragHandle: _handle,
      );
    },
    'feedback-close-dialog': (t, size) async {
      ignoreOverflow();
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const SizedBox.shrink());
      var ids = 0;
      final store = SourceFeedbackStore(
        authority: () => 'account',
        newId: () => 'id-${++ids}',
        get: (path, {query}) async {
          if (path == '/product-feedback/tickets') {
            return fx.page([fx.ticket(fx.first), fx.ticket(fx.second)]);
          }
          return fx.detail(path.split('/').last);
        },
        post: (path, {json, form, onProgress, abort}) async => {'ok': true},
      );
      addTearDown(store.dispose);
      await t.runAsync(store.loadList);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: SourceFeedbackProjectionView(
              store: store,
              pickFiles: () async => const [],
            ),
          ),
        ),
      );
      await frames(t, 20);
      Future<void> press(String key) async {
        await t.tap(find.byKey(ValueKey(key)));
        await frames(t, 20);
      }

      await press('feedback-ticket-${fx.first}');
      await press('feedback-close-caret');
      await press('feedback-close-reason-completed');
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('feedback-close-dialog'))
            .evaluate()
            .isNotEmpty,
        scrim: _corner,
      );
    },
    'agent-profile-edit-dialog': (t, size) async {
      ignoreOverflow();
      await t.pumpWidget(const SizedBox.shrink());
      final (w, _) = await mountWorkspace(t, size);
      w.openProfile(RaftProfileKind.agent, 'a1');
      await frames(t, 30);
      await t.tap(find.byKey(const ValueKey('agent-edit-display-name')));
      await frames(t, 25);
      final dialog = find.byType(RaftAgentProfileEditDialog);
      return SurfaceProbe(
        isOpen: () => dialog.evaluate().isNotEmpty,
        x: find.descendant(of: dialog, matching: anyX),
        scrim: _corner,
        dragHandle: _handle,
      );
    },
    'agent-reset-dialog': (t, size) async {
      ignoreOverflow();
      await t.pumpWidget(const SizedBox.shrink());
      final (w, _) = await mountWorkspace(t, size);
      w.openProfile(RaftProfileKind.agent, 'a1');
      await frames(t, 30);
      // Below 480px the commands sit behind the overflow menu.
      final overflow = find.byKey(const Key('agent-profile-overflow-trigger'));
      if (overflow.evaluate().isNotEmpty) {
        await t.tap(overflow);
        await frames(t, 20);
      }
      await t.tap(find.text('Restart / Reset').first);
      await frames(t, 25);
      final dialog = find.byType(RaftResetAgentDialog);
      return SurfaceProbe(
        isOpen: () => dialog.evaluate().isNotEmpty,
        x: find.descendant(of: dialog, matching: anyX),
        scrim: _corner,
      );
    },
    'report-issue-dialog': (t, size) async {
      final probe = await inWorkspace(
        t,
        size,
        RaftReportIssueDialog,
        (context, w) => unawaited(
          showReportIssueDialog(
            context,
            controller: w,
            agent: const {'id': 'a1', 'name': 'cindy', 'displayName': 'Cindy'},
            exportUrl: 'https://feedback.example.test',
          ),
        ),
      );
      return SurfaceProbe(
        isOpen: probe.isOpen,
        x: probe.x,
        scrim: _corner,
        dragHandle: _handle,
      );
    },
    'avatar-discard-confirm': (t, size) async {
      ignoreOverflow();
      await t.pumpWidget(const SizedBox.shrink());
      final (w, _) = await mountWorkspace(t, size);
      w.openProfile(RaftProfileKind.agent, 'a1');
      await frames(t, 30);
      await t.tap(find.byKey(const ValueKey('agent-profile-avatar-trigger')));
      await frames(t, 25);
      await t.tap(find.byKey(const ValueKey('avatar-choice-heart')));
      await frames(t, 5);
      await t.tap(
        find
            .descendant(of: find.byType(AgentAvatarDialog), matching: anyX)
            .first,
      );
      await frames(t, 25);
      final prompt = find.byType(RaftAvatarDiscardConfirmation);
      return SurfaceProbe(
        isOpen: () => prompt.evaluate().isNotEmpty,
        scrim: _corner,
      );
    },
    'composer-expanded-editor': (t, size) async {
      ignoreOverflow();
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: Column(
              children: [
                const Spacer(),
                RaftComposer(
                  initialDraft: 'one\ntwo\nthree',
                  onSend: (_) async => true,
                ),
              ],
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('composer-expand')));
      await frames(t, 25);
      return SurfaceProbe(
        isOpen: () =>
            find.byType(RaftComposerExpandedView).evaluate().isNotEmpty,
        x: find.byKey(const ValueKey('composer-collapse')),
        // Below 768 the editor is a bottom sheet: the scrim is the strip above it.
        scrim: size.width >= 768 ? _corner : const Offset(200, 10),
        dragHandle: find.byKey(const ValueKey('raft-sheet-handle')),
      );
    },
    'forward-dialog': (t, size) async {
      final probe = await inWorkspace(
        t,
        size,
        ForwardComposerPage,
        (context, w) => unawaited(
          forwardMessages(context, w, [RaftMessage(closeRows().first)]),
        ),
      );
      return SurfaceProbe(
        isOpen: probe.isOpen,
        x: anyX,
        back: find.byTooltip('Close forward target selection'),
        scrim: size.width >= 768 ? _corner : null,
      );
    },
    'community-agreement': (t, size) async {
      await openFromButton(
        t,
        size,
        (context) => unawaited(
          showCommunityAgreementDialog(
            context,
            agreement: CommunityAgreementRequired({
              'id': 'ag1',
              'title': 'Community rules',
              'version': 2,
              'bodyMarkdown': 'Be kind.',
            }),
            onAgree: (_) async {},
          ),
        ),
      );
      return SurfaceProbe(
        isOpen: () =>
            find.byType(RaftCommunityAgreementDialog).evaluate().isNotEmpty,
        x: anyX,
        scrim: _corner,
      );
    },
    'connected-app-detail': (t, size) => fromIntegrations(
      t,
      size,
      tap: const ValueKey('connected-app-slack'),
      surface: const ValueKey('connected-app-detail'),
    ),
    'connected-app-installed-detail': (t, size) => fromIntegrations(
      t,
      size,
      tap: const ValueKey('connected-app-installed-github'),
      surface: const ValueKey('connected-app-installed-detail'),
      installedTab: true,
    ),
    'connected-app-editor': (t, size) => fromIntegrations(
      t,
      size,
      tap: const ValueKey('connected-apps-register'),
      surface: const ValueKey('connected-app-editor'),
    ),
    'provider-edit-dialog': (t, size) => fromProviders(
      t,
      size,
      tap: find.byKey(const ValueKey('provider-edit-p1')),
      surface: find.byType(EditProviderConnectionDialog),
    ),
    'material-alert-dialog': (t, size) => fromProviders(
      t,
      size,
      tap: find.text('Assigned agents'),
      surface: find.byType(AlertDialog),
    ),
    'mention-link-dialog': (t, size) async {
      ignoreOverflow();
      await t.pumpWidget(const SizedBox.shrink());
      final (w, api) = await mountWorkspace(t, size);
      api.routes['GET /tasks/channel/c1/number/7'] = (_) => {
        'task': {
          'taskNumber': 7,
          'title': 'Ship it',
          'status': 'todo',
          'description': 'Task body',
        },
      };
      final presentation = MessagePresentation(
        controller: w,
        message: RaftMessage(closeRows().first),
        onExternalLink: (_) {},
      );
      unawaited(
        presentation.open(
          t.element(find.byType(WorkspaceView)),
          'raft-ref://task/7',
        ),
      );
      await frames(t, 30);
      return SurfaceProbe(
        isOpen: () => find.byType(AlertDialog).evaluate().isNotEmpty,
        scrim: _corner,
      );
    },
    'workspace-switcher-dialog': (t, size) async {
      ignoreOverflow();
      await t.pumpWidget(const SizedBox.shrink());
      final (w, _) = await mountWorkspace(t, size);
      w.servers = [w.server!];
      if (size.width >= 768) return SurfaceProbe(isOpen: () => true);
      // The state class is private; its switcher entry point is public.
      final state = t.state(find.byType(WorkspaceView)) as dynamic;
      unawaited(state.showWorkspaceSwitcher() as Future<void>);
      await frames(t, 25);
      return SurfaceProbe(
        isOpen: () => find.byType(SimpleDialog).evaluate().isNotEmpty,
        scrim: _corner,
      );
    },
    'channel-settings-confirm': (t, size) => fromChannelSettings(
      t,
      size,
      'Archive Channel',
      const ValueKey('channel-settings-confirm-dialog'),
    ),
    'sos-dialog': (t, size) => fromChannelSettings(
      t,
      size,
      'Stop Agents',
      const ValueKey('channel-sos-dialog'),
    ),
    'add-members': (t, size) => inWorkspace(
      t,
      size,
      AddMembersDialog,
      (context, w) => unawaited(
        showRaftModal<bool>(
          context,
          builder: (_) => AddMembersDialog(controller: w, channelId: 'c1'),
        ),
      ),
    ),
    'form-dialog': (t, size) => inWorkspace(
      t,
      size,
      RaftFormDialog,
      (context, w) => unawaited(WorkspaceActions.create(context, w)),
    ),
    'invite-human': (t, size) => inWorkspace(
      t,
      size,
      RaftInviteHumanDialog,
      (context, w) => unawaited(showWorkspaceMenuInvite(context, w)),
    ),
  };
  registerCloseTests(dialogSurfaces, harness);
  registerNoScrimTests(dialogSurfaces, harness);

  // Web ConfirmDialog gates every close on the in-flight confirm.
  testWidgets('confirm dialog ignores Esc, Back and the X while it runs', (
    t,
  ) async {
    final running = Completer<void>();
    await openFromButton(
      t,
      const Size(1280, 800),
      (context) => unawaited(
        RaftConfirmDialog.show(
          context,
          RaftConfirmDialog(
            surfaceKey: const ValueKey('probe-dialog'),
            title: 'Archive',
            message: 'Archive it?',
            confirmLabel: 'Confirm it',
            onConfirm: () => running.future,
          ),
        ),
      ),
    );
    final open = find.byKey(const ValueKey('probe-dialog'));
    await t.tap(find.text('Confirm it'));
    await frames(t, 10);
    await pressEscape(t);
    expect(open, findsOneWidget, reason: 'Escape closed a running confirm');
    await systemBack(t);
    expect(open, findsOneWidget, reason: 'Back closed a running confirm');
    await t.tapAt(_corner);
    await frames(t, 10);
    expect(open, findsOneWidget, reason: 'a scrim tap closed it');
    running.complete();
    await frames(t, 20);
    expect(open, findsNothing, reason: 'it closes once the confirm is done');
  });

  // Web AgentProfileEditDialog.requestClose: a dirty draft asks first.
  testWidgets('agent profile edit asks before it discards a changed name', (
    t,
  ) async {
    final probe = await harness['agent-profile-edit-dialog']!(
      t,
      const Size(1280, 800),
    );
    await t.enterText(
      find.byKey(const ValueKey('agent-profile-edit-display-name')),
      'Renamed',
    );
    await frames(t, 5);
    await pressEscape(t);
    expect(find.byType(RaftAvatarDiscardConfirmation), findsOneWidget);
    expect(probe.isOpen(), isTrue);
    await pressEscape(t); // Keep editing
    expect(find.byType(RaftAvatarDiscardConfirmation), findsNothing);
    expect(probe.isOpen(), isTrue);
    await t.tap(probe.x!.hitTestable().first);
    await frames(t, 20);
    await t.tap(find.text('Discard'));
    await frames(t, 20);
    expect(probe.isOpen(), isFalse);
  });

  // Web AddMachineDialog.handleCancel releases the placeholder on every exit.
  testWidgets('add computer dialog runs cancel() on Esc and Back', (t) async {
    var cancels = 0;
    for (final exit in [pressEscape, systemBack]) {
      await openFromButton(
        t,
        const Size(1280, 800),
        (context) => unawaited(
          RaftAddComputerDialog.show(
            context,
            (_) => RaftAddComputerDialog(
              commandsFor: (_) => null,
              register: () async {},
              cancel: () async => cancels++,
              done: (_) async {},
            ),
          ),
        ),
      );
      await exit(t);
    }
    expect(cancels, 2);
  });
}

/// Where Web has no backdrop close (`closeOnBackdrop` is opt-in on `Modal`)
/// a stray tap on the scrim must not discard the user's input.
void registerNoScrimTests(
  List<CloseSurface> surfaces,
  Map<String, OpenSurface> harness,
) {
  for (final surface in surfaces) {
    for (final (name, size) in closeSizes) {
      final affordances = surface.at(widthKey(name));
      if (affordances.isEmpty || affordances.contains(Affordance.scrim)) {
        continue;
      }
      testWidgets('${surface.id} @ $name ignores a scrim tap', (t) async {
        final probe = await harness[surface.id]!(t, size);
        if (probe.scrim == null) return; // no scrim at this width
        expect(probe.isOpen(), isTrue);
        await t.tapAt(probe.scrim!);
        await frames(t, 20);
        expect(
          probe.isOpen(),
          isTrue,
          reason:
              '${surface.id} @ $name closed on a scrim tap; Web only does '
              'that with closeOnBackdrop',
        );
      });
    }
  }
}

Future<SurfaceProbe> openBulkReset(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  Future<void> none() async {}
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: RaftComputerDetailView(
          key: UniqueKey(),
          data: const RaftComputerDetailData(
            id: 'm1',
            name: 'my-computer',
            online: true,
            isComputer: true,
            slug: 'demo',
            runtimes: [],
            createdLabel: 'today',
            canManage: true,
            agents: [
              RaftComputerAgent(
                id: 'a1',
                name: 'cindy',
                subtitle: 'claude',
                activity: 'online',
                activityText: 'Online',
              ),
            ],
          ),
          actions: RaftComputerDetailActions(
            rename: (_) => none(),
            describe: (_) => none(),
            scanWorkspaces: () async => const [],
            deleteWorkspace: (_) => none(),
            restart: none,
            deleteComputer: none,
            bulk: (_, _) async => 0,
          ),
        ),
      ),
    ),
  );
  await frames(t, 10);
  Future<void> tapKey(Finder f) async {
    await t.ensureVisible(f);
    await frames(t, 5);
    await t.tap(f);
    await frames(t, 10);
  }

  await tapKey(find.text('Select'));
  await tapKey(find.text('Select All'));
  await tapKey(find.text('Restart / Reset'));
  return SurfaceProbe(
    isOpen: () =>
        find.byKey(const ValueKey('computer-dialog')).evaluate().isNotEmpty,
    x: anyX,
    scrim: _corner,
  );
}
