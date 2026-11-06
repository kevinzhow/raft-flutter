import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/linux_dependencies.dart';
import 'linux_dependency_notice.dart';

class LinuxDependenciesSettings extends StatefulWidget {
  const LinuxDependenciesSettings({super.key, this.service});
  final LinuxDependencies? service;
  @override
  State<LinuxDependenciesSettings> createState() =>
      _LinuxDependenciesSettingsState();
}

class _LinuxDependenciesSettingsState extends State<LinuxDependenciesSettings> {
  LinuxDependencies get service => widget.service ?? LinuxDependencies.instance;
  bool checking = false;

  @override
  void initState() {
    super.initState();
    // The first view reads known status only; it does not load feature plugins.
    unawaited(service.inspect());
  }

  Future<void> check() async {
    if (checking) return;
    setState(() => checking = true);
    try {
      await service.checkAll();
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) => RaftGapColumn(
      gap: RaftSpace.x4,
      children: [
        const RaftSettingsSectionHeader(
          label: 'System dependencies',
          glyph: RaftGlyph.monitor,
        ),
        Text(
          raftText(
            context,
            'These optional system packages enable attachment previews. Chat and other features work without them.',
          ),
        ),
        RaftButton(
          key: const Key('linux-dependencies-check'),
          label: 'Check dependencies',
          busy: checking,
          onPressed: checking ? null : check,
        ),
        for (final feature in LinuxDependency.values) ...[
          Text(raftText(context, linuxDependencyName(feature))),
          Text(
            raftText(context, switch (service.state(feature).status) {
              LinuxDependencyStatus.unchecked => 'Not checked',
              LinuxDependencyStatus.available => 'Available',
              LinuxDependencyStatus.missing => 'Unavailable',
            }),
            key: Key(
              'linux-dependency-status-${feature.name}-${service.state(feature).status.name}',
            ),
          ),
          if (service.state(feature).status == LinuxDependencyStatus.missing)
            LinuxDependencyNotice(
              feature: feature,
              service: service,
              busy: checking,
              onRetry: check,
            ),
        ],
      ],
    ),
  );
}
