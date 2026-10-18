import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/shared_draft_attachment.dart';
import 'package:raft_flutter/data/workspace_composer.dart';
import 'package:raft_flutter/data/workspace_domain_ports.dart';
import 'package:raft_flutter/data/workspace_editor.dart';
import 'package:raft_flutter/data/workspace_editor_entrypoints.dart';
import 'package:raft_flutter/data/workspace_sends.dart';
import 'package:raft_flutter/data/workspace_session_context.dart';
import 'package:raft_flutter/data/workspace_uploads.dart';

typedef _Warning = ({List<String> unresolved, bool agentStopped});
const _warning = (unresolved: ['fixture'], agentStopped: false);
RaftChannel _channel(String id) =>
    RaftChannel({'id': id, 'name': id, 'joined': true, 'type': 'channel'});

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://editor-domain.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    selectServer('s');
  }
  final uploads = <(String, String, String?)>[];
  final sent = <Map<String, dynamic>>[];
  final uploadEntered = Completer<void>();
  final sendEntered = Completer<void>();
  Completer<ComposerReceipt>? pendingReceipt;
  Map<String, dynamic> receipt = {};
  @override
  Future<List<Map<String, dynamic>>> upload(
    String channelId,
    Uint8List bytes,
    String filename, {
    UploadCancellation? cancellation,
    void Function(int, int)? onProgress,
    String? mimeType,
  }) async {
    uploads.add((channelId, filename, mimeType));
    onProgress?.call(bytes.length, bytes.length);
    if (!uploadEntered.isCompleted) uploadEntered.complete();
    return [
      {'id': 'uploaded', 'filename': filename},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> uploadStream(
    String channelId,
    Stream<List<int>> Function() openRead,
    int length,
    String filename, {
    UploadCancellation? cancellation,
    void Function(int, int)? onProgress,
    String? mimeType,
  }) async => upload(
    channelId,
    Uint8List.fromList(await openRead().expand((chunk) => chunk).toList()),
    filename,
    cancellation: cancellation,
    onProgress: onProgress,
    mimeType: mimeType,
  );

  @override
  Future<ComposerReceipt> sendWithReceipt(
    String channelId,
    String content, {
    List<String>? attachments,
    List<Map<String, dynamic>>? mentions,
    String? randomId,
    bool asTask = false,
    String? timezone,
  }) async {
    sent.add({
      'channelId': channelId,
      'content': content,
      'attachments': attachments,
      'mentions': mentions,
      'randomId': randomId,
      'asTask': asTask,
    });
    if (!sendEntered.isCompleted) sendEntered.complete();
    return pendingReceipt?.future ??
        Future.value((
          message: RaftMessage({
            'id': 'accepted',
            'channelId': channelId,
            'content': content,
            'seq': '82',
          }),
          receipt: receipt,
        ));
  }
}

/// Real draft/upload/send transactions. The fake only provides frozen domain
/// boundaries and the original virtual entrypoints chosen by the root.
class _Fixture extends Fake
    implements
        WorkspaceSessionContext,
        WorkspaceTransportPort,
        WorkspacePresentationReadPort,
        WorkspacePresentationWritePort,
        WorkspaceMessageRowsPort,
        WorkspaceWindowFactsPort,
        WorkspaceConversationCommandsPort,
        WorkspaceThreadCreationPort,
        WorkspaceChannelDirectoryPort,
        WorkspaceEditorEntrypoints {
  _Fixture({
    _Fixture? source,
    WorkspaceComposer? sharedComposer,
    RestoreSharedDraftAttachment? restore,
  }) {
    composer =
        sharedComposer ??
        WorkspaceComposer(
          owner: receiverKey,
          read: (kind, scope) async =>
              readHeld?.future ?? stored[(kind, scope)],
          write: (kind, scope, value, {required requiredSuccess}) async {
            trace.add('save:$kind:$scope:$requiredSuccess');
            stored[(kind, scope)] = value;
          },
          authority: () => (client.generation, client.serverId),
        );
    owner = WorkspaceEditor(
      context: this,
      transport: this,
      presentation: this,
      presentationWrites: this,
      messages: this,
      windows: this,
      conversations: this,
      threads: this,
      directory: this,
      composer: composer,
      entrypoints: this,
      presentationSource: source?.owner,
      restoreSharedAttachment: restore,
    );
    if (source != null) presentationAuthority = source.navigationAuthority;
    addTearDown(() async {
      await composer.flushed;
      composer.disposeOwnedBy(receiverKey);
      await client.dispose();
    });
  }
  late final WorkspaceEditor owner;
  late final WorkspaceComposer composer;
  final trace = <String>[];
  final revoked = <String>{};
  final stored = <(String, String), dynamic>{};
  final commandCalls = <(String, String, dynamic)>[];
  dynamic commandResult;
  Completer<dynamic>? readHeld;
  Future<void> Function(RaftChannel)? refreshing;
  Future<int?> Function()? limit;
  Future<String?> Function()? creatingThread;
  Map<String, String>? virtualDrafts;
  Map<String, String?>? virtualHolds;
  Map<String, _Warning>? virtualWarnings;
  Map<String, List<Map<String, dynamic>>>? virtualMentions;
  List<UploadDraft>? virtualUploads;
  String? virtualScope;
  bool? paused, blocked;
  void Function(String, bool)? saving;
  Map<String, Map<String, dynamic>>? mentionResults;
  @override
  final _Client client = _Client();
  @override
  final receiverKey = Object();
  @override
  bool disposed = false;
  @override
  RaftRecord? server = RaftRecord({'id': 's', 'role': 'owner'});
  @override
  RaftChannel? channel = _channel('c');
  @override
  String navigationAuthority = 'authority-1';
  @override
  String? presentationAuthority;
  @override
  int generation = 1;
  @override
  BigInt watermark = BigInt.from(80);
  @override
  bool hasNewer = false;
  @override
  String? threadParentMessageId, threadChannelId;
  int channelWindow = 1, threadWindow = 1;
  @override
  final channels = <RaftChannel>[];
  @override
  final dms = <RaftChannel>[];
  @override
  int windowGeneration(bool thread) => thread ? threadWindow : channelWindow;
  @override
  bool isChannelRevoked(String id) => revoked.contains(id);
  @override
  void changed() {
    owner.synchronizeVisits();
    trace.add('changed');
  }

  @override
  void assignError(String? value) => trace.add('error:$value');
  @override
  void setSelectedChannel(RaftChannel? value) {
    trace.add('select-row:${value?.id}');
    channel = value;
  }

  @override
  void recordRowWrite(String id) {
    expect(composer.drafts.containsKey('pending'), isFalse);
    trace.add('record:$id');
  }

  @override
  void putRow(RaftChannel row) {
    trace.add('put:${row.id}');
    dms.add(row);
  }

  @override
  Future<void> selectChannel(
    RaftChannel next, {
    bool autoRead = true,
    bool navigate = true,
    bool retainContextUntilAccepted = false,
    bool preserveThread = false,
    void Function()? onDraftRestored,
  }) async {
    trace.add('open:${next.id}:$autoRead');
    channelWindow++;
    await refreshing?.call(next);
  }

  @override
  Future<String?> ensureThread() async {
    trace.add('ensure-thread');
    return creatingThread == null ? 'thread-real' : creatingThread!();
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    commandCalls.add((method, path, data));
    return commandResult;
  }

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async => {
    'maxBytes': 1024,
  };
  @override
  Map<String, String> get drafts => virtualDrafts ?? owner.drafts;
  @override
  Map<String, String?> get shareHolds => virtualHolds ?? owner.shareHolds;
  @override
  Map<String, _Warning> get sendWarnings =>
      virtualWarnings ?? owner.sendWarnings;
  @override
  Map<String, List<Map<String, dynamic>>> get pendingMentionActions =>
      virtualMentions ?? owner.pendingMentionActions;
  @override
  bool get conversationPaused => paused ?? owner.conversationPaused;
  @override
  String? draftScope({bool thread = false}) => thread
      ? owner.draftScope(thread: true)
      : virtualScope ?? owner.draftScope();
  @override
  void saveDraft(String text, {bool thread = false}) => saving == null
      ? owner.saveDraft(text, thread: thread)
      : saving!(text, thread);
  @override
  List<UploadDraft> uploads({bool thread = false}) =>
      virtualUploads ?? owner.uploads(thread: thread);
  @override
  bool sharedBlocked({bool thread = false}) =>
      blocked ?? owner.sharedBlocked(thread: thread);
  @override
  Future<int?> uploadLimitBytes() =>
      limit == null ? owner.uploadLimitBytes() : limit!();
  @override
  Future<Map<String, Map<String, dynamic>>> executeMentionActionResults(
    String action,
    List<String> resolutionIds,
  ) async =>
      mentionResults ??
      await owner.executeMentionActionResults(action, resolutionIds);
}

void main() {
  test('draft access retains the original receiver ownership, not adapter identity', () {
    final root = _Fixture();
    root.composer.drafts['c'] = 'saved';
    root.server = null;
    expect(root.owner.drafts['c'], 'saved');
    final borrowed = _Fixture(sharedComposer: root.composer);
    expect(borrowed.owner.drafts['c'], 'saved');
    borrowed.server = null;
    expect(borrowed.owner.drafts, isEmpty);
    borrowed.server = RaftRecord({'id': 's'});
    borrowed.disposed = true;
    expect(borrowed.owner.drafts, isEmpty);
  });

  test('draft writes preserve virtual scope and draft-map calls', () async {
    final f = _Fixture()..virtualScope = 'virtual';
    f.virtualDrafts = {};
    f.owner.saveDraft('text');
    await f.composer.flushed;
    expect(f.virtualDrafts, {'virtual': 'text'});
    expect(f.composer.drafts, isEmpty);
    expect(f.trace, ['save:draft:virtual:false']);
    f.revoked.add('virtual');
    f.owner.saveDraft('denied');
    expect(f.virtualDrafts!['virtual'], 'text');
  });

  test('shared text updates use the original virtual save entrypoint', () {
    final f = _Fixture();
    f.saving = (text, thread) => f.trace.add('virtual-save:$text:$thread');
    f.owner.updateDraftFromShare('shared');
    expect(f.trace, ['virtual-save:shared:false', 'changed']);
    expect(f.composer.revisions['c'], 1);
  });

  test(
    'borrowed draft admission uses source authority and receiver scope',
    () async {
      final source = _Fixture();
      final page = _Fixture(source: source)..virtualScope = 'page-scope';
      page.owner.saveDraft('accepted');
      await source.composer.flushed;
      expect(source.composer.drafts, {'page-scope': 'accepted'});
      expect(page.composer.drafts, isEmpty);
      source.navigationAuthority = 'authority-2';
      page.owner.saveDraft('stale');
      expect(source.composer.drafts['page-scope'], 'accepted');
    },
  );

  test('source aliases retain the immediate public warning getter and private notice store', () {
    final root = _Fixture()..virtualWarnings = {'c': _warning};
    final middle = _Fixture(source: root)..virtualWarnings = {'c': _warning};
    final page = _Fixture(source: middle);
    page.owner.setComposerError('page notice');
    expect(page.owner.composerErrorFor(), 'page notice');
    expect(middle.owner.composerErrorFor(), isNull);
    expect(root.owner.composerErrorFor(), isNull);
    page.channel = _channel('next');
    page.changed();
    expect(middle.virtualWarnings, isEmpty);
    expect(root.virtualWarnings, {'c': _warning});
    page.channel = _channel('c');
    page.changed();
    expect(page.owner.composerErrorFor(), isNull);
  });

  test(
    'visits clear virtual warnings once and keep independent thread scope',
    () {
      final f = _Fixture()..virtualWarnings = {};
      f.threadParentMessageId = 'p';
      f.owner.setComposerError('main');
      f.owner.setComposerError('thread', thread: true);
      f.virtualWarnings!.addAll({'c': _warning, 'thread:p': _warning});
      f.channel = _channel('next');
      f.changed();
      expect(f.virtualWarnings!.keys, ['thread:p']);
      expect(f.owner.composerErrorFor(thread: true), 'thread');
      f.threadParentMessageId = null;
      f.changed();
      expect(f.virtualWarnings, isEmpty);
      f.channel = _channel('c');
      f.changed();
      expect(f.owner.composerErrorFor(), isNull);
    },
  );

  test(
    'upload readiness uses virtual rows while upload aliases remain immediate',
    () {
      final root = _Fixture(), middle = _Fixture();
      final page = _Fixture(source: middle);
      final file = UploadDraft('a.txt', Uint8List(1), key: 1);
      root.composer.uploads.byScope['c'] = [file];
      expect(page.owner.uploads(), isEmpty);
      middle.composer.uploads.byScope['c'] = [file];
      expect(page.owner.uploads(), [file]);
      page.virtualUploads = [file];
      expect(page.owner.uploadsReady(), isFalse);
      file.id = 'accepted';
      expect(page.owner.uploadsReady(), isTrue);
    },
  );

  test(
    'share holds keep a blocked notice until the destination check succeeds',
    () {
      final f = _Fixture();
      f.owner.holdShared('c');
      expect(f.owner.sharedBlocked(), isTrue);
      expect(f.owner.sharedBlocked(thread: true), isFalse);
      f.owner.blockShared('c', 'refused');
      f.owner.releaseShared('c');
      expect(f.owner.shareNoticeFor(), 'refused');
      f.virtualHolds = {'c': 'virtual'};
      expect(f.owner.shareNoticeFor(), 'virtual');
      f.virtualHolds = null;
      f.composer.uploads.holds['c'] = null;
      f.owner.releaseShared('c');
      expect(f.owner.sharedBlocked(), isFalse);
      expect(f.owner.shareNoticeFor(), isNull);
    },
  );

  test(
    'resolved DM moves the draft before row authority, selection and reopening',
    () async {
      final f = _Fixture()..channel = _channel('pending');
      f.composer.drafts['pending'] = 'keep';
      f.composer.uploads.holds['pending'] = null;
      final real = _channel('real');
      await f.owner.adoptResolvedDm('pending', real);
      expect(f.composer.drafts, {'real': 'keep'});
      expect(f.composer.uploads.holds.containsKey('real'), isTrue);
      expect(f.channel, same(real));
      expect(f.trace, [
        'save:draft:pending:false',
        'save:attempt:pending:false',
        'save:draft:real:false',
        'record:real',
        'select-row:real',
        'put:real',
        'changed',
        'open:real:false',
      ]);
    },
  );

  test('restoring a draft rejects an old message generation', () async {
    final f = _Fixture()..readHeld = Completer<dynamic>();
    final restoring = f.owner.restoreDraft('c');
    f.generation++;
    f.readHeld!.complete({'text': 'stale'});
    await restoring;
    expect(f.composer.drafts, isEmpty);
    expect(f.trace, isEmpty);
  });

  test('send retains watermark, immutable mentions, receipt maps and one existing observer', () async {
    final f = _Fixture();
    f.client.pendingReceipt = Completer<ComposerReceipt>();
    f.virtualWarnings = {};
    f.virtualMentions = {};
    var deliveryChanges = 0;
    f.composer.sends.attach(f.receiverKey, (_, _) => deliveryChanges++);
    final mentions = [
      {'id': 'member', 'type': 'user', 'name': 'Member', 'extra': true},
    ];
    final sending = f.owner.send(
      'hello',
      mentions: mentions,
      randomId: 'stable',
    );
    await f.client.sendEntered.future;
    final row = f.composer.sends.pending['c']!.single.row;
    expect(row.json['optimisticDisplaySeq'], '81');
    expect(f.client.sent.single['mentions'], [
      {'type': 'user', 'id': 'member', 'name': 'Member'},
    ]);
    expect(
      () => (f.client.sent.single['mentions'] as List).first['id'] = 'changed',
      throwsUnsupportedError,
    );
    expect(f.trace.where((v) => v == 'changed'), isEmpty);
    f.client.pendingReceipt!.complete((
      message: RaftMessage({'id': 'accepted', 'channelId': 'c'}),
      receipt: {
        'pendingMentionActions': [
          {
            'resolutionId': 'resolution',
            'targetType': 'user',
            'availableActions': ['notify'],
          },
          {'resolutionId': 'invalid'},
        ],
        'unresolvedMentionHandles': ['missing', 4],
        'deliveryWarnings': [
          {
            'targetType': 'agent',
            'reason': 'agent_stopped',
            'targetId': 'agent',
          },
        ],
      },
    ));
    expect(await sending, isTrue);
    expect(f.virtualMentions!['c']!.single['resolutionId'], 'resolution');
    expect(f.virtualWarnings!['c']!.unresolved, ['missing']);
    expect(f.virtualWarnings!['c']!.agentStopped, isTrue);
    expect(f.owner.pendingMentionActions, isEmpty);
    expect(f.owner.sendWarnings, isEmpty);
    expect(deliveryChanges, 2);
  });

  test('send refreshes the window before admission and preserves its new generation', () async {
    final f = _Fixture()..hasNewer = true;
    final refreshed = Completer<void>();
    f.refreshing = (_) => refreshed.future;
    final sending = f.owner.send(
      'refresh',
      onWindowRefreshed: (window) => f.trace.add('refreshed:$window'),
    );
    expect(f.trace, ['error:null', 'open:c:true']);
    expect(f.client.sent, isEmpty);
    refreshed.complete();
    expect(await sending, isTrue);
    expect(
      f.trace.indexOf('refreshed:2'),
      greaterThan(f.trace.indexOf('open:c:true')),
    );
    expect(f.client.sent.single['channelId'], 'c');
  });

  test(
    'role change during refresh blocks the raw send and restores the draft',
    () async {
      final f = _Fixture()..hasNewer = true;
      final refreshed = Completer<void>();
      f.refreshing = (_) => refreshed.future;
      final sending = f.owner.send('do not send');
      f.server = RaftRecord({'id': 's', 'role': 'guest'});
      refreshed.complete();
      expect(await sending, isFalse);
      expect(f.client.sent, isEmpty);
      expect(f.composer.drafts['c'], 'do not send');
    },
  );

  test(
    'virtual conversion and share checks block sends before transport',
    () async {
      final f = _Fixture()..paused = true;
      expect(await f.owner.send('paused'), isFalse);
      expect(f.trace, ['error:Channel conversion in progress', 'changed']);
      f.paused = false;
      f.blocked = true;
      f.trace.clear();
      expect(await f.owner.send('held'), isFalse);
      expect(f.trace, isEmpty);
      expect(f.client.sent, isEmpty);
    },
  );

  test('thread sends create the destination without replacing the parent draft scope', () async {
    final f = _Fixture()..threadParentMessageId = 'parent';
    expect(await f.owner.send('reply', thread: true), isTrue);
    expect(f.client.sent.single['channelId'], 'thread-real');
    expect(f.trace, contains('ensure-thread'));
    expect(f.stored[('attempt', 'thread:parent')], isNull);
  });

  test(
    'upload admission uses virtual limits and rejects a changed authority',
    () async {
      final f = _Fixture();
      final checking = Completer<int?>();
      f.limit = () => checking.future;
      final attaching = f.owner.attachSelection([
        (name: 'image.png', bytes: Uint8List.fromList([1, 2])),
      ], text: (key, _) => key);
      expect(f.owner.uploads().single.checking, isTrue);
      f.server = RaftRecord({'id': 's', 'role': 'guest'});
      checking.complete(1024);
      await attaching;
      expect(f.client.uploads, isEmpty);
      expect(f.owner.uploads().single.canRetry, isFalse);
    },
  );

  test('accepted in-memory upload keeps raw-client MIME and removal', () async {
    final f = _Fixture();
    var checked = 0;
    f.limit = () async {
      checked++;
      return 1024;
    };
    await f.owner.attachSelection([
      (name: 'image.png', bytes: Uint8List.fromList([1, 2])),
    ], text: (key, _) => key);
    expect(checked, 1);
    expect(f.client.uploads, [('c', 'image.png', 'image/png')]);
    final file = f.owner.uploads().single;
    expect(file.id, 'uploaded');
    expect(f.owner.uploadsReady(), isTrue);
    f.owner.removeUpload(file);
    await f.composer.flushed;
    expect(f.owner.uploads(), isEmpty);
    expect(f.trace, isEmpty);
  });

  test('queued local files retain required persistence, transfer and release ordering', () async {
    final f = _Fixture();
    var released = 0, checked = 0;
    f.limit = () async {
      checked++;
      return 1024;
    };
    final file = SharedDraftAttachment(
      reference: {'id': 'local'},
      filename: 'shared.png',
      mimeType: 'image/png',
      sizeBytes: 2,
      openRead: () => Stream.value([1, 2]),
      release: () async {
        released++;
      },
    );
    await f.owner.stageSharedDraft('shared', [file], sourceToken: 'handoff');
    expect(f.composer.shareTokens['c'], {'handoff'});
    expect(f.trace, contains('save:draft:c:true'));
    expect(await f.owner.send('shared', randomId: 'queued'), isTrue);
    await f.composer.flushed;
    expect(checked, 1);
    expect(f.client.uploads, [('c', 'shared.png', 'image/png')]);
    expect(f.client.sent.single['attachments'], ['uploaded']);
    expect(released, 1);
    expect(f.owner.uploads(), isEmpty);
  });

  test(
    'mention execution retains virtual results and raw command parsing',
    () async {
      final f = _Fixture();
      f.mentionResults = {
        'yes': {'status': 'queued'},
        'no': {'status': 'delivered'},
      };
      expect(await f.owner.executeMentionActions('notify', ['yes', 'no']), {
        'yes',
      });
      expect(f.commandCalls, isEmpty);
      f.mentionResults = null;
      f.commandResult = {
        'results': [
          {'resolutionId': 'real', 'status': 'delivered'},
          {'status': 'ignored'},
        ],
      };
      expect(await f.owner.executeMentionActions('add', ['real']), {'real'});
      expect(f.commandCalls.single.$1, 'POST');
      expect(f.commandCalls.single.$2, '/messages/mention-actions/execute');
      expect(f.commandCalls.single.$3, {
        'action': 'add',
        'resolutionIds': ['real'],
      });
    },
  );
}
