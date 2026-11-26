import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/managed_mcp_apps.dart';
import '../data/workspace_controller.dart';
import '../platform/file_selection.dart';
import 'integrations_views.dart'
    show integrationCategories, integrationCategoryDisplay, integrationInitials;
import 'management_support.dart';
import 'mcp_app_connections.dart';
import 'mcp_app_server.dart';

class McpAppEditor extends StatefulWidget {
  const McpAppEditor({
    super.key,
    required this.controller,
    required this.appId,
    required this.onClose,
    required this.onChanged,
    required this.onBrowse,
  });

  final WorkspaceController controller;
  final String? appId;
  final VoidCallback onClose, onChanged, onBrowse;

  @override
  State<McpAppEditor> createState() => _McpAppEditorState();
}

class _McpAppEditorState extends ManagementState<McpAppEditor> {
  @override
  WorkspaceController get w => widget.controller;
  late final api = ManagedMcpAppsApi(w.client);
  late final String scope;
  ManagedMcpApp? app;
  bool canEdit = false;
  final name = TextEditingController();
  final description = TextEditingController();
  final homepage = TextEditingController();
  final whenToUse = TextEditingController();
  final server = McpServerDraft();
  String? category;

  bool get live => mounted && authority == scope;
  bool get manageable =>
      live &&
      w.can('manageIntegrations') &&
      (app?.canManage ?? widget.appId == null);

  @override
  void initState() {
    super.initState();
    scope = authority;
    canEdit = w.can('manageIntegrations');
    startManagement();
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    homepage.dispose();
    whenToUse.dispose();
    server.dispose();
    super.dispose();
  }

  @override
  void clearData() {
    app = null;
    canEdit = false;
    for (final field in [name, description, homepage, whenToUse]) {
      field.clear();
    }
    category = null;
    server.reset(null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  @override
  Future<void> loadData(int request, int generation) async {
    final id = app?.id ?? widget.appId;
    if (id == null || !live) return;
    final loaded = ManagedMcpApp(
      await api.request('GET', ManagedMcpAppsApi.app(id)),
    );
    if (live && accepts(generation, request)) _apply(loaded);
  }

  void _apply(ManagedMcpApp next) {
    app = next;
    canEdit = next.canManage;
    name.text = next.name;
    description.text = '${next.profile['description'] ?? ''}';
    homepage.text = '${next.profile['homepageUrl'] ?? ''}';
    whenToUse.text = '${next.profile['whenToUse'] ?? ''}';
    category = next.profile['category'] as String?;
    server.reset(next);
  }

  Future<McpJson> mutate(
    String method,
    String path, {
    Object? data,
    McpJson? query,
  }) async {
    if (!manageable) {
      throw const RaftUserError('The active server changed. Reopen this form.');
    }
    return api.request(method, path, data: data, query: query);
  }

  String? _optional(String text) => text.trim().isEmpty ? null : text.trim();
  McpJson get profile => {
    'name': name.text.trim(),
    'description': _optional(description.text),
    'homepageUrl': _optional(homepage.text),
    'category': category,
    'whenToUse': _optional(whenToUse.text),
  };

  Future<void> save() => run(() async {
    if (name.text.trim().isEmpty) {
      throw const RaftUserError('Give the App a name.');
    }
    final current = app;
    final payload = {'profile': profile, ...server.saveFields(current)};
    final next = ManagedMcpApp(
      await mutate(
        current == null ? 'POST' : 'PATCH',
        current == null ? '/mcp/apps' : ManagedMcpAppsApi.app(current.id),
        data: payload,
      ),
    );
    if (!mounted || !live) return;
    setState(() => _apply(next));
    widget.onChanged();
    showRaftToast(
      context,
      current != null
          ? 'Saved.'
          : next.auth == McpAuthKind.none
          ? 'App added. Its tools are ready for Agents.'
          : 'App added. Add a connection so Agents can use it.',
      tone: RaftToastRecipeTone.success,
    );
  }, refresh: false);

  Future<void> refreshTools() => run(() async {
    final path = ManagedMcpAppsApi.app(app!.id);
    final updated = await mutate('POST', '$path/refresh');
    if (!live) return;
    setState(() => app = ManagedMcpApp(updated));
    widget.onChanged();
  }, refresh: false);

  Future<void> reloadConnections() async {
    final current = app;
    if (current == null || !live) return;
    final next = ManagedMcpApp(
      await api.request('GET', ManagedMcpAppsApi.app(current.id)),
    );
    if (!live) return;
    setState(() => app = next);
    widget.onChanged();
  }

  Future<void> logo({bool reset = false}) => run(() async {
    final path = '${ManagedMcpAppsApi.app(app!.id)}/logo';
    final McpJson updated;
    if (reset) {
      updated = await mutate('DELETE', path);
    } else {
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
      updated = await mutate(
        'POST',
        path,
        data: FormData.fromMap({
          'logo': MultipartFile.fromBytes(bytes, filename: file.name),
        }),
      );
    }
    if (!live) return;
    setState(() => app = ManagedMcpApp(updated));
    widget.onChanged();
  }, refresh: false);

  Future<void> deleteApp() async {
    final current = app!;
    final deleted = await confirm(
      raftFormat(context, 'Delete {name}?', {'name': current.name}),
      'Removes the App, its connections and their sign-ins. Agents lose its tools.',
      () async {
        await mutate('DELETE', ManagedMcpAppsApi.app(current.id));
      },
      submit: 'Delete app',
      destructive: true,
    );
    if (deleted && live) {
      widget.onChanged();
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = app;
    final pending = current == null && widget.appId != null && loading;
    const saveFirst = RaftBanner(
      description: 'Save the app first.',
      status: RaftBannerRecipeStatus.info,
      size: RaftBannerRecipeSize.sm,
    );
    const saveAppFirst = 'Save app first';
    return RaftConnectedAppEditorCard(
      key: ValueKey(('mcp-app-editor', current?.id)),
      formTitle: pending
          ? ''
          : current == null
          ? raftText(context, 'New custom MCP app')
          : current.name,
      closeLabel: raftText(context, 'Close app form'),
      onClose: widget.onClose,
      submitLabel: raftText(
        context,
        busy
            ? 'Saving…'
            : current == null
            ? 'Add app'
            : 'Save',
      ),
      onSubmit:
          canEdit &&
              (current != null || widget.appId == null) &&
              !pending &&
              !busy &&
              !server.probing &&
              !isAppWhenToUseTooLong(whenToUse.text)
          ? save
          : null,
      banner: error == null
          ? null
          : RaftBanner(description: error!, size: RaftBannerRecipeSize.sm),
      body: pending
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: RaftSpace.x4),
              child: RaftAppEditorFootnote('Loading'),
            )
          : null,
      sections: [
        RaftAppEditorSection(
          id: 'profile',
          title: 'Profile',
          description: '',
          status: raftText(
            context,
            name.text.trim().isEmpty || description.text.trim().isEmpty
                ? 'Needs details'
                : 'Complete',
          ),
          child: _profile(current),
        ),
        RaftAppEditorSection(
          id: 'mcp_server',
          title: 'MCP server',
          description: '',
          status: _serverStatus(current),
          child: McpAppServerSection(
            draft: server,
            app: current,
            // `view ? Facts : appId ? null : Create`: a failed read of an
            // existing App leaves the section empty, never the create form.
            isNew: widget.appId == null,
            canEdit: canEdit,
            busy: busy,
            onChanged: () => setState(() {}),
            onProbe: (endpoint) =>
                mutate('POST', '/mcp/probe', data: {'endpointUrl': endpoint}),
            onRefresh: refreshTools,
            onBrowse: widget.onBrowse,
          ),
        ),
        RaftAppEditorSection(
          id: 'connections',
          title: 'Connections',
          description: '',
          status: current == null
              ? raftText(context, saveAppFirst)
              : current.auth == McpAuthKind.none
              ? raftText(context, 'Not needed')
              : _plural(
                  current.connections.length,
                  '{count} connection',
                  '{count} connections',
                ),
          child: current == null
              ? saveFirst
              : McpAppConnections(
                  key: ValueKey(current.id),
                  app: current,
                  workspace: w,
                  onReload: reloadConnections,
                ),
        ),
        RaftAppEditorSection(
          id: 'agents',
          title: 'Agents',
          description: '',
          status: current == null
              ? raftText(context, saveAppFirst)
              : _plural(
                  (current.agents['total'] as num? ?? 0).toInt(),
                  '{count} agent',
                  '{count} agents',
                ),
          child: current == null
              ? saveFirst
              : McpAppAgentSummary(current.agents, auth: current.auth),
        ),
        if (current != null) ...[
          RaftAppEditorSection(
            id: 'distribution',
            title: 'Distribution',
            description: '',
            status: raftText(context, 'Private'),
            child: RaftAppEditorActionRow(
              title: 'Marketplace publish request',
              description: "Publishing MCP Apps to the Marketplace isn't available yet. This App stays private to this server.",
              action: RaftButton(
                label: 'Request publish',
                uiVariant: RaftButtonVariant.standard,
                onPressed: null,
              ),
            ),
          ),
          if (canEdit)
            RaftAppEditorSection(
              id: 'danger',
              title: 'Danger zone',
              description: 'Deleting the App removes it for every Agent.',
              status: raftText(context, 'Restricted'),
              child: RaftAppEditorActionRow(
                title: 'Delete app',
                description: 'Removes the App, its connections and their sign-ins. Agents lose its tools.',
                action: RaftButton(
                  label: 'Delete',
                  glyph: RaftGlyph.trash2,
                  uiVariant: RaftButtonVariant.danger,
                  onPressed: busy ? null : deleteApp,
                ),
              ),
            ),
        ],
      ],
    );
  }

  String _plural(int count, String one, String other) =>
      raftFormat(context, count == 1 ? one : other, {'count': count});

  /// McpAppEditor.tsx `sectionStatus.mcp_server`: a saved App reports its
  /// server's health; a new one reports what validating the URL found.
  String _serverStatus(ManagedMcpApp? current) {
    if (current != null) {
      return raftText(context, switch (mcpObject(
        current.server['health'],
      )['status']) {
        'reachable' => 'Reachable',
        'unreachable' => 'Unreachable',
        _ => 'Not checked yet',
      });
    }
    final probe = server.probe;
    if (probe == null) return raftText(context, 'Not validated');
    return switch (probe['outcome']) {
      'ready' => _plural(
        (mcpObject(probe['tools'])['count'] as num? ?? 0).toInt(),
        '{count} tool',
        '{count} tools',
      ),
      'oauth' => raftText(context, 'OAuth sign-in'),
      'headers' => raftText(context, 'API key'),
      _ => raftText(context, 'Unreachable'),
    };
  }

  Widget _profile(ManagedMcpApp? current) {
    final logoUrl = current?.profile['logoUrl'] as String?;
    // McpAppProfileSection is a fragment: its rows sit in FormSection's own
    // `gap-(--field-gap)` (12), not the editor's default 16.
    return RaftAppEditorStack(
      gap: RaftSpace.x3,
      children: [
        RaftAppProfileGrid(
          logo: RaftAppEditorField(
            label: 'Logo',
            compact: true,
            hint: current == null
                ? 'Create the app first, then upload a logo from Edit.'
                : null,
            child: RaftAppProfileLogo(
              initials: integrationInitials(
                name.text.isEmpty ? current?.id ?? 'new-mcp-app' : name.text,
              ),
              logoUrl: logoUrl,
              actions: [
                if (current != null && canEdit)
                  RaftButton(
                    label: logoUrl == null ? 'Upload' : 'Change',
                    glyph: RaftGlyph.upload,
                    // McpAppProfileSection.tsx: a plain <Button>, which is
                    // raft-ui's outline default, not the accent CTA.
                    uiVariant: RaftButtonVariant.standard,
                    onPressed: busy ? null : () => logo(),
                  ),
                if (logoUrl != null && canEdit)
                  RaftButton(
                    label: 'Reset',
                    uiVariant: RaftButtonVariant.ghost,
                    onPressed: busy ? null : () => logo(reset: true),
                  ),
              ],
            ),
          ),
          fields: RaftAppEditorStack(
            gap: RaftSpace.x3,
            children: [
              _input(
                'mcp-profile-name',
                'App name',
                name,
                'Internal Wiki',
                required: true,
              ),
              _input(
                'mcp-profile-homepage',
                'Homepage URL',
                homepage,
                'https://example.com',
                optional: true,
              ),
              RaftAppEditorField(
                label: 'Category',
                optional: true,
                compact: true,
                child: RaftSelectField<String>(
                  value: category,
                  label: 'App category',
                  placeholder: raftText(context, 'Category'),
                  items: [
                    for (final value in integrationCategories)
                      RaftSelectItem(
                        value: value,
                        label: integrationCategoryDisplay(value),
                      ),
                  ],
                  onChanged: canEdit
                      ? (value) => setState(() => category = value)
                      : null,
                ),
              ),
            ],
          ),
        ),
        RaftAppEditorField(
          label: 'Description',
          optional: true,
          compact: true,
          child: RaftTextarea(
            fieldKey: const ValueKey('mcp-profile-description'),
            controller: description,
            enabled: canEdit && !busy,
            rows: 3,
            hintText: raftText(context, 'What Agents can do with this App.'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (canEdit)
          RaftAppWhenToUseField(
            fieldKey: const ValueKey('mcp-profile-when-to-use'),
            controller: whenToUse,
            enabled: !busy,
            onChanged: (_) => setState(() {}),
          ),
      ],
    );
  }

  Widget _input(
    String key,
    String label,
    TextEditingController field,
    String? hint, {
    bool optional = false,
    bool required = false,
  }) => RaftAppEditorField(
    label: label,
    required: required,
    optional: optional,
    compact: true,
    child: RaftRecipeInput(
      fieldKey: ValueKey(key),
      controller: field,
      enabled: canEdit && !busy,
      placeholder: hint == null ? null : raftText(context, hint),
      onChanged: (_) => setState(() {}),
    ),
  );
}
