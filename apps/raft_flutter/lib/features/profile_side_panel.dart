import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart';
import '../data/workspace_controller.dart';
import 'agent_detail_view.dart';
import 'external_identity.dart';
import 'fleet_views.dart';
import 'member_profile_view.dart';

final _profilePanelKeys = Expando<GlobalKey>('profile panel');

/// One panel element for every shell of this workspace.
///
/// Below 768 the profile is a page of the phone navigator; above it the same
/// profile is a column of the desktop workspace. Those shells are different
/// widget trees, and each used to mint its own key, so a resize disposed the
/// panel and the edit window it had pushed. The shared key lets the framework
/// move that panel into the new tree in the same frame.
GlobalKey profilePanelKeyFor(WorkspaceController controller) =>
    _profilePanelKeys[controller] ??= GlobalKey(debugLabel: 'profile-panel');

/// Web `ConnectedProfilePanel`: the profile slot of the URL (`profile=`) as a
/// side panel (desktop column / phone page) for an agent, a member or an
/// external message author. Closing returns to the surface underneath.
class ProfileSidePanel extends StatelessWidget {
  const ProfileSidePanel({
    super.key,
    required this.controller,
    required this.profile,
    required this.agentTab,
    required this.onClose,
    this.onBack,
    this.onMessage,
  });
  final WorkspaceController controller;
  final RaftProfileLocation profile;

  /// `?agentTab=` deep link (the hover card's "Recent activity").
  final String? agentTab;
  final VoidCallback onClose;

  /// Phone page stack: back leads the header (the panel is a full page).
  final VoidCallback? onBack;
  final Future<void> Function(RaftProfileKind kind, String id)? onMessage;

  @override
  Widget build(BuildContext context) {
    final w = controller;
    final key = ValueKey('profile-${profile.kind.name}-${profile.id}');
    final Widget body = switch (profile.kind) {
      RaftProfileKind.agent => FleetDetail(
        key: key,
        controller: w,
        computers: false,
        initial:
            w.services.entityDirectory.agent(profile.id) ?? {'id': profile.id},
        initialTab: AgentDetailTab.values.firstWhere(
          (tab) => tab.name == agentTab,
          orElse: () => AgentDetailTab.profile,
        ),
        onClose: onBack ?? onClose,
        closeAction: true,
        // Closing the profile replaces its history entry (like the member
        // profile's Message); `onBack` would pop the DM opened after it.
        onLeaveForMessage: onClose,
        // Nested creator / created-agent navigation stays in this panel.
        onOpenAgent: (id) => w.openProfile(RaftProfileKind.agent, id),
      ),
      RaftProfileKind.human => MemberProfileView(
        key: key,
        controller: w,
        userId: profile.id,
        onClose: onClose,
        onBack: onBack,
        onMessage: onMessage == null
            ? null
            : () => onMessage!(RaftProfileKind.human, profile.id),
      ),
      RaftProfileKind.external => ExternalProfileSource(
        key: key,
        controller: w,
        messageId: profile.id,
        channelId: profile.channelId ?? '',
        isMention: profile.isMention,
        builder: (author) => ExternalIdentityDetailPanel(
          controller: w,
          profile: author,
          onClose: onClose,
          onBack: onBack,
        ),
        fallback: (failed) => SourceProfileLoadingPanel(
          onBack: onBack,
          onClose: onClose,
          error: failed ? 'Profile unavailable' : null,
        ),
      ),
    };
    return KeyedSubtree(
      key: const Key('profile-panel'),
      child: RaftProfilePanelSurface(child: body),
    );
  }
}

/// Owner-approved difference (docs/parity.md): Web's docked profile panel is
/// non-modal and closes only from its X / Escape; on wide layouts a tap that
/// lands outside the panel also dismisses it. The tap is observed through a
/// raw pointer [Listener], so it never enters the gesture arena and the tapped
/// control still works. A tap that retargets the profile (another sender
/// avatar, a mention) switches it instead of closing it.
class ProfileOutsideTapDismiss extends StatefulWidget {
  const ProfileOutsideTapDismiss({
    super.key,
    required this.controller,
    required this.panelKey,
    required this.enabled,
    required this.onDismiss,
    required this.child,
  });
  final WorkspaceController controller;

  /// The mounted [ProfileSidePanel]; a tap inside its box is not outside.
  final GlobalKey panelKey;
  final bool enabled;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  State<ProfileOutsideTapDismiss> createState() =>
      _ProfileOutsideTapDismissState();
}

class _ProfileOutsideTapDismissState extends State<ProfileOutsideTapDismiss> {
  int? pointer;
  Offset? down;
  String? target;

  bool insidePanel(Offset global) {
    final box = widget.panelKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(global);
  }

  void onDown(PointerDownEvent e) {
    final profile = widget.controller.location.profile;
    final panel = widget.panelKey.currentContext?.findRenderObject();
    if (!widget.enabled ||
        profile == null ||
        panel is! RenderBox ||
        !panel.attached ||
        e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryButton ||
        insidePanel(e.position)) {
      pointer = null;
      return;
    }
    pointer = e.pointer;
    down = e.position;
    target = widget.controller.location.uri.toString();
  }

  void onUp(PointerUpEvent e) {
    if (e.pointer != pointer) return;
    pointer = null;
    final start = down, was = target;
    if (start == null || was == null) return;
    // A scroll / drag is not a tap.
    if ((e.position - start).distance > kTouchSlop) return;
    // The tapped control's own handler runs when the arena sweeps right after
    // this event; decide afterwards whether the profile was retargeted.
    // ignore: raft_lints/avoid_unreviewed_idle_work -- One-shot deferral out of a build or notification; the callback does not schedule another microtask itself.
    scheduleMicrotask(() {
      if (!mounted || !widget.enabled) return;
      // Any location change (another profile, a thread or task opened /
      // closed, a message jump) is the tapped control's own effect: keep it.
      if (widget.controller.location.uri.toString() == was) {
        widget.onDismiss();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: onDown,
    onPointerUp: onUp,
    onPointerCancel: (e) {
      if (e.pointer == pointer) pointer = null;
    },
    child: widget.child,
  );
}
