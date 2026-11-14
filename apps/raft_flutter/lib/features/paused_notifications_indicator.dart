// Source: packages/web/src/components/notifications/PausedNotificationsIndicator.tsx
// at v1.24.0-source.1 (1d689caf). Top bar: a small moon while notifications
// are paused (design §4.3, item 5); a click resumes them. Quiet hours alone
// show nothing here: they are a schedule, not a temporary state to undo.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/notification_levels.dart';
import '../data/notification_settings_api.dart';
import '../data/notification_settings_store.dart';
import '../data/workspace_controller.dart';

class PausedNotificationsIndicator extends StatefulWidget {
  const PausedNotificationsIndicator({
    super.key,
    required this.controller,
    this.now = DateTime.now,
  });
  final WorkspaceController controller;
  final DateTime Function() now;
  @override
  State<PausedNotificationsIndicator> createState() =>
      _PausedNotificationsIndicatorState();
}

class _PausedNotificationsIndicatorState
    extends State<PausedNotificationsIndicator> {
  NotificationSettingsStore? store;
  Timer? end;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    bind();
  }

  @override
  void didUpdateWidget(PausedNotificationsIndicator old) {
    super.didUpdateWidget(old);
    bind();
  }

  void bind() {
    final client = widget.controller.client;
    final next = client.user == null
        ? null
        : NotificationSettingsStore.of(client);
    if (identical(next, store)) return;
    store?.removeListener(changed);
    store = next?..addListener(changed);
    // The runtime reads the account settings once per signed-in account
    // (Web NotificationRuntime); later changes come as realtime frames.
    if (next != null && !next.accountLoaded) unawaited(next.loadAccount());
    schedule();
  }

  @override
  void dispose() {
    store?.removeListener(changed);
    end?.cancel();
    super.dispose();
  }

  void changed() {
    if (!mounted) return;
    schedule();
    setState(() {});
  }

  DateTime? get pausedUntil {
    final until = store?.account?.pausedUntil;
    return isPausedNow(until, widget.now()) ? until : null;
  }

  /// Re-renders when the pause ends, so the moon leaves on time.
  void schedule() {
    end?.cancel();
    final until = pausedUntil;
    if (until == null) return;
    final wait =
        until.difference(widget.now()) + const Duration(milliseconds: 50);
    end = Timer(wait.isNegative ? Duration.zero : wait, changed);
  }

  Future<void> resume() async {
    final store = this.store;
    if (store == null || busy) return;
    setState(() => busy = true);
    final result = await store.patchAccount({'pausedUntil': null});
    if (!mounted) return;
    setState(() => busy = false);
    if (result is PatchAccountError) {
      showRaftToast(context, 'Couldn’t resume notifications. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final until = pausedUntil;
    if (until == null) return const SizedBox.shrink();
    final local = until.toLocal();
    final when =
        '${MaterialLocalizations.of(context).formatShortMonthDay(local)} '
        '${TimeOfDay.fromDateTime(local).format(context)}';
    final label = raftFormat(
      context,
      'Notifications paused until {until}. Click to resume.',
      {'until': when},
    );
    // Web `<Button variant="on-frame" size="icon-md">` with a Tooltip.
    return RaftButton(
      key: const ValueKey('paused-notifications-indicator'),
      uiVariant: RaftButtonVariant.onFrame,
      uiSize: RaftButtonSize.iconMd,
      glyph: RaftGlyph.moon,
      tooltip: label,
      semanticLabel: label,
      onPressed: busy ? null : () => unawaited(resume()),
    );
  }
}
