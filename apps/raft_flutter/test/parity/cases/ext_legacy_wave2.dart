import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/runtime_auth.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/add_members_dialog.dart';
import 'package:raft_flutter/features/attachment_comments_view.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/community_join.dart'
    show communityAgreementError;
import 'package:raft_flutter/features/computer_runtime_provider_connect_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'thread_messages/chat_stage.dart' show ParityRaftClient;

final _fixture = jsonDecode(
  File('../../tool/parity-ext/fixtures/legacy-wave2.json').readAsStringSync(),
) as Map<String, dynamic>;

WorkspaceController _workspace(
  ParityContext ctx, {
  bool emptyMembers = false,
  bool emptyComments = false,
}) {
  final server = RaftRecord(
    Map<String, dynamic>.from(_fixture['server'] as Map),
  );
  final channels = [
    for (final raw in _fixture['channels'] as List)
      RaftChannel(Map<String, dynamic>.from(raw as Map)),
  ];
  final agents = [
    for (final raw in _fixture['agents'] as List)
      Map<String, dynamic>.from(raw as Map),
  ];
  final members = [
    for (final raw in _fixture['members'] as List)
      Map<String, dynamic>.from(raw as Map),
  ];
  final machine = Map<String, dynamic>.from(_fixture['machine'] as Map);
  final att = Map<String, dynamic>.from(_fixture['attachment'] as Map);
  final channelId = channels.first.id;
  final roster = emptyMembers
      ? {
          'humans': [
            for (final m in members)
              {
                'id': m['userId'],
                'name': m['name'],
                'displayName': m['displayName'],
                'description': m['description'],
                'avatarUrl': m['avatarUrl'],
                'role': m['role'],
              },
          ],
          'agents': [
            for (final a in agents)
              {
                'id': a['id'],
                'name': a['name'],
                'displayName': a['displayName'],
                'description': a['description'],
                'avatarUrl': a['avatarUrl'],
                'status': a['status'],
                'role': a['role'],
              },
          ],
        }
      : {
          'humans': [
            {
              'id': members.first['userId'],
              'name': members.first['name'],
              'displayName': members.first['displayName'],
              'description': members.first['description'],
              'avatarUrl': members.first['avatarUrl'],
              'role': members.first['role'],
            },
          ],
          'agents': [
            {
              'id': agents.first['id'],
              'name': agents.first['name'],
              'displayName': agents.first['displayName'],
              'description': agents.first['description'],
              'avatarUrl': agents.first['avatarUrl'],
              'status': agents.first['status'],
              'role': agents.first['role'],
            },
          ],
        };
  final client = ParityRaftClient(
    {
      'GET /agents': (_) => agents,
      'GET /servers/${server.id}/members': (_) => members,
      'GET /servers/${server.id}/machines': (_) => {
        'machines': [machine],
      },
      'GET /channels/$channelId/members': (_) => roster,
      'GET /attachments/${att['id']}/comments': (_) => {
        'comments': emptyComments ? const <Object>[] : att['comments'],
        'threadChannelId': 'chan-wave2-thread',
        'viewer': const {'canComment': true, 'reason': 'ok'},
      },
      'GET /servers/${server.id}/machines/${machine['id']}/runtime-auth/qwen/providers':
          (_) => {'kind': 'listed', 'providers': _fixture['runtimeProviders']},
    },
    user: Map<String, dynamic>.from(_fixture['user'] as Map),
  )..selectServer(server.id);
  final w = WorkspaceController(client)
    ..server = server
    ..channel = channels.first
    ..channels = channels;
  ctx.onDispose(w.dispose);
  return w;
}

class _Wave2RuntimeAuthClient extends RuntimeAuthClient {
  _Wave2RuntimeAuthClient(RaftClient client)
    : super(
        get: (path) => client.get(path),
        post: (path, body) => client.post(path, data: body),
        events: const Stream.empty(),
      );
}

class _AutoOpenForm extends StatefulWidget {
  const _AutoOpenForm({
    required this.dialogBuilder,
    this.dialogMaxWidth = 560,
    this.dismissible = true,
    this.dragDismissible = true,
    this.policy = RaftPresentationPolicy.form,
  });
  final WidgetBuilder dialogBuilder;
  final double dialogMaxWidth;
  final bool dismissible, dragDismissible;
  final RaftPresentationPolicy policy;

  @override
  State<_AutoOpenForm> createState() => _AutoOpenFormState();
}

class _AutoOpenFormState extends State<_AutoOpenForm> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showRaftForm<void>(
        context,
        builder: widget.dialogBuilder,
        dialogMaxWidth: widget.dialogMaxWidth,
        dismissible: widget.dismissible,
        dragDismissible: widget.dragDismissible,
        policy: widget.policy,
        guardUnsaved: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: RaftTokens.of(context).canvas,
    body: const SizedBox.expand(),
  );
}

ParityCase _reportIssueCase({required bool submitted}) => ParityCase(
  widgets: const ['raft_ui:RaftReportIssueDialog'],
  settle: const Duration(milliseconds: 250),
  build: (ctx) {
    final agent = Map<String, dynamic>.from(
      (_fixture['agents'] as List).first as Map,
    );
    final transcriptState = ValueNotifier<RaftTranscriptRequestState?>(null);
    ctx.onDispose(transcriptState.dispose);
    return _AutoOpenForm(
      dialogMaxWidth: 384,
      policy: submitted
          ? RaftPresentationPolicy.confirm
          : RaftPresentationPolicy.form,
      dialogBuilder: (_) => RaftReportIssueDialog(
        agentName: '${agent['displayName'] ?? agent['name']}',
        hasMachine: true,
        canIncludeMachineLog: false,
        transcriptState: transcriptState,
        onViewTicket: (_) {},
        onSubmit: (_) async {
          if (!submitted) {
            throw const RaftReportIssueFailure('not submitted in capture');
          }
          transcriptState.value = RaftTranscriptRequestState.requested;
          return const RaftReportIssueReceipt(
            reportId: 'rep-wave2-01',
            serverId: 'server-wave2',
            ticketId: 'tkt-wave2-01',
            transcriptAttachmentRequested: true,
            serverSlug: 'acme',
          );
        },
        onClose: () {},
      ),
    );
  },
  interact: submitted
      ? (tester, ctx) async {
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('report-issue-consent')));
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('report-issue-submit')));
          await tester.pumpAndSettle();
        }
      : null,
);

ParityCase _communityAgreementCase() => ParityCase(
  widgets: const ['raft_ui:RaftCommunityAgreementDialog'],
  settle: const Duration(milliseconds: 200),
  build: (ctx) {
    final agreement = Map<String, dynamic>.from(_fixture['agreement'] as Map);
    return _AutoOpenForm(
      dialogMaxWidth: 512,
      dismissible: false,
      dragDismissible: false,
      dialogBuilder: (_) => RaftCommunityAgreementDialog(
        title: agreement['title'] as String,
        version: agreement['version'] as int,
        bodyMarkdown: agreement['bodyMarkdown'] as String,
        errorMessage: communityAgreementError,
        onClose: () {},
        onAgree: () async {},
      ),
    );
  },
);

ParityCase _addComputerConfirmCase() => ParityCase(
  widgets: const ['raft_ui:RaftAddComputerDialog'],
  settle: const Duration(milliseconds: 200),
  build: (ctx) {
    final machine = Map<String, dynamic>.from(_fixture['machine'] as Map);
    return _AutoOpenForm(
      dialogMaxWidth: 512,
      dismissible: false,
      dragDismissible: false,
      dialogBuilder: (_) => RaftAddComputerDialog(
        commandsFor: (_) =>
            ('curl -fsSL https://example.test | sh', 'raft setup'),
        cancel: () async {},
        done: (_) async {},
        connected: RaftAddComputerConnection(
          hostname: '${machine['hostname']}',
          os: '${machine['os']}',
          requiresConfirmation: true,
        ),
      ),
    );
  },
);

ParityCase _addMembersCase({required bool empty}) {
  late WorkspaceController w;
  return ParityCase(
    widgets: const [
      'raft_flutter:AddMembersDialog',
      'raft_ui:RaftAddMembersDialogView',
    ],
    settle: const Duration(milliseconds: 250),
    build: (ctx) {
      w = _workspace(ctx, emptyMembers: empty);
      final members = _fixture['members'] as List;
      final agents = _fixture['agents'] as List;
      final secondMember = Map<String, dynamic>.from(members[1] as Map);
      final secondAgent = Map<String, dynamic>.from(agents[1] as Map);
      return _AutoOpenForm(
        dialogBuilder: (_) => AddMembersDialog(
          controller: w,
          channelId: w.channels.first.id,
          prefilledHumanIds: empty ? const [] : ['${secondMember['userId']}'],
          prefilledAgentIds: empty ? const [] : ['${secondAgent['id']}'],
          draftHint: empty
              ? null
              : 'Cindy suggested inviting Lux and Ben for design review.',
        ),
      );
    },
    interact: (tester, ctx) async {
      await Future.wait([
        for (final kind in WorkspaceEntityKind.values)
          w.entityDirectory.refresh(kind),
      ]);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    },
  );
}

ParityCase _channelMembersPageCase({required String platform}) {
  late WorkspaceController w;
  return ParityCase(
    widgets: const [
      'raft_flutter:ChannelMembers',
      'raft_ui:RaftChannelMembersModal',
    ],
    settle: const Duration(milliseconds: 250),
    build: (ctx) {
      w = _workspace(ctx, emptyMembers: true);
      final width = platform == 'desktop' ? 384.0 : 390.0;
      final height = platform == 'desktop' ? 720.0 : 844.0;
      return Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: height,
            child: ChannelMembers(
              controller: w,
              channel: w.channels.first,
              page: true,
            ),
          ),
        ),
      );
    },
    interact: (tester, ctx) async {
      await Future.wait([
        for (final kind in WorkspaceEntityKind.values)
          w.entityDirectory.refresh(kind),
      ]);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    },
  );
}

ParityCase _runtimeProviderConnectCase() {
  late WorkspaceController w;
  return ParityCase(
    widgets: const ['raft_flutter:RuntimeProviderConnectForm'],
    settle: const Duration(milliseconds: 250),
    build: (ctx) {
      w = _workspace(ctx);
      final machine = Map<String, dynamic>.from(_fixture['machine'] as Map);
      final authClient = _Wave2RuntimeAuthClient(w.client);
      return _AutoOpenRuntimeProviderDialog(
        controller: w,
        authClient: authClient,
        serverId: w.server!.id,
        machineId: '${machine['id']}',
      );
    },
    interact: (tester, ctx) async {
      await Future.wait([
        for (final kind in WorkspaceEntityKind.values)
          w.entityDirectory.refresh(kind),
      ]);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    },
  );
}

class _AutoOpenRuntimeProviderDialog extends StatefulWidget {
  const _AutoOpenRuntimeProviderDialog({
    required this.controller,
    required this.authClient,
    required this.serverId,
    required this.machineId,
  });
  final WorkspaceController controller;
  final RuntimeAuthClient authClient;
  final String serverId, machineId;

  @override
  State<_AutoOpenRuntimeProviderDialog> createState() =>
      _AutoOpenRuntimeProviderDialogState();
}

class _AutoOpenRuntimeProviderDialogState
    extends State<_AutoOpenRuntimeProviderDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showComputerRuntimeProviderConnectDialog(
        context,
        controller: widget.controller,
        client: widget.authClient,
        serverId: widget.serverId,
        machineId: widget.machineId,
        runtimeId: 'qwen',
        runtime: 'qwen',
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: RaftTokens.of(context).canvas,
    body: const SizedBox.expand(),
  );
}

ParityCase _attachmentCommentsCase({
  required String platform,
  required bool empty,
}) {
  late WorkspaceController w;
  return ParityCase(
    widgets: const [
      'raft_flutter:AttachmentCommentsView',
      'raft_ui:RaftAttachmentCommentsPanel',
    ],
    settle: const Duration(milliseconds: 250),
    build: (ctx) {
      w = _workspace(ctx, emptyComments: empty);
      final att = Map<String, dynamic>.from(_fixture['attachment'] as Map);
      final width = platform == 'desktop' ? 320.0 : 390.0;
      const height = 640.0;
      return Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: ctx.target(
            SizedBox(
              key: const ValueKey('wave2-frame'),
              width: width,
              height: height,
              child: AttachmentCommentsView(
                controller: w,
                attachmentId: '${att['id']}',
                filename: '${att['filename']}',
                pendingAnchor: empty
                    ? null
                    : Map<String, dynamic>.from(att['pendingAnchor'] as Map),
              ),
            ),
          ),
        ),
      );
    },
    interact: (tester, ctx) async {
      await Future.wait([
        for (final kind in WorkspaceEntityKind.values)
          w.entityDirectory.refresh(kind),
      ]);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    },
  );
}

ParityCase _messageImageExportCase() {
  final pngBytes = base64Decode(_fixture['exportPngBase64'] as String);
  final provider = MemoryImage(pngBytes, scale: 2.0);
  return ParityCase(
    widgets: const ['raft_ui:RaftImageReview'],
    settle: const Duration(milliseconds: 250),
    build: (ctx) => Builder(
      builder: (context) => ColoredBox(
        key: const ValueKey('wave2-lightbox'),
        color: RaftTokens.of(context).canvas,
        child: RaftImageReviewLightbox(
          onBackdrop: () {},
          backdropColor: raftChromeBlend(
            RaftTokens.of(context).colors['layer-backdrop']!,
            RaftTokens.of(context).canvas,
          ),
          child: RaftImageReview(
            preview: Image(
              image: provider,
              width: 178,
              height: 89,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
            onClose: () {},
            onCopy: () {},
            onSave: () {},
          ),
        ),
      ),
    ),
    interact: (tester, ctx) async {
      final element = tester.element(find.byType(RaftImageReview));
      await tester.runAsync(() => precacheImage(provider, element));
      await tester.pumpAndSettle();
    },
  );
}

final Map<String, ParityCase> extLegacyWave2Cases = {
  for (final platform in const ['desktop', 'phone'])
    for (final suffix in const ['brutal', 'elegant-dark']) ...{
      'components.legacy-wave2.report-issue.$platform.$suffix':
          _reportIssueCase(submitted: false),
      'components.legacy-wave2.report-issue-submitted.$platform.$suffix':
          _reportIssueCase(submitted: true),
      'components.legacy-wave2.community-agreement.$platform.$suffix':
          _communityAgreementCase(),
      'components.legacy-wave2.add-computer-confirm.$platform.$suffix':
          _addComputerConfirmCase(),
      'components.legacy-wave2.add-members.$platform.$suffix': _addMembersCase(
        empty: false,
      ),
      'components.legacy-wave2.add-members-empty.$platform.$suffix':
          _addMembersCase(empty: true),
      'components.legacy-wave2.channel-members-page.$platform.$suffix':
          _channelMembersPageCase(platform: platform),
      'components.legacy-wave2.runtime-provider-connect.$platform.$suffix':
          _runtimeProviderConnectCase(),
      'components.legacy-wave2.attachment-comments.$platform.$suffix':
          _attachmentCommentsCase(platform: platform, empty: false),
      'components.legacy-wave2.attachment-comments-empty.$platform.$suffix':
          _attachmentCommentsCase(platform: platform, empty: true),
      'components.legacy-wave2.message-image-export.$platform.$suffix':
          _messageImageExportCase(),
    },
};
