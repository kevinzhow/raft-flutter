import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/managed_mcp_credentials.dart';

/// AgentMcpTab's server draft, shared by add, edit and recommendations. The
/// owner fences and executes requests; this route owns inputs, never secrets
/// read from a catalog, and tests the same unsaved values that Save submits.
class McpServerEditor extends StatefulWidget {
  static const dialogMaxWidth = 672.0; // Web DialogCard max-w-2xl.
  const McpServerEditor({
    super.key,
    this.server,
    required this.onSave,
    required this.onTest,
  });
  final Map<String, dynamic>? server;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final Future<int> Function(Map<String, dynamic>) onTest;

  @override
  State<McpServerEditor> createState() => _McpServerEditorState();
}

class _HeaderEditors {
  _HeaderEditors(this.id, String name, this.persistedName)
    : name = TextEditingController(text: name);
  final int id;
  final String? persistedName;
  final TextEditingController name;
  final value = TextEditingController();

  ManagedMcpHeader get snapshot =>
      ManagedMcpHeader(name.text, value.text, persistedName: persistedName);
  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _McpServerEditorState extends State<McpServerEditor> {
  late final name = TextEditingController(text: widget.server?['name'] ?? '');
  late final description = TextEditingController(
    text: widget.server?['description'] ?? '',
  );
  late final endpoint = TextEditingController(
    text: widget.server?['endpointUrl'] ?? '',
  );
  late String provider = widget.server?['provider'] ?? 'custom';
  late String authMode = widget.server?['authMode'] ?? 'none';
  late final originalNames =
      (widget.server?['credentialHeaderNames'] as List?)
          ?.whereType<String>()
          .toList() ??
      <String>[];
  final headers = <_HeaderEditors>[];
  final inputKeys = [for (var i = 0; i < 4; i++) GlobalKey()];
  // Removed rows keep their controllers until the route's exit completes;
  // their EditableText/focus can still be mounted during the removal frame.
  final ownedHeaders = <_HeaderEditors>[];
  int sequence = 0, revision = 0;
  bool saving = false, testing = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared on draft changes or the next submit/test; owned only by this form route.
  String? error, testError;
  int? testedTools;
  RaftUnsavedGuardState? guard;
  late final String initialProvider, initialAuthMode;
  late final List<(String, String?)> initialHeaders;

  bool get creating => widget.server?['id'] == null;
  List<ManagedMcpHeader> get credentialRows => [
    for (final row in headers) row.snapshot,
  ];
  bool get incomplete =>
      authMode == 'headers' && managedMcpHeadersIncomplete(credentialRows);
  bool choicesChanged() {
    if (provider != initialProvider ||
        authMode != initialAuthMode ||
        headers.length != initialHeaders.length) {
      return true;
    }
    for (var i = 0; i < headers.length; i++) {
      if ((headers[i].name.text, headers[i].persistedName) !=
          initialHeaders[i]) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (authMode == 'headers') restoreHeaders();
    initialProvider = provider;
    initialAuthMode = authMode;
    initialHeaders = [
      for (final row in headers) (row.name.text, row.persistedName),
    ];
    guard = RaftUnsavedGuard.maybeOf(context)?..watch(choicesChanged);
  }

  void addHeader([String name = '', String? persistedName]) {
    final row = _HeaderEditors(++sequence, name, persistedName);
    headers.add(row);
    ownedHeaders.add(row);
  }

  void restoreHeaders() {
    headers.clear();
    for (final name in originalNames) {
      addHeader(name, creating ? null : name);
    }
  }

  @override
  void dispose() {
    guard?.unwatch(choicesChanged);
    name.dispose();
    description.dispose();
    endpoint.dispose();
    for (final row in ownedHeaders) {
      row.dispose();
    }
    super.dispose();
  }

  void changed([String? _]) => setState(() {
    revision++;
    error = testError = null;
    testedTools = null;
    guard?.recheck();
  });

  Map<String, dynamic> credentials() => managedMcpCredentials(
    creating: creating,
    authMode: authMode,
    headers: credentialRows,
    persistedNames: creating ? const [] : originalNames,
  );

  String? validate() {
    if (name.text.trim().isEmpty) return 'Name is required.';
    final uri = Uri.tryParse(endpoint.text.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return 'Enter a complete HTTP or HTTPS address.';
    }
    return incomplete ? managedMcpHeaderError : null;
  }

  Future<void> save() async {
    if (saving) return;
    final invalid = validate();
    setState(() => error = invalid);
    if (invalid != null) return;
    setState(() => saving = true);
    try {
      await widget.onSave({
        'name': name.text,
        'description': description.text.isEmpty ? null : description.text,
        'provider': provider,
        'authMode': authMode,
        'endpointUrl': endpoint.text.trim(),
        ...credentials(),
      });
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = raftErrorMessage(
            context,
            e,
            fallback: 'Managed MCP request failed',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> test() async {
    if (testing || saving || authMode == 'oauth' || incomplete) return;
    final ticket = revision;
    setState(() {
      testing = true;
      testError = null;
      testedTools = null;
    });
    try {
      final count = await widget.onTest({
        if (!creating) 'mcpServerId': widget.server!['id'],
        'endpointUrl': endpoint.text.trim(),
        'authMode': authMode,
        ...credentials(),
      });
      if (mounted && ticket == revision) setState(() => testedTools = count);
    } catch (e) {
      if (mounted && ticket == revision) {
        setState(
          () => testError = raftErrorMessage(
            context,
            e,
            fallback: 'Managed MCP request failed',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => testing = false);
    }
  }

  Widget field(String label, Widget input, {bool required = false}) =>
      RaftField(
        label: raftText(context, label),
        required: required,
        compact: true,
        child: input,
      );

  Widget selectInput(
    String id,
    String value,
    Map<String, String> choices,
    void Function(String)? onChanged,
  ) => RaftSelectField<String>(
    key: ValueKey(id),
    label: raftText(
      context,
      id == 'mcp-provider' ? 'Provider' : 'Authentication',
    ),
    value: value,
    items: [
      for (final item in choices.entries)
        RaftSelectItem(value: item.key, label: raftText(context, item.value)),
    ],
    onChanged: onChanged == null
        ? null
        : (next) {
            if (next != null) {
              onChanged(next);
              changed();
            }
          },
  );

  Widget inputs() {
    final fields = [
      field(
        'Provider',
        selectInput(
          'mcp-provider',
          provider,
          const {'custom': 'Custom', 'notion': 'Notion', 'linear': 'Linear'},
          !creating
              ? null
              : (value) {
                  provider = value;
                  authMode = value == 'custom' ? 'none' : 'oauth';
                  endpoint.text = switch (value) {
                    'notion' => 'https://mcp.notion.com/mcp',
                    'linear' => 'https://mcp.linear.app/mcp',
                    _ => '',
                  };
                  headers.clear();
                },
        ),
        required: true,
      ),
      field(
        'Authentication',
        selectInput(
          'mcp-auth-mode',
          authMode,
          const {
            'none': 'None',
            'headers': 'Credential headers',
            'oauth': 'OAuth',
          },
          provider != 'custom'
              ? null
              : (value) {
                  authMode = value;
                  if (value == 'headers') {
                    restoreHeaders();
                  } else {
                    headers.clear();
                  }
                },
        ),
        required: true,
      ),
      field(
        'Name',
        RaftTextInput(
          key: const ValueKey('mcp-name'),
          controller: name,
          semanticLabel: raftText(context, 'Name'),
          maxLength: 120,
          onChanged: changed,
        ),
        required: true,
      ),
      field(
        'MCP server URL',
        RaftTextInput(
          key: const ValueKey('mcp-endpoint'),
          controller: endpoint,
          semanticLabel: raftText(context, 'MCP server URL'),
          readOnly: provider != 'custom',
          enabled: provider == 'custom',
          keyboardType: TextInputType.url,
          onChanged: changed,
        ),
        required: true,
      ),
    ];
    final keyed = [
      for (var i = 0; i < fields.length; i++)
        KeyedSubtree(key: inputKeys[i], child: fields[i]),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 480) {
          return Column(spacing: RaftSpace.x3, children: keyed);
        }
        return Column(
          spacing: RaftSpace.x3,
          children: [
            for (var i = 0; i < keyed.length; i += 2)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: RaftSpace.x3,
                children: [
                  Expanded(child: keyed[i]),
                  Expanded(child: keyed[i + 1]),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget headerRow(_HeaderEditors row) => Row(
    key: ValueKey('mcp-credential-${row.id}'),
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: RaftSpace.x2,
    children: [
      Expanded(
        child: RaftTextInput(
          key: ValueKey('mcp-header-name-${row.id}'),
          controller: row.name,
          hintText: 'Authorization',
          semanticLabel: raftText(context, 'Header name'),
          onChanged: changed,
        ),
      ),
      Expanded(
        child: RaftTextInput(
          key: ValueKey('mcp-header-value-${row.id}'),
          controller: row.value,
          hintText: row.snapshot.retainsValue ? '••••••••' : 'Bearer ...',
          semanticLabel: raftFormat(context, 'Value for {name}', {
            'name': row.name.text.isEmpty
                ? raftText(context, 'credential header')
                : row.name.text,
          }),
          obscureText: true,
          onChanged: changed,
        ),
      ),
      RaftIconButton(
        key: ValueKey('mcp-remove-header-${row.id}'),
        glyph: RaftGlyph.trash2,
        tooltip: raftText(context, 'Remove header'),
        onPressed: () {
          headers.remove(row);
          changed();
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: RaftDismissScope(
      child: RaftDialogCard(
        key: const ValueKey('mcp-server-editor'),
        title: creating
            ? 'Add MCP server'
            : name.text.isEmpty
            ? 'MCP server'
            : name.text,
        maxWidth: McpServerEditor.dialogMaxWidth,
        onClose: () {
          if (!saving) Navigator.of(context).pop(false);
        },
        actions: Padding(
          padding: const EdgeInsets.only(top: RaftSpace.x4),
          child: OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: RaftSpace.x2,
            overflowSpacing: RaftSpace.x2,
            children: [
              RaftButton(
                label: 'Cancel',
                tone: RaftButtonRecipeVariant.outline,
                onPressed: saving
                    ? null
                    : () => Navigator.of(context).pop(false),
              ),
              RaftButton(
                key: const ValueKey('mcp-editor-save'),
                label: saving ? 'Saving…' : 'Save',
                glyph: RaftGlyph.check,
                tone: RaftButtonRecipeVariant.success,
                onPressed: saving ? null : save,
              ),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: RaftSpace.x4,
          children: [
            Text(
              raftText(
                context,
                'Raft Server owns authentication, refresh, and remote MCP requests.',
              ),
            ),
            if (error != null)
              RaftErrorBanner(raftText(context, error!), small: true),
            inputs(),
            field(
              'Description',
              RaftTextarea(
                controller: description,
                rows: 2,
                onChanged: changed,
                semanticLabel: raftText(context, 'Description'),
              ),
            ),
            if (authMode == 'oauth')
              RaftBanner(
                description: raftText(
                  context,
                  'Save this connection, then use Connect from Settings → MCP Servers to authorize it. OAuth tokens never leave Raft Server.',
                ),
              ),
            if (authMode == 'headers')
              field(
                'Credential Headers',
                Column(
                  spacing: RaftSpace.x2,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final row in headers) headerRow(row),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: RaftButton(
                        key: const ValueKey('mcp-add-header'),
                        label: 'Add Header',
                        glyph: RaftGlyph.plus,
                        size: RaftButtonRecipeSize.sm,
                        tone: RaftButtonRecipeVariant.outline,
                        onPressed: () {
                          addHeader();
                          changed();
                        },
                      ),
                    ),
                    if (headers.isEmpty)
                      Text(raftText(context, 'No credential headers.')),
                  ],
                ),
              ),
            if (authMode != 'oauth')
              Align(
                alignment: Alignment.centerLeft,
                child: RaftButton(
                  key: const ValueKey('mcp-editor-test'),
                  label: testing ? 'Testing…' : 'Test connection',
                  glyph: RaftGlyph.flaskConical,
                  size: RaftButtonRecipeSize.sm,
                  onPressed:
                      testing ||
                          saving ||
                          endpoint.text.trim().isEmpty ||
                          incomplete
                      ? null
                      : test,
                ),
              ),
            if (testedTools != null)
              RaftBanner(
                status: RaftBannerRecipeStatus.success,
                description: raftFormat(
                  context,
                  testedTools == 1
                      ? 'Connection succeeded. Found {count} tool.'
                      : 'Connection succeeded. Found {count} tools.',
                  {'count': testedTools},
                ),
              ),
            if (testError != null) RaftErrorBanner(testError!, small: true),
          ],
        ),
      ),
    ),
  );
}
