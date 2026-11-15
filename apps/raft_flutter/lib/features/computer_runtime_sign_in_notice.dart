// Web v1.24 components/machine/RuntimeSignInNotice.tsx (+ useRuntimeAuthView.ts):
// under a runtime picker, the picked runtime (Claude Code, Codex, Kimi Code,
// Qoder …) is signed out on the Computer. It says so, with the same Sign in
// the runtime chip's card offers, and blocks nothing: the agent can still be
// created or saved.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/runtime_auth.dart';
import '../data/workspace_controller.dart';
import 'computer_runtime_sign_in_dialog.dart';
import 'computers_rack/computers_rack_model.dart' show rackRuntimeDisplayName;

/// useRuntimeAuthView: the Computer's runtime sign-in state, read once (cached
/// per Computer) and again whenever the Computer reports a new one. Only the
/// newest read may land: an older answer that arrives after a newer read
/// started (a status update mid-read) is stale.
class RuntimeAuthViewWatch {
  RuntimeAuthViewWatch({required this.onChange});

  /// Called after a read landed (the owner rebuilds).
  final VoidCallback onChange;

  /// The latest view of this Computer; null before the first read, when the
  /// read failed (not allowed to see it), or when not [start]ed.
  RuntimeAuthView? view;
  RuntimeAuthClient? _client;
  String _server = '', _machine = '';
  void Function()? _unwatch;
  int _seq = 0;

  /// Reads and watches [machine]. [enabled] false stops any watch and clears
  /// the view.
  void start(
    RuntimeAuthClient client,
    String server,
    String machine, {
    bool enabled = true,
  }) {
    stop();
    view = null;
    if (!enabled) return;
    _client = client;
    _server = server;
    _machine = machine;
    view = client.cached(server, machine);
    _unwatch = client.watch(machine, reread);
    reread();
  }

  void reread() {
    final client = _client;
    if (client == null) return;
    final seq = ++_seq;
    client.read(_server, _machine).then(
      (next) {
        if (_client != client || seq != _seq) return;
        view = next;
        onChange();
      },
      // Not allowed to see it, or the read failed: the card stays as usage
      // alone.
      onError: (Object _) {},
    );
  }

  void stop() {
    _unwatch?.call();
    _unwatch = null;
    _client = null;
    _seq++;
  }

  void dispose() => stop();
}

class RuntimeSignInNotice extends StatefulWidget {
  const RuntimeSignInNotice({
    super.key,
    required this.controller,
    required this.serverId,
    required this.machineId,
    required this.machineName,
    required this.runtimeId,
    required this.enabled,
    this.client,
  });
  final WorkspaceController controller;
  final String? serverId, machineId;
  final String machineName, runtimeId;

  /// The caller's say on whether this person may see that state at all.
  final bool enabled;
  final RuntimeAuthClient? client;

  @override
  State<RuntimeSignInNotice> createState() => _RuntimeSignInNoticeState();
}

class _RuntimeSignInNoticeState extends State<RuntimeSignInNotice> {
  late final watch = RuntimeAuthViewWatch(onChange: _changed);
  late RuntimeAuthClient client;

  /// Runtimes with one sign-in only: Qwen Code's provider key has its own
  /// card, and its presence-only status is no "signed out"; Pi with no stored
  /// sign-in may still run on a key in the Computer's environment or
  /// models.json.
  String? get authRuntime {
    final runtime = runtimeAuthRuntimeFor(widget.runtimeId);
    return runtime != null &&
            runtimeAuthSupports(runtime, 'login') &&
            !runtimeAuthSignsInPerProvider(runtime)
        ? runtime
        : null;
  }

  bool get active =>
      widget.enabled &&
      authRuntime != null &&
      (widget.serverId?.isNotEmpty ?? false) &&
      (widget.machineId?.isNotEmpty ?? false);

  void _changed() {
    if (mounted) setState(() {});
  }

  void _start() {
    client = widget.client ?? runtimeAuthClientOf(widget.controller);
    watch.start(
      client,
      widget.serverId ?? '',
      widget.machineId ?? '',
      enabled: active,
    );
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(RuntimeSignInNotice old) {
    super.didUpdateWidget(old);
    if (old.serverId != widget.serverId ||
        old.machineId != widget.machineId ||
        old.runtimeId != widget.runtimeId ||
        old.enabled != widget.enabled ||
        old.client != widget.client) {
      _start();
    }
  }

  @override
  void dispose() {
    watch.dispose();
    super.dispose();
  }

  Future<void> signIn(String runtime) async {
    await showComputerRuntimeSignInDialog(
      context,
      controller: widget.controller,
      client: client,
      serverId: widget.serverId!,
      machineId: widget.machineId!,
      runtimeId: widget.runtimeId,
      runtime: runtime,
    );
    // The dialog ended: the notice reads the Computer's state again.
    client.invalidate(widget.serverId!, widget.machineId!);
  }

  @override
  Widget build(BuildContext context) {
    final runtime = authRuntime;
    final view = watch.view;
    if (!active || runtime == null) return const SizedBox.shrink();
    if (view?.statusOf(runtime)?.loggedOut != true) {
      return const SizedBox.shrink();
    }
    final canSignIn = view!.canAct && view.availability == 'ok';
    // raft-ui's warning Banner is role="status" (polite): picking a signed-out
    // runtime is announced without interrupting.
    return RaftBanner(
      key: const ValueKey('runtime-picker-not-signed-in'),
      status: RaftBannerRecipeStatus.warning,
      size: RaftBannerRecipeSize.sm,
      glyph: RaftGlyph.alertTriangle,
      description: raftFormat(
        context,
        '{runtime} is not signed in on {computer}.',
        {
          'runtime': rackRuntimeDisplayName(widget.runtimeId),
          'computer': widget.machineName,
        },
      ),
      action: canSignIn
          ? RaftButton(
              key: const ValueKey('runtime-picker-sign-in'),
              label: raftText(context, 'Sign in'),
              glyph: RaftGlyph.logIn,
              uiVariant: RaftButtonVariant.standard,
              uiSize: RaftButtonSize.md,
              onPressed: () => unawaited(signIn(runtime)),
            )
          : null,
    );
  }
}

/// The workspace's runtime-auth client, bound to the server-level identity
/// (the cache empties on account / server / role changes, as the usage
/// client's does).
RuntimeAuthClient runtimeAuthClientOf(WorkspaceController w) =>
    w.agentTabCache.putIfAbsent(
      'runtime-auth',
      () => RuntimeAuthClient(
        get: (path) => w.query(path),
        post: (path, body) => w.command('POST', path, data: body),
        events: w.client.events,
      ),
    ) as RuntimeAuthClient;
