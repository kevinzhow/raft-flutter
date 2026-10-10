import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';

/// Settings > Labs (SettingsPanel.tsx LabsSection, gated by
/// `server_labs_ui_v0`): GET /servers/:id/labs (canonical or legacy
/// readback), the owner master gate (PATCH .../labs/access) and per-Lab
/// enrollment (PUT .../labs/:key), both with the readback's expectedVersion.
class LabsView extends StatefulWidget {
  const LabsView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<LabsView> createState() => _LabsViewState();
}

/// Retired Lab keys the Web hides (serverLabsSettings.ts).
const _retiredLabs = {'inline_thread_replies_v0'};

class _LabsViewState extends ManagementState<LabsView> {
  @override
  WorkspaceController get w => widget.controller;
  Map<String, dynamic> readback = {};
  bool unavailable = false;
  String? mutationError;
  String get base => '/servers/${w.server!.id}';

  @override
  void initState() {
    super.initState();
    startManagement();
  }

  @override
  void clearData() {
    readback = {};
    unavailable = false;
    mutationError = null;
  }

  @override
  String get snapshotKey => 'labs';
  @override
  Map<String, Object?> captureSnapshot() => {
    'readback': readback,
    'unavailable': unavailable,
  };
  @override
  bool restoreSnapshot(Map<String, Object?> fields) {
    readback = fields['readback'] as Map<String, dynamic>;
    unavailable = fields['unavailable'] as bool;
    return true;
  }

  /// normalizeServerLabSettingsReadback: canonical `accessEnabled` /
  /// `version` / `labKey` or the legacy `masterEnabled` / `serverLabVersion`
  /// / `key` shape, optionally wrapped in `data`.
  static Map<String, dynamic> normalize(Object? payload) {
    var body = managementMap(payload);
    if (body['data'] is Map) body = managementMap(body['data']);
    final canonical = body.containsKey('accessEnabled');
    final permissions = managementMap(body['permissions']);
    return {
      'serverId': body['serverId'],
      'version': canonical ? body['version'] : body['serverLabVersion'],
      'masterEnabled': canonical
          ? body['accessEnabled'] == true
          : body['masterEnabled'] == true,
      'canSetMasterAccess': canonical
          ? body['canManageAccess']
          : permissions['canSetMasterAccess'],
      'canSetEnrollments': canonical
          ? body['canManageEnrollments']
          : permissions['canSetEnrollments'],
      'labs': [
        for (final lab in managementRows(body['labs']))
          if (!_retiredLabs.contains(lab[canonical ? 'labKey' : 'key']))
            {
              'key': lab[canonical ? 'labKey' : 'key'],
              'name': '${lab['name'] ?? ''}',
              'description': '${lab['description'] ?? ''}',
              'state': lab['state'],
              'enrolled': lab['enrolled'] == true,
            },
      ],
    };
  }

  @override
  Future<void> loadData(int request, int generation) async {
    try {
      final raw = await w.client.get('$base/labs');
      if (!accepts(generation, request)) return;
      final next = normalize(raw);
      if (next['serverId'] != w.server!.id) {
        throw StateError(
          'Labs settings response did not match the active server.',
        );
      }
      readback = next;
      unavailable = false;
    } on RaftApiException catch (e) {
      if (e.status != 404) rethrow;
      if (!accepts(generation, request)) return;
      readback = {};
      unavailable = true;
    }
  }

  Future<void> mutate(String method, String path, bool enabled) async {
    setState(() => mutationError = null);
    try {
      final raw = await w.client.request(
        method,
        path,
        data: {'enabled': enabled, 'expectedVersion': readback['version']},
      );
      final next = normalize(raw);
      if (!mounted) return;
      if (next['serverId'] != w.server!.id) {
        setState(
          () => mutationError =
              'Labs settings response did not match the active server.',
        );
        return;
      }
      setState(() => readback = next);
      saveSnapshot();
    } catch (_) {
      if (mounted) {
        setState(() => mutationError = 'Failed to update Labs settings.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = w.server?.string('role');
    final owner = role == 'owner', admin = owner || role == 'admin';
    final canSetMaster = readback['canSetMasterAccess'] as bool? ?? owner;
    final canSetEnrollments = readback['canSetEnrollments'] as bool? ?? admin;
    final master = readback['masterEnabled'] == true;
    final status = loading && readback.isEmpty
        ? RaftServerLabsStatus.loading
        : unavailable
        ? RaftServerLabsStatus.unavailable
        : readback.isEmpty
        ? RaftServerLabsStatus.failed
        : RaftServerLabsStatus.ready;
    return RaftServerLabsSection(
      status: status,
      busy: busy,
      masterEnabled: master,
      canSetMaster: canSetMaster,
      onMasterChanged: (value) => run(
        () => mutate('PATCH', '$base/labs/access', value),
        refresh: false,
      ),
      error: status == RaftServerLabsStatus.failed
          ? 'Failed to load Labs settings.'
          : mutationError,
      labs: [
        for (final lab in managementRows(readback['labs']))
          () {
            final open = lab['state'] == 'open';
            final editable = master && canSetEnrollments && open;
            return RaftServerLab(
              key: '${lab['key']}',
              name: '${lab['name']}',
              description: '${lab['description']}',
              checked: master && lab['enrolled'] == true,
              editable: editable,
              disabledReason: !master
                  ? 'Turn on Server Labs access first.'
                  : !canSetEnrollments
                  ? 'Only server owners and admins can change Lab enrollment.'
                  : !open
                  ? 'Paused, draft, and retired Labs are read-only here.'
                  : '',
              onChanged: (value) => run(
                () => mutate(
                  'PUT',
                  '$base/labs/${Uri.encodeComponent('${lab['key']}')}',
                  value,
                ),
                refresh: false,
              ),
            );
          }(),
      ],
    );
  }
}
