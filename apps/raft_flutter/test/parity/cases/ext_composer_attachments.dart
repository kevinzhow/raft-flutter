// raft-flutter parity EXTENSION suite builders (tool/parity-ext): composer
// attachments. Ids `components.composerattachments.<platform>.<kind>.<theme>`,
// dispatched on props.kind like tool/parity-ext/host/ComposerAttachmentCases.tsx;
// the state of each kind (files, route set, progress, drag, hover) is read from
// tool/parity-ext/fixtures/composer-attachments.json, the same file the React
// host reads.
//
// Mounts the real RaftComposer with the props RaftChatView passes (the
// attachment slot, notices, send blocking) over a real WorkspaceController
// whose fixture client answers `GET /attachments/upload-capabilities` and
// `POST /attachments/upload` from the fixture `routes` / `routeSets`
// (ready / never answers / fails). The files go through the product's
// `attachSelection` exactly like a picker result, so the checking, uploading,
// failed and limit states are produced by the product code, not painted.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/composer_attachments_view.dart';
import 'package:raft_flutter/features/pending_mention_actions.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'thread_composer/fake_workspace.dart';

Map<String, dynamic> _fixture(ParityContext ctx) =>
    ctx.fixtures['ext:composer-attachments'] as Map<String, dynamic>;

Map<String, dynamic> _kind(ParityContext ctx) => Map<String, dynamic>.from(
  (_fixture(ctx)['kinds'] as Map)[ctx.props['kind']] as Map,
);

/// The fixture routes of the case (`routes` overridden by its `routeSet`).
Map<String, dynamic> _routes(ParityContext ctx) {
  final fx = _fixture(ctx);
  final set = _kind(ctx)['routeSet'] as String?;
  return {
    ...Map<String, dynamic>.from(fx['routes'] as Map),
    if (set != null)
      ...Map<String, dynamic>.from((fx['routeSets'] as Map)[set] as Map),
  };
}

List<({String name, Uint8List bytes})> _files(ParityContext ctx) {
  final fx = _fixture(ctx);
  return [
    for (final raw in (_kind(ctx)['files'] as List).cast<Map>())
      () {
        final spec = Map<String, dynamic>.from(raw);
        Uint8List bytes;
        var name = spec['name'] as String? ?? '';
        if (spec['kind'] == 'image') {
          bytes = base64Decode((fx['images'] as Map)[spec['key']] as String);
        } else {
          final file = Map<String, dynamic>.from(
            (fx['files'] as Map)[spec['key']] as Map,
          );
          bytes = Uint8List.fromList(utf8.encode(file['text'] as String));
          name = file['name'] as String;
        }
        final pad = spec['padTo'] as int?;
        if (pad != null && bytes.length < pad) {
          bytes = Uint8List(pad)..setRange(0, bytes.length, bytes);
        }
        return (name: name, bytes: bytes);
      }(),
  ];
}

/// ParityFakeClient whose attachment endpoints follow the fixture routes.
class _AttachmentClient extends ParityFakeClient {
  _AttachmentClient({
    required super.user,
    required Map<String, dynamic> fixtureRoutes,
    required this.progress,
  }) : super(routes: const {}) {
    attachmentRoutes = fixtureRoutes;
  }
  late final Map<String, dynamic> attachmentRoutes;
  final int? progress;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    final route = attachmentRoutes['$method $path'];
    if (route is! Map) {
      return super.request(
        method,
        path,
        data: data,
        query: query,
        authorized: authorized,
        retried: retried,
        cancellation: cancellation,
        onSendProgress: onSendProgress,
        headers: headers,
        acceptServerExit: acceptServerExit,
        receiveTimeout: receiveTimeout,
      );
    }
    requests.add('$method $path');
    if (route[r'$pending'] == true) {
      if (progress != null) onSendProgress?.call(progress!, 100);
      return Completer<dynamic>().future;
    }
    final status = route[r'$status'] as int?;
    if (status != null) {
      final body = Map<String, dynamic>.from(
        (route[r'$body'] as Map?) ?? const {'error': 'fixture error'},
      );
      throw RaftApiException('${body['error']}', status: status);
    }
    return route;
  }
}

class _Host extends StatefulWidget {
  const _Host({required this.ctx});
  final ParityContext ctx;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final fx = ParityThreadFixture(widget.ctx.fixtureData);
  late final kind = _kind(widget.ctx);
  late final WorkspaceController w = _workspace();
  bool alsoCreateTask = false;

  WorkspaceController _workspace() {
    final client = _AttachmentClient(
      user: fx.authUser,
      fixtureRoutes: _routes(widget.ctx),
      progress: kind['progress'] as int?,
    );
    final channels = fx.composerChannels.map(RaftChannel.new).toList();
    return WorkspaceController(client)
      ..server = RaftRecord(fx.serverRecord)
      ..channels = channels
      ..channel = channels.first;
  }

  @override
  void initState() {
    super.initState();
    // The picker result arrives after the first frame, like a user's pick.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      w.attachSelection(
        _files(widget.ctx),
        text: (key, args) => raftFormat(context, key, args),
      );
    });
  }

  @override
  void dispose() {
    w.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // The product composer rebuilds on its per-conversation signal; the
    // controller itself does not notify for a draft change. Only against the
    // Web: the frozen a57b9dab captures of this case were taken without the
    // signal (no attachment row), and Elegant / Brutal are scored against them.
    listenable: widget.ctx.againstWeb
        ? Listenable.merge([w, w.composer.changes(w.draftScope())])
        : w,
    builder: (context, _) {
      final thread = kind['thread'] == true;
      final drafts = w.uploads();
      return RaftComposer(
        initialDraft: kind['draft'] as String? ?? '',
        frame: (_, composer, _) => Stack(
          children: [
            composer,
            if (kind['drag'] == true)
              const Positioned.fill(child: RaftComposerDropOverlay()),
          ],
        ),
        accessoryRow: raftComposerAccessory(context, w),
        taskAction: thread
            ? null
            : RaftComposerTaskToggle(
                key: const Key('composer-as-task'),
                checked: alsoCreateTask,
                label: raftText(context, 'As Task'),
                onChanged: (checked) =>
                    setState(() => alsoCreateTask = checked),
              ),
        onAttach: () {},
        onImagePick: () {},
        hasAttachments: drafts.isNotEmpty,
        attachments: composerAttachmentsFor(
          context,
          w,
          thread: false,
          onPreview: (_) {},
        ),
        submitSpinner: drafts.any(
          (d) => d.checking || (d.error == null && d.id == null),
        ),
        submitTooltip: composerSendBlockTitle(context, drafts),
        hint: thread
            ? raftText(context, 'Message thread')
            : fx.messages['composerPlaceholder'] as String,
        canSend: w.uploadsReady(),
        onSend: (_) async => true,
        onSendWithMentions: (_, _) async => true,
      );
    },
  );
}

ParityCase _case() => ParityCase(
  widgets: const [
    'raft_ui:RaftComposer',
    'raft_ui:RaftComposerAttachments',
    'raft_ui:RaftComposerDropOverlay',
    'raft_flutter:WorkspaceController.attachSelection',
  ],
  notes:
      'Extension suite (not official). Files go through the product '
      'attachSelection over the fixture upload routes.',
  settle: const Duration(milliseconds: 400),
  build: (ctx) => Material(
    type: MaterialType.transparency,
    child: Align(
      alignment: Alignment.topLeft,
      child: KeyedSubtree(
        key: const ValueKey('composer-attachments-case'),
        child: SizedBox(
          width: double.parse('${ctx.props['width']}'),
          child: _Host(ctx: ctx),
        ),
      ),
    ),
  ),
  interact: (t, ctx) async {
    // Thumbnails decode on the engine thread, outside the fake clock.
    final host = t.state<_HostState>(find.byType(_Host));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final context = t.element(find.byType(RaftComposer));
    await t.runAsync(
      () => Future.wait([
        for (final draft in host.w.uploads())
          if (draft.mimeType == 'image/png')
            precacheImage(MemoryImage(draft.bytes), context),
      ]),
    );
    await t.pump(const Duration(milliseconds: 100));
  },
);

const _kinds = {
  'desktop': [
    'one-image',
    'images',
    'file',
    'file-long',
    'mixed',
    'checking',
    'uploading',
    'uploading-progress',
    'uploading-finishing',
    'failed',
    'failed-quota',
    'over-size',
    'over-count',
    'empty-file',
    'drag-over',
    'hover-remove',
    'thread-image',
  ],
  'mobile': [
    'one-image',
    'images',
    'file',
    'mixed',
    'checking',
    'uploading',
    'uploading-progress',
    'failed',
    'failed-quota',
    'over-size',
    'over-count',
    'thread-image',
  ],
};

/// Every extension composer attachment case, keyed by id (3 themes each).
final Map<String, ParityCase> extComposerAttachmentCases = {
  for (final MapEntry(key: platform, value: kinds) in _kinds.entries)
    for (final kind in kinds)
      for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
        'components.composerattachments.$platform.$kind.$theme': _case(),
};
