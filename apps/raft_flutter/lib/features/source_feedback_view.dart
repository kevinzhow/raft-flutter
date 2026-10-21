import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart' show DioMediaType, FormData, MultipartFile;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/file_selection.dart';

import '../data/source_feedback_store.dart';
import '../data/workspace_controller.dart';
import 'feedback_attachment_preview.dart';
import 'management_support.dart'
    show pageIdentity, readPageSnapshot, writePageSnapshot;

/// `GET /product-feedback/tickets/:id/attachments/:id`.
typedef FeedbackAttachmentLoader = Future<Uint8List> Function(
  String ticketId,
  String attachmentId,
);

/// Picks image attachments (the Web `<input type=file accept=...>`).
typedef FeedbackFilePicker = Future<List<SourceFeedbackFile>> Function();

const _imageTypes = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
};

/// The host picker restricted to FEEDBACK_ATTACHMENT_TYPES. Files over the
/// size limit are not read; the store reports them by name.
Future<List<SourceFeedbackFile>> pickFeedbackImages() async {
  final files = await selectImages(
    typeGroup: XTypeGroup(
      label: 'Images',
      extensions: _imageTypes.keys.toList(),
      mimeTypes: _imageTypes.values.toSet().toList(),
      uniformTypeIdentifiers: ['public.image'],
    ),
  );
  final picked = <SourceFeedbackFile>[];
  for (final file in files) {
    final extension = file.name.split('.').last.toLowerCase();
    final type = file.mimeType ?? _imageTypes[extension] ?? '';
    final size = await file.length();
    picked.add(
      SourceFeedbackFile(
        name: file.name,
        contentType: type,
        declaredSize: size,
        bytes: size > sourceFeedbackMaxAttachmentBytes
            ? Uint8List(0)
            : await file.readAsBytes(),
      ),
    );
  }
  return picked;
}

/// Account-owned My Feedback workspace: inbox, New feedback, the ticket
/// conversation with its reply composer, and Close ticket.
class SourceFeedbackView extends StatefulWidget {
  const SourceFeedbackView({
    super.key,
    required this.controller,
    this.onUnreadChanged,
    this.initialTicketId,
  });
  final WorkspaceController controller;
  final ValueChanged<int>? onUnreadChanged;

  /// `/settings/feedback/ticket/:id` deep link (the Report Issue dialog's
  /// "View ticket"): the ticket opens once the inbox is read.
  final String? initialTicketId;
  @override
  State<SourceFeedbackView> createState() => _SourceFeedbackViewState();
}

class _SourceFeedbackViewState extends State<SourceFeedbackView> {
  late SourceFeedbackStore store;
  StreamSubscription<RaftEvent>? session;

  /// The inbox's first page as the last visit accepted it (this session, in
  /// memory): painted at the first frame while the store's own read runs, so
  /// a revisit shows rows instead of a skeleton.
  static const _inboxKey = 'feedback:inbox';
  List<SourceFeedbackTicket> seed = const [];
  List<SourceFeedbackTicket> _remembered = const [];

  void rememberInbox() {
    if (!store.authorized || store.listLoading || store.listError != null) {
      return;
    }
    final rows = store.tickets.take(20).toList(growable: false);
    if (rows.length == _remembered.length &&
        [
          for (var i = 0; i < rows.length; i++)
            identical(rows[i], _remembered[i]),
        ].every((same) => same)) {
      return;
    }
    _remembered = rows;
    writePageSnapshot(
      widget.controller,
      _inboxKey,
      pageIdentity(widget.controller),
      {'tickets': rows},
    );
  }

  /// Account/server identity only: the inbox survives channel switches and
  /// thread opens (Source feedback store is account-owned).
  String? authority() {
    final w = widget.controller;
    final user = w.client.user;
    if (user == null) return null;
    return jsonEncode([
      w.client.origin,
      user.id,
      w.client.serverId,
      w.server?.id,
      w.server?.string('role'),
      w.client.generation,
    ]);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      return await widget.controller.client.get(path, query: query);
    } on RaftApiException catch (e) {
      throw SourceFeedbackFailure(
        sourceFeedbackErrorFor(e.details['code'] as String?, e.status),
      );
    }
  }

  /// handsFeedbackTransport writes: multipart `FormData` (fields +
  /// `attachments`) or JSON, upload progress capped below 1 until the
  /// response, and cancellation tied to the store's abort handle.
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? json,
    SourceFeedbackForm? form,
    ValueChanged<double>? onProgress,
    SourceFeedbackAbort? abort,
  }) async {
    final cancellation = UploadCancellation();
    abort?.onAbort(cancellation.cancel);
    Object? data = json;
    if (form != null) {
      final body = FormData();
      for (final MapEntry(:key, :value) in form.fields.entries) {
        body.fields.add(MapEntry(key, value));
      }
      for (final file in form.attachments) {
        body.files.add(
          MapEntry(
            'attachments',
            MultipartFile.fromBytes(
              file.bytes,
              filename: file.name,
              contentType: DioMediaType.parse(file.contentType),
            ),
          ),
        );
      }
      data = body;
    }
    try {
      final result = await widget.controller.client.request(
        'POST',
        path,
        data: data,
        cancellation: cancellation,
        onSendProgress: onProgress == null
            ? null
            : (sent, total) {
                if (total > 0) onProgress(math.min(.99, sent / total));
              },
      );
      onProgress?.call(1);
      return result;
    } on RaftApiException catch (e) {
      throw SourceFeedbackFailure(
        sourceFeedbackErrorFor(e.details['code'] as String?, e.status),
      );
    }
  }

  void bind() {
    store = SourceFeedbackStore(
      get: get,
      post: post,
      newId: widget.controller.client.newRandomId,
      authority: authority,
      onUnreadChanged: (count) {
        if (mounted && store.authorized) widget.onUnreadChanged?.call(count);
      },
    );
    final cached = readPageSnapshot(widget.controller, _inboxKey)?['tickets'];
    seed = cached is List<SourceFeedbackTicket> ? cached : const [];
    _remembered = seed;
    store.addListener(rememberInbox);
    widget.controller.addListener(changed);
    session = widget.controller.client.events.listen((_) => changed());
    final ticket = widget.initialTicketId;
    unawaited(
      store.loadList().then((_) {
        if (mounted && ticket != null) return store.openTicket(ticket);
      }),
    );
  }

  void changed() {
    if (!mounted) return;
    if (store.syncAuthority()) {
      // Another account/server/role: the previous page is not its inbox.
      setState(() => seed = const []);
      _remembered = const [];
      unawaited(store.loadList());
    }
  }

  @override
  void initState() {
    super.initState();
    bind();
  }

  @override
  void didUpdateWidget(SourceFeedbackView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(changed);
      unawaited(session?.cancel());
      store.removeListener(rememberInbox);
      store.dispose();
      bind();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    unawaited(session?.cancel());
    store.removeListener(rememberInbox);
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SourceFeedbackProjectionView(
    store: store,
    pickFiles: pickFeedbackImages,
    inboxSeed: seed,
    loadAttachment: (ticketId, attachmentId) =>
        widget.controller.client.getBytes(
          '/product-feedback/tickets/${Uri.encodeComponent(ticketId)}'
          '/attachments/${Uri.encodeComponent(attachmentId)}',
        ),
  );
}

String _status(String status, String? closure) => switch (status) {
  'in_progress' => 'In progress',
  'resolved' => 'Resolved',
  // FeedbackStatusChip: closed as completed reads Resolved.
  'closed' when closure == 'completed' => 'Resolved',
  'closed' => 'Closed',
  _ => 'Open',
};

String? _reason(String? reason) => switch (reason) {
  'completed' => 'Completed',
  'no_longer_needed' => 'No longer needed',
  'not_planned' => 'Not planned',
  'cannot_reproduce' => 'Cannot reproduce',
  'duplicate' => 'Duplicate',
  _ => null,
};

/// useSafeError: the closed transport error set, never server text.
String _errorCopy(SourceFeedbackError error) => switch (error) {
  SourceFeedbackError.unavailable => "Couldn't load feedback. Try again.",
  SourceFeedbackError.unauthorized =>
    'Your feedback session expired. Reopen feedback and try again.',
  SourceFeedbackError.notFound =>
    'This feedback ticket is no longer available.',
  SourceFeedbackError.rateLimited =>
    'Too many feedback requests. Try again later.',
  SourceFeedbackError.conflict =>
    'This retry no longer matches the original request.',
  SourceFeedbackError.invalid => 'Check the feedback details and try again.',
};

String _problemCopy(BuildContext context, SourceFeedbackProblem problem) =>
    switch (problem.attachment) {
      null => raftText(context, _errorCopy(problem.error!)),
      SourceFeedbackAttachmentIssue.tooMany => raftFormat(
        context,
        'Choose no more than {count} screenshots.',
        {'count': sourceFeedbackMaxAttachments},
      ),
      SourceFeedbackAttachmentIssue.unsupported => raftFormat(
        context,
        '{name} is not a supported image.',
        {'name': problem.name},
      ),
      SourceFeedbackAttachmentIssue.tooLarge => raftFormat(
        context,
        '{name} is larger than 10 MB.',
        {'name': problem.name},
      ),
    };

String _announcement(SourceFeedbackAnnouncement value) => switch (value) {
  SourceFeedbackAnnouncement.created => 'Feedback created',
  SourceFeedbackAnnouncement.replySent => 'Reply sent',
  SourceFeedbackAnnouncement.closed => 'Ticket closed',
  SourceFeedbackAnnouncement.uploadCanceled => 'Upload canceled',
};

RaftFeedbackCloseReason _closeReason(SourceFeedbackCloseReason reason) =>
    reason == SourceFeedbackCloseReason.completed
    ? RaftFeedbackCloseReason.completed
    : RaftFeedbackCloseReason.noLongerNeeded;

SourceFeedbackCloseReason _sourceReason(RaftFeedbackCloseReason reason) =>
    reason == RaftFeedbackCloseReason.completed
    ? SourceFeedbackCloseReason.completed
    : SourceFeedbackCloseReason.noLongerNeeded;

List<RaftFeedbackPendingFile> _pending(List<SourceFeedbackPending> items) => [
  for (final item in items)
    RaftFeedbackPendingFile(
      id: item.id,
      name: item.file.name,
      contentType: item.file.contentType,
      bytes: item.file.bytes.isEmpty ? null : item.file.bytes,
      progress: item.progress,
      state: switch (item.state) {
        SourceFeedbackUploadState.ready => RaftFeedbackUploadState.ready,
        SourceFeedbackUploadState.uploading =>
          RaftFeedbackUploadState.uploading,
        SourceFeedbackUploadState.failed => RaftFeedbackUploadState.failed,
      },
    ),
];

// Original provider.js16–20 formats new Date(number): epoch milliseconds,
// local timezone, medium date (including year), short localized time.
bool _dateSymbolsReady = false;
String _date(BuildContext context, int milliseconds) {
  if (!_dateSymbolsReady) {
    // intl's local provider installs its bundled symbol tables synchronously;
    // the returned completed Future performs no network or file operations.
    unawaited(initializeDateFormatting());
    _dateSymbolsReady = true;
  }
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  // Intl.DateTimeFormat(dateStyle medium, timeStyle short): en joins the
  // date and time with ", " ("Oct 3, 2026, 10:00 AM").
  // Chromium's Intl separates the time and day period with a plain space.
  return (zh
          ? DateFormat.yMMMd('zh_CN').add_jm().format(value)
          : '${DateFormat.yMMMd('en').format(value)}, '
                '${DateFormat.jm('en').format(value)}')
      .replaceAll('\u202f', ' ');
}

String _size(int bytes) => '${(bytes / 1024).ceil()} kB';

/// Transport-independent presentation of [SourceFeedbackStore] (widget
/// tests drive it with fake transports). The Settings host supplies the
/// "Feedback" panel header above it; the workspace is raft_ui's hands-feedback
/// port (inbox, New feedback form, ticket conversation, close dialog).
class SourceFeedbackProjectionView extends StatefulWidget {
  const SourceFeedbackProjectionView({
    super.key,
    required this.store,
    this.pickFiles,
    this.inboxSeed = const [],
    this.loadAttachment,
  });
  final SourceFeedbackStore store;
  final FeedbackFilePicker? pickFiles;

  /// Reads a ticket's attachment with the session (Web `openAttachment`);
  /// without it the sent attachments stay plain rows.
  final FeedbackAttachmentLoader? loadAttachment;

  /// The previous visit's first inbox page, shown instead of the skeleton
  /// until the store's own read lands.
  final List<SourceFeedbackTicket> inboxSeed;

  @override
  State<SourceFeedbackProjectionView> createState() =>
      _SourceFeedbackProjectionViewState();
}

class _SourceFeedbackProjectionViewState
    extends State<SourceFeedbackProjectionView>
    with WidgetsBindingObserver {
  final newMessage = TextEditingController();
  final reply = TextEditingController();
  final replyFocus = FocusNode();
  final newFocus = FocusNode();
  SourceFeedbackRoute? route;
  String? ticket;
  int announced = 0;
  bool dialogOpen = false;

  SourceFeedbackStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.addListener(sync);
    announced = store.announcementRevision;
    sync();
  }

  @override
  void didUpdateWidget(SourceFeedbackProjectionView old) {
    super.didUpdateWidget(old);
    if (old.store != widget.store) {
      old.store.removeListener(sync);
      widget.store.addListener(sync);
      announced = widget.store.announcementRevision;
      sync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(sync);
    newMessage.dispose();
    reply.dispose();
    replyFocus.dispose();
    newFocus.dispose();
    super.dispose();
  }

  /// FeedbackTicket refreshes on window focus.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        store.route == SourceFeedbackRoute.ticket) {
      unawaited(store.loadDetail());
    }
  }

  void _setText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  /// Store -> controllers, the dialog route and announcements.
  void sync() {
    if (!mounted) return;
    final nextRoute = store.route;
    final opened = nextRoute != route || store.selectedId != ticket;
    route = nextRoute;
    ticket = store.selectedId;
    _setText(newMessage, store.newMessage);
    _setText(reply, store.reply);
    if (opened && nextRoute == SourceFeedbackRoute.create) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && store.route == SourceFeedbackRoute.create) {
          newFocus.requestFocus();
        }
      });
    }
    if (store.announcementRevision != announced) {
      announced = store.announcementRevision;
      final value = store.announcement;
      if (value != null) {
        final view = View.maybeOf(context);
        if (view != null) {
          unawaited(
            SemanticsService.sendAnnouncement(
              view,
              raftText(context, _announcement(value)),
              Directionality.of(context),
            ),
          );
        }
        if (value == SourceFeedbackAnnouncement.replySent) {
          replyFocus.requestFocus();
        }
      }
    }
    if (store.closeRequest != null && !dialogOpen) {
      dialogOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showClose());
    } else if (store.closeRequest == null && dialogOpen) {
      dialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _showClose() async {
    if (!mounted || store.closeRequest == null) {
      dialogOpen = false;
      return;
    }
    await showRaftDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final request = store.closeRequest;
          final error = store.closeError;
          return RaftFeedbackCloseDialog(
            reason: _closeReason(
              request?.reason ?? SourceFeedbackCloseReason.noLongerNeeded,
            ),
            busy: store.closing,
            error: error == null ? null : raftText(context, _errorCopy(error)),
            onCancel: store.dismissClose,
            onConfirm: () => unawaited(store.confirmClose()),
          );
        },
      ),
    );
  }

  int _previewRequest = 0;

  /// Web `openAttachment`: the screenshot is read with the session, then
  /// shown in the lightbox; a failure says so and shows nothing. The latest
  /// tap wins, and an answer for another account or screen is dropped.
  Future<void> _openSent(String ticketId, SourceFeedbackAttachment file) async {
    final request = ++_previewRequest;
    try {
      if (file.id.isEmpty) throw const RaftApiException('No attachment id');
      final bytes = await widget.loadAttachment!(ticketId, file.id);
      if (!mounted || request != _previewRequest || !store.authorized) return;
      await showFeedbackImage(
        context,
        filename: file.filename,
        contentType: file.contentType,
        bytes: bytes,
      );
    } catch (_) {
      if (mounted && request == _previewRequest && store.authorized) {
        showRaftToast(
          context,
          'The attachment could not be opened. Try again.',
        );
      }
    }
  }

  /// Web `openPendingAttachment`: a picked screenshot, before it is sent.
  void _openPending(String id) {
    _previewRequest++;
    for (final item in [...store.newAttachments, ...store.replyAttachments]) {
      if (item.id != id || item.file.bytes.isEmpty) continue;
      unawaited(
        showFeedbackImage(
          context,
          filename: item.file.name,
          contentType: item.file.contentType,
          bytes: item.file.bytes,
        ),
      );
      return;
    }
  }

  Future<void> _attach({required bool reply}) async {
    final picker = widget.pickFiles;
    if (picker == null) return;
    final files = await picker();
    if (!mounted || files.isEmpty) return;
    if (reply) {
      store.addReplyAttachments(files);
    } else {
      store.addNewAttachments(files);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final route = store.route;
      return PopScope(
        canPop: route == SourceFeedbackRoute.inbox,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (route == SourceFeedbackRoute.create) {
            store.cancelNew();
          } else {
            store.back();
          }
        },
        child: !store.authorized
            ? Center(
                child: Text(
                  raftText(
                    context,
                    _errorCopy(SourceFeedbackError.unauthorized),
                  ),
                ),
              )
            : switch (route) {
                SourceFeedbackRoute.inbox => _inbox(context),
                SourceFeedbackRoute.create => _create(context),
                SourceFeedbackRoute.ticket => _ticket(context),
              },
      );
    },
  );

  bool _matches(SourceFeedbackTicket t, SourceFeedbackFilter filter) =>
      switch (filter) {
        SourceFeedbackFilter.all => true,
        SourceFeedbackFilter.open =>
          t.status == 'open' || t.status == 'in_progress',
        SourceFeedbackFilter.resolved =>
          t.status == 'resolved' || t.status == 'closed',
      };

  Widget _inbox(BuildContext context) {
    // Nothing accepted yet but the previous visit's page is known: show it
    // while the first read runs (no skeleton, no jump when rows are replaced).
    final seeded =
        store.tickets.isEmpty &&
        store.listLoading &&
        store.listError == null &&
        widget.inboxSeed.isNotEmpty;
    List<SourceFeedbackTicket> ticketsFor(SourceFeedbackFilter filter) => seeded
        ? [
            for (final t in widget.inboxSeed)
              if (_matches(t, filter)) t,
          ]
        : store.ticketsForFilter(filter);
    final rows = ticketsFor(store.filter);
    return RaftFeedbackInbox(
      key: ValueKey((store, store.authority())),
      headerAction: store.canWrite
          ? RaftFeedbackHeaderButton(
              key: const ValueKey('feedback-new'),
              label: 'New feedback',
              onPressed: store.startNew,
            )
          : RaftIconButton(
              glyph: RaftGlyph.refreshCw,
              tooltip: raftText(context, 'Refresh'),
              onPressed: store.listLoading
                  ? null
                  : () => unawaited(store.loadList()),
            ),
      anyTickets: seeded || store.tickets.isNotEmpty,
      filter: switch (store.filter) {
        SourceFeedbackFilter.all => RaftFeedbackFilter.all,
        SourceFeedbackFilter.open => RaftFeedbackFilter.active,
        SourceFeedbackFilter.resolved => RaftFeedbackFilter.ended,
      },
      onFilter: (value) => store.setFilter(switch (value) {
        RaftFeedbackFilter.all => SourceFeedbackFilter.all,
        RaftFeedbackFilter.active => SourceFeedbackFilter.open,
        RaftFeedbackFilter.ended => SourceFeedbackFilter.resolved,
      }),
      loading: store.listLoading && !seeded,
      error: store.listError == null
          ? null
          : raftText(context, _errorCopy(store.listError!)),
      onRetry: () => unawaited(store.loadList(retry: true)),
      onOpen: (id) => unawaited(store.openTicket(id)),
      onLoadMore: store.nextCursor != null && !store.listLoading
          ? () => unawaited(store.loadList(more: true))
          : null,
      onClose: store.canWrite
          ? (id, reason) => store.requestClose(id, _sourceReason(reason))
          : null,
      closeDisabled: store.closing,
      ticketsForFilter: (value) => feedbackRows(
        context,
        ticketsFor(switch (value) {
          RaftFeedbackFilter.all => SourceFeedbackFilter.all,
          RaftFeedbackFilter.active => SourceFeedbackFilter.open,
          RaftFeedbackFilter.ended => SourceFeedbackFilter.resolved,
        }),
      ),
      tickets: feedbackRows(context, rows),
    );
  }

  List<RaftFeedbackTicketRow> feedbackRows(
    BuildContext context,
    List<SourceFeedbackTicket> rows,
  ) => [
    for (final ticket in rows)
      RaftFeedbackTicketRow(
        id: ticket.id,
        // User content: first line only, never a dictionary lookup.
        title: ticket.title,
        date: _date(context, ticket.updatedAt),
        problem: ticket.kind != 'feedback',
        status: switch (_status(ticket.status, ticket.closureReason)) {
          'In progress' => RaftFeedbackStatus.inProgress,
          'Resolved' => RaftFeedbackStatus.resolved,
          'Closed' => RaftFeedbackStatus.closed,
          _ => RaftFeedbackStatus.open,
        },
        unreadLabel: ticket.unread ? ticket.badgeLabel : null,
        unreadSemantics: ticket.unread
            ? raftFormat(context, '{count} unread', {
                'count': ticket.badgeCount,
              })
            : null,
        closeReason: ticket.status == 'closed'
            ? null
            : _closeReason(SourceFeedbackCloseReason.defaultFor(ticket.status)),
      ),
  ];

  Widget _create(BuildContext context) {
    final sending = store.newSending;
    final failed = store.newAttachments.any(
      (a) => a.state == SourceFeedbackUploadState.failed,
    );
    return RaftFeedbackNewForm(
      onBack: store.back,
      problem: store.newKind == 'bug',
      onKind: (problem) => store.setNewKind(problem ? 'bug' : 'feedback'),
      composer: RaftFeedbackComposer(
        controller: newMessage,
        focusNode: newFocus,
        inputKey: const ValueKey('feedback-new-message'),
        label: 'What would you like us to know?',
        placeholder: 'Describe your idea or the bug you ran into…',
        newFeedback: true,
        onChanged: store.setNewMessage,
        attachments: _pending(store.newAttachments),
        onRemoveAttachment: store.removeNewAttachment,
        onOpenAttachment: _openPending,
        onAttachImage: () => unawaited(_attach(reply: false)),
        onAttachFile: () => unawaited(_attach(reply: false)),
        busy: sending,
        error: store.newError == null
            ? null
            : _problemCopy(context, store.newError!),
        actions: [
          RaftRecipeButton(
            key: const ValueKey('feedback-new-cancel'),
            label: 'Cancel',
            variant: RaftButtonRecipeVariant.ghost,
            size: RaftButtonRecipeSize.sm,
            onPressed: store.cancelNew,
          ),
          RaftRecipeButton(
            key: const ValueKey('feedback-new-submit'),
            glyph: RaftGlyph.send,
            label: sending
                ? 'Submitting…'
                : failed
                ? 'Retry upload'
                : 'Submit',
            variant: RaftButtonRecipeVariant.accent,
            size: RaftButtonRecipeSize.sm,
            disabled: !store.canSubmitNew,
            onPressed: () => unawaited(store.submitNew()),
          ),
        ],
      ),
    );
  }

  Widget _ticket(BuildContext context) {
    final ticket = store.detail;
    final writable = store.canWrite;
    final sending = store.replySending;
    String sender(String author) => switch (author) {
      'reporter' => 'You',
      'staff' => 'Team',
      _ => 'Update',
    };
    RaftFeedbackAuthor author(String value) => switch (value) {
      'reporter' => RaftFeedbackAuthor.reporter,
      'staff' => RaftFeedbackAuthor.staff,
      _ => RaftFeedbackAuthor.system,
    };
    final reason = _reason(ticket?.closureReason);
    return RaftFeedbackConversation(
      key: ValueKey('feedback-detail-${store.selectedId}'),
      onBack: store.back,
      loading: store.detailLoading && ticket == null,
      error: store.detailError == null
          ? null
          : raftText(context, _errorCopy(store.detailError!)),
      onRetry: () => unawaited(store.loadDetail(retry: true)),
      onLoadMore: store.nextCommentCursor != null && !store.detailLoading
          ? () => unawaited(store.loadDetail(more: true))
          : null,
      messages: [
        if (ticket != null)
          RaftFeedbackMessageData(
            id: ticket.id,
            author: RaftFeedbackAuthor.reporter,
            sender: 'You',
            time: _date(context, ticket.createdAt),
            body: ticket.message,
            attachments: [
              for (final attachment in store.attachments)
                (attachment.filename, _size(attachment.size)),
            ],
            onOpenAttachment: widget.loadAttachment == null
                ? null
                : (index) =>
                      unawaited(_openSent(ticket.id, store.attachments[index])),
            footer: [
              RaftFeedbackKindChip(problem: ticket.kind != 'feedback'),
              RaftFeedbackStatusBadge(
                status: switch (_status(ticket.status, ticket.closureReason)) {
                  'In progress' => RaftFeedbackStatus.inProgress,
                  'Resolved' => RaftFeedbackStatus.resolved,
                  'Closed' => RaftFeedbackStatus.closed,
                  _ => RaftFeedbackStatus.open,
                },
              ),
              if (reason != null) RaftFeedbackClosureReason(reason),
              if (writable && ticket.status != 'closed')
                RaftFeedbackCloseSplit(
                  defaultReason: _closeReason(
                    SourceFeedbackCloseReason.defaultFor(ticket.status),
                  ),
                  disabled: store.closing,
                  onChoose: (reason) =>
                      store.requestClose(ticket.id, _sourceReason(reason)),
                ),
            ],
          ),
        for (final comment in store.comments)
          RaftFeedbackMessageData(
            id: comment.id,
            author: author(comment.authorType),
            sender: sender(comment.authorType),
            time: _date(context, comment.createdAt),
            body: comment.body,
          ),
      ],
      composer: !writable || ticket == null || ticket.status == 'closed'
          ? null
          : RaftFeedbackComposer(
              controller: reply,
              focusNode: replyFocus,
              inputKey: const ValueKey('feedback-reply-input'),
              label: 'Reply',
              placeholder: 'Write a reply…',
              onChanged: store.setReply,
              onSubmit: () => unawaited(store.sendReply()),
              attachments: _pending(store.replyAttachments),
              onRemoveAttachment: store.removeReplyAttachment,
              onOpenAttachment: _openPending,
              onAttachImage: () => unawaited(_attach(reply: true)),
              onAttachFile: () => unawaited(_attach(reply: true)),
              busy: sending,
              error: store.actionError == null
                  ? null
                  : _problemCopy(context, store.actionError!),
              actions: [
                RaftRecipeButton(
                  key: const ValueKey('feedback-reply-send'),
                  glyph: RaftGlyph.send,
                  glyphSize: 14,
                  tooltip: raftText(
                    context,
                    sending ? 'Sending…' : 'Send reply',
                  ),
                  variant: RaftButtonRecipeVariant.accent,
                  size: RaftButtonRecipeSize.iconSm,
                  disabled: !store.canSendReply,
                  onPressed: () => unawaited(store.sendReply()),
                ),
              ],
            ),
    );
  }
}
