// The Applications app editor (Web SettingsPanel.tsx IntegrationsSection
// `showRegisterDrawer`): one modal for registering and editing an app, with the
// Profile / Login with Raft / App permissions / Webhook / Distribution / Danger
// zone sections. State, API calls and the one-time secret flow live here; the
// presentation is raft_ui's RaftConnectedAppEditorCard.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/file_selection.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../platform/content_links.dart';
import 'agent_jwt_settings.dart';
import 'app_notifications_catalog.dart';
import 'app_when_to_use.dart';
import 'integrations_views.dart';
import 'management_support.dart';

/// The one-time client secret the page keeps (Web `createdSecret` /
/// `createdSecretClientId` / `secretCopied`), shown in the editor strip while
/// it is open and under the filters otherwise.
class ConnectedAppSecret {
  const ConnectedAppSecret(this.clientId, this.value, {this.copied = false});
  final String clientId, value;
  final bool copied;
  ConnectedAppSecret copy({bool? copied}) =>
      ConnectedAppSecret(clientId, value, copied: copied ?? this.copied);
}

const _identityScopes = ['openid', 'profile', 'identity'];
const _optionalIdentityScopes = ['email'];
const _directoryScopes = ['agent:read'];
const _inboundScopes = ['agent:event:write', 'agent:notification:write'];

/// `DeclaredScopesPicker.updateScope`: identity first, then the optional and
/// agent scopes in catalog order.
List<String> toggleDeclaredScope(Iterable<String> value, String scope) {
  if (_identityScopes.contains(scope)) return [..._identityScopes];
  final next = {..._identityScopes, ...value};
  if (!next.add(scope)) next.remove(scope);
  return [
    ..._identityScopes,
    for (final s in [
      ..._optionalIdentityScopes,
      ..._directoryScopes,
      ..._inboundScopes,
    ])
      if (next.contains(s)) s,
  ];
}

/// `toggleAppNotificationGroup`: unchecking a group drops its events.
({List<String> groups, List<String> events}) toggleNotificationGroup(
  List<String> groups,
  List<String> events,
  String group,
  bool checked,
) {
  final nextGroups = checked
      ? [...groups, group]
      : [
          for (final g in groups)
            if (g != group) g,
        ];
  final nextEvents = checked
      ? events
      : [
          for (final e in events)
            if (!(appNotificationEventGroups[e] ?? const <String>[]).contains(
              group,
            ))
              e,
        ];
  return _sortedSelection(nextGroups, nextEvents);
}

({List<String> groups, List<String> events}) _sortedSelection(
  List<String> groups,
  List<String> events,
) => (
  groups: [
    for (final g in appNotificationGroups)
      if (groups.contains(g)) g,
  ],
  events: [
    for (final e in appNotificationEventGroups.keys)
      if (events.contains(e)) e,
  ],
);

class ConnectedAppEditor extends StatefulWidget {
  const ConnectedAppEditor({
    super.key,
    required this.controller,
    required this.secret,
    required this.onSaved,
    required this.onClose,
    required this.onDenied,
    this.app,
  });
  final WorkspaceController controller;

  /// The app being edited; null registers a new one.
  final Map<String, dynamic>? app;
  final ValueNotifier<ConnectedAppSecret?> secret;

  /// An app was created / changed / deleted: reload the lists. [created] is the
  /// new app's record on registration (the host opens My apps).
  final Future<void> Function({Map<String, dynamic>? created}) onSaved;
  final VoidCallback onClose;

  /// A 401/403 on a mutation: the host drops its private rows and returns true.
  final bool Function(Object error) onDenied;
  @override
  State<ConnectedAppEditor> createState() => _ConnectedAppEditorState();
}

class _ConnectedAppEditorState extends State<ConnectedAppEditor> {
  WorkspaceController get w => widget.controller;
  late final int generation = w.client.generation;
  Map<String, dynamic>? editing;
  final name = TextEditingController(),
      clientId = TextEditingController(),
      description = TextEditingController(),
      whenToUse = TextEditingController(),
      homepage = TextEditingController(),
      returnUrl = TextEditingController(),
      manifest = TextEditingController(),
      endpoint = TextEditingController();
  String category = 'Other';
  List<String> scopes = [..._identityScopes];
  List<String> groups = [], events = [];
  Map<String, dynamic>? notifications;
  bool notificationsLoading = false, configOpen = false;
  Map<String, dynamic>? shareLink;
  String shareUrl = '';
  bool shareLoading = false, shareCopied = false;
  bool submitting = false, logoUploading = false, regenerating = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- error clears when the next save or guarded action starts or a confirm dialog retries; webhookSecret is a one-time value cleared on disable and with the editor.
  String? savingId, error, webhookBusy, webhookSecret;
  bool webhookSecretCopied = false;
  Timer? shareCopyReset, secretCopyReset;

  bool get live => mounted && generation == w.client.generation;
  String get base => '/integrations/clients/${editing?['id']}';
  String tr(String s) => raftText(context, s);
  /// Web `err.response?.data?.error || formatMessage(fallback)`; the English
  /// source string, localized by the banner.
  String failure(Object e, String fallback) =>
      userErrorText(e, fallback: fallback, where: 'connected app editor');

  @override
  void initState() {
    super.initState();
    final app = widget.app;
    if (app != null) {
      editing = app;
      fill(app);
      unawaited(loadShare());
      // A revisit paints the last accepted App Notifications settings and
      // revalidates in place (never the one-time signing secret).
      final cached = readPageSnapshot(w, _notificationsKey(app))?['data'];
      if (cached is Map<String, dynamic>) applyNotifications(cached);
      unawaited(loadNotifications(quiet: cached is Map<String, dynamic>));
    }
    for (final c in [
      name,
      clientId,
      description,
      whenToUse,
      homepage,
      returnUrl,
      manifest,
    ]) {
      c.addListener(refresh);
    }
    widget.secret.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    shareCopyReset?.cancel();
    secretCopyReset?.cancel();
    widget.secret.removeListener(refresh);
    for (final c in [
      name,
      clientId,
      description,
      whenToUse,
      homepage,
      returnUrl,
      manifest,
      endpoint,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void fill(Map<String, dynamic> app) {
    name.text = '${app['name'] ?? ''}';
    clientId.text = '${app['clientId'] ?? ''}';
    description.text = '${app['description'] ?? ''}';
    whenToUse.text = '${app['whenToUse'] ?? ''}';
    homepage.text = '${app['homepageUrl'] ?? ''}';
    returnUrl.text = '${app['returnUrl'] ?? ''}';
    manifest.text = '${app['agentManifestUrl'] ?? ''}';
    scopes = declaredIntegrationScopes(app['allowedScopes']);
    category = integrationCategoryLabel(app['category'] as String?);
  }

  Future<void> loadShare() async {
    setState(() => shareLoading = true);
    try {
      final data = await w.client.get('$base/share-link');
      if (live) shareLink = managementMap(data);
    } on RaftApiException catch (e) {
      if (live && e.status != 404) {
        error = failure(e, 'Failed to load private share link');
      }
    } finally {
      if (live) setState(() => shareLoading = false);
    }
  }

  String _notificationsKey(Map<String, dynamic> app) =>
      'integrations:app-notifications:${app['id']}';

  /// The accepted settings without anything secret: the signing secret is only
  /// ever shown once, from the save/rotate answer.
  Map<String, dynamic> _withoutSecrets(Map<String, dynamic> data) => {
    ...data,
    'webhook': {
      for (final entry in managementMap(data['webhook']).entries)
        if (!entry.key.toLowerCase().contains('secret')) entry.key: entry.value,
    },
  };

  /// [quiet] revalidates settings already on screen: no loading state, and a
  /// draft in progress is not overwritten.
  Future<void> loadNotifications({bool quiet = false}) async {
    final identity = pageIdentity(w);
    if (!quiet) setState(() => notificationsLoading = true);
    try {
      final data = await w.client.get('$base/app-notifications');
      if (data is! Map ||
          data['current_groups'] is! List ||
          data['current_events'] is! List) {
        throw StateError('Invalid App Notifications settings response');
      }
      if (!live) return;
      final accepted = managementMap(data);
      final draft =
          quiet &&
          (requestChanged ||
              endpoint.text !=
                  '${managementMap(notifications?['webhook'])['endpoint_url'] ?? ''}');
      if (draft) {
        notifications = accepted;
      } else {
        applyNotifications(accepted);
      }
      final app = editing;
      if (app != null) {
        writePageSnapshot(w, _notificationsKey(app), identity, {
          'data': _withoutSecrets(accepted),
        });
      }
    } catch (e) {
      if (live && !(quiet && notifications != null)) {
        error = failure(e, 'Failed to load App Notifications settings');
      }
    } finally {
      if (live) setState(() => notificationsLoading = false);
    }
  }

  void applyNotifications(Map<String, dynamic> data) {
    notifications = data;
    configOpen = managementMap(data['webhook'])['enabled'] == true;
    final pending = data['pending_revision'];
    final requested = pending is Map
        ? pending
        : {'groups': data['current_groups'], 'events': data['current_events']};
    final selection = _sortedSelection(
      managementStrings(requested['groups']),
      managementStrings(requested['events']),
    );
    groups = selection.groups;
    events = selection.events;
    endpoint.text = '${managementMap(data['webhook'])['endpoint_url'] ?? ''}';
  }

  bool get requestChanged {
    final state = notifications;
    if (state == null) return groups.isNotEmpty || events.isNotEmpty;
    final pending = state['pending_revision'];
    final requested = pending is Map
        ? pending
        : {
            'groups': state['current_groups'],
            'events': state['current_events'],
          };
    return managementStrings(requested['groups']).join('\u0000') !=
            groups.join('\u0000') ||
        managementStrings(requested['events']).join('\u0000') !=
            events.join('\u0000');
  }

  Future<void> savePermissions(String id) => w.client.request(
    'PUT',
    '/integrations/clients/$id/app-notifications/permissions',
    data: {'groups': groups, 'events': events},
  );

  Map<String, dynamic> payload() {
    Object? value(TextEditingController c) => c.text.isEmpty ? null : c.text;
    return {
      'name': name.text,
      'description': value(description),
      'whenToUse': value(whenToUse),
      'homepageUrl': value(homepage),
      'returnUrl': value(returnUrl),
      'agentManifestUrl': value(manifest),
      'allowedScopes': scopes,
      'category': category,
    };
  }

  bool get whenToUseTooLong => isAppWhenToUseTooLong(whenToUse.text);

  Future<void> save() async {
    if (submitting) return;
    if (whenToUseTooLong) {
      setState(
        () => error = raftFormat(
          context,
          'Use no more than {limit} characters before saving.',
          {'limit': appWhenToUseMaxCodePoints},
        ),
      );
      return;
    }
    setState(() {
      submitting = true;
      savingId = editing?['id'] as String?;
      error = null;
    });
    final isNew = editing == null;
    try {
      if (!isNew) {
        await w.client.patch(base, data: payload());
        if (!live) return;
        if (notifications != null && requestChanged) {
          await savePermissions('${editing!['id']}');
        }
        if (!live) return;
        await widget.onSaved();
        if (live) widget.onClose();
      } else {
        final data = <String, dynamic>{
          for (final e in payload().entries)
            if (e.value != null) e.key: e.value,
        };
        if (clientId.text.isNotEmpty) data['clientId'] = clientId.text;
        final created = managementMap(
          await w.client.post('/integrations/clients', data: data),
        );
        if (!live) return;
        final client = managementMap(created['client']);
        final secret = created['clientSecret'];
        if (secret is String) {
          widget.secret.value = ConnectedAppSecret('${client['id']}', secret);
        }
        if (requestChanged) await savePermissions('${client['id']}');
        if (!live) return;
        widget.onClose();
        await widget.onSaved(created: client);
      }
    } catch (e) {
      if (live && widget.onDenied(e)) {
        widget.onClose();
      } else if (live) {
        error = failure(
          e,
          isNew ? 'Failed to register app' : 'Failed to update app',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
          savingId = null;
        });
      }
    }
  }

  Future<T?> guarded<T>(
    Future<T> Function() action,
    String fallback, {
    void Function(bool busy)? busy,
  }) async {
    busy?.call(true);
    if (mounted) setState(() => error = null);
    try {
      return await action();
    } catch (e) {
      if (live && widget.onDenied(e)) {
        widget.onClose();
      } else if (live) {
        setState(() => error = failure(e, fallback));
      }
      return null;
    } finally {
      busy?.call(false);
      if (mounted) setState(() {});
    }
  }

  Future<void> copy(String value, {required void Function() done}) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) setState(done);
  }

  Future<void> uploadLogo() async {
    final file = await selectImage(
      typeGroup: const XTypeGroup(
        label: 'App logo',
        extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
        mimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
        uniformTypeIdentifiers: ['public.image'],
      ),
    );
    if (file == null || !live) return;
    final bytes = await file.readAsBytes();
    if (!live) return;
    await guarded(
      () async {
        final mime = {
          'jpg': 'image/jpeg',
          'jpeg': 'image/jpeg',
          'png': 'image/png',
          'gif': 'image/gif',
          'webp': 'image/webp',
        }[file.name.split('.').last.toLowerCase()];
        final updated = await w.client.post(
          '$base/logo',
          data: FormData.fromMap({
            'logo': MultipartFile.fromBytes(
              bytes,
              filename: file.name,
              contentType: mime == null ? null : DioMediaType.parse(mime),
            ),
          }),
        );
        if (live) {
          editing = managementMap(updated);
          await widget.onSaved();
        }
      },
      'Failed to upload app logo',
      busy: (b) => logoUploading = b,
    );
  }

  Future<void> clearLogo() => guarded(
    () async {
      final updated = await w.client.delete('$base/logo');
      if (live) {
        editing = managementMap(updated);
        await widget.onSaved();
      }
    },
    'Failed to reset app logo',
    busy: (b) => logoUploading = b,
  );

  Future<void> createShare() async {
    await guarded(
      () async {
        final data = managementMap(await w.client.post('$base/share-link'));
        if (!live) return;
        if (data['client'] is Map) editing = managementMap(data['client']);
        shareLink = managementMap(data['link']);
        shareUrl =
            '${ContentLinks.originFor(w.client.origin).origin}/integration-invites/${Uri.encodeComponent('${data['token']}')}';
        shareCopied = false;
      },
      'Failed to create private share link',
      busy: (b) => shareLoading = b,
    );
  }

  Future<void> revokeShare() => guarded(
    () async {
      await w.client.delete('$base/share-link');
      if (live) {
        shareLink = null;
        shareUrl = '';
        shareCopied = false;
      }
    },
    'Failed to revoke private share link',
    busy: (b) => shareLoading = b,
  );

  Future<void> requestPublish() async {
    final id = '${editing!['id']}';
    await guarded(
      () async {
        await w.client.patch(base, data: payload());
        final updated = await w.client.post('$base/request-publish');
        if (live) {
          editing = managementMap(updated);
          await widget.onSaved();
        }
      },
      'Failed to request marketplace publish',
      busy: (b) => savingId = b ? id : null,
    );
  }

  Future<void> confirmRegenerate() async {
    final app = editing!;
    final confirmed = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        title: raftFormat(context, 'Regenerate secret for {name}?', {
          'name': app['name'],
        }),
        content: RaftInlineCodeMessage(
          prefix: tr('The existing client secret for '),
          code: '${app['clientId']}',
          suffix: tr(
            ' will stop working immediately. The new secret is shown once after regeneration.',
          ),
        ),
        confirmLabel: tr('Regenerate secret'),
        loadingLabel: tr('Regenerating...'),
        confirmGlyph: RaftGlyph.alertTriangle,
        confirmVariant: RaftButtonRecipeVariant.primary,
        confirmKey: const ValueKey(
          'connected-app-regenerate-secret-confirm-button',
        ),
        onConfirm: () async {
          regenerating = true;
          // A retry from the confirm dialog: the earlier failure is over.
          error = null;
          try {
            final data = managementMap(
              await w.client.post('$base/regenerate-secret'),
            );
            if (!live) return;
            editing = managementMap(data['client']);
            widget.secret.value = ConnectedAppSecret(
              '${editing!['id']}',
              '${data['clientSecret']}',
            );
            await widget.onSaved();
          } catch (e) {
            error = failure(e, 'Failed to regenerate client secret');
            rethrow;
          } finally {
            regenerating = false;
          }
        },
      ),
    );
    if (confirmed == true && mounted) setState(() {});
  }

  Future<void> confirmOffline() async {
    final app = editing!;
    await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        title: raftFormat(context, 'Request offline review for {name}?', {
          'name': app['name'],
        }),
        content: RaftInlineCodeMessage(
          prefix: tr(
            'App Admin must approve before this app is removed from the public marketplace. Until then ',
          ),
          code: '${app['clientId']}',
          suffix: tr(
            ' stays listed, installable, and usable by existing connections. If approved, every installed server will lose access and existing grants and tokens will be revoked.',
          ),
        ),
        confirmLabel: tr('Request offline'),
        loadingLabel: tr('Requesting...'),
        confirmGlyph: RaftGlyph.upload,
        confirmVariant: RaftButtonRecipeVariant.danger,
        onConfirm: () async {
          error = null;
          try {
            final updated = await w.client.post('$base/request-unpublish');
            if (live) {
              editing = managementMap(updated);
              await widget.onSaved();
            }
          } catch (e) {
            error = failure(e, 'Failed to request marketplace offline review');
            rethrow;
          }
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> confirmDelete() async {
    final app = editing!;
    final deleted = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        title: raftFormat(context, 'Delete {name}?', {'name': app['name']}),
        content: RaftInlineCodeMessage(
          prefix: tr(
            "This permanently deletes the app's OAuth client, secret, and all grants. Any existing Login with Raft setup using ",
          ),
          code: '${app['clientId']}',
          suffix: tr(
            " will stop working. If this app was privately shared, every server that installed it will lose access too. This can't be undone.",
          ),
        ),
        confirmLabel: tr('Delete app'),
        loadingLabel: tr('Deleting...'),
        confirmGlyph: RaftGlyph.trash2,
        confirmKey: const ValueKey('connected-app-delete-confirm-button'),
        onConfirm: () async {
          await w.client.delete(base);
          if (live) await widget.onSaved();
        },
      ),
    );
    if (deleted == true && mounted) widget.onClose();
  }

  Future<void> saveEndpoint() async {
    await guarded(
      () async {
        final data = managementMap(
          await w.client.request(
            'PUT',
            '$base/app-notifications/webhook',
            data: {'endpointUrl': endpoint.text},
          ),
        );
        webhookSecret = data['signing_secret'] as String?;
        webhookSecretCopied = false;
        await loadNotifications();
      },
      'Failed to save App Notifications endpoint',
      busy: (b) => webhookBusy = b ? 'endpoint' : null,
    );
  }

  Future<void> rotateSecret() async {
    await guarded(
      () async {
        final data = managementMap(
          await w.client.post('$base/app-notifications/webhook/rotate-secret'),
        );
        webhookSecret = data['signing_secret'] as String?;
        webhookSecretCopied = false;
        await loadNotifications();
      },
      'Failed to rotate App Notifications secret',
      busy: (b) => webhookBusy = b ? 'rotate' : null,
    );
  }

  Future<bool> disableEndpoint() async {
    final ok = await guarded(
      () async {
        await w.client.delete('$base/app-notifications/webhook');
        webhookSecret = null;
        await loadNotifications();
        return true;
      },
      'Failed to disable App Notifications endpoint',
      busy: (b) => webhookBusy = b ? 'disable' : null,
    );
    return ok ?? false;
  }

  Future<void> toggleWebhook(bool enabled) async {
    if (editing == null) return;
    if (enabled) {
      setState(() => configOpen = true);
      return;
    }
    if (managementMap(notifications?['webhook'])['enabled'] == true &&
        !await disableEndpoint()) {
      return;
    }
    if (mounted) setState(() => configOpen = false);
  }

  String groupLabel(String group) =>
      tr(appNotificationGroupLabels[group] ?? group);

  String permissionLabel(String group) => group == 'agent_reminder_write'
      ? groupLabel(group)
      : raftFormat(context, '{resource} · read', {
          'resource': groupLabel(group),
        });

  static const _groupSummaries = <String, String>{
    'server': 'Server information',
    'agent': 'Directory, profiles, and status',
    'channel': 'Public channel information',
    'computer': 'Status and version',
    'agent_reminder_write': 'Write due reminders (official apps only)',
  };

  String? get publishStatus => editing?['publishStatus'] as String?;

  RaftButtonRecipeSize get small => RaftButtonRecipeSize.sm;

  @override
  Widget build(BuildContext context) {
    final app = editing;
    final status = publishStatus;
    final secret = widget.secret.value;
    final profileComplete =
        name.text.trim().isNotEmpty &&
        description.text.trim().isNotEmpty &&
        homepage.text.trim().isNotEmpty;
    final loginStatus = returnUrl.text.trim().isNotEmpty
        ? (app != null ? 'OAuth ready' : 'Ready to save')
        : 'Not configured (optional)';
    final webhook = managementMap(notifications?['webhook']);
    final notificationsStatus = notificationsLoading
        ? 'Loading'
        : app == null
        ? 'Save app first'
        : webhook['enabled'] == true
        ? 'Enabled'
        : configOpen
        ? 'Setup'
        : 'Off';
    final distribution = switch (status) {
      null => 'Available after save',
      'publish_requested' || 'in_review' => 'Review pending',
      'unpublish_requested' => 'Offline pending',
      'published' => 'Published',
      'rejected' => 'Rejected',
      _ => 'Private',
    };
    final sections = [
      RaftAppEditorSection(
        id: 'profile',
        glyph: RaftGlyph.user,
        railLabel: 'Profile',
        title: 'Profile',
        description: 'Public identity and Marketplace-facing metadata.',
        status: tr(profileComplete ? 'Complete' : 'Needs details'),
        child: profile(),
      ),
      RaftAppEditorSection(
        id: 'login',
        glyph: RaftGlyph.shield,
        railLabel: 'Login with Raft',
        title: 'Login with Raft',
        description: 'Authorized by the user at login.',
        status: tr(loginStatus),
        child: login(),
      ),
      RaftAppEditorSection(
        id: 'permissions',
        glyph: RaftGlyph.shield,
        railLabel: 'App permissions',
        title: 'App permissions',
        description:
            'Approved by a Server admin at installation. The app accesses data directly.',
        status: raftFormat(context, '{count} permissions selected', {
          'count': groups.length,
        }),
        child: permissions(),
      ),
      RaftAppEditorSection(
        id: 'notifications',
        glyph: RaftGlyph.bell,
        railLabel: 'Webhook',
        title: 'Webhook',
        experimentalBadge: true,
        description: 'Deliver subscribed events to the app.',
        status: tr(notificationsStatus),
        child: webhookSection(),
      ),
      RaftAppEditorSection(
        id: 'distribution',
        glyph: RaftGlyph.link2,
        railLabel: 'Distribution',
        title: 'Distribution',
        description:
            'Private sharing, Marketplace review, and publication state.',
        status: tr(distribution),
        child: distributionSection(),
      ),
      RaftAppEditorSection(
        id: 'danger',
        glyph: RaftGlyph.alertTriangle,
        railLabel: 'Danger zone',
        title: 'Danger zone',
        description:
            'Credential rotation, offline review, and deletion stay separate from routine configuration.',
        status: tr(app == null ? 'Available after save' : 'Restricted'),
        warning: true,
        child: dangerSection(),
      ),
    ];
    final showSecret = secret != null;
    return RaftConnectedAppEditorCard(
      eyebrow: app == null ? 'Register app' : 'Edit app',
      name: app == null ? tr('New connected app') : '${app['name']}',
      description: 'Configure login, permissions, and events.',
      initials: integrationInitials(
        name.text.isNotEmpty
            ? name.text
            : '${app?['name'] ?? app?['clientId'] ?? 'App'}',
      ),
      logoUrl: app?['logoUrl'] as String?,
      closeLabel: tr('Close app form'),
      onClose: widget.onClose,
      submitLabel: tr(
        submitting
            ? 'Saving…'
            : app == null
            ? 'Register app'
            : 'Save',
      ),
      onSubmit:
          whenToUseTooLong ||
              submitting ||
              notificationsLoading ||
              savingId != null && savingId == '${app?['id']}'
          ? null
          : save,
      railLabel: 'App editor sections',
      banner: (error != null && error!.isNotEmpty) || showSecret
          ? RaftAppEditorStack(
              gap: RaftSpace.x2,
              children: [
                if (error != null && error!.isNotEmpty)
                  RaftConnectedAppsError(error!),
                if (showSecret)
                  RaftAppEditorSecretReveal(
                    secret: secret.value,
                    copied: secret.copied,
                    onCopy: () => copySecretToClipboard(secret),
                  ),
              ],
            )
          : null,
      sections: sections,
    );
  }

  Future<void> copySecretToClipboard(ConnectedAppSecret secret) async {
    await Clipboard.setData(ClipboardData(text: secret.value));
    widget.secret.value = secret.copy(copied: true);
    secretCopyReset?.cancel();
    secretCopyReset = Timer(const Duration(milliseconds: 1500), () {
      final current = widget.secret.value;
      if (current != null) widget.secret.value = current.copy(copied: false);
    });
  }

  Widget input(
    TextEditingController controller, {
    String? placeholder,
    bool mono = false,
    bool enabled = true,
    int? maxLength,
    Key? key,
  }) => RaftRecipeInput(
    fieldKey: key,
    controller: controller,
    placeholder: placeholder == null ? null : tr(placeholder),
    mono: mono,
    enabled: enabled,
    maxLength: maxLength,
  );

  Widget profile() {
    final app = editing;
    final initials = integrationInitials(
      name.text.isNotEmpty
          ? name.text
          : '${app?['name'] ?? app?['clientId'] ?? 'App'}',
    );
    return RaftAppEditorStack(
      children: [
        RaftAppEditorProfileGrid(
          logo: RaftAppEditorField(
            label: 'Logo',
            hint: app == null
                ? 'Register the app first, then upload a logo from Edit.'
                : 'Upload a square logo, or reset to the deterministic monogram.',
            child: RaftAppEditorLogoWell(
              initials: initials,
              logoUrl: app?['logoUrl'] as String?,
              actions: [
                if (app != null)
                  RaftSettingsRecipeButton(
                    label: logoUploading
                        ? 'Uploading…'
                        : app['logoUrl'] != null
                        ? 'Change'
                        : 'Upload',
                    glyph: RaftGlyph.upload,
                    glyphSize: 14,
                    size: small,
                    onPressed: logoUploading ? null : uploadLogo,
                  ),
                if (app != null && app['logoUrl'] != null)
                  RaftSettingsRecipeButton(
                    label: 'Reset',
                    size: small,
                    onPressed: logoUploading ? null : clearLogo,
                  ),
              ],
            ),
          ),
          fields: RaftAppEditorStack(
            gap: RaftSpace.x3,
            children: [
              RaftAppEditorField(
                label: 'App name',
                child: input(
                  name,
                  placeholder: 'db9 Cloud Drive',
                  key: const ValueKey('connected-app-name'),
                ),
              ),
              RaftAppEditorField(
                label: 'Homepage URL',
                child: input(homepage, placeholder: 'https://example.com'),
              ),
              RaftAppEditorField(
                label: 'Category',
                child: RaftSelectField<String>(
                  key: const ValueKey('connected-app-category'),
                  value: category,
                  label: 'App category',
                  items: [
                    for (final c in integrationCategories)
                      // ds-allow: RaftSelectField items are DropdownMenuItem
                      DropdownMenuItem(value: c, child: Text(tr(c))),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => category = v);
                  },
                ),
              ),
            ],
          ),
        ),
        RaftAppEditorField(
          label: 'Description',
          child: RaftRecipeTextarea(
            controller: description,
            placeholder: tr('What this integration is for'),
            recipeText: true,
            minHeight: 96,
          ),
        ),
        RaftAppEditorField(
          label: 'Client ID',
          optional: true,
          hint: 'Optional — auto-generated if left empty.',
          child: input(
            clientId,
            placeholder: 'optional; auto-generated if empty',
            mono: true,
            enabled: app == null,
          ),
        ),
        AppWhenToUseField(
          controller: whenToUse,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget login() => RaftAppEditorStack(
    children: [
      RaftAppEditorField(
        label: 'Return URL',
        child: input(
          returnUrl,
          placeholder: 'https://example.com/login/callback',
        ),
      ),
      RaftAppEditorField(
        label: 'Agent Manifest URL',
        optional: true,
        child: input(
          manifest,
          placeholder:
              'https://example.com/.well-known/raft-agent-manifest.json',
        ),
      ),
      RaftDeclaredScopesPicker(
        value: {...scopes},
        onChanged: (scope) =>
            setState(() => scopes = toggleDeclaredScope(scopes, scope)),
        tooltips: {
          for (final e in integrationScopeCopy.entries) e.key: tr(e.value),
        },
        fixedIdentity: _identityScopes,
        optionalIdentity: _optionalIdentityScopes,
        agentMessaging: _inboundScopes,
        legacyAgentScopeNote: scopes.contains('agent:read')
            ? 'Existing agent:read login access is preserved. Configure App permissions separately.'
            : null,
        resourceNote: 'The user chooses the target agent when authorizing.',
      ),
      AgentJwtSettings(
        controller: w,
        clientId: editing?['id'] as String?,
        canManage: w.can('manageIntegrations'),
      ),
    ],
  );

  Widget permissions() {
    final pending = notifications?['pending_revision'];
    final source = notifications?['source_installation'];
    final locked =
        notificationsLoading || (editing != null && notifications == null);
    return RaftAppEditorStack(
      gap: RaftSpace.x3,
      children: [
        RaftAppPermissionsTable(
          enabled: !locked,
          rows: [
            for (final g in appNotificationGroups)
              RaftAppPermissionRow(
                id: g,
                label: appNotificationGroupLabels[g] ?? g,
                summary: _groupSummaries[g] ?? '',
                selected: groups.contains(g),
                accessLabel: permissionLabel(g),
                writeAccess: g == 'agent_reminder_write',
              ),
          ],
          onChanged: (id, on) => setState(() {
            final next = toggleNotificationGroup(groups, events, id, on);
            groups = next.groups;
            events = next.events;
          }),
        ),
        RaftAppEditorFootnote(
          'Uses existing installation credentials and APIs. No login or webhook required.',
        ),
        if (pending is Map)
          RaftAppEditorFootnote(
            raftFormat(
              context,
              'Revision {revision} is pending App Review. Current approved permissions remain active until review completes.',
              {'revision': pending['revision']},
            ),
            warning: true,
          ),
        if (source is Map) sourceInstallation(managementMap(source)),
      ],
    );
  }

  Widget sourceInstallation(Map<String, dynamic> source) => RaftAppEditorPanel(
    title: 'Installation on this server',
    description: source['enabled'] != true
        ? 'App disabled'
        : source['status'] == 'suspended'
        ? 'Installation suspended'
        : 'Installed',
    child: RaftAppEditorStack(
      gap: RaftSpace.x2,
      children: [
        RaftAppEditorField(
          label: 'Installation ID',
          child: RaftAppEditorReadonlyInput(
            value: '${source['installation_id']}',
            label: 'Installation ID',
          ),
        ),
        RaftAppEditorFootnote(
          'Use this ID when requesting an installation token or configuring subscriptions.',
        ),
      ],
    ),
  );

  Widget statusBadge() {
    if (notificationsLoading) {
      return const RaftSettingsRecipeBadge(
        label: 'Loading',
        appearance: RaftBadgeRecipeAppearance.outline,
        uppercase: true,
      );
    }
    final state = notifications;
    if (state?['pending_revision'] != null) {
      return const RaftSettingsRecipeBadge(
        label: 'Pending App Review',
        variant: RaftBadgeRecipeVariant.warning,
        uppercase: true,
      );
    }
    if (managementStrings(state?['current_events']).isNotEmpty) {
      return const RaftSettingsRecipeBadge(
        label: 'Request approved',
        variant: RaftBadgeRecipeVariant.success,
        uppercase: true,
      );
    }
    return const RaftSettingsRecipeBadge(
      label: 'Disabled',
      appearance: RaftBadgeRecipeAppearance.outline,
      uppercase: true,
    );
  }

  Widget webhookSection() {
    final app = editing;
    final webhook = managementMap(notifications?['webhook']);
    final busy = webhookBusy != null;
    final pending = notifications?['pending_revision'];
    return RaftAppEditorStack(
      gap: RaftSpace.x3,
      children: [
        RaftAppEditorPanel(
          title: 'Delivery',
          description: 'Endpoint and signing secret.',
          trailing: statusBadge(),
          child: RaftAppEditorStack(
            gap: RaftSpace.x3,
            children: [
              RaftAppEditorSwitchRow(
                title: 'Enable Webhook',
                description:
                    'Receive selected Raft events at a signed HTTPS webhook.',
                note: app == null
                    ? 'Save the app before enabling its webhook.'
                    : null,
                value: configOpen && app != null,
                onChanged:
                    app == null ||
                        notificationsLoading ||
                        notifications == null ||
                        busy
                    ? null
                    : toggleWebhook,
              ),
              if (configOpen && app != null) ...[
                RaftAppEditorInlineForm(
                  field: RaftAppEditorField(
                    label: 'HTTPS endpoint',
                    child: RaftRecipeInput(
                      controller: endpoint,
                      mono: true,
                      placeholder: 'https://example.com/raft/events',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  action: RaftSettingsRecipeButton(
                    label: webhookBusy == 'endpoint'
                        ? 'Saving...'
                        : 'Save endpoint',
                    size: small,
                    onPressed: busy || endpoint.text.trim().isEmpty
                        ? null
                        : saveEndpoint,
                  ),
                ),
                RaftAppEditorActionLine(
                  message: webhook['enabled'] == true
                      ? raftFormat(context, 'Enabled · revision {revision}', {
                          'revision': webhook['config_revision'],
                        })
                      : tr('Enter an endpoint to finish enabling delivery.'),
                  actions: [
                    if (webhook['enabled'] == true)
                      RaftSettingsRecipeButton(
                        label: webhookBusy == 'rotate'
                            ? 'Rotating...'
                            : 'Rotate secret',
                        glyph: RaftGlyph.rotateCw,
                        glyphSize: 13,
                        size: small,
                        onPressed: busy ? null : rotateSecret,
                      ),
                  ],
                ),
                if (webhookSecret != null)
                  RaftAppEditorSigningSecret(
                    secret: webhookSecret!,
                    copied: webhookSecretCopied,
                    onCopy: () => copy(
                      webhookSecret!,
                      done: () => webhookSecretCopied = true,
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (configOpen && app != null)
          RaftAppEditorPanel(
            title: 'Webhook events',
            description:
                'Choose events for the resources selected in App permissions. Each installation controls its subscriptions separately.',
            child: RaftAppEditorStack(
              gap: RaftSpace.x3,
              children: [
                for (final g in appNotificationGroups)
                  if (groups.contains(g)) ...eventGroup(g),
                if (groups.isEmpty)
                  RaftAppEditorCallout(
                    'No App permissions selected.',
                    bold: true,
                  ),
                if (pending is Map)
                  RaftAppEditorCallout(
                    raftFormat(
                      context,
                      'Revision {revision} is pending App Review. Current approved permissions remain active until review completes.',
                      {'revision': pending['revision']},
                    ),
                    tone: RaftAppEditorCalloutTone.warning,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> eventGroup(String group) {
    final list = [
      for (final e in appNotificationEventGroups.entries)
        if (e.value.first == group) e,
    ];
    if (list.isEmpty) return const [];
    final locked = notificationsLoading || notifications == null;
    return [
      RaftAppEditorEventGroup(
        title: raftFormat(context, '{group} events', {
          'group': groupLabel(group),
        }),
        children: [
          for (final e in list)
            RaftAppEditorCheckTile(
              label: tr(appNotificationEventLabels[e.key] ?? e.key),
              caption: e.value.length > 1
                  ? tr('Requires Agent + Computer')
                  : null,
              value: events.contains(e.key),
              enabled: !locked && e.value.every(groups.contains),
              onChanged: (on) => setState(() {
                final next = on
                    ? [...events, e.key]
                    : [
                        for (final v in events)
                          if (v != e.key) v,
                      ];
                events = _sortedSelection(groups, next).events;
              }),
            ),
        ],
      ),
    ];
  }

  Widget distributionSection() {
    final app = editing;
    final status = publishStatus;
    final hint = switch (status) {
      'publish_requested' || 'in_review' =>
        'Marketplace review is pending. You can edit this app while it waits, or delete it to withdraw the request.',
      'unpublish_requested' =>
        'Marketplace offline review is pending. The app stays listed and installable until App Admin approves removal; approval revokes existing server installs and access.',
      _ => null,
    };
    final shareable = status == 'private' || status == 'rejected';
    final expires = shareLink?['expiresAt'];
    return RaftAppEditorStack(
      children: [
        if (app == null)
          RaftAppEditorCallout(
            'Save the app before creating a share link or requesting Marketplace review.',
            bold: true,
          ),
        if (app != null && hint != null)
          RaftAppEditorCallout(hint, tone: RaftAppEditorCalloutTone.warning),
        if (app != null && shareable)
          RaftAppEditorBox(
            key: const ValueKey('connected-app-private-share-card'),
            child: RaftAppEditorStack(
              gap: RaftSpace.x3,
              children: [
                RaftAppEditorActionRow(
                  title: 'Private share link',
                  description:
                      'Invite another server owner or admin to install this app without listing it in the public marketplace.',
                  extra: shareLink == null
                      ? null
                      : raftFormat(context, 'Active link expires {when}.', {
                          'when': expires is String && expires.isNotEmpty
                              ? expires
                              : tr('never'),
                        }),
                  action: Wrap(
                    spacing: RaftSpace.x2,
                    runSpacing: RaftSpace.x2,
                    alignment: WrapAlignment.end,
                    children: [
                      RaftSettingsRecipeButton(
                        label: shareLoading
                            ? 'Working...'
                            : shareLink != null
                            ? 'Regenerate'
                            : 'Create link',
                        size: small,
                        onPressed: shareLoading ? null : createShare,
                      ),
                      if (shareLink != null)
                        RaftSettingsRecipeButton(
                          label: 'Revoke',
                          size: small,
                          onPressed: shareLoading ? null : revokeShare,
                        ),
                    ],
                  ),
                ),
                if (shareUrl.isNotEmpty)
                  RaftAppEditorCopyRow(
                    value: shareUrl,
                    copied: shareCopied,
                    label: 'Private share URL',
                    onCopy: () {
                      copy(shareUrl, done: () => shareCopied = true);
                      shareCopyReset?.cancel();
                      shareCopyReset = Timer(
                        const Duration(milliseconds: 1500),
                        () => refreshCopied(),
                      );
                    },
                  ),
              ],
            ),
          ),
        if (app != null && shareable)
          RaftAppEditorBox(
            cream: true,
            child: RaftAppEditorActionRow(
              title: 'Marketplace publish request',
              description:
                  'Category and data access come from the app metadata and declared scopes above. Requesting review saves those changes first.',
              action: RaftSettingsRecipeButton(
                label: savingId == '${app['id']}'
                    ? 'Requesting…'
                    : 'Request publish',
                variant: RaftButtonRecipeVariant.accent,
                size: small,
                onPressed: whenToUseTooLong || savingId == '${app['id']}'
                    ? null
                    : requestPublish,
              ),
            ),
          ),
        if (status == 'published')
          RaftAppEditorCallout(
            'This app is published in the Marketplace. Offline review is kept in Danger zone because approval revokes active installs and access.',
            tone: RaftAppEditorCalloutTone.success,
          ),
      ],
    );
  }

  void refreshCopied() {
    if (mounted) setState(() => shareCopied = false);
  }

  Widget dangerSection() {
    final app = editing;
    if (app == null) {
      return RaftAppEditorFootnote(
        'Save the app before lifecycle or credential actions become available.',
      );
    }
    final status = publishStatus;
    return RaftAppEditorStack(
      children: [
        RaftAppEditorBox(
          softBorder: true,
          shadow: false,
          child: RaftAppEditorActionRow(
            title: 'Client secret',
            description:
                'Regenerating invalidates the previous secret for this app. The new secret is shown once.',
            action: RaftSettingsRecipeButton(
              key: const ValueKey('connected-app-regenerate-secret-button'),
              label: regenerating
                  ? 'Regenerating...'
                  : 'Regenerate client secret',
              variant: RaftButtonRecipeVariant.primary,
              size: small,
              onPressed: submitting || regenerating ? null : confirmRegenerate,
            ),
          ),
        ),
        if (status == 'published')
          RaftAppEditorBox(
            softBorder: true,
            shadow: false,
            child: RaftAppEditorActionRow(
              title: 'Marketplace lifecycle',
              description:
                  'Requesting offline review keeps the app live until App Admin approves removal.',
              action: RaftSettingsRecipeButton(
                label: 'Request offline',
                size: small,
                onPressed: confirmOffline,
              ),
            ),
          ),
        if (const {
          'private',
          'publish_requested',
          'in_review',
          'rejected',
        }.contains(status))
          RaftSettingsActionCard(
            key: const ValueKey('connected-app-delete-card'),
            title: 'Delete app',
            description:
                'Permanently deletes this app registration and its current credentials.',
            stacked: true,
            action: RaftSettingsRecipeButton(
              label: 'Delete',
              glyph: RaftGlyph.trash2,
              glyphSize: 14,
              variant: RaftButtonRecipeVariant.danger,
              size: small,
              onPressed: confirmDelete,
            ),
          ),
      ],
    );
  }
}
