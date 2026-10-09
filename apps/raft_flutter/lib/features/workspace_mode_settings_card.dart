import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_mode_store.dart';

/// The settings consumer of the actual availability and personal preference.
/// The workspace host can share its store; standalone settings own its lifetime.
class WorkspaceModeSettingsCard extends StatefulWidget {
  const WorkspaceModeSettingsCard({
    super.key,
    required this.controller,
    this.store,
    this.onBeforeChange,
  });
  final WorkspaceController controller;
  final WorkspaceModeStore? store;
  final VoidCallback? onBeforeChange;
  @override
  State<WorkspaceModeSettingsCard> createState() =>
      _WorkspaceModeSettingsCardState();
}

class _WorkspaceModeSettingsCardState extends State<WorkspaceModeSettingsCard> {
  late WorkspaceModeStore store;
  void bind() => store = widget.store ?? WorkspaceModeStore(widget.controller);
  void release(WorkspaceModeSettingsCard owner) {
    if (owner.store == null) store.dispose();
  }

  @override
  void initState() {
    super.initState();
    bind();
  }

  @override
  void didUpdateWidget(WorkspaceModeSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.store != widget.store) {
      release(oldWidget);
      bind();
    }
  }

  @override
  void dispose() {
    release(widget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      if (!store.showCard) return const SizedBox.shrink();
      final authority = store.authority;
      return RaftWorkspaceModeCard(
        enabled: store.enabled,
        onChanged: (value) {
          if (!mounted || store.authority != authority || !store.showCard) {
            return;
          }
          widget.onBeforeChange?.call();
          store.setEnabled(value, capturedAuthority: authority);
        },
      );
    },
  );
}
