// Web ForwardComposerDialog on a narrow viewport (< md) renders
// ForwardComposerMobile: a full-screen "Select destinations" page (Recent
// targets from the channel + DM stores, search), then an "Add a note" page
// with the forwarded-bundle preview and the note composer.
// Source: packages/web/src/components/message/ForwardComposerMobile.tsx,
// ForwardComposerTargetList.tsx, forwardComposerModel.tsx.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';
import '../data/cause_notice.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'channel_footer_states.dart' show jointChannelReadOnly;
import 'forward_messages_dialog.dart';
import 'private_route_guard.dart';
import 'sender_avatar_projection.dart';

/// One destination: a local channel/DM (`localTarget`) or a search row.
class _Destination {
  _Destination({
    required this.key,
    required this.label,
    this.channel,
    this.search,
  });
  final String key, label;
  final RaftChannel? channel;
  final Map<String, dynamic>? search;
  String? get channelId =>
      channel?.id ??
      (search?['channelId'] is String ? search!['channelId'] : null);
}

/// `targetLabel`: `@peer` for DMs, `#name` otherwise.
String forwardTargetLabel(RaftChannel c) {
  if (c.type == 'dm') {
    final peer = c.json['peerDisplayName'] ?? c.json['peerName'] ?? c.name;
    return '@$peer';
  }
  return '#${c.name}';
}

/// Web `targetIcon` / the search row icon: the row's peer artwork. [type] is
/// the channel type, or `dm` / `human` / `agent` for people.
Widget forwardTargetIcon(
  String origin, {
  required String name,
  required String type,
  bool agent = false,
  String? peerId,
  String? avatarUrl,
  String? gravatarHash,
}) {
  final person = type == 'dm' || type == 'human' || type == 'agent';
  if (!person) return raftForwardTargetIcon(name: name, type: type);
  final isAgent = agent || type == 'agent';
  final id = peerId ?? name;
  final projection = projectSenderAvatar(
    origin: origin,
    senderId: id,
    senderType: isAgent ? 'agent' : 'user',
    agents: [
      if (isAgent) {'id': id, 'avatarUrl': avatarUrl},
    ],
    members: [
      if (!isAgent)
        {'userId': id, 'avatarUrl': avatarUrl, 'gravatarHash': gravatarHash},
    ],
    requestSize: 40,
  );
  return raftForwardTargetIcon(
    name: name,
    type: type,
    agent: isAgent,
    pixelKey: projection.pixelKey,
    uploadedUrl: projection.uploadedUrl,
    gravatarUrl: projection.gravatarUrl,
  );
}

/// `targetPickerLabel`: DMs keep `@peer`, channels show the bare name.
String forwardTargetPickerLabel(RaftChannel c) =>
    c.type == 'dm' ? forwardTargetLabel(c) : c.name;

/// Approximates `localeCompare(..., {sensitivity: "base", numeric: true})`
/// under the ICU root collation used by Chromium: case-insensitive, ASCII
/// punctuation ordered before digits before letters, `@` before `#`.
int forwardLabelCompare(String a, String b) {
  const punctuation = "_-,;:!?.'\"()[]{}@*/\\&#%`^+<=>|~\$";
  int rank(int code) {
    final ch = String.fromCharCode(code);
    final p = punctuation.indexOf(ch);
    if (p >= 0) return p;
    if (code >= 48 && code <= 57) return 100 + code - 48;
    final lower = ch.toLowerCase().codeUnitAt(0);
    if (lower >= 97 && lower <= 122) return 200 + lower - 97;
    return 1000 + lower;
  }

  final x = a.codeUnits, y = b.codeUnits;
  for (var i = 0; i < x.length && i < y.length; i++) {
    final d = rank(x[i]) - rank(y[i]);
    if (d != 0) return d;
  }
  return x.length - y.length;
}

/// `getForwardTargets` with an empty query: channels then DMs, most recent
/// activity first, ties by label.
List<RaftChannel> forwardRecentTargets(
  List<RaftChannel> channels,
  List<RaftChannel> dms,
) {
  final now = sourceTimeNow();
  int time(RaftChannel c) =>
      DateTime.tryParse(
        '${c.json['lastMessageAt'] ?? c.json['createdAt'] ?? ''}',
      )?.millisecondsSinceEpoch ??
      0;
  bool forwardable(RaftChannel c) {
    if (c.archived || c.type == 'thread') return false;
    if (c.type == 'dm') return true;
    // canForwardToTarget: a read-only (locked) Joint Channel takes no forward.
    if (jointChannelReadOnly(c.json, now)) return false;
    return c.joined;
  }

  final all = [...channels, ...dms].where(forwardable).toList();
  all.sort((a, b) {
    final t = time(b) - time(a);
    if (t != 0) return t;
    final l = forwardLabelCompare(forwardTargetLabel(a), forwardTargetLabel(b));
    return l != 0 ? l : a.id.compareTo(b.id);
  });
  return all;
}

Future<bool> showForwardComposerPage(
  BuildContext context,
  WorkspaceController controller,
  List<RaftMessage> messages,
) async =>
    await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) =>
            ForwardComposerPage(controller: controller, messages: messages),
      ),
    ) ??
    false;

class ForwardComposerPage extends StatefulWidget {
  const ForwardComposerPage({
    super.key,
    required this.controller,
    required this.messages,
    this.desktop = false,
  });
  final WorkspaceController controller;
  final List<RaftMessage> messages;

  /// ForwardComposerDesktop (>= md): the two-pane dialog card instead of the
  /// full-screen pages.
  final bool desktop;
  @override
  State<ForwardComposerPage> createState() => _ForwardComposerPageState();
}

class _ForwardComposerPageState extends State<ForwardComposerPage> {
  WorkspaceController get w => widget.controller;
  final search = TextEditingController(), note = TextEditingController();
  final searchFocus = FocusNode();
  final selected = <String, _Destination>{};
  List<Map<String, dynamic>> results = [];
  late final String authority;
  Timer? debounce;
  int request = 0;
  late bool multi = widget.desktop;
  bool preview = false, loading = false, failed = false;
  bool busy = false;
  // The failed forward. Bound to the destination selection it failed for: Web
  // resets the note composer (and its banner) when the destinations change,
  // so a banner about other destinations must not stay. A new send clears it.
  late final CauseNotice errorNotice = CauseNotice(
    scope: () => selected.keys.join('\u0000'),
  );
  String? get error => errorNotice.message;
  ForwardAttempt? attempt;
  bool get current => mounted && authority == workspaceAuthority(w);

  @override
  void initState() {
    super.initState();
    authority = workspaceAuthority(w);
    w.addListener(authorityChanged);
  }

  void authorityChanged() {
    if (authority == workspaceAuthority(w)) return;
    ++request;
    debounce?.cancel();
    if (mounted && ModalRoute.of(context)?.isActive == true) {
      Navigator.of(context).removeRoute(ModalRoute.of(context)!);
    }
  }

  @override
  void dispose() {
    ++request;
    debounce?.cancel();
    w.removeListener(authorityChanged);
    search.dispose();
    note.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  String get sourceLabel {
    final source = w.channels
        .followedBy(w.dms)
        .where((c) => c.id == widget.messages.first.channelId)
        .firstOrNull;
    return source == null
        ? ''
        : source.type == 'dm' || source.type == 'thread'
        ? forwardTargetLabel(source)
        : '#${source.name}';
  }

  void changedSearch(String value) {
    ++request;
    debounce?.cancel();
    final query = value.trim();
    setState(() {
      results = [];
      failed = false;
      loading = query.isNotEmpty;
    });
    if (query.isNotEmpty) {
      debounce = Timer(const Duration(milliseconds: 250), () => load(query));
    }
  }

  Future<void> load(String query) async {
    final ticket = ++request;
    try {
      final value = await w.query(
        '/messages/forward/targets/search',
        query: {'q': query, 'limit': 20},
      );
      if (!current || ticket != request) return;
      setState(() {
        results = (value['targets'] as List)
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        loading = false;
      });
    } catch (_) {
      if (!current || ticket != request) return;
      setState(() {
        loading = false;
        failed = true;
      });
    }
  }

  void choose(_Destination d) {
    if (busy) return;
    // The row (tabIndex 0) takes focus from the search input on Web, which
    // also closes the soft keyboard.
    searchFocus.unfocus();
    setState(() {
      if (multi) {
        if (selected.remove(d.key) == null && selected.length < 10) {
          selected[d.key] = d;
        }
      } else {
        selected
          ..clear()
          ..[d.key] = d;
        preview = true;
      }
    });
  }

  /// Joins / opens a DM for search rows that need it, then forwards.
  Future<bool> send() async {
    if (!current || busy || selected.isEmpty) return false;
    setState(() {
      busy = true;
      errorNotice.clear();
    });
    var resolving = true;
    try {
      for (final d in selected.values) {
        final target = d.search;
        if (target == null ||
            d.channelId != null && target['requiredAction'] == null) {
          continue;
        }
        if (target['requiredAction'] == 'join_channel' &&
            target['channelId'] is String) {
          await w.command('POST', '/channels/${target['channelId']}/join');
        } else if (target['requiredAction'] == 'create_dm') {
          final created = await w.command(
            'POST',
            '/channels/dm',
            data: {
              target['type'] == 'agent' ? 'agentId' : 'userId': target['id'],
            },
          );
          if (created is Map && created['id'] is String) {
            target['channelId'] = created['id'];
          }
        }
      }
      resolving = false;
      final destinations = [
        for (final d in selected.values)
          if (d.channelId != null) d.channelId!,
      ];
      attempt ??= ForwardAttempt(
        requestId: w.client.newRandomId(),
        sources: widget.messages.map((m) => m.id).toList(),
        destinations: destinations,
        note: note.text,
      );
      final response = await w.command(
        'POST',
        '/messages/forward',
        data: attempt!.payload,
      );
      if (!current || !mounted) return false;
      attempt!.apply(response);
      if (attempt!.completed) {
        Navigator.of(context).pop(true);
        return true;
      }
      // Web: some destinations did not take the forward; the toast and the
      // composer banner ask to retry the remaining ones.
      const retry =
          'Some destinations failed. Retry the remaining destinations.';
      setState(() => errorNotice.raise(retry));
      showRaftToast(context, retry);
    } catch (e) {
      if (current) {
        // Web ForwardComposerDialog: `forwardToast.error(message)` plus the
        // composer's own error banner carrying the same message.
        final message = resolving
            ? 'The selected destinations are no longer available. Review your selection and try again.'
            : forwardRequestFailureMessage(e);
        logUserError(e, where: 'forward messages');
        setState(() => errorNotice.raise(message));
        showRaftToast(context, message);
      }
    } finally {
      if (current) setState(() => busy = false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && preview && !busy) setState(() => preview = false);
    },
    child: widget.desktop
        ? desktopDialog()
        : RaftForwardPage(child: preview ? previewStep() : targetsStep()),
  );

  /// ForwardedBundleCard's `formatShortDateTime` in the account's zone / hour cycle.
  String Function(DateTime) forwardStamp() {
    final user = w.client.user;
    return SourceTimeFormatter(
      locale: Localizations.localeOf(context).toLanguageTag(),
      preferredTimezone:
          user?.string('preferredTimezone') ?? user?.string('timezone'),
      preferredTimeFormat: sourceTimeFormatPreference(
        user?.string('preferredTimeFormat') ?? user?.string('timeFormat'),
      ),
      systemTimeFormat: MediaQuery.alwaysUse24HourFormatOf(context)
          ? SourceTimeFormat.twentyFourHour
          : null,
    ).shortDateTime;
  }

  /// The forwarded-bundle preview metadata of the selected messages.
  Map<String, dynamic> get previewMetadata {
    final source = w.channels
        .followedBy(w.dms)
        .where((c) => c.id == widget.messages.first.channelId)
        .firstOrNull;
    final thread = source?.type == 'thread';
    return <String, dynamic>{
      'kind': 'forwarded-bundle',
      'version': 1,
      'forwardedItems': [
        for (final (index, m) in widget.messages.indexed)
          {
            'index': index,
            'sourceMessageSeq': m.json['seq'],
            'sourceMessageId': m.id,
            'sourceTargetId': thread ? null : source?.id,
            'sourceAuthorSnapshot': {
              'type': m.string('senderType') == 'agent' ? 'agent' : 'user',
              'id': m.string('senderId'),
              'name': m.author,
              'uniqueName': m.author,
            },
            'sourceCreatedAt': m.json['createdAt'],
            'sourceTargetSnapshot': {
              'id': source?.id,
              'type': source?.type,
              'label': sourceLabel,
              'labelVisibility': source?.type == 'channel' || thread
                  ? 'public'
                  : 'restricted',
            },
            'contentSnapshot': m.content,
            'attachmentPolicy': 'projected',
            'provenanceState': 'available',
          },
      ],
    };
  }

  /// ForwardComposerDesktop.tsx: the two-pane dialog card.
  Widget desktopDialog() {
    final query = search.text.trim();
    return RaftForwardDesktopDialog(
      title: raftText(context, 'Forward'),
      subtitle: raftFormat(context, '{count} selected from {source}', {
        'count': widget.messages.length,
        'source': sourceLabel,
      }),
      close: RaftCloseButton(
        tooltip: 'Close forward composer',
        onPressed: busy ? null : () => Navigator.of(context).pop(false),
      ),
      search: RaftForwardDesktopSearch(
        controller: search,
        focusNode: searchFocus,
        placeholder: raftText(context, 'Search targets'),
        onChanged: changedSearch,
      ),
      selectedLabel: raftFormat(context, '{count} selected', {
        'count': selected.length,
      }),
      showClear: selected.isNotEmpty,
      clearLabel: raftText(context, 'Clear'),
      onClear: busy ? null : () => setState(selected.clear),
      rows: query.isEmpty
          ? [
              for (final c in forwardRecentTargets(w.channels, w.dms))
                localRow(c),
            ]
          : searchRows(),
      error: error,
      preview: RaftForwardedBundle(
        metadata: previewMetadata,
        formatTimestamp: forwardStamp(),
      ),
      noteLabel: raftText(context, 'Optional note'),
      // Web mounts the same compact MessageInput as the phone page, with
      // allowEmptySubmit; Send stays off until a destination is chosen.
      note: RaftComposer(
        key: const Key('forward-desktop-note'),
        variant: RaftComposerVariant.compact,
        hint: raftText(context, 'Add a note'),
        hasAttachments: true,
        canSend: selected.isNotEmpty,
        bottomSafeInset: 0,
        enabled: !busy,
        submitBusy: busy,
        submitTooltip: raftText(context, 'Send forward'),
        initialDraft: note.text,
        onDraftChanged: (text) => note.text = text,
        onSend: (text) {
          note.text = text;
          return send();
        },
      ),
    );
  }

  Widget targetsStep() {
    final selectedFrom = raftFormat(context, '{count} selected from {source}', {
      'count': widget.messages.length,
      'source': sourceLabel,
    });
    final query = search.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftForwardPageHeader(
          leading: multi
              ? RaftForwardIconAction(
                  glyph: RaftGlyph.undo2,
                  tooltip: raftText(context, 'Cancel'),
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          selected.clear();
                          multi = false;
                        }),
                )
              : RaftForwardIconAction(
                  glyph: RaftGlyph.arrowLeft,
                  tooltip: raftText(context, 'Close forward target selection'),
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
          title: raftText(context, 'Select destinations'),
          subtitle: selectedFrom,
          trailing: multi
              ? RaftForwardIconAction(
                  glyph: RaftGlyph.check,
                  accent: true,
                  tooltip: raftText(context, 'Done'),
                  onPressed: selected.isEmpty || busy
                      ? null
                      : () => setState(() => preview = true),
                )
              : RaftForwardTextAction(
                  label: raftText(context, 'Select multiple'),
                  onPressed: () {
                    searchFocus.unfocus();
                    setState(() {
                      selected.clear();
                      multi = true;
                    });
                  },
                ),
        ),
        Expanded(
          child: RaftForwardTargetsBody(
            search: RaftForwardSearchInput(
              controller: search,
              focusNode: searchFocus,
              placeholder: raftText(context, 'Search targets'),
              onChanged: changedSearch,
            ),
            label: multi
                ? raftFormat(context, '{count} selected', {
                    'count': selected.length,
                  })
                : raftText(context, 'Recent'),
            labelAction: multi && selected.isNotEmpty
                ? RaftForwardLinkAction(
                    label: raftText(context, 'Clear'),
                    onTap: () => setState(selected.clear),
                  )
                : null,
            rows: query.isEmpty
                ? [
                    for (final c in forwardRecentTargets(w.channels, w.dms))
                      localRow(c),
                  ]
                : searchRows(),
          ),
        ),
      ],
    );
  }

  List<Widget> searchRows() {
    if (loading) return const [RaftForwardSearchStatus(loading: true)];
    if (failed) {
      return [
        RaftForwardSearchStatus(
          message: raftText(context, "Couldn't search destinations."),
          retryLabel: raftText(context, 'Try again'),
          onRetry: () => changedSearch(search.text),
        ),
      ];
    }
    if (results.isEmpty) {
      return [
        RaftForwardSearchStatus(
          message: raftText(context, 'No destinations match your search.'),
        ),
      ];
    }
    return [
      for (final r in results)
        () {
          final key = r['channelId'] is String
              ? 'channel:${r['channelId']}'
              : '${r['type']}:${r['id']}';
          final unavailable =
              r['canForwardNow'] != true && r['requiredAction'] == null;
          final type = r['type'];
          final action = r['requiredAction'];
          return RaftForwardTargetRow(
            key: ValueKey('forward-search-target-$type-${r['id']}'),
            icon: forwardTargetIcon(
              w.client.origin,
              name: '${r['title']}',
              type: type == 'channel'
                  ? '${r['channelType'] ?? 'channel'}'
                  : '$type',
              agent: r['subtitle'] == 'agent',
              peerId: r['id'] is String ? r['id'] as String : null,
              avatarUrl: r['avatarUrl'] is String
                  ? r['avatarUrl'] as String
                  : null,
            ),
            label: '${r['title']}',
            selected: selected.containsKey(key),
            checkbox: multi,
            checkboxDisabled:
                !selected.containsKey(key) && selected.length >= 10,
            unavailable: unavailable,
            trailing: action == 'join_channel' || action == 'create_dm'
                ? RaftForwardTargetBadge(
                    glyph: action == 'join_channel'
                        ? RaftGlyph.logIn
                        : RaftGlyph.userPlus,
                    label: raftText(
                      context,
                      action == 'join_channel' ? 'Not joined' : 'New DM',
                    ),
                  )
                : null,
            onTap: unavailable
                ? null
                : () => choose(
                    _Destination(key: key, label: '${r['title']}', search: r),
                  ),
          );
        }(),
    ];
  }

  Widget localRow(RaftChannel c) {
    final key = 'channel:${c.id}';
    return RaftForwardTargetRow(
      key: ValueKey('forward-target-${c.id}'),
      icon: forwardTargetIcon(
        w.client.origin,
        name: forwardTargetPickerLabel(c),
        type: c.type,
        agent: c.json['peerType'] == 'agent',
        peerId: c.json['peerId'] is String ? c.json['peerId'] as String : null,
        avatarUrl: c.json['peerAvatarUrl'] is String
            ? c.json['peerAvatarUrl'] as String
            : null,
        gravatarHash: c.json['peerGravatarHash'] is String
            ? c.json['peerGravatarHash'] as String
            : null,
      ),
      label: forwardTargetPickerLabel(c),
      selected: selected.containsKey(key),
      checkbox: multi,
      checkboxDisabled: !selected.containsKey(key) && selected.length >= 10,
      onTap: () => choose(
        _Destination(key: key, label: forwardTargetLabel(c), channel: c),
      ),
    );
  }

  Widget previewStep() {
    final labels = selected.values.map((d) => d.label).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftForwardPageHeader(
          leading: RaftForwardIconAction(
            glyph: RaftGlyph.arrowLeft,
            tooltip: raftText(context, 'Back to destinations'),
            onPressed: busy ? null : () => setState(() => preview = false),
          ),
          title: raftText(context, 'Add a note'),
          subtitle: raftFormat(context, 'Send to {targets}', {
            'targets': labels,
          }),
        ),
        Expanded(
          child: RaftForwardPreviewStep(
            error: error,
            previewLabel: raftText(context, 'Message preview'),
            preview: RaftForwardedBundle(
              metadata: previewMetadata,
              formatTimestamp: forwardStamp(),
              headerLine: 16.5,
            ),
            noteLabel: raftText(context, 'Optional note'),
            // Web mounts MessageInput variant="compact" with allowEmptySubmit:
            // the same composer the attachment comments use; the note may be
            // empty, so it counts as "has content" (`hasAttachments`).
            note: RaftComposer(
              key: const Key('forward-mobile-note'),
              variant: RaftComposerVariant.compact,
              hint: raftText(context, 'Add a note'),
              autofocus: true,
              hasAttachments: true,
              bottomSafeInset: 0,
              enabled: !busy && attempt == null,
              submitBusy: busy,
              submitTooltip: raftText(context, 'Send forward'),
              initialDraft: note.text,
              onDraftChanged: (text) => note.text = text,
              onSend: (text) {
                note.text = text;
                return send();
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Web `forwardRequestFailureMessage`: a fixed sentence per server `code`,
/// "We couldn't confirm whether the forward finished" otherwise. The server's
/// own error text is not shown for a forward.
String forwardRequestFailureMessage(Object error) {
  final code = error is RaftApiException ? error.details['code'] : null;
  return switch (code) {
    'cross_source_bundle' => 'Select messages from one conversation or thread.',
    'source_not_found' => 'One or more selected messages are no longer available. Review the original conversation and try again.',
    'forwarded_source_not_supported' => "Forwarded messages can't be forwarded again. Select the original messages instead.",
    'unsupported_source_message' || 'unsupported_source' => "One or more selected items can't be forwarded. Select regular messages instead.",
    'cross_server_source' =>
      "Messages from another server can't be forwarded here.",
    _ => "We couldn't confirm whether the forward finished. It's safe to try again.",
  };
}
