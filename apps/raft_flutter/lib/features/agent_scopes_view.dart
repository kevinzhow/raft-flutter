import 'page_layout.dart';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart'
    show pageIdentity, readPageSnapshot, writePageSnapshot;

/// Whole-set scope updates. Default mode remains distinct from a custom set
/// that happens to contain all currently known scopes.
class AgentScopesView extends StatefulWidget {
  const AgentScopesView({
    super.key,
    required this.controller,
    required this.agentId,
  });
  final WorkspaceController controller;
  final String agentId;
  @override
  State<AgentScopesView> createState() => _AgentScopesViewState();
}

class _AgentScopesViewState extends State<AgentScopesView> {
  late final int generation;
  final names = const {
    'inbox:receive': 'Receive messages and wake notifications',
    'server:read': 'Read server information',
    'server:update': 'Update server settings',
    'channel:read': 'Read channel membership',
    'channel:create': 'Create channels',
    'channel:update': 'Update channels',
    'channel:add_member': 'Add channel members',
    'channel:remove_member': 'Remove channel members',
    'channel:join': 'Join channels',
    'channel:leave': 'Leave channels',
    'thread:unfollow': 'Unfollow threads',
    'message:read': 'Read and search messages',
    'message:send': 'Send messages',
    'attachment:upload': 'Upload attachments',
    'attachment:view': 'View attachments',
    'task:read': 'Read tasks',
    'task:write': 'Create and manage tasks',
    'knowledge:read': 'Read the Raft manual',
    'action:prepare': 'Prepare action cards',
  };
  Set<String> scopes = {};
  String mode = 'default';
  bool loading = true, busy = false;

  /// Permissions have been accepted at least once (snapshot or a read).
  bool loaded = false;

  /// Unsaved checkbox edits; a background revalidation never overwrites them.
  bool edited = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Clears on a successful read, on Retry and when a save starts; the page is a route per agent and is disposed on navigation.
  String? error;
  String get path => '/agents/${widget.agentId}/scopes';
  String get snapshotKey => 'agent-scopes:${widget.agentId}';
  @override
  void initState() {
    super.initState();
    generation = widget.controller.client.generation;
    // Revisit: the accepted permissions render at once and revalidate quietly.
    final snapshot = readPageSnapshot(widget.controller, snapshotKey);
    if (snapshot != null) {
      scopes = Set.of(snapshot['scopes'] as Set<String>);
      mode = snapshot['mode'] as String;
      loading = false;
      loaded = true;
    }
    load();
  }

  Future<void> load() async {
    final identity = pageIdentity(widget.controller);
    try {
      final value = await widget.controller.query(path);
      if (generation != widget.controller.client.generation ||
          identity != pageIdentity(widget.controller)) {
        return;
      }
      final granted = (value['granted'] as List).cast<String>().toSet();
      final String nextMode = value['mode'];
      writePageSnapshot(widget.controller, snapshotKey, identity, {
        'scopes': Set<String>.unmodifiable(granted),
        'mode': nextMode,
      });
      if (!mounted) return;
      setState(() {
        if (!edited) {
          scopes = granted;
          mode = nextMode;
        }
        loading = false;
        loaded = true;
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = userErrorText(
            e,
            fallback: 'Failed to load agent permissions',
            where: 'agent scopes load',
          );
        });
      }
    }
  }

  Future<void> save({bool defaults = false}) async {
    if (busy || generation != widget.controller.client.generation) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.controller.command(
        'PUT',
        path,
        data: defaults
            ? {'mode': 'default'}
            : {'scopes': scopes.toList()..sort()},
      );
      edited = false;
      await load();
      if (mounted) {
        showRaftToast(
          context,
          'Agent permissions saved',
          tone: RaftToastRecipeTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = userErrorText(
            e,
            fallback: defaults
                ? 'Failed to reset agent permissions'
                : 'Failed to save agent permissions',
            where: 'agent scopes save',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: raftPageAppBar(
      context,
      title: raftText(context, 'Agent permissions'),
    ),
    body: loading
        ? const Center(child: RaftSpinner())
        : error != null && !loaded
        ? RaftLoadError(
            error!,
            onRetry: () {
              setState(() {
                loading = true;
                error = null;
              });
              load();
            },
          )
        : ListView(
            key: const Key('agent-scope-list'),
            padding: raftScrollPadding(context, const EdgeInsets.all(24)),
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: RaftSpace.x3),
                  child: RaftErrorBanner(error!),
                ),
              Text(
                raftText(
                  context,
                  mode == 'default'
                      ? 'Default permissions'
                      : 'Custom permissions',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                raftText(
                  context,
                  'Custom permissions keep future capabilities disabled until you enable them. Identity, personal profile and reminders remain available.',
                ),
              ),
              for (final scope in {...names.keys, ...scopes})
                RaftCheckboxRow(
                  key: ValueKey('scope-$scope'),
                  title: raftText(context, names[scope] ?? scope),
                  description: scope,
                  value: scopes.contains(scope),
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          edited = true;
                          if (value == true) {
                            scopes.add(scope);
                          } else {
                            scopes.remove(scope);
                          }
                          mode = 'custom';
                        }),
                ),
              Wrap(
                spacing: 12,
                children: [
                  RaftButton(
                    label: 'Save Permissions',
                    busy: busy,
                    onPressed: save,
                  ),
                  RaftButton.text(
                    onPressed: busy ? null : () => save(defaults: true),
                    child: Text(
                      raftText(context, 'Restore Default Permissions'),
                    ),
                  ),
                ],
              ),
            ],
          ),
  );
}
