import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_client/raft_client.dart';

import '../data/user_error.dart';
import '../data/web_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'agent_runtime_labels.dart' show runtimeLabelWithStatus;
import 'management_support.dart';
import 'member_profile_rules.dart';
import 'provider_edit_dialog.dart';
import '../data/feature_flag_client_facts.dart';

class ProviderConnectionsView extends StatefulWidget {
  const ProviderConnectionsView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<ProviderConnectionsView> createState() => _ProviderConnectionsState();
}

class _ProviderConnectionsState
    extends ManagementState<ProviderConnectionsView> {
  @override
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>> connections = [], options = [];
  bool enabled = false;
  @override
  void initState() {
    super.initState();
    startManagement();
  }

  @override
  void clearData() {
    connections = [];
    options = [];
    enabled = false;
  }

  @override
  String get snapshotKey => 'provider-connections';
  @override
  Map<String, Object?> captureSnapshot() => {
    'connections': connections,
    'options': options,
    'enabled': enabled,
  };
  @override
  bool restoreSnapshot(Map<String, Object?> fields) {
    connections = fields['connections'] as List<Map<String, dynamic>>;
    options = fields['options'] as List<Map<String, dynamic>>;
    enabled = fields['enabled'] as bool;
    return true;
  }

  /// ProviderConnectionsSettings never shows the server's text: each action
  /// fails with its own `settings.providers.*` message.
  Future<T> _web<T>(String message, Future<T> Function() action) =>
      withWebError(
        message,
        action,
        serverText: false,
        where: 'provider connections',
      );

  @override
  Future<void> loadData(int request, int generation) => _web(
    'Provider connections could not be loaded.',
    () => _loadData(request, generation),
  );

  Future<void> _loadData(int request, int generation) async {
    final flags = managementMap(
      await w.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(
          keys: ['provider_connections_v0'],
          serverId: w.server?.id,
        ),
      ),
    );
    if (!accepts(generation, request)) return;
    final active = managementRows(
      flags['evaluations'],
    ).any((f) => f['key'] == 'provider_connections_v0' && f['enabled'] == true);
    if (!active) {
      enabled = false;
      connections = [];
      options = [];
      return;
    }
    final catalog = managementMap(await w.client.get('/provider-connections'));
    if (!accepts(generation, request)) return;
    enabled = true;
    connections = managementRows(catalog['connections']);
    options = managementRows(catalog['providerOptions']);
  }

  Future<void> create() async {
    if (options.isEmpty) {
      throw const RaftUserError(
        'The provider connection could not be created.',
      );
    }
    await form(
      'Add provider connection',
      [
        const RaftFormField('name', 'Connection name', required: true),
        RaftFormField(
          'providerId',
          'Provider',
          choices: {for (final p in options) '${p['id']}': '${p['label']}'},
        ),
        const RaftFormField(
          'endpointUrl',
          'Gateway endpoint',
          help: 'Required for an OpenAI or Anthropic compatible gateway.',
          validator: managementHttpUrl,
        ),
        const RaftFormField(
          'supportsImageInput',
          'Image input',
          initial: 'false',
          choices: {'false': 'Text only', 'true': 'Text and images'},
        ),
        const RaftFormField(
          'apiKey',
          'API key',
          required: true,
          obscure: true,
          trim: false,
          help: 'Encrypted on the server. The key cannot be read back.',
        ),
      ],
      (v) async {
        final gateway = options.any(
          (p) => p['id'] == v['providerId'] && p['providerKind'] == 'gateway',
        );
        if (gateway && v['endpointUrl']!.isEmpty) {
          throw const RaftUserError(
            'The provider connection could not be created.',
          );
        }
        await _web('The provider connection could not be created.', () async {
          await w.client.post(
            '/provider-connections',
            data: {
              'name': v['name'],
              'providerId': v['providerId'],
              'apiKey': v['apiKey'],
              if (gateway) 'endpointUrl': v['endpointUrl'],
              if (gateway)
                'supportsImageInput': v['supportsImageInput'] == 'true',
            },
          );
        });
      },
      submit: 'Add',
    );
  }

  Future<void> edit(Map<String, dynamic> connection) async {
    final gateway = options.any(
      (p) =>
          p['id'] == connection['providerId'] && p['providerKind'] == 'gateway',
    );
    await scopedRaftModal<bool>(
      form: true,
      (dialogContext) => EditProviderConnectionDialog(
        controller: w,
        connection: connection,
        gateway: gateway,
        onCompleted: reload,
      ),
    );
  }

  Future<void> rotate(Map<String, dynamic> connection) async {
    await form(
      'Rotate provider credential',
      [
        const RaftFormField(
          'apiKey',
          'New API key',
          required: true,
          obscure: true,
          trim: false,
        ),
      ],
      (v) => _web('The provider connection could not be updated.', () async {
        await w.client.post(
          '/provider-connections/${connection['id']}/credentials/rotate',
          data: {'apiKey': v['apiKey']},
        );
      }),
      description:
          'The new credential replaces the existing one. Agents must use the new credential version.',
      submit: 'Rotate',
    );
  }

  Future<void> assigned(Map<String, dynamic> connection) async {
    if (!mounted) return;
    String? detachId;
    // The dialog opens at once and fills in when the list answers.
    await scopedDialog<void>(
      (dialog) => _LoadedDialog<Map<String, dynamic>>(
        load: () async => managementMap(
          await w.client.get(
            '/provider-connections/${connection['id']}/agents',
          ),
        ),
        builder: (context, data, failure) => AlertDialog(
          title: Text('Agents using ${connection['name']}'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data == null)
                    Text(
                      raftText(
                        context,
                        failure == null
                            ? 'Loading…'
                            : _loadFailure(
                                failure,
                                'Assigned Agents could not be loaded.',
                              ),
                      ),
                    )
                  else if (managementRows(data['agents']).isEmpty)
                    const Text('No agents use this connection.'),
                  for (final a in managementRows(data?['agents']))
                    ListTile(
                      title: Text(humanDisplayName(a)),
                      subtitle: Text(
                        '${runtimeLabelWithStatus(context, '${a['runtime'] ?? ''}')} · ${a['status']}${a['computerName'] == null ? '' : ' · ${a['computerName']}'}',
                      ),
                      trailing: a['deleted'] == true
                          ? RaftTooltip(
                              message: 'Detach deleted agent',
                              child: IconButton(
                                icon: const RaftIcon(
                                  RaftGlyph.link2Off,
                                  size: 15,
                                ),
                                onPressed: () {
                                  detachId = a['id'];
                                  Navigator.pop(context);
                                },
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
    if (detachId != null) {
      await confirm(
        'Detach deleted agent?',
        'Remove the assignment left by this deleted agent.',
        () => _web('The provider connection could not be updated.', () async {
          await w.client.delete(
            '/provider-connections/${connection['id']}/agents/$detachId',
          );
        }),
        submit: 'Detach',
      );
    }
  }

  /// The online Built-in Pi computers (the directory's copy when it has been
  /// read, else the machines list) and the provider's model names.
  Future<({List<Map<String, dynamic>> candidates, List<String> models})>
  _verificationInputs(Map<String, dynamic> connection) async {
    final directory = w.services.entityDirectory;
    final local = directory.state(WorkspaceEntityKind.computers).loaded;
    final machines = local
        ? directory.rows(WorkspaceEntityKind.computers)
        : managementRows(
            managementMap(
              await w.client.get('/servers/${w.server!.id}/machines'),
            )['machines'],
          );
    final candidates = machines
        .where(
          (m) =>
              m['status'] == 'online' &&
              managementStrings(m['runtimes']).contains('builtin'),
        )
        .toList();
    if (candidates.isEmpty) {
      // Web `settings.providers.verifyNoComputers`.
      throw const RaftUserError(
        'No online Computer with the Built-in runtime is connected.',
      );
    }
    List<String> models = [];
    try {
      models = managementStrings(
        managementMap(
          await w.client.get(
            '/provider-connections/${connection['id']}/models',
          ),
        )['models'],
      );
    } on RaftApiException catch (e) {
      if (e.status != 410) rethrow;
    }
    return (candidates: candidates, models: models);
  }

  Future<void> verify(Map<String, dynamic> connection) async {
    final generation = w.client.generation, sourceAuthority = authority;
    Map<String, dynamic> result = {};
    String? requestId, requestFingerprint;
    // The form opens at once; its computer and model choices fill in when the
    // inputs are read.
    final submitted =
        await scopedDialog<bool>(
          form: true,
          (
            dialog,
          ) => _LoadedDialog<({List<Map<String, dynamic>> candidates, List<String> models})>(
            load: () => _verificationInputs(connection),
            builder: (dialogContext, inputs, failure) => inputs == null
                ? RaftFormDialog(
                    title: 'Verify on a computer',
                    fields: const [],
                    description: failure == null
                        ? 'Loading…'
                        : _loadFailure(
                            failure,
                            'Verification could not be started.',
                          ),
                    submitLabel: 'Verify',
                    onSubmit: (_) async => throw const RaftUserError(
                      'Verification could not be started.',
                    ),
                  )
                : RaftFormDialog(
                    title: 'Verify on a computer',
                    fields: [
                      RaftFormField(
                        'computerId',
                        'Computer',
                        choices: {
                          for (final m in inputs.candidates)
                            '${m['id']}': '${m['name']}',
                        },
                      ),
                      RaftFormField(
                        'model',
                        'Model',
                        initial: inputs.models.firstOrNull ?? '',
                        required: true,
                        help: inputs.models.isEmpty
                            ? 'Enter the model supported by this provider.'
                            : 'Available: ${inputs.models.join(', ')}',
                      ),
                    ],
                    onSubmit: (v) async {
                      if (!accepts(generation) ||
                          sourceAuthority != authority) {
                        throw StateError(
                          'The active workspace changed. Reopen this form.',
                        );
                      }
                      try {
                        final fingerprint =
                            '${v['computerId']}\u0000${v['model']}';
                        if (requestFingerprint != fingerprint) {
                          requestFingerprint = fingerprint;
                          requestId = w.client.newRandomId();
                        }
                        result = managementMap(
                          await w.client.request(
                            'POST',
                            '/provider-connections/${connection['id']}/probes',
                            receiveTimeout: const Duration(seconds: 50),
                            data: {
                              'probeRequestId': requestId,
                              'requestDigest': providerProbeRequestDigest(
                                connectionId: connection['id'],
                                // ignore: raft_lints/avoid_render_index_assertion -- Submit values of the form dialog: every field id is present in the submitted map.
                                computerId: v['computerId']!,
                                // ignore: raft_lints/avoid_render_index_assertion -- Submit values of the form dialog: every field id is present in the submitted map.
                                model: v['model']!,
                              ),
                              'computerId': v['computerId'],
                              'runtime': 'builtin',
                              'model': v['model'],
                              'probeKind': 'canary',
                            },
                          ),
                        );
                        final receipt = managementMap(result['probe']);
                        if (receipt['probeRequestId'] != requestId ||
                            receipt['connectionId'] != connection['id'] ||
                            receipt['computerId'] != v['computerId'] ||
                            receipt['runtime'] != 'builtin' ||
                            receipt['model'] != v['model'] ||
                            receipt['probeKind'] != 'canary') {
                          result = {};
                          throw const RaftUserError(
                            'Verification could not be started.',
                          );
                        }
                        if (receipt['outcome'] == 'success' &&
                            (receipt['verifiedAt'] is! String ||
                                receipt['closedAt'] is! String)) {
                          result = {};
                          throw const RaftUserError(
                            'Verification could not be started.',
                          );
                        }
                      } catch (e) {
                        if (accepts(generation) &&
                            sourceAuthority == authority &&
                            invalidateDeniedMutation(e) &&
                            dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(false);
                        }
                        // Web `settings.providers.verifyError`; 401/403 stay
                        // untouched for the page's authority handling.
                        if (e is RaftUserError ||
                            e is RaftApiException &&
                                const [401, 403].contains(e.status)) {
                          rethrow;
                        }
                        logUserError(e, where: 'provider verify');
                        throw const RaftUserError(
                          'Verification could not be started.',
                        );
                      }
                    },
                    submitLabel: 'Verify',
                    description:
                        'Run one canary request through the selected computer. This may incur the provider’s normal usage charges.',
                  ),
          ),
        ) ==
        true;
    if (submitted && mounted) {
      final receipt = managementMap(result['probe']);
      await scopedDialog<void>(
        (context) => AlertDialog(
          title: Text(
            receipt['outcome'] == 'success'
                ? 'Provider verified'
                : 'Provider verification result',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Outcome: ${receipt['outcome'] ?? 'Pending'}'),
                if (receipt['category'] != null)
                  Text('Reason: ${receipt['category']}'),
                if (receipt['latencyMs'] != null)
                  Text('Response time: ${receipt['latencyMs']} ms'),
                if (result['reply'] is String) SelectableText(result['reply']),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> history(Map<String, dynamic> connection) async {
    // The dialog opens at once and fills in when the receipts answer.
    await scopedDialog<void>(
      (dialog) => _LoadedDialog<List<Map<String, dynamic>>>(
        load: () async => managementRows(
          managementMap(
            await w.client.get(
              '/provider-connections/${connection['id']}/probes',
            ),
          )['receipts'],
        ),
        builder: (dialog, receipts, failure) => AlertDialog(
          title: Text(raftText(context, 'Provider verification history')),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (receipts == null)
                    Text(
                      raftText(
                        context,
                        failure == null ? 'Loading…' : _loadFailure(failure),
                      ),
                    )
                  else if (receipts.isEmpty)
                    Text(
                      raftText(context, 'No completed verification receipts.'),
                    ),
                  for (final r in receipts ?? const <Map<String, dynamic>>[])
                    ListTile(
                      leading: Icon(
                        r['outcome'] == 'success'
                            ? Icons.verified_outlined
                            : Icons.error_outline,
                      ),
                      title: Text('${r['model']} · ${r['outcome']}'),
                      subtitle: Text(
                        '${r['verifiedAt']}\nComputer ${r['computerId']} · ${r['runtime']}\n${r['category'] ?? ''}${r['latencyMs'] == null ? '' : ' · ${r['latencyMs']} ms'}\nConfiguration ${r['configVersion']} · Credential version ${r['credentialVersion']}',
                      ),
                      isThreeLine: true,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(raftText(context, 'Close')),
            ),
          ],
        ),
      ),
    );
  }

  /// ProviderConnectionsSettings renders nothing while the feature is off.
  @override
  Widget build(BuildContext context) => !enabled && !loading
      ? const SizedBox.shrink()
      : ListView(
          primary: false,
          padding: raftScrollPadding(
            context,
            RaftSettingsPanelFrame.contentInset,
          ),
          children: [
            RaftProviderConnectionsFrame(
              loading: loading && connections.isEmpty,
              error: error == null ? null : raftText(context, error!),
              canAdd: options.isNotEmpty && !busy,
              onAdd: w.can('manageExternalAuth') ? () => run(create) : null,
              rows: [
                for (final connection in connections)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${connection['name']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${options.where((p) => p['id'] == connection['providerId']).firstOrNull?['label'] ?? connection['providerId']} · ${connection['status']} · ${connection['enabled'] == true ? 'Enabled' : 'Disabled'}',
                        ),
                        if (connection['endpointUrl'] != null)
                          SelectableText('${connection['endpointUrl']}'),
                        Text(
                          '${connection['assignedAgentCount']} assigned agents · ${connection['hasCredential'] == true ? 'Credential saved' : 'No credential'}',
                        ),
                        if (connection['latestVerified'] is Map)
                          Text(
                            'Verified on ${managementMap(connection['latestVerified'])['computerName'] ?? 'computer'} · ${managementMap(connection['latestVerified'])['model']}',
                          ),
                        Wrap(
                          children: [
                            KeyedSubtree(
                              key: ValueKey(
                                'provider-edit-${connection['id']}',
                              ),
                              child: action(
                                'Edit connection',
                                () => run(() => edit(connection)),
                              ),
                            ),
                            action(
                              'Assigned agents',
                              () => run(
                                () => assigned(connection),
                                refresh: false,
                              ),
                            ),
                            action(
                              'Verify on computer',
                              () => run(() => verify(connection)),
                            ),
                            action(
                              'Verification history',
                              () => run(
                                () => history(connection),
                                refresh: false,
                              ),
                            ),
                            if (w.can('rotateServerSecrets'))
                              action(
                                'Rotate credential',
                                () => run(() => rotate(connection)),
                              ),
                            action(
                              'Delete connection',
                              () => run(() async {
                                await confirm(
                                  'Delete ${connection['name']}?',
                                  'Remove this connection and its encrypted credential. Assigned agents must be detached first.',
                                  () => _web(
                                    'The provider connection could not be updated.',
                                    () async {
                                      await w.client.delete(
                                        '/provider-connections/${connection['id']}',
                                      );
                                    },
                                  ),
                                  submit: 'Delete',
                                  destructive: true,
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
}

/// The English source text for a dialog's failed read: the caller's own
/// message (`RaftUserError`) or [fallback]; never the exception text.
String _loadFailure(Object failure, [String fallback = raftGenericErrorText]) {
  logUserError(failure, where: 'provider dialog read');
  return failure is RaftUserError ? failure.message : fallback;
}

/// Opens a dialog at once: [builder] gets no data (and, once the read failed,
/// the [failure]) until [load] answers, then the data.
class _LoadedDialog<T> extends StatefulWidget {
  const _LoadedDialog({required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T? data, Object? failure) builder;
  @override
  State<_LoadedDialog<T>> createState() => _LoadedDialogState<T>();
}

class _LoadedDialogState<T> extends State<_LoadedDialog<T>> {
  T? data;
  Object? failure;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final value = await widget.load();
      if (mounted) setState(() => data = value);
    } catch (e) {
      if (mounted) setState(() => failure = e);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, data, failure);
}
