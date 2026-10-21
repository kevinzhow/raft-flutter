import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';

/// `appAgentJwtSettingsSchema` (packages/shared agentAudienceJwt.ts): the
/// body of `GET/PUT /integrations/clients/:id/agent-jwt`. [parse] returns null
/// for a body the schema would reject, which the card reports as a failure.
class AgentJwtSettingsData {
  const AgentJwtSettingsData({
    required this.appScope,
    required this.enabled,
    required this.canEnable,
    required this.audience,
  });
  final bool appScope, enabled, canEnable;
  final String audience;

  static AgentJwtSettingsData? parse(Object? raw) {
    if (raw is! Map) return null;
    final scope = raw['scope'];
    if ((scope != 'app' && scope != 'installation') ||
        raw['enabled'] is! bool ||
        raw['appEnabled'] is! bool ||
        raw['effectiveEnabled'] is! bool ||
        raw['canEnable'] is! bool ||
        raw['audience'] is! String ||
        raw['expiresIn'] != 300) {
      return null;
    }
    return AgentJwtSettingsData(
      appScope: scope == 'app',
      enabled: raw['enabled'] as bool,
      canEnable: raw['canEnable'] as bool,
      audience: raw['audience'] as String,
    );
  }
}

/// AgentJwtSettings.tsx: the "Agent access JWT" card of a connected app.
/// [clientId] null is an unregistered app (the card only explains). A
/// different server or app gets a fresh state and request lifetime.
class AgentJwtSettings extends StatefulWidget {
  AgentJwtSettings({
    required this.controller,
    required this.clientId,
    required this.canManage,
  }) : super(key: ValueKey('agent-jwt:${controller.server?.id}:$clientId'));
  final WorkspaceController controller;
  final String? clientId;
  final bool canManage;
  @override
  State<AgentJwtSettings> createState() => _AgentJwtSettingsState();
}

class _AgentJwtSettingsState extends State<AgentJwtSettings> {
  AgentJwtSettingsData? settings;
  bool enabled = false, saving = false, failed = false;
  late bool loading = widget.clientId != null;
  String get _path => '/integrations/clients/${widget.clientId}/agent-jwt';

  @override
  void initState() {
    super.initState();
    if (widget.clientId != null) _load();
  }

  Future<void> _load() async {
    final identity = pageIdentity(widget.controller);
    try {
      final data = AgentJwtSettingsData.parse(
        await widget.controller.client.get(_path),
      );
      if (data == null) throw const FormatException('agent jwt settings');
      if (!mounted || identity != pageIdentity(widget.controller)) return;
      setState(() {
        settings = data;
        enabled = data.enabled;
        loading = failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  Future<void> _save() async {
    final current = settings;
    if (current == null || !widget.canManage || saving) return;
    final identity = pageIdentity(widget.controller);
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      final data = AgentJwtSettingsData.parse(
        await widget.controller.client.request(
          'PUT',
          _path,
          data: {'enabled': enabled},
        ),
      );
      if (data == null) throw const FormatException('agent jwt settings');
      if (!mounted || identity != pageIdentity(widget.controller)) return;
      setState(() {
        settings = data;
        enabled = data.enabled;
        saving = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;
    return RaftAgentJwtCard(
      canManage: widget.canManage,
      registered: widget.clientId != null,
      loading: loading,
      failed: failed,
      saving: saving,
      enabled: enabled,
      settings: s == null
          ? null
          : RaftAgentJwtView(
              appScope: s.appScope,
              enabled: s.enabled,
              canEnable: s.canEnable,
              audience: s.audience,
            ),
      onChanged: (value) => setState(() => enabled = value),
      onSave: _save,
    );
  }
}
