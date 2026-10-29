import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/incoming_share_targets.dart';
import '../platform/incoming_share_inbox.dart' show IncomingShareFailureReason;
import '../platform/incoming_share_staging.dart';
import '../platform/native_sharing.dart' show IncomingSharedFile;
import 'forward_composer_page.dart' show forwardTargetIcon;

/// How the page shows a copy that is still running when the user is ready.
///
/// Both styles turn Continue into a progress block with Cancel when it is
/// pressed before the copy finished; they differ in what the file card shows
/// before that. One constant so the other option is a one-word change.
enum IncomingShareWaitStyle {
  /// Option B: each file chip of "Add shared content" carries its own progress
  /// bar and error, and Continue stays available.
  card,

  /// Option A: chips stay plain; only Continue shows progress.
  button,
}

const incomingShareWaitStyle = IncomingShareWaitStyle.card;

class IncomingSharePicker extends StatefulWidget {
  const IncomingSharePicker({
    super.key,
    required this.client,
    required this.servers,
    required this.onContinue,
    required this.valid,
    this.initialServer,
    this.staging,
    this.cachedTargets,
  });
  final RaftClient client;
  final List<RaftRecord> servers;
  final String? initialServer;
  final bool Function() valid;
  final Future<void> Function(RaftRecord, IncomingShareTarget) onContinue;

  /// Background copy of the shared files. The picker shows its per-item
  /// progress and closes if the copy fails; null when nothing is copied.
  final IncomingShareStaging? staging;

  /// Device-cached destinations painted before the network answers. A seed is
  /// only ever shown: it is replaced by the fresh directory, and hand-off
  /// waits for that revalidation before it adds anything.
  final FutureOr<List<IncomingShareTarget>?> Function(RaftRecord server)?
  cachedTargets;
  @override
  State<IncomingSharePicker> createState() => _IncomingSharePickerState();
}

class _IncomingSharePickerState extends State<IncomingSharePicker> {
  RaftRecord? server;
  late List<RaftRecord> servers = widget.servers;
  StreamSubscription<RaftEvent>? events;
  IncomingShareTarget? selected;

  /// Web's single-select forward flow: choosing a row opens the second page
  /// ("Add shared content"), whose action is Continue.
  bool review = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when Continue starts and when a destination row is tapped (the only ways into the review step).
  String? handoffError;
  List<IncomingShareTarget> targets = [];
  final search = TextEditingController();
  final searchFocus = FocusNode();
  // ignore: raft_lints/avoid_imperative_notice_state -- Load error with Retry: cleared when a load starts or when a server read succeeds with no server; retry calls load.
  String? error;

  /// Notices above the rows. "No longer available" describes a dropped
  /// selection, so it ends when the user picks another destination; "could
  /// not be loaded" describes a failed refresh and ends when one succeeds
  /// (see [load]).
  final CauseNotice notice = CauseNotice();
  static const _lostNotice = 'The selected destination is no longer available.';
  static const _refreshFailedNotice = 'Conversations could not be loaded.';

  /// [loading]: no row to show yet. Rows are a device seed (or stale after an
  /// authority event) while a check is pending; [revalidating] is that state.
  bool loading = false, busy = false;
  int request = 0, _checks = 0;
  bool get revalidating => _checks > 0;

  /// Settles when every check started so far has finished. Never throws.
  Future<void> validation = Future.value();
  @override
  void initState() {
    super.initState();
    widget.staging?.addListener(stagingChanged);
    events = widget.client.events.listen((event) {
      if (!busy &&
          (event.name.startsWith('server:member') ||
              const {
                'channel:updated',
                'channel:members-updated',
                'channel:authority-updated',
                'channel:removed',
                'dm:new',
              }.contains(event.name))) {
        refreshAuthority();
      }
    });
    final initial =
        widget.servers.where((s) => s.id == widget.initialServer).firstOrNull ??
        widget.servers.firstOrNull;
    if (initial != null) {
      load(initial);
    } else {
      loading = true;
    }
    // The server list shown first is the device's; membership is re-read now.
    revalidateServers();
  }

  void stagingChanged() {
    if (!mounted) return;
    // A failed copy stays on the page: the file that failed shows why, and
    // Continue is unavailable until the user leaves.
    setState(() {});
  }

  /// Leaves the page and abandons a hand-off that is still waiting; the host
  /// stops the copy, checks nothing further and removes the staged files.
  void cancel() {
    widget.staging?.cancel();
    Navigator.of(context).pop(false);
  }

  /// Runs [body] as one pending check: hand-off waits for all of them.
  Future<void> _check(Future<void> Function() body) {
    _checks++;
    final done = body().whenComplete(() {
      _checks--;
      if (mounted) setState(() {});
    });
    final settled = done.then<void>((_) {}, onError: (Object _) {});
    validation = Future.wait([validation, settled]).then<void>((_) {});
    return settled;
  }

  /// Authority changed: keep what is on screen but re-read it. A row the fresh
  /// directory no longer offers is dropped with a notice.
  void refreshAuthority() {
    revalidateServers();
    final current = server;
    if (current != null) load(current, keepSelection: true);
  }

  /// Membership: a server the account no longer belongs to leaves the picker
  /// (with its destinations and selection); a changed role reloads them.
  Future<void> revalidateServers() => _check(() async {
    try {
      final next = await widget.client.servers();
      if (!mounted || !widget.valid()) return;
      final current = server;
      final fresh = current == null
          ? null
          : next.where((s) => s.id == current.id).firstOrNull;
      setState(() => servers = next);
      if (current != null && fresh != null) {
        if (fresh.string('role') != current.string('role')) {
          load(fresh, keepSelection: true);
        } else {
          setState(() => server = fresh);
        }
        return;
      }
      final alternative = next.firstOrNull;
      if (alternative != null) {
        // The selected destination's server is gone.
        final lost = current != null && selected != null;
        load(alternative);
        if (lost) {
          setState(() => _raiseLost());
        }
      } else {
        request++;
        setState(() {
          if (selected != null) _raiseLost();
          // Nothing to load: the read that just succeeded supersedes an
          // earlier "could not be loaded" error.
          error = null;
          server = null;
          selected = null;
          review = false;
          targets = [];
          loading = false;
        });
      }
    } catch (_) {
      // Offline: the device's list stays; hand-off re-reads membership.
      if (mounted && server == null && targets.isEmpty) {
        setState(() {
          loading = false;
          error = 'Conversations could not be loaded.';
        });
      }
    }
  });

  void _raiseLost() =>
      notice.raise(_lostNotice, whileTrue: () => selected == null);

  Future<void> load(RaftRecord next, {bool keepSelection = false}) {
    final ticket = ++request;
    final same = server?.id == next.id;
    // Seed from the device synchronously when the source can: the first frame
    // already lists the cached destinations.
    final seed = same ? null : widget.cachedTargets?.call(next);
    final seeded = seed is List<IncomingShareTarget> ? seed : null;
    setState(() {
      server = next;
      if (!(same && keepSelection)) {
        selected = null;
        review = false;
      }
      if (!same) {
        targets = seeded ?? [];
        search.clear();
      }
      loading = targets.isEmpty;
      error = null;
      if (!(same && keepSelection)) notice.clear();
    });
    bool current() => mounted && request == ticket && widget.valid();
    return _check(() async {
      if (seed is Future<List<IncomingShareTarget>?>) {
        try {
          final rows = await seed;
          if (current() && rows != null && targets.isEmpty) {
            setState(() {
              targets = rows;
              loading = false;
            });
          }
        } catch (_) {
          // A missing device copy only means a spinner until the read ends.
        }
      }
      try {
        final rows = await incomingShareTargets(widget.client, next);
        if (!current()) return;
        setState(() {
          targets = rows;
          loading = false;
          // The refresh worked: a failed-refresh notice is over.
          if (notice.message == _refreshFailedNotice) notice.clear();
          final held = selected;
          if (held != null) {
            final fresh = rows.where((t) => t.key == held.key).firstOrNull;
            selected = fresh;
            if (fresh == null) {
              review = false;
              _raiseLost();
            }
          }
        });
      } catch (e) {
        if (!current()) return;
        setState(() {
          loading = false;
          if (targets.isEmpty ||
              e is RaftApiException && (e.status == 403 || e.status == 404)) {
            // Refused or nothing to show: no destination of this server stays
            // selectable on the strength of the device copy.
            targets = [];
            selected = null;
            review = false;
            error = 'Conversations could not be loaded.';
          } else {
            notice.raise(_refreshFailedNotice);
          }
        });
      }
    });
  }

  Future<void> proceed() async {
    if (selected == null ||
        server == null ||
        busy ||
        widget.staging?.failed == true ||
        !widget.valid()) {
      return;
    }
    final destination = selected, scope = server;
    if (destination == null || scope == null) return;
    if (destination.requiresJoin) {
      final accepted = await RaftConfirmDialog.show(
        context,
        RaftConfirmDialog(
          title: 'Join Channel',
          confirmLabel: 'Join Channel',
          confirmVariant: RaftButtonRecipeVariant.primary,
          message: raftFormat(context, 'Join {name} to add shared content?', {
            'name': destination.label,
          }),
        ),
      );
      if (!mounted ||
          accepted != true ||
          !widget.valid() ||
          server?.id != scope.id ||
          selected?.key != destination.key) {
        return;
      }
    }
    setState(() {
      busy = true;
      handoffError = null;
    });
    try {
      await widget.onContinue(scope, destination);
      if (mounted && widget.valid()) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted && widget.valid()) {
        setState(() {
          busy = false;
          handoffError = 'The shared content could not be added. Try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    widget.staging?.removeListener(stagingChanged);
    request++;
    events?.cancel();
    search.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  /// Web `getForwardTargets`: most recent activity first, then by label.
  /// Destinations that have no conversation yet (a new DM) follow.
  List<IncomingShareTarget> get ordered {
    final query = search.text.trim().toLowerCase();
    int time(IncomingShareTarget t) {
      final json = t.channel?.json;
      return DateTime.tryParse(
            '${json?['lastMessageAt'] ?? json?['createdAt'] ?? ''}',
          )?.millisecondsSinceEpoch ??
          0;
    }

    return targets.where((t) => t.label.toLowerCase().contains(query)).toList()
      ..sort((a, b) {
        final order = time(b) - time(a);
        return order != 0
            ? order
            : a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
  }

  /// The share, as the second line of the target page.
  String summary(BuildContext context) {
    final raw = widget.staging?.raw;
    final files = raw?.files.length ?? 0;
    final text = raw?.text != null && raw!.text!.isNotEmpty;
    if (files == 0) return raftText(context, 'Sharing text');
    return raftFormat(
      context,
      text
          ? files == 1
                ? 'Sharing {count} file and text'
                : 'Sharing {count} files and text'
          : files == 1
          ? 'Sharing {count} file'
          : 'Sharing {count} files',
      {'count': files},
    );
  }

  /// Compact copy progress of the targets page (the file card is not visible
  /// there): `Preparing 1 of 3 files · 4.2 / 30.1 MB`, by bytes.
  Widget progress(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.staging!.overall,
    builder: (context, bytes, _) => RaftProgressBar(
      key: const Key('incoming-share-preparing'),
      label:
          '${raftFormat(context, 'Preparing {done} of {total} files', {'done': widget.staging!.copied, 'total': widget.staging!.total})}'
          '${bytes == null || bytes.waiting ? '' : ' · ${bytes.sizeLabel}'}',
      value: bytes?.fraction == null
          ? 100 * widget.staging!.copied / widget.staging!.total
          : 100 * bytes!.fraction!,
    ),
  );

  /// What the user reads when the copy failed: the file and the reason.
  String? stagingError(BuildContext context) {
    final staging = widget.staging;
    if (staging == null || !staging.failed) return null;
    final failure = staging.failure;
    final index = failure?.index;
    final name = index != null && index < staging.files.length
        ? staging.files[index].file.filename
        : '';
    return switch (failure?.reason) {
      IncomingShareFailureReason.tooLarge => raftFormat(
        context,
        '{name} is larger than 25 MB and cannot be added.',
        {'name': name},
      ),
      IncomingShareFailureReason.tooMany => raftText(
        context,
        'Up to 9 files can be shared at once.',
      ),
      IncomingShareFailureReason.totalTooLarge => raftText(
        context,
        'These files are larger than 100 MB together.',
      ),
      IncomingShareFailureReason.unreadable => raftFormat(
        context,
        '{name} could not be read.',
        {'name': name},
      ),
      IncomingShareFailureReason.permission => raftFormat(
        context,
        'Raft can no longer read {name}.',
        {'name': name},
      ),
      IncomingShareFailureReason.empty => raftFormat(
        context,
        '{name} is empty.',
        {'name': name},
      ),
      _ => raftText(context, 'The shared content could not be added.'),
    };
  }

  /// Short reason under a failed chip.
  String fileError(BuildContext context, IncomingShareFileProgress file) =>
      switch (file.failure) {
        IncomingShareFailureReason.tooLarge => raftText(
          context,
          'Larger than 25 MB',
        ),
        IncomingShareFailureReason.permission => raftText(
          context,
          'Permission revoked',
        ),
        IncomingShareFailureReason.empty => raftText(context, 'Empty file'),
        IncomingShareFailureReason.totalTooLarge => raftText(
          context,
          'Over the 100 MB total',
        ),
        _ => raftText(context, 'Could not be read'),
      };

  RaftForwardShareFileState chipState(IncomingShareFileState state) =>
      incomingShareWaitStyle == IncomingShareWaitStyle.button &&
          state != IncomingShareFileState.failed
      ? RaftForwardShareFileState.ready
      : switch (state) {
          IncomingShareFileState.waiting => RaftForwardShareFileState.waiting,
          IncomingShareFileState.copying => RaftForwardShareFileState.copying,
          IncomingShareFileState.ready ||
          IncomingShareFileState.stopped => RaftForwardShareFileState.ready,
          IncomingShareFileState.failed => RaftForwardShareFileState.failed,
        };

  /// The block above Continue while it waits: the copy first (by bytes), then
  /// the checks and the hand-off. Null when nothing is pending.
  RaftForwardWait? wait(BuildContext context) {
    final staging = widget.staging;
    if (!busy) return null;
    if (staging != null && staging.preparing && staging.total > 0) {
      return RaftForwardWait(
        label: raftFormat(context, 'Preparing {done} of {total} files', {
          'done': staging.copied,
          'total': staging.total,
        }),
        progress: staging.overall,
        onCancel: cancel,
      );
    }
    return RaftForwardWait(
      label: raftText(context, 'Adding to the conversation'),
      onCancel: cancel,
    );
  }

  bool get preparing =>
      widget.staging?.preparing == true && widget.staging!.total > 0;

  @override
  Widget build(BuildContext context) {
    final target = selected;
    final second = review && target != null;
    return PopScope(
      canPop: !second || busy,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Leaving while a hand-off waits abandons it (a finished hand-off
          // pops with true).
          if (busy && result != true) widget.staging?.cancel();
        } else if (second) {
          setState(() => review = false);
        }
      },
      child: RaftForwardPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (second)
              ..._reviewStep(context, target)
            else
              ..._targetsStep(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _targetsStep(BuildContext context) {
    final query = search.text.trim();
    final rows = ordered;
    return [
      RaftForwardPageHeader(
        leading: RaftForwardIconAction(
          glyph: RaftGlyph.arrowLeft,
          tooltip: raftText(context, 'Back'),
          onPressed: busy ? cancel : () => Navigator.of(context).pop(false),
        ),
        title: raftText(context, 'Select destinations'),
        subtitle: summary(context),
      ),
      Expanded(
        child: RaftForwardTargetsBody(
          leading: [
            if (stagingError(context) case final message?)
              RaftBanner(
                key: const Key('incoming-share-error'),
                status: RaftBannerRecipeStatus.warning,
                description: message,
                descriptionWeight: FontWeight.w700,
              )
            else if (preparing)
              progress(context),
            if (servers.length > 1)
              RaftForwardServerChips(
                semanticLabel: raftText(context, 'Server'),
                names: {for (final s in servers) s.id: s.name},
                selected: server?.id ?? '',
                onSelected: busy
                    ? null
                    // ignore: raft_lints/avoid_render_where_without_or_else -- The id comes from the server chips built from the same `servers` list in this build.
                    : (id) => load(servers.firstWhere((s) => s.id == id)),
              ),
          ],
          search: RaftForwardSearchInput(
            controller: search,
            focusNode: searchFocus,
            placeholder: raftText(context, 'Search targets'),
            onChanged: (_) => setState(() {}),
          ),
          label: raftText(context, 'Recent'),
          itemCount: loading || error != null
              ? 1
              : (rows.isEmpty ? 1 : rows.length) +
                    (notice.message == null ? 0 : 1),
          itemBuilder: (context, index) {
            if (loading) return const RaftForwardSearchStatus(loading: true);
            final shown = notice.message;
            if (shown != null && index == 0) {
              return RaftForwardSearchStatus(
                key: const Key('incoming-share-notice'),
                message: raftText(context, shown),
              );
            }
            if (shown != null) index--;
            if (error != null) {
              return RaftForwardSearchStatus(
                message: raftText(context, error!),
                retryLabel: raftText(context, 'Retry'),
                onRetry: () =>
                    server == null ? refreshAuthority() : load(server!),
              );
            }
            if (rows.isEmpty) {
              return RaftForwardSearchStatus(
                message: raftText(
                  context,
                  query.isEmpty
                      ? 'No destinations available.'
                      : 'No destinations match your search.',
                ),
              );
            }
            final row = rows[index];
            final channel = row.channel;
            return RaftForwardTargetRow(
              key: ValueKey('incoming-target-${row.key}'),
              icon: forwardTargetIcon(
                widget.client.origin,
                name: row.label,
                type: channel?.type ?? 'dm',
                agent:
                    row.agentId != null || channel?.json['peerType'] == 'agent',
                peerId:
                    row.agentId ??
                    row.userId ??
                    (channel?.json['peerId'] is String
                        ? channel!.json['peerId'] as String
                        : null),
                avatarUrl: channel?.json['peerAvatarUrl'] is String
                    ? channel!.json['peerAvatarUrl'] as String
                    : null,
                gravatarHash: channel?.json['peerGravatarHash'] is String
                    ? channel!.json['peerGravatarHash'] as String
                    : null,
              ),
              // Web `targetPickerLabel`: channels show the bare name.
              label: channel != null && channel.type != 'dm'
                  ? channel.name
                  : row.label,
              selected: selected?.key == row.key,
              checkbox: false,
              trailing: row.requiresJoin
                  ? RaftForwardTargetBadge(
                      glyph: RaftGlyph.logIn,
                      label: raftText(context, 'Not joined'),
                    )
                  : channel == null
                  ? RaftForwardTargetBadge(
                      glyph: RaftGlyph.userPlus,
                      label: raftText(context, 'New DM'),
                    )
                  : null,
              onTap: busy
                  ? null
                  : () => setState(() {
                      selected = row;
                      review = true;
                      handoffError = null;
                    }),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _reviewStep(BuildContext context, IncomingShareTarget target) {
    final raw = widget.staging?.raw;
    final files = raw?.files ?? const <IncomingSharedFile>[];
    return [
      RaftForwardPageHeader(
        leading: RaftForwardIconAction(
          glyph: RaftGlyph.arrowLeft,
          tooltip: raftText(context, 'Back to Destinations'),
          onPressed: busy ? cancel : () => setState(() => review = false),
        ),
        title: raftText(context, 'Add shared content'),
        subtitle: raftFormat(context, 'Add to {target}', {
          'target': target.label,
        }),
      ),
      Expanded(
        child: RaftForwardPreviewStep(
          warnings: const [],
          error:
              stagingError(context) ??
              (handoffError == null ? null : raftText(context, handoffError!)),
          previewLabel: raftText(context, 'Shared content'),
          preview: RaftForwardSharePreview(
            header: raftText(context, 'Shared'),
            count: files.isEmpty
                ? null
                : raftFormat(
                    context,
                    files.length == 1 ? '{count} file' : '{count} files',
                    {'count': files.length},
                  ),
            text: raw?.text,
            files: [
              for (final (i, f) in files.indexed)
                RaftForwardShareFile(
                  filename: f.filename,
                  mimeType: f.mimeType,
                  sizeBytes: f.sizeBytes,
                  state: chipState(
                    widget.staging?.files[i].state ??
                        IncomingShareFileState.ready,
                  ),
                  transfer: widget.staging?.files[i].progress,
                  error:
                      widget.staging?.files[i].state ==
                          IncomingShareFileState.failed
                      ? fileError(context, widget.staging!.files[i])
                      : null,
                ),
            ],
          ),
          hint: files.isEmpty
              ? null
              : raftText(
                  context,
                  'Files are added to the composer. Review them before sending.',
                ),
          action: RaftForwardContinueAction(
            key: const Key('incoming-share-continue'),
            label: raftText(context, 'Continue'),
            busy: busy,
            busyLabel: raftText(
              context,
              preparing ? 'Preparing files' : 'Adding…',
            ),
            wait: wait(context),
            onPressed: busy || loading || widget.staging?.failed == true
                ? null
                : proceed,
          ),
        ),
      ),
    ];
  }
}
