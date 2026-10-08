import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

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
    'server:read': 'Read workspace information',
    'server:update': 'Update workspace settings',
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
  String? error;
  String get path => '/agents/${widget.agentId}/scopes';
  @override
  void initState() {
    super.initState();
    generation = widget.controller.client.generation;
    load();
  }

  Future<void> load() async {
    try {
      final value = await widget.controller.query(path);
      if (!mounted || generation != widget.controller.client.generation) return;
      setState(() {
        scopes = (value['granted'] as List).cast<String>().toSet();
        mode = value['mode'];
        loading = false;
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
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
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            showCloseIcon: true,
            content: Text(raftText(context, 'Agent permissions saved')),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(raftText(context, 'Agent permissions'))),
    body: loading
        ? Center(child: CircularProgressIndicator())
        : ListView(
            key: const Key('agent-scope-list'),
            padding: const EdgeInsets.all(24),
            children: [
              if (error != null)
                Semantics(liveRegion: true, child: Text(error!)),
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
                CheckboxListTile(
                  key: ValueKey('scope-$scope'),
                  title: Text(raftText(context, names[scope] ?? scope)),
                  subtitle: Text(scope),
                  value: scopes.contains(scope),
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
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
                    label: 'Save permissions',
                    busy: busy,
                    onPressed: save,
                  ),
                  TextButton(
                    onPressed: busy ? null : () => save(defaults: true),
                    child: Text(
                      raftText(context, 'Restore default permissions'),
                    ),
                  ),
                ],
              ),
            ],
          ),
  );
}
