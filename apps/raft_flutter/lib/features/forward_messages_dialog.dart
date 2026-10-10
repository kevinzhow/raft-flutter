import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'forward_composer_page.dart';
import 'private_route_guard.dart';

/// The retry keeps the exact server idempotency payload, including destinations.
/// Successful destinations are reported separately from failed destinations.
class ForwardAttempt {
  ForwardAttempt({
    required String requestId,
    required List<String> sources,
    required List<String> destinations,
    required String note,
  }) : payload = Map.unmodifiable({
         'requestId': requestId,
         'sourceMessageIds': List<String>.unmodifiable(sources),
         'destinationChannelIds': List<String>.unmodifiable(destinations),
         'note': note.trim(),
       });
  final Map<String, dynamic> payload;
  List<String> get destinations => payload['destinationChannelIds'];
  final Map<String, String> outcomes = {};
  final Map<String, String> errors = {};
  void apply(dynamic response) {
    if (response is! Map || response['results'] is! List) {
      throw const RaftApiException(
        'The forward response was incomplete. Retry this request.',
      );
    }
    final rows = (response['results'] as List).whereType<Map>().toList();
    for (final id in destinations) {
      final matching = rows
          .where((r) => r['destinationChannelId'] == id)
          .toList();
      // Missing/duplicate/unrecognized receipts never become success.
      if (matching.length != 1 ||
          !['success', 'failed'].contains(matching.single['status'])) {
        if (outcomes[id] != 'success') {
          outcomes[id] = 'unknown';
          errors[id] = 'No conclusive receipt. Retry the same request.';
        }
        continue;
      }
      final row = matching.single;
      if (row['status'] == 'success' &&
          row['message'] is Map &&
          row['message']['id'] is String &&
          (row['message']['id'] as String).isNotEmpty) {
        outcomes[id] = 'success';
        errors.remove(id);
      } else if (row['status'] == 'success' && outcomes[id] != 'success') {
        outcomes[id] = 'unknown';
        errors[id] = 'No conclusive receipt. Retry the same request.';
      } else if (outcomes[id] != 'success') {
        outcomes[id] = 'failed';
        errors[id] = row['error'] is String
            ? row['error']
            : 'Could not forward to this target.';
      }
    }
  }

  bool get completed => destinations.every((id) => outcomes[id] == 'success');
}

Future<bool> forwardMessages(
  BuildContext context,
  WorkspaceController controller,
  List<RaftMessage> messages,
) async {
  if (messages.isEmpty || messages.length > 20) {
    throw const RaftApiException('Forward between 1 and 20 messages.');
  }
  if (messages.any(
    (m) =>
        m.string('messageType') != 'chat' || m.json['actionMetadata'] != null,
  )) {
    throw const RaftApiException(
      'Only original, ordinary chat messages can be forwarded.',
    );
  }
  // Web ForwardComposerDialog: ForwardComposerMobile below `md` (768px).
  if (MediaQuery.sizeOf(context).width < 768) {
    return showForwardComposerPage(context, controller, messages);
  }
  return await showDialog<bool>(
        context: context,
        builder: (_) =>
            ForwardMessagesDialog(controller: controller, messages: messages),
      ) ??
      false;
}

class ForwardMessagesDialog extends StatefulWidget {
  const ForwardMessagesDialog({
    super.key,
    required this.controller,
    required this.messages,
  });
  final WorkspaceController controller;
  final List<RaftMessage> messages;
  @override
  State<ForwardMessagesDialog> createState() => _ForwardMessagesDialogState();
}

class _ForwardMessagesDialogState extends State<ForwardMessagesDialog> {
  WorkspaceController get w => widget.controller;
  final search = TextEditingController(), note = TextEditingController();
  final selected = <String, Map<String, dynamic>>{};
  List<Map<String, dynamic>> targets = [];
  late final String authority;
  Route<dynamic>? ownedRoute;
  Timer? debounce;
  int request = 0;
  bool loading = false, busy = false;
  String? error;
  ForwardAttempt? attempt;
  bool get current => mounted && authority == workspaceAuthority(w);
  @override
  void initState() {
    super.initState();
    authority = workspaceAuthority(w);
    w.addListener(authorityChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ownedRoute ??= ModalRoute.of(context);
  }

  void authorityChanged() {
    if (authority == workspaceAuthority(w)) return;
    ++request;
    debounce?.cancel();
    targets.clear();
    selected.clear();
    note.clear();
    search.clear();
    attempt = null;
    closeOwned();
  }

  void closeOwned() {
    final route = ownedRoute;
    if (mounted && route != null && route.isActive) {
      Navigator.of(context).removeRoute(route, false);
    }
  }

  @override
  void dispose() {
    ++request;
    debounce?.cancel();
    w.removeListener(authorityChanged);
    search.dispose();
    note.dispose();
    super.dispose();
  }

  void changedSearch(String _) {
    ++request;
    debounce?.cancel();
    final empty = search.text.trim().isEmpty;
    setState(() {
      // Results stay until the new ones arrive (replaced in place); only an
      // emptied query returns to the idle, empty list.
      if (empty) targets = [];
      loading = !empty;
      error = null;
    });
    debounce = Timer(const Duration(milliseconds: 250), loadTargets);
  }

  Future<void> loadTargets() async {
    final ticket = ++request, query = search.text.trim();
    if (!current || query.isEmpty) return;
    try {
      final value = await w.query(
        '/messages/forward/targets/search',
        query: {'q': query, 'limit': 20},
      );
      if (!current || ticket != request) return;
      setState(() {
        targets = (value['targets'] as List)
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        loading = false;
      });
    } catch (e) {
      if (!current || ticket != request) return;
      denied(e);
      if (current) {
        setState(() {
          targets = [];
          loading = false;
          error = '$e';
        });
      }
    }
  }

  void denied(Object e) {
    if (e is RaftApiException && [401, 403].contains(e.status)) closeOwned();
  }

  Future<void> prepare(Map<String, dynamic> target) async {
    if (!current || busy || attempt != null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (target['requiredAction'] == 'join_channel' &&
          target['channelId'] is String) {
        await w.command('POST', '/channels/${target['channelId']}/join');
      } else if (target['requiredAction'] == 'create_dm' &&
          ['human', 'agent'].contains(target['type'])) {
        await w.command(
          'POST',
          '/channels/dm',
          data: {
            target['type'] == 'human' ? 'userId' : 'agentId': target['id'],
          },
        );
      } else {
        throw const RaftApiException(
          'This target is not available. Search again.',
        );
      }
      if (current) await loadTargets();
    } catch (e) {
      if (current) {
        denied(e);
        if (current) setState(() => error = '$e');
      }
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  Future<void> send() async {
    if (!current || busy || selected.isEmpty) return;
    attempt ??= ForwardAttempt(
      requestId: w.client.newRandomId(),
      sources: widget.messages.map((m) => m.id).toList(),
      destinations: selected.keys.toList(),
      note: note.text,
    );
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await w.command(
        'POST',
        '/messages/forward',
        data: attempt!.payload,
      );
      if (!current) return;
      attempt!.apply(response);
      setState(() {});
      if (mounted && attempt!.completed && ownedRoute?.isCurrent == true) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (current) {
        denied(e);
        if (current) setState(() => error = '$e');
      }
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(raftText(context, 'Forward messages')),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.messages.length} ${raftText(context, 'messages')}'),
            TextField(
              controller: note,
              enabled: attempt == null && !busy,
              maxLength: 4000,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: raftText(context, 'Optional note'),
              ),
            ),
            if (attempt == null)
              TextField(
                controller: search,
                enabled: !busy,
                onChanged: changedSearch,
                decoration: InputDecoration(
                  labelText: raftText(context, 'Search channels or people'),
                ),
              ),
            if (error != null) Semantics(liveRegion: true, child: Text(error!)),
            // ds-allow: reserves the progress bar's height so it appearing never moves the rows.
            SizedBox(
              height: 4,
              child: loading ? const LinearProgressIndicator() : null,
            ),
            Expanded(
              child: ListView(
                children: [
                  if (attempt == null && selected.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      children: [
                        for (final entry in selected.entries)
                          InputChip(
                            label: Text('${entry.value['title']}'),
                            onDeleted: busy
                                ? null
                                : () => setState(
                                    () => selected.remove(entry.key),
                                  ),
                          ),
                      ],
                    ),
                  if (attempt == null)
                    for (final target in targets)
                      if (target['canForwardNow'] == true &&
                          target['channelId'] is String)
                        CheckboxListTile(
                          title: Text('${target['title']}'),
                          subtitle: Text('${target['subtitle'] ?? ''}'),
                          value: selected.containsKey(target['channelId']),
                          onChanged: busy
                              ? null
                              : (value) => setState(() {
                                  if (value == true) {
                                    if (selected.length >= 10) {
                                      error = 'Select up to 10 destinations.';
                                      return;
                                    }
                                    selected[target['channelId']] = target;
                                  } else {
                                    selected.remove(target['channelId']);
                                  }
                                }),
                        )
                      else
                        ListTile(
                          title: Text('${target['title']}'),
                          subtitle: Text('${target['subtitle'] ?? ''}'),
                          trailing:
                              [
                                'join_channel',
                                'create_dm',
                              ].contains(target['requiredAction'])
                              ? TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => prepare(target),
                                  child: Text(
                                    raftText(
                                      context,
                                      target['requiredAction'] == 'join_channel'
                                          ? 'Join channel'
                                          : 'Create direct message',
                                    ),
                                  ),
                                )
                              : null,
                        ),
                  if (attempt != null)
                    for (final id in attempt!.destinations)
                      ListTile(
                        title: Text('${selected[id]?['title'] ?? ''}'),
                        leading: Icon(
                          attempt!.outcomes[id] == 'success'
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                        ),
                        subtitle: Text(
                          attempt!.outcomes[id] == 'success'
                              ? raftText(context, 'Forwarded')
                              : attempt!.errors[id] ??
                                    raftText(context, 'Awaiting confirmation'),
                        ),
                      ),
                ],
              ),
            ),
            if (attempt != null)
              Text(
                raftText(
                  context,
                  'Retry keeps the same messages, note and destinations. Confirmed destinations will not be duplicated.',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: Text(raftText(context, 'Cancel')),
        ),
        RaftButton(
          label: raftText(context, attempt == null ? 'Forward' : 'Retry'),
          busy: busy,
          onPressed: busy || selected.isEmpty ? null : send,
        ),
      ],
    ),
  );
}
