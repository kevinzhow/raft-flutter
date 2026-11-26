import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/managed_mcp_apps.dart';
import '../data/cause_notice.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart';
import 'mcp_web_sign_in.dart';

class AgentMcpAccess extends StatefulWidget {
  const AgentMcpAccess({
    super.key,
    required this.workspace,
    required this.agentId,
    required this.app,
    required this.granting,
    required this.onSaved,
    required this.onClose,
  });

  final WorkspaceController workspace;
  final String agentId;
  final ManagedMcpAgentApp app;
  final bool granting;
  final VoidCallback onSaved, onClose;

  @override
  State<AgentMcpAccess> createState() => _AgentMcpAccessState();
}

class _AgentMcpAccessState extends State<AgentMcpAccess> {
  static const _default = '';
  static const _new = 'new';
  late final api = ManagedMcpAppsApi(widget.workspace.client);
  late final String scope;
  McpJson? view;
  String? choice;
  late final _notice = CauseNotice(scope: () => pageIdentity(widget.workspace));
  String? get error => _notice.message;
  set error(String? message) => _notice.raise(message);
  bool loading = true, saving = false;

  bool get live => mounted && pageIdentity(widget.workspace) == scope;
  String get appId => Uri.encodeComponent(widget.app.id);
  String get agentId => Uri.encodeComponent(widget.agentId);
  List<McpJson> get candidates => mcpRows(view?['candidates']);
  bool get noAuth => widget.app.auth == McpAuthKind.none;
  bool get hasDefault =>
      candidates.any((row) => row['isServerDefault'] == true);
  bool get canMakeDefault =>
      view?['canSetServerDefault'] == true && !hasDefault;
  bool get newMustBeDefault => view?['newConnectionPinnable'] == false;
  bool get canAuthorize =>
      !widget.granting &&
      widget.app.auth == McpAuthKind.oauth &&
      view?['canAuthorizeNew'] == true &&
      (!newMustBeDefault || canMakeDefault);

  @override
  void initState() {
    super.initState();
    scope = pageIdentity(widget.workspace);
    _load();
  }

  Future<McpJson> _authorization() => api.request(
    'GET',
    '/mcp/servers/$appId/connection-authorization',
    query: {'agentId': widget.agentId},
  );

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await _authorization();
      if (!live) return;
      setState(() {
        view = result;
        if (widget.granting) {
          final ready = candidates.where((row) => row['status'] == 'ready');
          final candidate =
              ready
                  .where((row) => row['isServerDefault'] == true)
                  .firstOrNull ??
              ready.firstOrNull;
          choice = candidate?['isServerDefault'] == true
              ? _default
              : candidate?['connectionId'] as String? ?? _default;
        } else {
          final binding = mcpObject(result['binding']);
          choice = binding['present'] == true
              ? binding['connectionId'] as String?
              : hasDefault || noAuth
              ? _default
              : null;
        }
      });
    } catch (_) {
      if (live) setState(() => error = "Couldn't load this App's connections.");
    } finally {
      if (live) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    if (!live || saving) return;
    if (choice == _new) {
      try {
        await openMcpWebSignIn(widget.workspace);
      } catch (_) {
        if (live) setState(() => error = 'Could not open this address.');
      }
      return;
    }
    await _write(choice == _default ? null : choice);
  }

  Future<void> _write(String? id) async {
    if (!live || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await api.request(
        'PUT',
        '/mcp/agents/$agentId/assignments/$appId',
        data: {
          if (widget.granting) 'enabled': true,
          if (!noAuth) 'connectionId': id,
        },
      );
      if (live) widget.onSaved();
    } catch (failure) {
      if (live) setState(() => error = mcpAppError(failure));
    } finally {
      if (live) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final title = raftFormat(context, '{name} for this agent', {
      'name': widget.app.name,
    });
    final submit = choice == _new
        ? 'Open in web'
        : widget.granting
        ? 'Grant Access'
        : 'Save';
    final readOnly = view?['viewerRole'] == 'observer';
    final content = RaftAppEditorStack(
      children: [
        if (loading)
          const Center(child: RaftSpinner())
        else if (view == null)
          RaftLoadError(
            error ?? "Couldn't load this App's connections.",
            onRetry: _load,
          )
        else ...[
          if (error case final message?) RaftConnectedAppsError(message),
          if (noAuth)
            const RaftAppEditorFootnote('No connection needed')
          else ...[
            if (!widget.granting &&
                widget.app.connection['connectionMissing'] == true)
              const RaftAppEditorFootnote(
                "No connection is selected for this Agent. Choose one below; until then it can't use this App.",
                warning: true,
              ),
            if (widget.granting &&
                candidates.every((row) => row['status'] != 'ready'))
              const RaftAppEditorFootnote(
                'No connection is signed in yet. The Agent can be granted now and will ask for sign-in in its conversation the first time it uses this App.',
              )
            else
              RaftRadioGroup<String>(
                value: choice,
                onChanged: saving || readOnly
                    ? null
                    : (value) => setState(() => choice = value),
                children: [
                  if (!widget.granting)
                    _radio(
                      _default,
                      'Use the server default',
                      // Nothing to follow: the option says so and cannot be
                      // chosen (McpAgentConnectionDrawer.tsx:243).
                      enabled: hasDefault || noAuth,
                      description: noAuth
                          ? 'No connection needed'
                          : hasDefault
                          ? null
                          : 'No server default yet. Set one or choose a specific connection below.',
                    ),
                  for (final candidate in candidates)
                    if (candidate['connectionId']
                        case final String connectionId)
                      _radio(
                        widget.granting && candidate['isServerDefault'] == true
                            ? _default
                            : connectionId,
                        candidate['name'] as String? ?? 'Unnamed connection',
                        enabled: candidate['status'] == 'ready',
                        isDefault: candidate['isServerDefault'] == true,
                      ),
                  if (canAuthorize) _radio(_new, 'Authorize a new connection'),
                ],
              ),
            if (choice == _new)
              RaftAppEditorFootnote(
                raftFormat(
                  context,
                  'Sign in on Raft Web. Open {name} from Apps to manage its connections.',
                  {'name': widget.app.name},
                ),
              ),
          ],
          if (readOnly)
            const RaftAppEditorFootnote(
              "You can see how this Agent uses the App, but you can't change it.",
            ),
        ],
      ],
    );
    final button = RaftButton(
      key: const ValueKey('mcp-agent-commit'),
      label: submit,
      busy: saving,
      onPressed:
          view != null && !readOnly && !saving && (noAuth || choice != null)
          ? _save
          : null,
    );
    return RaftDialog.card(
      title: title,
      onClose: widget.onClose,
      contentKey: const ValueKey('agent-mcp-access'),
      footer: RaftButtonWrap(
        children: [
          RaftButton(
            label: 'Cancel',
            uiVariant: RaftButtonVariant.ghost,
            onPressed: widget.onClose,
          ),
          button,
        ],
      ),
      sheetCommit: button,
      child: Padding(
        padding: const EdgeInsets.all(RaftSpace.x4),
        child: DefaultTextStyle.merge(
          style: RaftPanelText.muted(t),
          child: content,
        ),
      ),
    );
  }

  Widget _radio(
    String value,
    String label, {
    bool enabled = true,
    bool isDefault = false,
    String? description,
  }) => RaftRadioGroupItem<String>(
    value: value,
    enabled: enabled,
    crossAxisAlignment: isDefault || description != null
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: RaftSpace.x1,
      children: [
        Text(raftText(context, label)),
        if (isDefault || description != null)
          Wrap(
            spacing: RaftSpace.x1_5,
            runSpacing: RaftSpace.x1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isDefault)
                RaftBadge(
                  label: raftText(context, 'Default'),
                  variant: RaftBadgeRecipeVariant.success,
                ),
              if (description != null)
                Text(
                  raftText(context, description),
                  style: RaftTokens.of(context).scale(
                    RaftTypeScale.caption,
                    color: RaftTokens.of(context).ui.foregroundMuted,
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}
