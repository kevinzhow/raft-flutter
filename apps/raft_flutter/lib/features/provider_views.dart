import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';

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
  Future<void> loadData(int request, int generation) async {
    final flags = managementMap(
      await w.client.post(
        '/feature-flags/evaluate',
        data: {
          'keys': ['provider_connections_v0'],
          'serverId': w.server?.id,
          'platform': defaultTargetPlatform == TargetPlatform.android
              ? 'mobile'
              : 'web',
        },
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
    if (options.isEmpty) throw StateError('No provider choices are available.');
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
          throw StateError('A gateway endpoint is required.');
        }
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
      },
      submit: 'Add',
    );
  }

  Future<void> edit(Map<String, dynamic> connection) async {
    await form(
      'Edit provider connection',
      [
        RaftFormField(
          'name',
          'Connection name',
          initial: connection['name'] ?? '',
          required: true,
        ),
        RaftFormField(
          'enabled',
          'Enabled',
          initial: connection['enabled'] == true ? 'true' : 'false',
          choices: const {'true': 'Enabled', 'false': 'Disabled'},
        ),
        if (connection['endpointUrl'] != null) ...[
          RaftFormField(
            'endpointUrl',
            'Gateway endpoint',
            initial: connection['endpointUrl'] ?? '',
            required: true,
            validator: managementHttpUrl,
          ),
          RaftFormField(
            'supportsImageInput',
            'Image input',
            initial: connection['supportsImageInput'] == true
                ? 'true'
                : 'false',
            choices: const {'false': 'Text only', 'true': 'Text and images'},
          ),
        ],
      ],
      (v) async {
        await w.client.patch(
          '/provider-connections/${connection['id']}',
          data: {
            'name': v['name'],
            'enabled': v['enabled'] == 'true',
            if (v.containsKey('endpointUrl')) 'endpointUrl': v['endpointUrl'],
            if (v.containsKey('supportsImageInput'))
              'supportsImageInput': v['supportsImageInput'] == 'true',
          },
        );
      },
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
      (v) async {
        await w.client.post(
          '/provider-connections/${connection['id']}/credentials/rotate',
          data: {'apiKey': v['apiKey']},
        );
      },
      description: 'The new credential replaces the existing one. Agents must use the new credential version.',
      submit: 'Rotate',
    );
  }

  Future<void> assigned(Map<String, dynamic> connection) async {
    final data = managementMap(
      await w.client.get('/provider-connections/${connection['id']}/agents'),
    );
    if (!mounted) return;
    String? detachId;
    await scopedDialog<void>(
      (context) => AlertDialog(
        title: Text('Agents using ${connection['name']}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (managementRows(data['agents']).isEmpty)
                  const Text('No agents use this connection.'),
                for (final a in managementRows(data['agents']))
                  ListTile(
                    title: Text('${a['displayName'] ?? a['name']}'),
                    subtitle: Text(
                      '${a['runtime']} · ${a['status']}${a['computerName'] == null ? '' : ' · ${a['computerName']}'}',
                    ),
                    trailing: a['deleted'] == true
                        ? IconButton(
                            tooltip: 'Detach deleted agent',
                            icon: const RaftIcon(RaftGlyph.link2Off, size: 15),
                            onPressed: () {
                              detachId = a['id'];
                              Navigator.pop(context);
                            },
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
    );
    if (detachId != null) {
      await confirm(
        'Detach deleted agent?',
        'Remove the assignment left by this deleted agent.',
        () async {
          await w.client.delete(
            '/provider-connections/${connection['id']}/agents/$detachId',
          );
        },
        submit: 'Detach',
      );
    }
  }

  Future<void> verify(Map<String, dynamic> connection) async {
    final machineData = managementMap(
      await w.client.get('/servers/${w.server!.id}/machines'),
    );
    final candidates = managementRows(machineData['machines'])
        .where(
          (m) =>
              m['status'] == 'online' &&
              managementStrings(m['runtimes']).contains('builtin'),
        )
        .toList();
    if (candidates.isEmpty) {
      throw StateError(
        'Connect a computer with the Built-in Pi runtime before verification.',
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
    Map<String, dynamic> result = {};
    String? requestId, requestFingerprint;
    final submitted = await form(
      'Verify on a computer',
      [
        RaftFormField(
          'computerId',
          'Computer',
          choices: {for (final m in candidates) '${m['id']}': '${m['name']}'},
        ),
        RaftFormField(
          'model',
          'Model',
          initial: models.firstOrNull ?? '',
          required: true,
          help: models.isEmpty
              ? 'Enter the model supported by this provider.'
              : 'Available: ${models.join(', ')}',
        ),
      ],
      (v) async {
        final fingerprint = '${v['computerId']}\u0000${v['model']}';
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
                computerId: v['computerId']!,
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
          throw StateError(
            'The verification receipt does not match this request. Refresh and retry.',
          );
        }
        if (receipt['outcome'] == 'success' &&
            (receipt['verifiedAt'] is! String ||
                receipt['closedAt'] is! String)) {
          result = {};
          throw StateError(
            'The computer has not returned a completed verification receipt. Retry this request.',
          );
        }
      },
      submit: 'Verify',
      description: 'Run one canary request through the selected computer. This may incur the provider’s normal usage charges.',
    );
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
    final result = managementMap(
      await w.client.get('/provider-connections/${connection['id']}/probes'),
    );
    final receipts = managementRows(result['receipts']);
    await scopedDialog<void>(
      (dialog) => AlertDialog(
        title: Text(raftText(context, 'Provider verification history')),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (receipts.isEmpty)
                  Text(
                    raftText(context, 'No completed verification receipts.'),
                  ),
                for (final r in receipts)
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
    );
  }

  @override
  Widget build(BuildContext context) => page(
    'Provider connections',
    [
      if (!enabled && !loading)
        const Text('Provider connections are not enabled for this workspace.'),
      if (enabled && connections.isEmpty && !loading)
        const Text(
          'Add a provider connection to share an encrypted credential with agents.',
        ),
      for (final connection in connections)
        Card(
          child: Padding(
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
                    action(
                      'Edit connection',
                      () => run(() => edit(connection)),
                    ),
                    action(
                      'Assigned agents',
                      () => run(() => assigned(connection), refresh: false),
                    ),
                    action(
                      'Verify on computer',
                      () => run(() => verify(connection)),
                    ),
                    action(
                      'Verification history',
                      () => run(() => history(connection), refresh: false),
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
                          () async {
                            await w.client.delete(
                              '/provider-connections/${connection['id']}',
                            );
                          },
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
        ),
    ],
    actions: [
      if (enabled && w.can('manageExternalAuth'))
        action(
          'Add provider',
          () => run(create),
          glyph: RaftGlyph.plus,
          glyphSize: 16,
        ),
    ],
  );
}
