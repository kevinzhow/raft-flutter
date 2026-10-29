import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';

/// `normalizeAppSetupUrl` (packages/shared appSetup.ts): empty is "no setup
/// page"; otherwise an HTTPS URL (or loopback HTTP) of at most 2000 characters,
/// without credentials or a fragment. Throws [FormatException] otherwise.
String? normalizeAppSetupUrl(Object? raw) {
  if (raw == null || raw == '') return null;
  if (raw is! String || raw.length > 2000) {
    throw const FormatException('setup URL must be at most 2000 characters');
  }
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (!isSafeAppSetupUrl(value)) {
    throw const FormatException('setup URL must be HTTPS');
  }
  return value;
}

/// `isSafeOAuthReturnUrl`: a navigable web URL; local HTTP stays available for
/// development.
bool isSafeAppSetupUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return false;
  final loopback = const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
  return (uri.scheme == 'https' || (uri.scheme == 'http' && loopback)) &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment;
}

/// An App declares a setup page (`app.setupUrl` is set).
bool hasAppSetup(Map<String, dynamic> app) {
  final url = app['setupUrl'];
  return url is String && url.isNotEmpty;
}

/// The host a setup URL opens, or null for a URL that is not a safe one.
String? appSetupDomain(Object? url) {
  try {
    final value = normalizeAppSetupUrl(url);
    if (value == null) return null;
    final uri = Uri.parse(value);
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  } on FormatException {
    return null;
  }
}

/// `GET /integrations/clients/:id/setup`: the configuration progress of one
/// installation, separate from every installation permission.
class AppSetupState {
  const AppSetupState({
    required this.status,
    required this.url,
    required this.description,
    required this.canConfigure,
  });
  final String status;
  final String? url, description;
  final bool canConfigure;

  bool get complete => status == 'complete';

  /// Null for a body the Web client would reject.
  static AppSetupState? parse(Object? raw) {
    if (raw is! Map) return null;
    final status = raw['status'];
    final revision = raw['revision'];
    final description = raw['description'];
    final completedAt = raw['completedAt'];
    final canConfigure = raw['canConfigure'];
    if (!const {'not_required', 'pending', 'complete'}.contains(status) ||
        canConfigure is! bool ||
        (description != null && description is! String) ||
        revision is! int ||
        revision < 1 ||
        (completedAt != null && completedAt is! String) ||
        (canConfigure && status != 'not_required' && raw['url'] == null)) {
      return null;
    }
    try {
      return AppSetupState(
        status: status as String,
        url: normalizeAppSetupUrl(raw['url']),
        description: description as String?,
        canConfigure: canConfigure,
      );
    } on FormatException {
      return null;
    }
  }
}

/// AppSetupPanel: the per-installation setup state of an installed App.
/// Returning from the App only refreshes; completion is written by the App's
/// own back end. A different server or app gets a fresh state.
class AppSetupPanel extends StatefulWidget {
  AppSetupPanel({
    required this.controller,
    required this.clientId,
    this.open = managementLaunch,
  }) : super(key: ValueKey('app-setup:${controller.server?.id}:$clientId'));
  final WorkspaceController controller;
  final String clientId;
  final Future<void> Function(String url) open;
  @override
  State<AppSetupPanel> createState() => _AppSetupPanelState();
}

class _AppSetupPanelState extends State<AppSetupPanel>
    with WidgetsBindingObserver {
  AppSetupState? state;
  bool failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    final identity = pageIdentity(widget.controller);
    try {
      final data = AppSetupState.parse(
        await widget.controller.client.get(
          '/integrations/clients/${widget.clientId}/setup',
        ),
      );
      if (data == null) throw const FormatException('app setup state');
      if (!mounted ||
          request != _request ||
          identity != pageIdentity(widget.controller)) {
        return;
      }
      setState(() {
        state = data;
        failed = false;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          state = null;
          failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    // A finished read of "no setup required" leaves nothing to show.
    if (s?.status == 'not_required') return const SizedBox.shrink();
    return RaftAppSetupPanel(
      failed: failed,
      view: s == null
          ? null
          : RaftAppSetupView(
              complete: s.complete,
              canConfigure: s.canConfigure && s.url != null,
              description: s.description,
              domain: appSetupDomain(s.url),
            ),
      onOpen: s?.url == null ? null : () => _open(s!.url!),
      onRefresh: _load,
    );
  }

  Future<void> _open(String url) async {
    try {
      await widget.open(url);
    } catch (_) {
      if (mounted) {
        showRaftToast(context, 'Could not open this address.');
      }
    }
  }
}
