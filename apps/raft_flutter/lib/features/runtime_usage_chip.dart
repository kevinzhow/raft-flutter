// Web components/machine/RuntimeAccountUsageChip.tsx: the runtime chip on
// Computer detail "Detected Runtimes" and the agent Runtime Config row. A
// usage provider chip reads the Computer's private usage snapshot, shows its
// health Status and opens the usage card on hover / focus / click.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/runtime_account_usage.dart';
import '../data/workspace_controller.dart';
import 'resource_cards.dart' show resourceRelativeTime;

/// The workspace's usage client, bound to the server-level identity (the
/// panel cache empties on account / server / role changes).
RuntimeAccountUsageClient runtimeUsageClient(WorkspaceController w) =>
    w.agentTabCache.putIfAbsent(
      'runtime-account-usage',
      () => RuntimeAccountUsageClient(
        get: (path) => w.query(path),
        post: (path, body) => w.command('POST', path, data: body),
      ),
    ) as RuntimeAccountUsageClient;

/// machineRuntimeUsageVisibility.ts canViewMachineRuntimeAccountUsage: the
/// attaching human, the creator, or `editMachines`.
bool canViewRuntimeUsage(WorkspaceController w, Map<String, dynamic>? m) {
  if (m == null) return false;
  final me = w.client.user?.id;
  final creator = m['creator'];
  return m['computerAttachedByCurrentUser'] == true ||
      (me != null && creator is Map && creator['id'] == me) ||
      w.can('editMachines');
}

/// RuntimeAccountUsageGateChip: the usage chip when [enabled] and the
/// runtime has a usage provider, otherwise [chip] as is.
Widget runtimeUsageGateChip({
  required WorkspaceController controller,
  required bool enabled,
  required String runtimeId,
  required String machineId,
  required String label,
  String? runtimeVersion,
  required Widget Function(Widget? status) chip,
  RuntimeAccountUsageClient? client,
}) {
  final serverId = controller.server?.id;
  if (!enabled ||
      serverId == null ||
      machineId.isEmpty ||
      runtimeUsageProvider(runtimeId) == null) {
    return chip(null);
  }
  return RuntimeUsageChip(
    key: ValueKey('runtime-usage-$machineId-$runtimeId'),
    controller: controller,
    serverId: serverId,
    machineId: machineId,
    runtimeId: runtimeId,
    runtimeVersion: runtimeVersion,
    label: label,
    chip: chip,
    client: client,
  );
}

class RuntimeUsageChip extends StatefulWidget {
  const RuntimeUsageChip({
    super.key,
    required this.controller,
    required this.serverId,
    required this.machineId,
    required this.runtimeId,
    required this.label,
    required this.chip,
    this.runtimeVersion,
    this.client,
  });
  final WorkspaceController controller;
  final String serverId, machineId, runtimeId, label;
  final String? runtimeVersion;
  final Widget Function(Widget? status) chip;
  final RuntimeAccountUsageClient? client;
  @override
  State<RuntimeUsageChip> createState() => _RuntimeUsageChipState();
}

class _RuntimeUsageChipState extends State<RuntimeUsageChip> {
  static const followUpDelay = Duration(milliseconds: 1200);
  static const followUpAttempts = 8;

  late RuntimeAccountUsageClient client;
  final model = _UsageModel();
  RuntimeUsageRead? result;
  bool loading = false, loadError = false;

  /// idle | requesting | requested | unconfirmed | timeout | cooldown |
  /// computer_offline.
  String refreshState = 'idle';
  int subject = 0, poll = 0;
  Timer? ticker, reread;

  String get provider => runtimeUsageProvider(widget.runtimeId)!;

  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  void didUpdateWidget(RuntimeUsageChip old) {
    super.didUpdateWidget(old);
    if (old.serverId != widget.serverId ||
        old.machineId != widget.machineId ||
        old.runtimeId != widget.runtimeId ||
        old.client != widget.client) {
      reread?.cancel();
      result = null;
      refreshState = 'idle';
      start();
    }
  }

  @override
  void dispose() {
    subject++;
    poll++;
    ticker?.cancel();
    reread?.cancel();
    model.dispose();
    super.dispose();
  }

  void start() {
    client = widget.client ?? runtimeUsageClient(widget.controller);
    result = client.cached(widget.serverId, widget.machineId, provider);
    final generation = ++subject;
    scheduleMicrotask(() {
      if (!mounted || generation != subject) return;
      read(generation).then((next) {
        if (generation != subject) return;
        if (next != null && (next.missing || next.state == 'stale')) {
          backgroundRefresh(generation);
        }
      });
      tick();
    });
  }

  void changed() {
    if (!mounted) return;
    setState(() {});
    model.ping();
  }

  /// Drains the refresh countdown once a second while it runs.
  void tick() {
    ticker?.cancel();
    if (cooldownLeft == Duration.zero) return;
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (cooldownLeft == Duration.zero) ticker?.cancel();
      changed();
    });
  }

  Duration get cooldownLeft =>
      client.cooldownRemaining(widget.serverId, widget.machineId, provider);

  Future<RuntimeUsageRead?> read([int? generation]) async {
    final ticket = generation ?? subject;
    loading = true;
    loadError = false;
    changed();
    try {
      final next = await client.read(
        widget.serverId,
        widget.machineId,
        provider,
      );
      if (mounted && ticket == subject) result = next;
      return next;
    } catch (_) {
      if (mounted && ticket == subject) loadError = true;
      return null;
    } finally {
      if (mounted && ticket == subject) {
        loading = false;
        changed();
      }
    }
  }

  void followUp(int generation) {
    final ticket = ++poll;
    var attempt = 0;
    void next() {
      if (!mounted || generation != subject || ticket != poll) return;
      if (attempt >= followUpAttempts) {
        refreshState = 'unconfirmed';
        changed();
        return;
      }
      reread?.cancel();
      reread = Timer(followUpDelay, () async {
        attempt++;
        client.invalidate(widget.serverId, widget.machineId, provider);
        final value = await read(generation);
        if (value == null ||
            !mounted ||
            generation != subject ||
            ticket != poll) {
          return;
        }
        if (value.state == 'fresh') {
          refreshState = 'idle';
          changed();
          return;
        }
        next();
      });
    }

    next();
  }

  Future<void> backgroundRefresh(int generation) async {
    try {
      final out = await client.refresh(
        widget.serverId,
        widget.machineId,
        provider,
        'stale_or_missing',
      );
      if (!mounted || generation != subject) return;
      refreshState = out.state;
      tick();
      changed();
      if (out.state == 'requested' || out.state == 'cooldown') {
        followUp(generation);
      }
    } catch (_) {
      if (mounted && generation == subject) {
        refreshState = 'computer_offline';
        changed();
      }
    }
  }

  Future<void> refresh() async {
    final generation = subject;
    refreshState = 'requesting';
    changed();
    try {
      final out = await client.refresh(
        widget.serverId,
        widget.machineId,
        provider,
        'manual',
      );
      if (!mounted || generation != subject) return;
      tick();
      if (out.state == 'fresh') {
        if (out.snapshot != null) {
          loadError = false;
          result = RuntimeUsageRead('fresh', out.snapshot);
          refreshState = 'idle';
        } else {
          refreshState = 'unconfirmed';
        }
        changed();
        return;
      }
      refreshState = out.state;
      changed();
      if (out.accepted || out.state == 'cooldown') followUp(generation);
    } catch (_) {
      if (mounted && generation == subject) {
        refreshState = 'computer_offline';
        changed();
      }
    }
  }

  RaftRuntimeUsageData data(BuildContext context) {
    final r = result;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    String? relative(Object? at) {
      final text = resourceRelativeTime(
        at as String?,
        now: client.now(),
        chinese: zh,
      );
      return text.isEmpty ? null : text;
    }

    final cooldown = cooldownLeft;
    final footer = switch (refreshState) {
      'requested' => raftText(context, 'Refresh requested'),
      'unconfirmed' => raftText(
        context,
        'Refresh sent, but no update was observed',
      ),
      'timeout' => raftText(
        context,
        'Refresh timed out — the computer did not return usage in time',
      ),
      _ when cooldown > Duration.zero => raftFormat(
        context,
        'Refresh again in ~{seconds}s',
        {'seconds': (cooldown.inMilliseconds / 1000).ceil()},
      ),
      'computer_offline' => raftText(context, 'Computer offline'),
      _ => raftText(context, 'Cached snapshot only'),
    };
    final snapshot = r?.snapshot;
    return RaftRuntimeUsageData(
      provider: runtimeUsageProviderName(provider),
      version: widget.runtimeVersion,
      loading: loading,
      loadError: loadError,
      state: r?.missing == true ? 'missing' : r?.state,
      updated: relative(snapshot?['collectedAt']),
      accounts: [
        for (final a in (snapshot?['accounts'] as List? ?? const []))
          if (a is Map)
            RaftRuntimeUsageAccount(
              health: '${a['health'] ?? 'error'}',
              plan: a['planLabel'] as String?,
              identity: (a['maskedLabel'] ?? a['displayName']) as String?,
              windows: [
                for (final w in (a['windows'] as List? ?? const []))
                  if (w is Map)
                    RaftRuntimeUsageWindow(
                      label: '${w['label'] ?? ''}',
                      status: '${w['status'] ?? 'ok'}',
                      percent: (((w['usedRatio'] as num?) ?? 0) * 100).round(),
                      reset:
                          relative(w['resetsAt']) ??
                          (w['resetsAt'] is String
                              ? raftText(context, 'later')
                              : null),
                    ),
              ],
            ),
      ],
      footer: footer,
      refreshing: refreshState == 'requesting',
      refreshDisabled: refreshState == 'requesting' || cooldown > Duration.zero,
    );
  }

  void openSheet(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: raftText(context, 'Close runtime usage'),
      barrierColor: Colors.black.withValues(alpha: .4),
      pageBuilder: (dialogContext, _, _) => ListenableBuilder(
        listenable: model,
        builder: (sheetContext, _) => RaftRuntimeUsageSheet(
          data: data(sheetContext),
          onRefresh: refresh,
          onClose: () => Navigator.of(dialogContext).maybePop(),
        ),
      ),
    );
    read();
  }

  @override
  Widget build(BuildContext context) {
    final value = data(context);
    return RaftRuntimeUsageChip(
      label: widget.label,
      data: value,
      onOpen: read,
      onRefresh: refresh,
      onOpenSheet: openSheet,
      chip: widget.chip(
        value.known ? RaftRuntimeUsageStatus(attention: value.attention) : null,
      ),
    );
  }
}

class _UsageModel extends ChangeNotifier {
  void ping() => notifyListeners();
}
