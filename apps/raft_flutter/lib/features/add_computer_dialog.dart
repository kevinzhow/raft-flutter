// Web packages/web/src/components/machine/AddMachineDialog.tsx +
// ComputerCommandGuide.tsx (raft-source 26f77ef): "Add Computer" (choose
// Your Computer / Cloud Computer), then "Connect Computer" (install + setup
// commands per platform while waiting for the Computer to connect).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'computer_setup_commands.dart';

/// Opens the Add Computer flow the Web mounts from the Computers rail `+`.
Future<void> showAddComputerDialog(
  BuildContext context,
  WorkspaceController w, {
  String deployment = const String.fromEnvironment(
    'RAFT_DEPLOYMENT_ENV',
    defaultValue: 'production',
  ),
}) {
  final t = RaftTokens.of(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    // Modal: `bg-layer-backdrop theme-brutal:bg-black/60`.
    barrierColor: t.brutal
        ? Colors.black.withValues(alpha: .6)
        : t.colors['layer-backdrop'],
    builder: (_) => AddComputerDialog(controller: w, deployment: deployment),
  );
}

class AddComputerDialog extends StatefulWidget {
  const AddComputerDialog({
    super.key,
    required this.controller,
    this.deployment = 'production',
  });
  final WorkspaceController controller;
  final String deployment;
  @override
  State<AddComputerDialog> createState() => _AddComputerDialogState();
}

enum _Step { type, waiting, connected }

class _AddComputerDialogState extends State<AddComputerDialog> {
  WorkspaceController get w => widget.controller;
  _Step step = _Step.type;
  bool registering = false;
  String error = '';
  String? registeredId;
  String platform = 'mac-linux';
  Map<String, dynamic>? connected;
  final name = TextEditingController();

  @override
  void initState() {
    super.initState();
    w.entityDirectory.addListener(_directoryChanged);
  }

  @override
  void dispose() {
    w.entityDirectory.removeListener(_directoryChanged);
    name.dispose();
    super.dispose();
  }

  /// useComputerConnectionWatch: the registered row coming online.
  void _directoryChanged() {
    if (!mounted || step != _Step.waiting || registeredId == null) return;
    final row = w.entityDirectory.computer(registeredId!);
    if (row != null && row['status'] == 'online') {
      setState(() {
        connected = row;
        step = _Step.connected;
        name.text = '${row['hostname'] ?? ''}';
      });
    }
  }

  int get maxMachines => switch (w.server?.string('plan')) {
    'free' => 1,
    _ => -1,
  };

  Future<void> next() async {
    setState(() {
      registering = true;
      error = '';
    });
    try {
      final result = await w.command(
        'POST',
        '/servers/${w.server!.id}/machines',
        data: {'name': 'my-computer'},
      );
      final machine = result is Map ? result['machine'] : null;
      if (machine is! Map || machine['id'] is! String) {
        throw const RaftApiException('Failed to register computer');
      }
      registeredId = machine['id'] as String;
      if (mounted) setState(() => step = _Step.waiting);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is RaftApiException && e.message.isNotEmpty
              ? e.message
              : 'Failed to register computer',
        );
      }
    } finally {
      if (mounted) setState(() => registering = false);
    }
  }

  Future<void> cancel() async {
    final id = registeredId;
    if (id != null && step != _Step.connected) {
      try {
        await w.command('DELETE', '/servers/${w.server!.id}/machines/$id');
      } catch (_) {
        // Best effort, like the Web dialog.
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> done() async {
    final id = registeredId;
    final finalName = name.text.trim();
    if (id != null && finalName.isNotEmpty && finalName != 'my-computer') {
      try {
        await w.command(
          'PATCH',
          '/servers/${w.server!.id}/machines/$id',
          data: {'name': finalName},
        );
      } catch (_) {}
    }
    unawaited(
      w.entityDirectory.refresh(WorkspaceEntityKind.computers, force: true),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final machines = w.entityDirectory
        .rows(WorkspaceEntityKind.computers)
        .length;
    final atLimit = maxMachines != -1 && machines >= maxMachines;
    final title = switch (step) {
      _Step.type => 'Add Computer',
      _Step.waiting => 'Connect Computer',
      _Step.connected => 'Computer Connected',
    };
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: RaftDialogCard(
            key: const ValueKey('computer-dialog'),
            title: title,
            // Card `max-w-lg p-6`.
            maxWidth: 512,
            onClose: step == _Step.connected ? done : cancel,
            child: switch (step) {
              _Step.type => _typeStep(t, atLimit, machines),
              _Step.waiting => _waitingStep(t),
              _Step.connected => _connectedStep(t),
            },
          ),
        ),
      ),
    );
  }

  Widget _typeStep(RaftTokens t, bool atLimit, int machines) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (atLimit) ...[
        RaftBanner(
          description:
              'Computer limit reached ($machines/$maxMachines on Free plan). Upgrade for more',
        ),
        const SizedBox(height: 16),
      ] else if (error.isNotEmpty) ...[
        RaftBanner(description: error),
        const SizedBox(height: 16),
      ],
      Row(
        children: [
          Expanded(
            child: RaftMachineTypeOption(
              glyph: RaftGlyph.monitor,
              title: 'Your Computer',
              description: 'Run agents on your own computer',
              selected: true,
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: RaftMachineTypeOption(
              glyph: RaftGlyph.cloud,
              title: 'Cloud Computer',
              description: 'Coming soon',
              disabled: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          RaftRecipeButton(
            label: 'Cancel',
            variant: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.md,
            onPressed: cancel,
          ),
          const SizedBox(width: 12),
          RaftRecipeButton(
            key: const ValueKey('add-computer-next'),
            label: registering ? 'Setting up…' : 'Next',
            variant: RaftButtonRecipeVariant.accent,
            size: RaftButtonRecipeSize.md,
            disabled: registering || atLimit,
            onPressed: next,
          ),
        ],
      ),
    ],
  );

  Widget _waitingStep(RaftTokens t) {
    final c = ComputerCommands.build(
      slug: w.server?.string('slug') ?? '',
      serverUrl: w.client.origin,
      deployment: widget.deployment,
      windows: platform == 'windows',
    );
    final windows = platform == 'windows';
    final note = RaftTypography.body(
      t,
      size: 12,
      line: 20,
      color: t.brutal
          ? Colors.black.withValues(alpha: .6)
          : t.colors['foreground-muted'],
    );
    final label = RaftTypography.body(
      t,
      size: 12,
      line: 16,
      weight: FontWeight.w700,
      color: t.brutal
          ? Colors.black.withValues(alpha: .6)
          : t.colors['foreground-muted'],
    );
    return Column(
      key: const ValueKey('add-computer-waiting'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ComputerCommandGuide header: Terminal + "Connect command" and the
        // platform SegmentedControl (`sm:flex-row sm:justify-between`).
        Row(
          children: [
            RaftIcon(
              RaftGlyph.terminal,
              size: 16,
              color: t.brutal ? Colors.black : t.colors['foreground-strong'],
            ),
            const SizedBox(width: 8),
            const Expanded(child: RaftSectionEyebrow('Connect command')),
            const SizedBox(width: 12),
            RaftRecipeSegmentedControl<String>(
              value: platform,
              onChanged: (v) => setState(() => platform = v),
              items: const [
                ('mac-linux', null, 'macOS / Linux'),
                ('windows', null, 'Windows x64'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          windows
              ? 'Install Raft Computer from PowerShell, then connect this Windows x64 machine to the server.'
              : 'Install the Raft Computer CLI on this macOS or Linux machine, then connect it to this server.',
          style: note,
        ),
        const SizedBox(height: 8),
        if (windows) ...[
          Row(
            children: [
              Text(
                'RAFT COMPUTER · WINDOWS X64',
                style: label.copyWith(letterSpacing: .3),
              ),
              const SizedBox(width: 8),
              const RaftRecipeBadge(
                'Experimental',
                variant: RaftBadgeRecipeVariant.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (c != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('1. Install', style: label),
              const SizedBox(height: 4),
              RaftCopyableCode(c.install, copyLabel: 'Copy 1. install command'),
              const SizedBox(height: 12),
              Text('2. Setup', style: label),
              const SizedBox(height: 4),
              RaftCopyableCode(c.setup, copyLabel: 'Copy 2. setup command'),
            ],
          ),
        const SizedBox(height: 16),
        RaftBanner(
          status: RaftBannerRecipeStatus.info,
          description: 'Waiting for computer to connect...',
          // `<span className="font-bold text-foreground-strong">` after a
          // `<Status variant="warning" pulse />` dot.
          descriptionWeight: FontWeight.w700,
          leading: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.colors['warning'],
              border: Border.all(
                color: t.brutal ? Colors.black : t.colors['line-strong']!,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            RaftRecipeButton(
              label: 'Cancel',
              variant: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.md,
              onPressed: cancel,
            ),
            const SizedBox(width: 12),
            const RaftRecipeButton(
              label: 'Done',
              variant: RaftButtonRecipeVariant.success,
              size: RaftButtonRecipeSize.md,
              disabled: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _connectedStep(RaftTokens t) {
    final m = connected ?? const {};
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftBanner(
          status: RaftBannerRecipeStatus.success,
          title: 'Computer connected successfully!',
          description: '${m['hostname'] ?? ''} — ${m['os'] ?? 'Unknown OS'}',
        ),
        const SizedBox(height: 16),
        RaftRecipeInput(
          controller: name,
          placeholder: '${m['hostname'] ?? 'My Mac'}',
          autofocus: true,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: RaftRecipeButton(
            label: 'Done',
            variant: RaftButtonRecipeVariant.success,
            size: RaftButtonRecipeSize.md,
            onPressed: done,
          ),
        ),
      ],
    );
  }
}
