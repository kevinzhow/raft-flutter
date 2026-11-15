// The Computer page's Owner value (Web v1.24 features/computer/
// ComputerOwnerField.tsx): who Raft records as the owner (an avatar, the
// display name and the @handle, a button that opens their profile) or Public,
// then Transfer owner and Make it mine when the viewer may. The page
// decides who may; this draws the row and the claim's loading state.
import 'dart:async';

import 'package:flutter/material.dart';

import '../raft_ui.dart';

/// The owner shown in the row (`machine.owner`).
class RaftComputerOwner {
  const RaftComputerOwner({
    required this.name,
    required this.handle,
    this.avatarUrl,
  });
  final String name, handle;
  final String? avatarUrl;
}

/// The row's value: `flex flex-wrap items-center gap-2`.
class RaftComputerOwnerValue extends StatefulWidget {
  const RaftComputerOwnerValue({
    super.key,
    required this.owner,
    this.openOwner,
    this.transfer,
    this.makeMine,
  });

  /// Null: the Computer is Public.
  final RaftComputerOwner? owner;
  final VoidCallback? openOwner;

  /// Set when the viewer may transfer the owner (shows Transfer owner).
  final VoidCallback? transfer;

  /// Set when the viewer connected this Public Computer (shows Make it mine).
  /// It reports its own failure; the button shows loading until it ends.
  final Future<void> Function()? makeMine;

  @override
  State<RaftComputerOwnerValue> createState() => _RaftComputerOwnerValueState();
}

class _RaftComputerOwnerValueState extends State<RaftComputerOwnerValue> {
  bool _claiming = false;

  Future<void> _claim() async {
    final claim = widget.makeMine;
    if (claim == null || _claiming) return;
    setState(() => _claiming = true);
    try {
      await claim();
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final strong = t.colors['foreground-strong']!;
    final hint = t.colors['foreground-hint'] ?? t.colors['foreground-muted']!;
    final owner = widget.owner;
    Widget identity() {
      if (owner == null) {
        return RaftCssText(
          'Public (no owner)',
          key: const ValueKey('computer-owner-public'),
          style: raftCssText.merge(
            RaftTypography.body(t, size: 14, line: 20, color: hint),
          ),
        );
      }
      final row = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftAvatarSlot(
            name: owner.name,
            agent: false,
            avatarUrl: owner.avatarUrl,
            slot: RaftAvatarSlotContext.creatorLink,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: RaftCssText(
              owner.name,
              style: raftCssText.merge(
                RaftTypography.body(
                  t,
                  size: 14,
                  line: 20,
                  color: strong,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          RaftCssText(
            '@${owner.handle}',
            style: raftCssText.merge(
              RaftTypography.mono(t, size: 12, line: 16, color: hint),
            ),
          ),
        ],
      );
      final open = widget.openOwner;
      return open == null
          ? row
          : RaftInteractive(
              key: const ValueKey('computer-owner'),
              onPressed: open,
              semanticLabel: '${owner.name} @${owner.handle}',
              builder: (context, state) => row,
            );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        identity(),
        if (widget.transfer case final transfer?)
          RaftButton(
            key: const ValueKey('computer-owner-transfer'),
            label: 'Transfer owner',
            tone: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.md,
            onPressed: transfer,
          ),
        if (widget.makeMine != null)
          RaftButton(
            key: const ValueKey('computer-owner-make-mine'),
            label: 'Make it mine',
            tone: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.md,
            busy: _claiming,
            onPressed: _claiming ? null : () => unawaited(_claim()),
          ),
      ],
    );
  }
}
