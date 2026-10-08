import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';
import 'mcp_views.dart';
import 'app_notifications_catalog.dart';

const integrationScopeLabels = <String, String>{
  'openid': 'OpenID identity',
  'profile': 'Basic profile',
  'email': 'Email address',
  'identity': 'Raft identity card',
  'agent:read': 'Read workspace agent directory',
  'agent:event:write': 'Send structured events to an agent',
  'agent:notification:write': 'Send notifications to an agent',
  'agent:action_request:write': 'Request agent action',
};
const integrationCategories = [
  'AI & Automation',
  'Communication',
  'Productivity & Collaboration',
  'Developer Tools',
  'Data & Analytics',
  'Business Ops',
  'Infrastructure',
  'Content & Creative',
  'Other',
];

class IntegrationsView extends StatefulWidget {
  const IntegrationsView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<IntegrationsView> createState() => _IntegrationsState();
}

class _IntegrationsState extends ManagementState<IntegrationsView> {
  @override
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>> apps = [], marketplace = [], access = [];
  String filter = '';
  @override
  void initState() {
    super.initState();
    startManagement();
  }

  @override
  void clearData() {
    apps = [];
    marketplace = [];
    access = [];
  }

  @override
  Future<void> loadData(int request, int generation) async {
    final data = await Future.wait(
      [
        '/integrations/clients',
        '/integrations/marketplace',
        '/integrations/overview',
      ].map(w.client.get),
    );
    if (!accepts(generation, request)) return;
    apps = managementRows(data[0]);
    marketplace = managementRows(data[1]);
    access = managementRows(data[2]);
  }

  Future<void> edit([Map<String, dynamic>? app]) async {
    Map<String, dynamic>? created;
    final scopes = managementStrings(app?['allowedScopes']);
    final saved = await form(
      app == null ? 'Register app' : 'Edit app',
      [
        RaftFormField(
          'name',
          'App name',
          initial: app?['name'] ?? '',
          required: true,
        ),
        if (app == null)
          const RaftFormField(
            'clientId',
            'Client ID',
            help: 'Leave blank to generate an ID.',
          ),
        RaftFormField(
          'description',
          'Description',
          initial: app?['description'] ?? '',
          multiline: true,
        ),
        RaftFormField(
          'whenToUse',
          'When to use this app',
          initial: app?['whenToUse'] ?? '',
          multiline: true,
        ),
        RaftFormField(
          'homepageUrl',
          'Homepage',
          initial: app?['homepageUrl'] ?? '',
          validator: managementHttpUrl,
        ),
        RaftFormField(
          'returnUrl',
          'Return URL',
          initial: app?['returnUrl'] ?? '',
          validator: managementHttpUrl,
        ),
        RaftFormField(
          'agentManifestUrl',
          'Agent manifest URL',
          initial: app?['agentManifestUrl'] ?? '',
          validator: managementHttpUrl,
        ),
        RaftFormField(
          'category',
          'Category',
          initial: app?['category'] ?? 'Other',
          choices: {for (final c in integrationCategories) c: c},
        ),
        RaftFormField(
          'scopes',
          'Allowed scopes',
          initial: app == null
              ? 'openid, profile, identity'
              : scopes.join(', '),
          help: integrationScopeLabels.keys.join(', '),
          validator: (v) =>
              parseIntegrationScopes(v)
                  .any((s) => !integrationScopeLabels.containsKey(s))
              ? 'Choose supported scopes from the list.'
              : null,
        ),
      ],
      (values) async {
        final data = <String, dynamic>{
          for (final e in values.entries)
            if (e.key != 'scopes' && e.key != 'clientId')
              e.key: e.value.isEmpty ? null : e.value,
          'allowedScopes': parseIntegrationScopes(values['scopes']!),
        };
        if (app == null) {
          if (values['clientId']!.isNotEmpty) {
            data['clientId'] = values['clientId'];
          }
          created = managementMap(
            await w.client.post('/integrations/clients', data: data),
          );
        } else {
          await w.client.patch(
            '/integrations/clients/${app['id']}',
            data: data,
          );
        }
      },
      submit: app == null ? 'Register' : 'Save',
    );
    if (saved) {
      await reload();
      final credential = created?['clientSecret'];
      if (credential is String && credential.isNotEmpty) {
        await secret(credential, label: 'App client secret');
      }
    }
  }

  Future<void> openApp(Map<String, dynamic> app) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(app['name'] ?? 'App')),
          body: AppManagementView(
            controller: w,
            appId: app['id'],
            initial: app,
          ),
        ),
      ),
    );
    await reload();
  }

  Future<void> install(Map<String, dynamic> listing) async {
    final installed = listing['installationId'] != null;
    final scopes = managementStrings(listing['allowedScopes'])
        .map((s) => integrationScopeLabels[s] ?? s)
        .join('\n');
    final changed = await confirm(
      installed
          ? 'Uninstall ${listing['name']}?'
          : 'Install ${listing['name']}?',
      installed
          ? 'Disconnect this app from this workspace and revoke its access.'
          : '${listing['description'] ?? ''}\n\nRequested permissions:\n$scopes',
      () async {
        final path = '/integrations/marketplace/${listing['id']}/install';
        if (installed) {
          await w.client.delete(path);
        } else {
          await w.client.post(path);
        }
      },
      submit: installed ? 'Uninstall' : 'Install',
      destructive: installed,
    );
    if (changed) await reload();
  }

  Future<void> privateInvite() async {
    String? token;
    Map<String, dynamic> invite = {};
    final read = await form(
      'Install a private app',
      [
        const RaftFormField(
          'code',
          'Private sharing code or link',
          required: true,
          obscure: true,
          trim: false,
        ),
      ],
      (v) async {
        final input = v['code']!.trim();
        final uri = Uri.tryParse(input);
        token = uri != null && uri.hasScheme
            ? uri.pathSegments.lastOrNull
            : input;
        if (token == null || token!.isEmpty) {
          throw StateError('Enter a valid private sharing code.');
        }
        invite = managementMap(
          await w.client.get(
            '/integration-invites/${Uri.encodeComponent(token!)}',
          ),
        );
      },
      submit: 'Review permissions',
    );
    if (!read || token == null) return;
    final app = managementMap(invite['client']);
    final eligible = managementRows(invite['manageableServers'])
        .any((s) => s['id'] == w.server?.id);
    if (!eligible) {
      throw StateError(
        'You must own or administer this workspace to install the app.',
      );
    }
    final changed = await confirm(
      'Install ${app['name']}?',
      '${app['description'] ?? ''}\nPublisher: ${app['publisherName'] ?? app['sourceServerName'] ?? ''}\n\nRequested permissions:\n${managementStrings(app['allowedScopes']).map((s) => integrationScopeLabels[s] ?? s).join('\n')}',
      () async {
        await w.client.post(
          '/integration-invites/${Uri.encodeComponent(token!)}/install',
          data: {'serverId': w.server!.id},
        );
      },
      submit: 'Install',
    );
    token = null;
    if (changed) await reload();
  }

  Future<void> notificationGrant(Map<String, dynamic> app) async {
    final path =
        '/integrations/marketplace/${app['id']}/install/app-notifications';
    final state = managementMap(await w.client.get(path));
    await confirm(
      'Review app notification permissions',
      'Requested workspace access: ${managementStrings(state['requested_groups']).join(', ')}\nSubscribed events: ${managementStrings(state['requested_events']).join(', ')}\n\nCurrent access: ${managementStrings(state['effective_groups']).join(', ')}${state['app_review_pending'] == true ? '\nThe app has pending permission changes under marketplace review.' : ''}',
      () async {
        await w.client.request('PUT', '$path/grant');
      },
      submit: 'Approve current permissions',
    );
  }

  @override
  Widget build(BuildContext context) => page(
    'Connected apps',
    [
      TextField(
        decoration: const InputDecoration(
          labelText: 'Search apps',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => filter = v.toLowerCase()),
      ),
      heading('Marketplace'),
      if (marketplace.isEmpty && !loading)
        const Text('No apps are listed for this workspace.'),
      for (final app in marketplace.where(
        (a) =>
            '${a['name']} ${a['description']}'.toLowerCase().contains(filter),
      ))
        Card(
          child: ListTile(
            leading: const Icon(Icons.apps),
            title: Text('${app['name']}'),
            subtitle: Text(
              '${app['description'] ?? ''}\n${app['category'] ?? 'Other'}${app['official'] == true ? ' · Official' : ''}',
            ),
            isThreeLine: true,
            trailing: w.can('manageIntegrations')
                ? action(
                    app['installationId'] != null ? 'Uninstall' : 'Install',
                    () => run(() => install(app), refresh: false),
                  )
                : null,
            onTap: () => scopedDialog<void>(
              (context) => AlertDialog(
                title: Text('${app['name']}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${app['description'] ?? ''}'),
                      if (app['whenToUse'] != null) Text('${app['whenToUse']}'),
                      if (app['installationId'] != null &&
                          w.can('manageIntegrations'))
                        action('Review notification permissions', () {
                          Navigator.pop(context);
                          run(() => notificationGrant(app));
                        }),
                      const SizedBox(height: 12),
                      for (final s in managementStrings(app['allowedScopes']))
                        Text('• ${integrationScopeLabels[s] ?? s}'),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  if (w.can('manageIntegrations'))
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        run(() => install(app), refresh: false);
                      },
                      child: Text(
                        app['installationId'] != null ? 'Uninstall' : 'Install',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      heading('My apps'),
      if (apps.isEmpty && !loading)
        const Text('Register an app to connect it with Raft.'),
      for (final app in apps.where(
        (a) => '${a['name']}'.toLowerCase().contains(filter),
      ))
        Card(
          child: ListTile(
            title: Text('${app['name']}'),
            subtitle: Text(
              '${app['description'] ?? ''}\n${app['publishStatus'] ?? 'private'}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openApp(app),
          ),
        ),
      heading('Agent access'),
      if (access.isEmpty && !loading)
        const Text('No pending requests or active app access.'),
      for (final item in access)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['clientName']} · ${item['agentDisplayName'] ?? item['agentName']}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  item['type'] == 'pending'
                      ? 'Approval requested'
                      : 'Access granted',
                ),
                for (final s in managementStrings(item['scopes']))
                  Text('• ${integrationScopeLabels[s] ?? s}'),
                if (w.can('manageIntegrations'))
                  Wrap(
                    children: [
                      if (item['type'] == 'pending') ...[
                        action(
                          'Approve',
                          () => run(() async {
                            await confirm(
                              'Approve app access?',
                              'Allow ${item['clientName']} to access ${item['agentDisplayName'] ?? item['agentName']} with the listed permissions.',
                              () async {
                                await w.client.post(
                                  '/integrations/requests/${item['id']}/approve',
                                );
                              },
                              submit: 'Approve',
                            );
                          }),
                        ),
                        action(
                          'Deny',
                          () => run(() async {
                            await w.client.post(
                              '/integrations/requests/${item['id']}/deny',
                            );
                          }),
                        ),
                      ] else
                        action(
                          'Revoke',
                          () => run(() async {
                            await confirm(
                              'Revoke app access?',
                              'Disconnect this app from the agent.',
                              () async {
                                await w.client.post(
                                  '/integrations/grants/${item['id']}/revoke',
                                );
                              },
                              submit: 'Revoke',
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
      if (w.can('manageIntegrations'))
        action('Install private app', () => run(privateInvite, refresh: false)),
      if (w.can('manageIntegrations'))
        action(
          'Register app',
          () => run(() => edit(), refresh: false),
          icon: Icons.add,
        ),
      action(
        'MCP',
        () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('MCP connections')),
              body: AgentMcpView(controller: w),
            ),
          ),
        ),
      ),
    ],
  );
}

List<String> parseIntegrationScopes(String input) =>
    input.split(RegExp(r'[,\s]+')).where((v) => v.isNotEmpty).toSet().toList();

class AppManagementView extends StatefulWidget {
  const AppManagementView({
    super.key,
    required this.controller,
    required this.appId,
    required this.initial,
  });
  final WorkspaceController controller;
  final String appId;
  final Map<String, dynamic> initial;
  @override
  State<AppManagementView> createState() => _AppManagementState();
}

class _AppManagementState extends ManagementState<AppManagementView> {
  @override
  WorkspaceController get w => widget.controller;
  Map<String, dynamic> app = {}, notifications = {}, share = {};
  @override
  void initState() {
    super.initState();
    app = widget.initial;
    startManagement();
  }

  @override
  void clearData() {
    app = {};
    notifications = {};
    share = {};
  }

  String get base => '/integrations/clients/${widget.appId}';
  @override
  Future<void> loadData(int request, int generation) async {
    final values = await Future.wait([
      w.client.get('/integrations/clients'),
      if (w.can('manageIntegrations')) w.client.get('$base/app-notifications'),
      if (w.can('manageIntegrations')) readShare(),
    ]);
    if (!accepts(generation, request)) return;
    app =
        managementRows(values[0])
            .where((a) => a['id'] == widget.appId)
            .firstOrNull ??
        {};
    if (values.length > 1) {
      notifications = managementMap(values[1]);
      share = managementMap(values[2]);
    }
  }

  Future<dynamic> readShare() async {
    try {
      return await w.client.get('$base/share-link');
    } on RaftApiException catch (e) {
      if (e.status == 404) return <String, dynamic>{};
      rethrow;
    }
  }

  Future<void> edit() async {
    await form(
      'Edit app',
      [
        RaftFormField(
          'name',
          'App name',
          initial: app['name'] ?? '',
          required: true,
        ),
        RaftFormField(
          'description',
          'Description',
          initial: app['description'] ?? '',
          multiline: true,
        ),
        RaftFormField(
          'whenToUse',
          'When to use this app',
          initial: app['whenToUse'] ?? '',
          multiline: true,
        ),
        for (final f in ['homepageUrl', 'returnUrl', 'agentManifestUrl'])
          RaftFormField(
            f,
            {
              'homepageUrl': 'Homepage',
              'returnUrl': 'Return URL',
              'agentManifestUrl': 'Agent manifest URL',
            }[f]!,
            initial: app[f] ?? '',
            validator: managementHttpUrl,
          ),
        RaftFormField(
          'category',
          'Category',
          initial: app['category'] ?? 'Other',
          choices: {for (final c in integrationCategories) c: c},
        ),
        RaftFormField(
          'scopes',
          'Allowed scopes',
          initial: managementStrings(app['allowedScopes']).join(', '),
          help: integrationScopeLabels.keys.join(', '),
          validator: (v) =>
              parseIntegrationScopes(v)
                  .any((s) => !integrationScopeLabels.containsKey(s))
              ? 'Choose supported scopes.'
              : null,
        ),
      ],
      (v) async {
        await w.client.patch(
          base,
          data: {
            for (final e in v.entries)
              if (e.key != 'scopes') e.key: e.value.isEmpty ? null : e.value,
            'allowedScopes': parseIntegrationScopes(v['scopes']!),
          },
        );
      },
    );
  }

  Future<void> uploadLogo() async {
    final generation = w.client.generation, scope = authority;
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'App logo',
          extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
          mimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
        ),
      ],
    );
    if (file == null || !accepts(generation) || scope != authority) return;
    if (await file.length() > 5 * 1024 * 1024) {
      throw StateError('App logo must be 5 MB or smaller.');
    }
    final mime = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
    }[file.name.split('.').last.toLowerCase()];
    if (mime == null) {
      throw StateError('Choose a JPEG, PNG, GIF or WebP image.');
    }
    final bytes = await file.readAsBytes();
    if (!accepts(generation) || scope != authority) return;
    await w.client.post(
      '$base/logo',
      data: FormData.fromMap({
        'logo': MultipartFile.fromBytes(
          bytes,
          filename: file.name,
          contentType: DioMediaType.parse(mime),
        ),
      }),
    );
  }

  Future<void> permissions() async {
    final pending = managementMap(notifications['pending_revision']);
    await form(
      'App notification permissions',
      [
        RaftFormField(
          'groups',
          'Permission groups',
          initial: managementStrings(
            pending['groups'] ?? notifications['current_groups'],
          ).join(', '),
          help: appNotificationGroups
              .where(
                (g) => app['official'] == true || g != 'agent_reminder_write',
              )
              .join(', '),
          validator: (v) =>
              parseIntegrationScopes(v).any(
                (g) =>
                    !appNotificationGroups.contains(g) ||
                    (g == 'agent_reminder_write' && app['official'] != true),
              )
              ? 'Choose supported permission groups.'
              : null,
        ),
        RaftFormField(
          'events',
          'Subscribed events',
          help: appNotificationEventGroups.keys.join(', '),
          validator: (v) =>
              parseIntegrationScopes(v)
                  .any((e) => !appNotificationEventGroups.containsKey(e))
              ? 'Choose supported notification events.'
              : null,
          initial: managementStrings(
            pending['events'] ?? notifications['current_events'],
          ).join(', '),
        ),
      ],
      (v) async {
        final groups = parseIntegrationScopes(v['groups']!);
        for (final event in parseIntegrationScopes(v['events']!)) {
          for (final required
              in appNotificationEventGroups[event] ?? const <String>[]) {
            if (!groups.contains(required)) {
              throw StateError(
                '$event requires the $required permission group.',
              );
            }
          }
        }
        await w.client.request(
          'PUT',
          '$base/app-notifications/permissions',
          data: {
            'groups': parseIntegrationScopes(v['groups']!),
            'events': parseIntegrationScopes(v['events']!),
          },
        );
      },
      description: 'Changing published app permissions may require review and new installation approval.',
    );
  }

  Future<void> configureWebhook() async {
    Map<String, dynamic> result = {};
    final saved = await form(
      'Configure app webhook',
      [
        RaftFormField(
          'url',
          'HTTPS webhook address',
          initial:
              managementMap(notifications['webhook'])['endpoint_url'] ?? '',
          required: true,
          validator: (v) => Uri.tryParse(v)?.scheme == 'https'
              ? null
              : 'Use an HTTPS address.',
        ),
      ],
      (v) async {
        result = managementMap(
          await w.client.request(
            'PUT',
            '$base/app-notifications/webhook',
            data: {'endpointUrl': v['url']},
          ),
        );
      },
    );
    if (saved && result['signing_secret'] is String) {
      await secret(result['signing_secret'], label: 'Webhook signing secret');
    }
  }

  @override
  Widget build(BuildContext context) => page(app['name'] ?? 'App', [
    if (app.isNotEmpty) ...[
      Text(app['description'] ?? ''),
      if (app['whenToUse'] != null) Text(app['whenToUse']),
      SelectableText('Client ID: ${app['clientId']}'),
      Text('Publication: ${app['publishStatus'] ?? 'private'}'),
      for (final s in managementStrings(app['allowedScopes']))
        Text('• ${integrationScopeLabels[s] ?? s}'),
      if (w.can('manageIntegrations'))
        Wrap(
          children: [
            action('Edit app', () => run(edit)),
            action('Upload logo', () => run(uploadLogo)),
            if (app['logoUrl'] != null)
              action(
                'Remove logo',
                () => run(() async {
                  await confirm(
                    'Remove app logo?',
                    'The app will use its default icon.',
                    () async {
                      await w.client.delete('$base/logo');
                    },
                    submit: 'Remove',
                    destructive: true,
                  );
                }),
              ),
            if (w.can('rotateServerSecrets'))
              action(
                'Rotate client secret',
                () => run(() async {
                  await confirm('Rotate client secret?', 'Existing client credentials will stop working. Update the app with the new secret.', () async {
                    final result = await w.client.post(
                      '$base/regenerate-secret',
                    );
                    await secret(
                      result['clientSecret'],
                      label: 'New app client secret',
                    );
                  }, submit: 'Rotate');
                }),
              ),
            if ([
              'private',
              'rejected',
              'published',
            ].contains(app['publishStatus']))
              action(
                app['publishStatus'] == 'published'
                    ? 'Request unpublish'
                    : 'Request publication',
                () => run(() async {
                  await confirm(
                    app['publishStatus'] == 'published'
                        ? 'Request unpublish?'
                        : 'Submit app for review?',
                    app['publishStatus'] == 'published'
                        ? 'Ask to remove this app from the marketplace.'
                        : 'Submit this app for marketplace review. Publication happens after approval.',
                    () async {
                      await w.client.post(
                        '$base/${app['publishStatus'] == 'published' ? 'request-unpublish' : 'request-publish'}',
                      );
                    },
                    submit: 'Submit request',
                  );
                }),
              ),
          ],
        ),
      if (w.can('manageIntegrations')) ...[
        heading('App notifications'),
        Text(
          'Permission groups: ${managementStrings(notifications['current_groups']).join(', ')}',
        ),
        Text(
          'Events: ${managementStrings(notifications['current_events']).join(', ')}',
        ),
        if (notifications['pending_revision'] != null)
          const Text('Permission changes await marketplace review.'),
        Wrap(
          children: [
            action('Edit notification permissions', () => run(permissions)),
            action('Configure webhook', () => run(configureWebhook)),
            if (managementMap(notifications['webhook'])['enabled'] == true) ...[
              if (w.can('rotateServerSecrets'))
                action(
                  'Rotate webhook secret',
                  () => run(() async {
                    await confirm('Rotate webhook secret?', 'The previous signing secret remains valid during the server rotation window.', () async {
                      final result = await w.client.post(
                        '$base/app-notifications/webhook/rotate-secret',
                        data: {'emergency': false},
                      );
                      await secret(
                        result['signing_secret'],
                        label: 'New webhook signing secret',
                      );
                    }, submit: 'Rotate');
                  }),
                ),
              action(
                'Disable webhook',
                () => run(() async {
                  await confirm(
                    'Disable webhook?',
                    'Stop this app from receiving notifications.',
                    () async {
                      await w.client.delete('$base/app-notifications/webhook');
                    },
                    submit: 'Disable',
                  );
                }),
              ),
            ],
          ],
        ),
        if (['private', 'rejected'].contains(app['publishStatus'])) ...[
          heading('Private sharing'),
          Text(
            share.isEmpty
                ? 'No active sharing link.'
                : 'Sharing link is active.',
          ),
          Wrap(
            children: [
              action(
                'Create sharing link',
                () => run(() async {
                  final result = await w.client.post('$base/share-link');
                  await secret(
                    result['token'],
                    label: 'Private app sharing code',
                  );
                }),
              ),
              if (share.isNotEmpty)
                action(
                  'Revoke sharing link',
                  () => run(() async {
                    await confirm(
                      'Revoke sharing link?',
                      'People with the old link will no longer be able to install this app.',
                      () async {
                        await w.client.delete('$base/share-link');
                      },
                      submit: 'Revoke',
                      destructive: true,
                    );
                  }),
                ),
            ],
          ),
        ],
        heading('Delete app'),
        action(
          'Delete app',
          () => run(() async {
            final removed = await confirm(
              'Delete ${app['name']}?',
              'Delete the app and revoke its installations and grants. This cannot be undone.',
              () async {
                await w.client.delete(base);
              },
              submit: 'Delete',
              destructive: true,
            );
            if (removed && mounted) Navigator.pop(this.context);
          }, refresh: false),
          icon: Icons.delete,
        ),
      ],
    ],
  ]);
}
