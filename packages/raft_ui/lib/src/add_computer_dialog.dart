// Web packages/web/src/components/machine/AddMachineDialog.tsx +
// ComputerCommandGuide.tsx (raft-source 26f77ef): "Add Computer" (choose
// Your Computer / Cloud Computer), then "Connect Computer" (install + setup
// commands per platform while waiting), then "Computer Connected" (name it).
// The app performs the requests through the callbacks.
import 'package:flutter/material.dart';

import '../raft_ui.dart';

class RaftAddComputerConnection {
  const RaftAddComputerConnection({required this.hostname, this.os});
  final String hostname;
  final String? os;
}

class RaftAddComputerDialog extends StatefulWidget {
  const RaftAddComputerDialog({
    super.key,
    required this.commandsFor,
    required this.register,
    required this.cancel,
    required this.done,
    this.connected,
  });

  /// (install, setup) for macOS/Linux or Windows; null without a slug.
  final (String, String)? Function(bool windows) commandsFor;

  /// Registers the placeholder row ("Next"); throws
  /// [RaftComputerActionError] with the copy to show.
  final Future<void> Function() register;

  /// Leaves the flow, releasing an unconnected registration.
  final Future<void> Function() cancel;

  /// Names the connected Computer and closes.
  final Future<void> Function(String name) done;

  /// The registered Computer once it is online (switches to the last step).
  final RaftAddComputerConnection? connected;

  /// Web `Modal`: `bg-layer-backdrop theme-brutal:bg-black/60`, not
  /// dismissed by the backdrop.
  static Future<void> show(BuildContext context, WidgetBuilder builder) {
    final t = RaftTokens.of(context);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: t.brutal
          ? Colors.black.withValues(alpha: .6)
          : t.colors['layer-backdrop'],
      builder: builder,
    );
  }

  /// The same backdrop painted inline (fixture captures of the open modal).
  static Widget backdrop(BuildContext context, Widget dialog) {
    final t = RaftTokens.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: t.brutal
                ? Colors.black.withValues(alpha: .6)
                : t.colors['layer-backdrop']!,
          ),
        ),
        dialog,
      ],
    );
  }

  @override
  State<RaftAddComputerDialog> createState() => _RaftAddComputerDialogState();
}

class _RaftAddComputerDialogState extends State<RaftAddComputerDialog> {
  bool waiting = false, registering = false;
  String error = '';
  String platform = 'mac-linux';
  final name = TextEditingController();

  bool get connectedStep => widget.connected != null;

  @override
  void didUpdateWidget(RaftAddComputerDialog old) {
    super.didUpdateWidget(old);
    if (old.connected == null && widget.connected != null) {
      name.text = widget.connected!.hostname;
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> next() async {
    setState(() {
      registering = true;
      error = '';
    });
    try {
      await widget.register();
      if (mounted) setState(() => waiting = true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is RaftComputerActionError
              ? e.message
              : 'Failed to register computer',
        );
      }
    } finally {
      if (mounted) setState(() => registering = false);
    }
  }

  Future<void> cancel() async {
    await widget.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> done() async {
    await widget.done(name.text.trim());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final title = connectedStep
        ? 'Computer Connected'
        : waiting
        ? 'Connect Computer'
        : 'Add Computer';
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
            onClose: connectedStep ? done : cancel,
            child: connectedStep
                ? _connectedStep(t)
                : waiting
                ? _waitingStep(t)
                : _typeStep(t),
          ),
        ),
      ),
    );
  }

  Widget _typeStep(RaftTokens t) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (error.isNotEmpty) ...[
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
            disabled: registering,
            onPressed: next,
          ),
        ],
      ),
    ],
  );

  Widget _waitingStep(RaftTokens t) {
    final c = widget.commandsFor(platform == 'windows');
    final windows = platform == 'windows';
    // Tailwind `sm` (640px viewport).
    final narrow = MediaQuery.sizeOf(context).width < 640;
    final heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftIcon(
          RaftGlyph.terminal,
          size: 16,
          color: t.brutal ? Colors.black : t.colors['foreground-strong'],
        ),
        const SizedBox(width: 8),
        const Flexible(child: RaftSectionEyebrow('Connect command')),
      ],
    );
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
        // platform SegmentedControl (`flex-col items-start gap-2
        // sm:flex-row sm:items-center sm:justify-between`).
        Flex(
          direction: narrow ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: narrow
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (narrow) heading else Expanded(child: heading),
            SizedBox(width: narrow ? 0 : 12, height: narrow ? 8 : 0),
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
              RaftCopyableCode(c.$1, copyLabel: 'Copy 1. install command'),
              const SizedBox(height: 12),
              Text('2. Setup', style: label),
              const SizedBox(height: 4),
              RaftCopyableCode(c.$2, copyLabel: 'Copy 2. setup command'),
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
    final m = widget.connected;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftBanner(
          status: RaftBannerRecipeStatus.success,
          title: 'Computer connected successfully!',
          description: '${m?.hostname ?? ''} — ${m?.os ?? 'Unknown OS'}',
        ),
        const SizedBox(height: 16),
        RaftRecipeInput(
          controller: name,
          placeholder: m?.hostname ?? 'My Mac',
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
