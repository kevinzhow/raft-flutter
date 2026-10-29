import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../platform/content_links.dart';
import '../data/feature_flag_client_facts.dart';
import 'management_support.dart'
    show
        cachedServerFlag,
        pageIdentity,
        readPageSnapshot,
        rememberServerFlag,
        writePageSnapshot;

/// InviteHumanDialog.tsx: By email (one row per invitee, per-row role when
/// guest invites are on) and By link (the server's join link with its limits).
/// Billing seat-limit gating is a separate port.
Future<bool> showWorkspaceMenuInvite(
  BuildContext context,
  WorkspaceController workspace,
) async {
  final serverId = workspace.server?.id,
      origin = workspace.client.origin,
      principal = workspace.client.user?.id,
      generation = workspace.client.generation,
      role = workspace.server?.string('role');
  bool current() =>
      context.mounted &&
      serverId != null &&
      principal != null &&
      origin == workspace.client.origin &&
      principal == workspace.client.user?.id &&
      generation == workspace.client.generation &&
      serverId == workspace.server?.id &&
      role == workspace.server?.string('role') &&
      workspace.can('inviteMembers');
  if (!current()) return false;
  final sent = await showRaftForm<bool>(
    context,
    builder: (_) => _InviteDialog(
      workspace: workspace,
      serverId: serverId!,
      current: current,
    ),
  );
  return sent == true && current();
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({
    required this.workspace,
    required this.serverId,
    required this.current,
  });
  final WorkspaceController workspace;
  final String serverId;
  final bool Function() current;
  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  WorkspaceController get w => widget.workspace;
  static const _guestFlag = 'server_guest_v0';
  static const _linkKey = 'invite-dialog:link';
  static const _billingKey = 'invite-dialog:billing';

  // The last accepted guest gate, seat summary and join link (this session,
  // in memory; the flag also from the device) paint at the first frame and
  // are revalidated in place, so the dialog neither waits nor reflows.
  late bool guest = cachedServerFlag(w, _guestFlag) ?? false;
  bool copied = false, busy = false;
  late Map<String, dynamic>? link = _cachedLink;
  late bool loading = link == null;
  Timer? copiedTimer;

  Map<String, dynamic>? get _cachedLink {
    final value = readPageSnapshot(w, _linkKey)?['link'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  void _rememberLink() =>
      writePageSnapshot(w, _linkKey, pageIdentity(w), {'link': link});

  @override
  void initState() {
    super.initState();
    unawaited(loadGuestFlag());
    unawaited(loadLink());
    unawaited(loadBilling());
  }

  /// Web `loadBilling` (GET /billing/subscription): a failed summary leaves the
  /// seat banner off.
  late Map<String, dynamic>? billing = () {
    final value = readPageSnapshot(w, _billingKey)?['billing'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }();
  Future<void> loadBilling() async {
    final identity = pageIdentity(w);
    try {
      final value = await w.query('/billing/subscription');
      if (mounted && value is Map) {
        final next = Map<String, dynamic>.from(value);
        setState(() => billing = next);
        writePageSnapshot(w, _billingKey, identity, {'billing': next});
      }
    } catch (_) {}
  }

  /// shared getBillingCapacityLimitState(capacity, usage, "human") +
  /// formatBillingCapacityLimitMessage(..., " Upgrade for more.").
  String? get seatLimitMessage {
    final capacity = billing?['capacity'], usage = billing?['usage'];
    if (capacity is! Map || usage is! Map) return null;
    String? label;
    num? used, limit;
    final maxHumans = capacity['maxHumans'], humans = usage['humans'];
    final maxSeats = capacity['maxUniversalSeats'],
        seats = usage['universalSeats'];
    if (maxHumans is num &&
        humans is num &&
        maxHumans != -1 &&
        humans + 1 > maxHumans) {
      (label, used, limit) = ('Human seat limit', humans, maxHumans);
    } else if (maxSeats is num &&
        seats is num &&
        maxSeats != -1 &&
        seats + 1 > maxSeats) {
      (label, used, limit) = ('Seat limit', seats, maxSeats);
    }
    if (label == null) return null;
    return '${raftText(context, label)} reached ($used/$limit on ${billing?['displayName']} plan).${raftText(context, ' Upgrade for more.')}';
  }

  @override
  void dispose() {
    copiedTimer?.cancel();
    super.dispose();
  }

  // useServerFeatureFlag(SERVER_GUEST_FEATURE_FLAG_KEY): a client read of a
  // server-owned gate; it decides what to offer, never what is permitted.
  Future<void> loadGuestFlag() async {
    final identity = pageIdentity(w);
    try {
      final result = await w.command(
        'POST',
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(
          keys: ['server_guest_v0'],
          serverId: widget.serverId,
        ),
      );
      final on =
          result is Map &&
          (result['evaluations'] as List? ?? []).whereType<Map>().any(
            (f) => f['key'] == 'server_guest_v0' && f['enabled'] == true,
          );
      rememberServerFlag(w, _guestFlag, on, identity);
      if (mounted) setState(() => guest = on);
    } catch (_) {}
  }

  /// InviteHumanDialog `setError(err.response?.data?.error ||
  /// "Failed to prepare join link")`. The dialog's own error row belongs to
  /// the email form, so a join-link failure is reported as a toast rather
  /// than dropped.
  void linkFailed(Object e) => showRaftToast(
    context,
    userErrorText(
      e,
      fallback: 'Failed to prepare join link',
      where: 'join link',
    ),
  );

  // The first existing join link, else a fresh unlimited one.
  Future<void> loadLink() async {
    final identity = pageIdentity(w);
    try {
      final links = await w.query('/servers/${widget.serverId}/join-links');
      var existing = links is List ? links.whereType<Map>().firstOrNull : null;
      if (existing == null) {
        final data = await w.command(
          'POST',
          '/servers/${widget.serverId}/join-links',
          data: {'maxUses': null, 'expiresAt': null},
        );
        existing = data is Map ? data['link'] as Map? : null;
      }
      if (mounted) {
        setState(() {
          link = existing == null ? null : Map<String, dynamic>.from(existing);
          loading = false;
        });
        if (identity == pageIdentity(w)) _rememberLink();
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        linkFailed(e);
      }
    }
  }

  String? get url {
    final token = link?['token'];
    if (token == null) return null;
    final origin = ContentLinks.originFor(w.client.origin).origin;
    return '$origin/join/$token';
  }

  Future<void> copy() async {
    final u = url;
    if (u == null) return;
    await Clipboard.setData(ClipboardData(text: u));
    if (!mounted) return;
    setState(() => copied = true);
    copiedTimer?.cancel();
    copiedTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => copied = false);
    });
  }

  // Revoke the current link and create one with the chosen limits.
  Future<void> apply(String maxUses, String expiry) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final id = link?['id'];
      if (id != null) {
        await w.command('DELETE', '/servers/${widget.serverId}/join-links/$id');
      }
      final days = const {'1h': 1 / 24, '1d': 1, '7d': 7, '30d': 30}[expiry];
      final data = await w.command(
        'POST',
        '/servers/${widget.serverId}/join-links',
        data: {
          'maxUses': maxUses == 'unlimited' ? null : int.tryParse(maxUses),
          'expiresAt': days == null
              ? null
              : DateTime.now()
                    .add(Duration(minutes: (days * 24 * 60).round()))
                    .toUtc()
                    .toIso8601String(),
        },
      );
      final next = data is Map ? data['link'] as Map? : null;
      if (mounted) {
        setState(
          () => link = next == null ? null : Map<String, dynamic>.from(next),
        );
        _rememberLink();
      }
    } catch (e) {
      if (mounted) linkFailed(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> revoke() async {
    final id = link?['id'];
    if (busy || id == null) return;
    setState(() => busy = true);
    try {
      await w.command('DELETE', '/servers/${widget.serverId}/join-links/$id');
      if (mounted) {
        setState(() => link = null);
        _rememberLink();
      }
    } catch (e) {
      if (mounted) linkFailed(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> send(List<(String, String)> invites) async {
    for (final (email, _) in invites) {
      final error = sourceInviteEmailError(email);
      if (error != null) throw RaftUserError(error);
    }
    if (!widget.current()) {
      throw const RaftUserError('Failed to send invites');
    }
    // A failed invite rethrows as caught: the dialog shows the server's text
    // or `member.invite.failedSend` through the error scope.
    await Future.wait([
      for (final (email, role) in invites)
        w.client.post(
          '/servers/${widget.serverId}/invites',
          data: {'email': email, 'role': role},
        ),
    ]);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => RaftInviteHumanDialog(
    onClose: () => Navigator.of(context).pop(false),
    onSend: send,
    canOfferGuest: guest,
    seatLimitMessage: seatLimitMessage,
    onViewBilling: () {
      Navigator.of(context).pop(false);
      w.navigation.navigate(
        RaftLocation.at(
          serverSlug: w.location.serverSlug,
          route: RaftRoute.settings,
          settingsPath: const ['billing'],
        ),
      );
      w.notifyListeners();
    },
    link: RaftInviteLink(
      loading: loading || busy,
      url: url,
      copied: copied,
      hasLink: link != null,
    ),
    onCopyLink: copy,
    onApplyLink: apply,
    onRevokeLink: revoke,
  );
}

/// Exact shared emailValidation.ts3–22 validation, before any invitation POST.
String? sourceInviteEmailError(String value) {
  final email = value.trim(), at = value.trim().indexOf('@');
  if (email.isEmpty ||
      email.length > 254 ||
      RegExp(r'\s').hasMatch(email) ||
      at <= 0 ||
      at != email.lastIndexOf('@')) {
    return 'Enter a valid email address';
  }
  final local = email.substring(0, at), domain = email.substring(at + 1);
  if (local.length > 64 ||
      domain.isEmpty ||
      domain.startsWith('.') ||
      domain.endsWith('.') ||
      !domain.contains('.') ||
      domain.contains('..') ||
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'Enter a valid email address';
  }
  return null;
}
