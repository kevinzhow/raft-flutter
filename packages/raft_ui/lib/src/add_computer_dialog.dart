// Web packages/web/src/components/machine/AddMachineDialog.tsx +
// ComputerCommandGuide.tsx (raft-source 26f77ef): "Add Computer" (choose
// Your Computer / Cloud Computer), then "Connect Computer" (install + setup
// commands per platform while waiting), then "Computer Connected" (name it).
// The app performs the requests through the callbacks.
import 'dart:async';

import 'package:flutter/material.dart';

import '../raft_ui.dart';

import 'package:raft_theme/recipes.dart' show RaftRecipeSet;

class RaftAddComputerConnection {
  const RaftAddComputerConnection({
    required this.hostname,
    this.os,
    this.requiresConfirmation = false,
  });
  final String hostname;
  final String? os;
  final bool requiresConfirmation;
  bool get loadingDetails =>
      hostname.trim().isEmpty || (os ?? '').trim().isEmpty;
}

class RaftAddComputerDialog extends StatefulWidget {
  const RaftAddComputerDialog({
    super.key,
    required this.commandsFor,
    this.installAndSetupFor,
    required this.register,
    required this.cancel,
    required this.done,
    this.connected,
    this.onViewPlans,
  });

  /// Web `nav.toSettings("billing")` for the quota error's View Plans link.
  final VoidCallback? onViewPlans;

  /// (install, setup) for macOS/Linux or Windows; null without a slug.
  final (String, String)? Function(bool windows) commandsFor;

  /// mac/Linux production one-paste install + setup (Web
  /// `ComputerCommands.installAndSetup`); null keeps the two steps.
  final String? Function(bool windows)? installAndSetupFor;

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
    return showRaftDialog<void>(
      legacyMaterial: true,
      context: context,
      barrierDismissible: false,
      legacyBarrierColor: t.colors['layer-backdrop'],
      builder: builder,
    );
  }

  /// The same backdrop painted inline (fixture captures of the open modal).
  static Widget backdrop(BuildContext context, Widget dialog) {
    final t = RaftTokens.of(context);
    if (t.recipeSet != RaftRecipeSet.legacy) {
      return RaftDialogBackdrop(child: dialog);
    }
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: t.colors['layer-backdrop']!)),
        dialog,
      ],
    );
  }

  @override
  State<RaftAddComputerDialog> createState() => _RaftAddComputerDialogState();
}

/// Web `WAITING_HINT_DELAY_MS`: how long "waiting for computer" runs before the
/// dialog points at the terminal (the browser cannot see a failed install).
const raftAddComputerWaitingHintDelay = Duration(seconds: 45);

class _RaftAddComputerDialogState extends State<RaftAddComputerDialog> {
  bool waiting = false, registering = false, waitingStalled = false;
  final stalledTimer = RaftIdleTimer(yieldToAnimation: false);
  bool confirmedComputerMatch = false, saving = false;
  bool nameEdited = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next register attempt starts; the dialog state is dropped when it closes.
  String error = '';
  String platform = 'mac-linux';
  final name = TextEditingController();

  bool get connectedStep => widget.connected != null;
  bool get canFinish =>
      connectedStep &&
      !widget.connected!.loadingDetails &&
      !(widget.connected!.requiresConfirmation && !confirmedComputerMatch);

  @override
  void initState() {
    super.initState();
    name.text = widget.connected?.hostname ?? '';
  }

  @override
  void didUpdateWidget(RaftAddComputerDialog old) {
    super.didUpdateWidget(old);
    if (old.connected == null && widget.connected != null) {
      confirmedComputerMatch = false;
    }
    if (!nameEdited && old.connected?.hostname != widget.connected?.hostname) {
      name.text = widget.connected?.hostname ?? '';
    }
  }

  @override
  void dispose() {
    stalledTimer.cancel();
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
      if (mounted) {
        setState(() => waiting = true);
        stalledTimer.start(raftAddComputerWaitingHintDelay, () {
          if (mounted) setState(() => waitingStalled = true);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = RaftErrorScope.of(context)(
            e,
            fallback: 'Failed to register computer',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => registering = false);
    }
  }

  Future<void> cancel() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = '';
    });
    try {
      await widget.cancel();
      if (mounted) Navigator.of(context).pop();
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = RaftErrorScope.of(context)(
            failure,
            fallback: 'Could not finish computer setup.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> done() async {
    if (!canFinish || saving) return;
    setState(() {
      saving = true;
      error = '';
    });
    try {
      await widget.done(name.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = RaftErrorScope.of(context)(
            failure,
            fallback: 'Could not finish computer setup.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final title = connectedStep
        ? 'Computer Connected'
        : waiting
        ? 'Connect Computer'
        : 'Add Computer';
    // Escape and the system back gesture leave through the same path as the
    // X: `cancel` releases an unconnected registration, `done` names the
    // connected Computer.
    void leave() {
      if (!saving) unawaited(canFinish ? done() : cancel());
    }

    return RaftDismissScope(
      onDismiss: leave,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) leave();
        },
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RaftDialog.card(
                key: const ValueKey('computer-dialog'),
                title: title,
                // Card `max-w-lg p-6`.
                maxWidth: 512,
                onClose: leave,
                child: connectedStep
                    ? _connectedStep(t)
                    : waiting
                    ? _waitingStep(t)
                    : _typeStep(t),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _errorBanner() => [
    if (error.isNotEmpty) ...[
      // Web `<Banner intent="warning" className="mb-4 font-bold">`; a quota
      // error ("... limit reached") adds the inline View Plans link.
      RaftBanner(
        description: raftText(context, error),
        descriptionWeight: FontWeight.w700,
        descriptionTail: error.contains('limit reached')
            ? (
                label: raftText(context, 'View Plans'),
                onPressed: () {
                  Navigator.of(context).maybePop();
                  widget.onViewPlans?.call();
                },
              )
            : null,
        descriptionTailWeight: FontWeight.w700,
      ),
      const SizedBox(height: 16),
    ],
  ];

  Widget _typeStep(RaftTokens t) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ..._errorBanner(),
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
            disabled: saving,
            onPressed: cancel,
          ),
          const SizedBox(width: 12),
          RaftRecipeButton(
            key: const ValueKey('add-computer-next'),
            label: registering ? 'Setting Up…' : 'Next',
            variant: RaftButtonRecipeVariant.accent,
            size: RaftButtonRecipeSize.md,
            disabled: registering || saving,
            onPressed: next,
          ),
        ],
      ),
    ],
  );

  Widget _waitingStep(RaftTokens t) {
    return Column(
      key: const ValueKey('add-computer-waiting'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._errorBanner(),
        RaftComputerCommandGuide(
          platform: platform,
          onPlatform: (v) => setState(() => platform = v),
          commands: widget.commandsFor(platform == 'windows'),
          installAndSetup: widget.installAndSetupFor?.call(
            platform == 'windows',
          ),
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
              border: Border.all(color: t.colors['line-strong']!),
            ),
          ),
        ),
        if (waitingStalled) ...[
          const SizedBox(height: 8),
          // `-mt-2 mb-4 text-footnote text-foreground-muted`.
          Text(
            raftText(
              context,
              'Still waiting? Check the terminal where you ran the command. If it says Raft Computer is already running, or the install failed, use "Already have Raft Computer on this machine?" above.',
            ),
            key: const ValueKey('add-computer-still-waiting'),
            style: RaftTypography.body(
              t,
              size: 12,
              line: 20,
              color: raftPanelInk(t, .6, t.colors['foreground-muted']!),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            RaftRecipeButton(
              label: saving ? 'Canceling...' : 'Cancel',
              variant: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.md,
              disabled: saving,
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
        ..._errorBanner(),
        if (m!.loadingDetails)
          const RaftBanner(
            key: ValueKey('add-computer-details-loading'),
            status: RaftBannerRecipeStatus.info,
            description: 'Loading computer details...',
          )
        else
          RaftBanner(
            status: RaftBannerRecipeStatus.success,
            title: 'Computer connected successfully!',
            description: '${m.hostname} — ${m.os}',
          ),
        const SizedBox(height: 16),
        RaftRecipeInput(
          controller: name,
          placeholder: m.hostname.trim().isEmpty ? 'Computer name' : m.hostname,
          autofocus: true,
          enabled: !saving,
          onChanged: (_) => nameEdited = true,
        ),
        const SizedBox(height: 16),
        if (m.requiresConfirmation) ...[
          _confirmComputer(t, m),
          const SizedBox(height: 16),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: RaftRecipeButton(
            label: saving ? 'Saving...' : 'Done',
            variant: RaftButtonRecipeVariant.success,
            size: RaftButtonRecipeSize.md,
            disabled: saving || !canFinish,
            onPressed: done,
          ),
        ),
      ],
    );
  }

  Widget _confirmComputer(RaftTokens t, RaftAddComputerConnection computer) {
    final label = raftFormat(
      context,
      'This is the computer I just set up{hostname}.',
      {'hostname': computer.hostname.isEmpty ? '' : ' (${computer.hostname})'},
    );
    void change(bool value) => setState(() => confirmedComputerMatch = value);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => change(!confirmedComputerMatch),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.colors['layer-panel'],
          border: Border.all(color: t.colors['line-muted']!, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RaftCheckbox(
              key: const ValueKey('add-computer-confirm-match'),
              value: confirmedComputerMatch,
              onChanged: change,
              semanticLabel: label,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: RaftTypography.body(
                  t,
                  size: 14,
                  line: 20,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ComputerCommandGuide.tsx: "Connect command" header with the platform
/// segmented control, the platform description, and the install / setup
/// [RaftCopyableCode] rows. [commands] is (install, setup) of the selected
/// platform; null renders the "generate a fresh command" notice.
class RaftComputerCommandGuide extends StatefulWidget {
  const RaftComputerCommandGuide({
    super.key,
    required this.platform,
    required this.onPlatform,
    required this.commands,
    this.installAndSetup,
  });
  final String platform;
  final ValueChanged<String> onPlatform;
  final (String, String)? commands;

  /// When set on macOS / Linux, the guide shows this single install-then-setup
  /// command instead of the separate install and setup steps.
  final String? installAndSetup;

  @override
  State<RaftComputerCommandGuide> createState() =>
      _RaftComputerCommandGuideState();
}

class _RaftComputerCommandGuideState extends State<RaftComputerCommandGuide> {
  /// The "Already have Raft Computer on this machine?" disclosure: the
  /// one-line command installs first and only connects if that succeeds, so a
  /// machine that already runs it could never get past "waiting" without the
  /// connect-only command (Web bug-triage task #22).
  bool showConnectOnly = false;

  String get platform => widget.platform;
  String? get installAndSetup => widget.installAndSetup;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, box) => _build(context, box.maxWidth));

  Widget _build(BuildContext context, double available) {
    final t = RaftTokens.of(context);
    final c = widget.commands;
    final windows = platform == 'windows';
    // Tailwind `sm` (640px viewport); a guide in a host too narrow for the
    // heading beside the platform control stacks them instead of overflowing.
    // The 0.7.0 segmented control is wider (12px item padding, 14px semibold), so
    // the Raft look stacks earlier; the frozen looks keep 380.
    final stackBelow = t.recipeSet == RaftRecipeSet.legacy ? 380 : 560;
    final narrow =
        MediaQuery.sizeOf(context).width < 640 || available < stackBelow;
    final heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftIcon(
          RaftGlyph.terminal,
          size: 16,
          color: t.colors['foreground-strong'],
        ),
        const SizedBox(width: 8),
        const Flexible(child: RaftSectionEyebrow('Connect command')),
      ],
    );
    final note = RaftTypography.body(
      t,
      size: 12,
      line: 20,
      color: t.colors['foreground-muted'],
    );
    final label = RaftTypography.body(
      t,
      size: 12,
      line: 16,
      weight: FontWeight.w700,
      color: t.colors['foreground-muted'],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: `flex-col items-start gap-2 sm:flex-row sm:items-center
        // sm:justify-between`.
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
              onChanged: widget.onPlatform,
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
              ? 'Install Raft Computer from PowerShell, then connect this Windows x64 computer to the server.'
              : 'Install the Raft Computer CLI on this macOS or Linux computer, then connect it to this server.',
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
        if (c != null && !windows && installAndSetup != null) ...[
          // One displayed step: no step label, and the generic CLI copy label.
          RaftCopyableCode(
            installAndSetup!,
            copyLabel: 'Copy Computer CLI command',
          ),
          const SizedBox(height: 8),
          RaftUnderlineTextButton(
            key: const ValueKey('computer-command-already-installed'),
            label: raftText(
              context,
              'Already have Raft Computer on this machine?',
            ),
            style: RaftTypography.body(
              t,
              size: 12,
              line: 16,
              weight: FontWeight.w600,
              color: t.colors['foreground'],
            ),
            onPressed: () => setState(() => showConnectOnly = !showConnectOnly),
          ),
          if (showConnectOnly) ...[
            const SizedBox(height: 8),
            Column(
              key: const ValueKey('computer-command-connect-only'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  raftText(
                    context,
                    'Skip the install and only connect it to this server. If raft-computer is not found, run it as ~/.local/bin/raft-computer.',
                  ),
                  style: note,
                ),
                const SizedBox(height: 8),
                RaftCopyableCode(c.$2, copyLabel: 'Copy 2. setup command'),
              ],
            ),
          ],
        ] else if (c != null)
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
      ],
    );
  }
}
