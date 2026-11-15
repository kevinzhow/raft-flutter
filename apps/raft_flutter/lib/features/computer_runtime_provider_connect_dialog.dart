// Web v1.24 features/computer/RuntimeProviderConnectDialog.tsx
// (+ providerConnectFailure.ts): Qwen Code has no sign-in: the person
// connects it to a model provider with an API key, saved in Qwen's own
// settings on the Computer. The key lives in the dialog's password field
// until it is sent, and is dropped once saved or when the dialog closes; it
// is never shown again, logged or traced.
//
// Steps: read the providers the Computer's Qwen offers, choose one, give its
// API key (and its endpoint or model where it needs them), done.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/runtime_auth.dart';
import '../data/workspace_controller.dart';
import 'computer_runtime_sign_out_dialog.dart' show runtimeComputerName;
import 'computers_rack/computers_rack_model.dart' show rackRuntimeDisplayName;

/// How a provider list or connect that did not complete is worded: only the
/// request's status and code, or the Computer's result, are read.
class ProviderFailure {
  const ProviderFailure(this.source, {required this.retryable});

  /// The catalog's English text (`{runtime}` and `{computer}` filled later).
  final String source;
  final bool retryable;
}

/// A field the server refused, by the code it answered with.
enum ProviderField { apiKey, baseUrl, model }

const _fieldByCode = {
  'invalid_api_key': ProviderField.apiKey,
  'invalid_base_url': ProviderField.baseUrl,
  'invalid_model': ProviderField.model,
};

String providerFieldSource(ProviderField field) => switch (field) {
  ProviderField.apiKey => 'Paste the whole API key, with no spaces.',
  ProviderField.baseUrl => 'Enter an http or https URL.',
  ProviderField.model => 'Enter one model name, with no spaces.',
};

const _tooOldSource = 'Upgrade this Computer to connect a provider from here';
const _notAttachedSource =
    "This Computer has no owner, so its runtimes can't be connected from here";

/// providerRequestFailure: a request the server refused or could not relay
/// (a [ProviderFailure] or the [ProviderField] it refused).
Object providerRequestFailure(Object error, {required bool connect}) {
  final (:status, :code) = runtimeAuthRequestError(error);
  final field = code == null ? null : _fieldByCode[code];
  if (field != null) return field;
  if (code == 'computer_offline') {
    return const ProviderFailure(
      'This Computer is offline. Connect it, then try again.',
      retryable: true,
    );
  }
  if (code == 'computer_upgrade_required') {
    return const ProviderFailure(_tooOldSource, retryable: false);
  }
  if (code == 'computer_not_attached') {
    return const ProviderFailure(_notAttachedSource, retryable: false);
  }
  if (code == 'computer_timeout' || status == 504) {
    return ProviderFailure(
      connect
          ? '{runtime} took too long to answer. The key may or may not be saved: check the card, then try again if needed.'
          : 'The Computer did not answer in time. Try again.',
      retryable: true,
    );
  }
  if (code == 'rate_limited' || status == 429) {
    return const ProviderFailure(
      'Too many attempts on this Computer. Try again in a few minutes.',
      retryable: true,
    );
  }
  if (status == 400) {
    return const ProviderFailure(
      'Check the details and try again.',
      retryable: true,
    );
  }
  if (status == 403) {
    return const ProviderFailure(
      'Only the person who connected this Computer, or an owner or admin, can connect its runtimes to a provider.',
      retryable: false,
    );
  }
  if (status == 404) {
    return const ProviderFailure(
      "This Computer or runtime wasn't found.",
      retryable: false,
    );
  }
  return const ProviderFailure(
    "Couldn't reach the Computer. Try again.",
    retryable: true,
  );
}

/// providerResultFailure: the Computer answered, but without a list or a save.
ProviderFailure providerResultFailure(
  Map<String, dynamic> result, {
  required bool connect,
}) {
  final kind = result['kind'];
  if (kind == 'busy') {
    return const ProviderFailure(
      'Another provider is being connected on this Computer. Try again in a moment.',
      retryable: true,
    );
  }
  if (kind == 'unsupported') {
    return result['reason'] == 'not_installed'
        ? const ProviderFailure(
            '{runtime} is not installed on this Computer.',
            retryable: false,
          )
        : const ProviderFailure(
            "{runtime} on this Computer can't be connected from the web.",
            retryable: false,
          );
  }
  return switch (result['reason']) {
    'rejected' => const ProviderFailure(
      '{runtime} did not accept these settings. Check the key and try again.',
      retryable: true,
    ),
    'timed_out' => ProviderFailure(
      connect
          ? '{runtime} took too long to answer. The key may or may not be saved: check the card, then try again if needed.'
          : '{runtime} took too long to answer. Try again.',
      retryable: true,
    ),
    'process_failed' => const ProviderFailure(
      '{runtime} could not run on this Computer. Try again.',
      retryable: true,
    ),
    'invalid_response' => const ProviderFailure(
      "{runtime} answered in a way this page can't read. Update {runtime} on the Computer, then try again.",
      retryable: false,
    ),
    // The server could not hand the connect to the Computer's own
    // connection: nothing was saved.
    _ => const ProviderFailure(
      "Couldn't reach the Computer. Try again.",
      retryable: true,
    ),
  };
}

/// Opens the provider connect dialog for [runtime] (a runtime-auth id, Qwen)
/// on the Computer [machineId]; [runtimeId] is the Raft runtime id it is
/// shown for. A sheet on a phone, a dialog from 768; Esc and the X close it,
/// a press outside does not (Web `disablePointerDismissal`).
Future<void> showComputerRuntimeProviderConnectDialog(
  BuildContext context, {
  required WorkspaceController controller,
  required RuntimeAuthClient client,
  required String serverId,
  required String machineId,
  required String runtimeId,
  required String runtime,
}) => showRaftForm<void>(
  context,
  dismissible: false,
  dragDismissible: false,
  // Web has no discard question here; the key is dropped with the dialog.
  guardUnsaved: false,
  builder: (dialog) => RuntimeProviderConnectForm(
    client: client,
    serverId: serverId,
    machineId: machineId,
    runtimeId: runtimeId,
    runtime: runtime,
    computer:
        runtimeComputerName(controller, machineId) ??
        raftText(dialog, 'this Computer'),
  ),
);

/// ChoiceList's `max-h-70` scroll area.
const _listMaxHeight = 280.0;

enum _Step { choose, details, done }

class RuntimeProviderConnectForm extends StatefulWidget {
  const RuntimeProviderConnectForm({
    super.key,
    required this.client,
    required this.serverId,
    required this.machineId,
    required this.runtimeId,
    required this.runtime,
    required this.computer,
  });
  final RuntimeAuthClient client;
  final String serverId, machineId, runtimeId, runtime, computer;

  @override
  State<RuntimeProviderConnectForm> createState() =>
      _RuntimeProviderConnectFormState();
}

class _RuntimeProviderConnectFormState
    extends State<RuntimeProviderConnectForm> {
  // loading | failed | listed
  String listKind = 'loading';
  ProviderFailure? listFailure;
  List<Map<String, dynamic>> providers = const [];
  _Step step = _Step.choose;
  String? chosenId, detailsFor, endpointId;
  final baseUrl = TextEditingController();
  final model = TextEditingController();
  // The API key, only while the form is open and unsent. Never logged, never
  // shown back.
  final apiKey = TextEditingController();
  final search = TextEditingController();
  final searchFocus = FocusNode();
  bool connecting = false;
  ProviderFailure? failure;
  ProviderField? fieldError;
  int listAttempt = 0;

  String get runtimeName => rackRuntimeDisplayName(widget.runtimeId);
  Map<String, Object?> get values => {
    'runtime': runtimeName,
    'computer': widget.computer,
  };

  @override
  void initState() {
    super.initState();
    // Read once on open and again from Try again (each read starts Qwen on
    // the Computer).
    loadProviders();
  }

  @override
  void dispose() {
    baseUrl.dispose();
    model.dispose();
    apiKey.dispose();
    search.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  void loadProviders() {
    final attempt = ++listAttempt;
    setState(() => listKind = 'loading');
    widget.client
        .listProviders(widget.serverId, widget.machineId, widget.runtime)
        .then(
          (result) {
            if (!mounted || attempt != listAttempt) return;
            setState(() {
              if (result['kind'] == 'listed') {
                providers = [
                  for (final p in result['providers'] as List)
                    if (p is Map) Map<String, dynamic>.from(p),
                ];
                listKind = 'listed';
              } else {
                listFailure = providerResultFailure(result, connect: false);
                listKind = 'failed';
              }
            });
          },
          onError: (Object error) {
            if (!mounted || attempt != listAttempt) return;
            final refused = providerRequestFailure(error, connect: false);
            setState(() {
              listFailure = refused is ProviderFailure
                  ? refused
                  : const ProviderFailure(
                      'Check the details and try again.',
                      retryable: true,
                    );
              listKind = 'failed';
            });
          },
        );
  }

  Map<String, dynamic>? get chosen {
    for (final p in providers) {
      if (p['id'] == chosenId) return p;
    }
    return null;
  }

  Map<String, dynamic> _endpoint(Map<String, dynamic> p) => p['endpoint'] is Map
      ? Map<String, dynamic>.from(p['endpoint'] as Map)
      : const {'kind': 'fixed'};

  String groupLabel(Map<String, dynamic> p) {
    final group = p['group'] is Map ? p['group'] as Map : null;
    final id = '${group?['id'] ?? 'third-party'}';
    final label = group?['label'];
    if (label is String && label.isNotEmpty) return label;
    return switch (id) {
      'third-party' => raftText(context, 'Other providers'),
      'custom' => raftText(context, 'Custom'),
      _ => id,
    };
  }

  void choose(String id) => setState(() => chosenId = id);

  void next() {
    final c = chosen;
    if (c == null) return;
    if (detailsFor != c['id']) {
      detailsFor = '${c['id']}';
      endpointId = null;
      baseUrl.clear();
      model.clear();
      apiKey.clear();
    }
    setState(() {
      failure = null;
      fieldError = null;
      step = _Step.details;
    });
  }

  void back() => setState(() {
    failure = null;
    fieldError = null;
    step = _Step.choose;
  });

  bool get ready {
    final c = chosen;
    if (c == null || apiKey.text.trim().isEmpty) return false;
    final endpoint = _endpoint(c);
    if (endpoint['kind'] == 'choice' && endpointId == null) return false;
    if (endpoint['kind'] == 'custom' && baseUrl.text.trim().isEmpty) {
      return false;
    }
    if (c['needsModelIds'] == true && model.text.trim().isEmpty) return false;
    return true;
  }

  void connect() {
    final c = chosen;
    if (c == null || !ready || connecting) return;
    final endpoint = _endpoint(c);
    String? url;
    if (endpoint['kind'] == 'choice') {
      for (final option in (endpoint['options'] as List? ?? const [])) {
        if (option is Map && option['id'] == endpointId) {
          url = '${option['url']}';
        }
      }
    } else if (endpoint['kind'] == 'custom') {
      url = baseUrl.text.trim();
    }
    final input = <String, dynamic>{
      'providerId': c['id'],
      'apiKey': apiKey.text.trim(),
      'baseUrl': ?url,
      if (c['needsModelIds'] == true) 'modelIds': [model.text.trim()],
    };
    setState(() {
      connecting = true;
      failure = null;
      fieldError = null;
    });
    widget.client
        .connectProvider(
          widget.serverId,
          widget.machineId,
          widget.runtime,
          input,
        )
        .then(
          (result) {
            // A save, or one that may have happened: the card reads the new
            // status.
            if (result['kind'] == 'connected' ||
                (result['kind'] == 'failed' &&
                    result['reason'] == 'timed_out')) {
              widget.client.invalidate(widget.serverId, widget.machineId);
            }
            if (!mounted) return;
            setState(() {
              connecting = false;
              if (result['kind'] == 'connected') {
                apiKey.clear();
                step = _Step.done;
              } else {
                failure = providerResultFailure(result, connect: true);
              }
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            final refused = providerRequestFailure(error, connect: true);
            setState(() {
              connecting = false;
              if (refused is ProviderField) {
                fieldError = refused;
              } else {
                failure = refused as ProviderFailure;
              }
            });
          },
        );
  }

  void close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final title = raftFormat(context, 'Connect {runtime} to a provider', {
      'runtime': runtimeName,
    });
    final body = _body(context);
    final actions = _actions(context);
    return PopScope(
      canPop: !connecting,
      child: RaftDismissScope(
        child: RaftFormFrame.sheetOf(context)
            ? RaftFormSheet(
                title: title,
                onClose: connecting ? null : close,
                body: body,
                footer: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: RaftSpace.x2,
                  overflowSpacing: RaftSpace.x2,
                  children: actions,
                ),
              )
            : RaftDialog.card(
                key: ValueKey('runtime-provider-dialog-${widget.runtime}'),
                title: title,
                onClose: close,
                closeEnabled: !connecting,
                maxWidth: 448,
                footer: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: RaftSpace.x2,
                  runSpacing: RaftSpace.x2,
                  children: actions,
                ),
                child: body,
              ),
      ),
    );
  }

  RaftButton _button(
    String label,
    VoidCallback? onPressed, {
    bool primary = true,
    bool busy = false,
    Key? key,
  }) => RaftButton(
    key: key,
    label: label,
    uiVariant: primary ? RaftButtonVariant.primary : RaftButtonVariant.ghost,
    uiSize: RaftButtonSize.lg,
    onPressed: onPressed,
    busy: busy,
  );

  List<Widget> _actions(BuildContext context) {
    String tr(String s) => raftText(context, s);
    if (step == _Step.done) {
      return [
        _button(
          tr('Done'),
          close,
          key: const ValueKey('runtime-provider-done'),
        ),
      ];
    }
    if (listKind == 'failed') {
      return [
        _button(tr('Close'), close, primary: false),
        if (listFailure?.retryable == true)
          _button(
            tr('Try again'),
            loadProviders,
            key: const ValueKey('runtime-provider-retry'),
          ),
      ];
    }
    if (step == _Step.details && chosen != null) {
      return [
        _button(
          tr('Back'),
          connecting ? null : back,
          primary: false,
          key: const ValueKey('runtime-provider-back'),
        ),
        _button(
          connecting ? tr('Connecting') : tr('Connect'),
          ready && !connecting ? connect : null,
          busy: connecting,
          key: const ValueKey('runtime-provider-connect'),
        ),
      ];
    }
    return [
      _button(tr('Cancel'), close, primary: false),
      if (listKind == 'listed')
        _button(
          tr('Continue'),
          chosen == null ? null : next,
          key: const ValueKey('runtime-provider-continue'),
        ),
    ];
  }

  TextStyle _muted(RaftTokens t, {double size = 14}) => RaftTypography.body(
    t,
    size: size,
    line: size * 1.5,
    color: t.colors['foreground-muted'] ?? t.strong,
  );

  Widget _body(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    if (step == _Step.done) {
      return RaftBanner(
        key: const ValueKey('runtime-provider-saved'),
        status: RaftBannerRecipeStatus.success,
        glyph: RaftGlyph.circleCheck,
        description: raftFormat(
          context,
          'Saved on this Computer. {runtime} checks the key when an agent runs.',
          values,
        ),
      );
    }
    if (listKind == 'loading') {
      return Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const RaftSpinner(),
            const SizedBox(width: RaftSpace.x2),
            Expanded(
              child: Text(
                raftFormat(
                  context,
                  'Reading the providers on {computer}…',
                  values,
                ),
                style: _muted(t),
              ),
            ),
          ],
        ),
      );
    }
    if (listKind == 'failed') {
      return RaftBanner(
        key: const ValueKey('runtime-provider-list-failed'),
        status: RaftBannerRecipeStatus.warning,
        glyph: RaftGlyph.alertTriangle,
        description: raftFormat(context, listFailure!.source, values),
      );
    }
    final c = chosen;
    if (step == _Step.choose || c == null) {
      return Column(
        key: const ValueKey('runtime-provider-choose'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('Choose the provider your API key is from.'),
            style: _muted(t),
          ),
          const SizedBox(height: RaftSpace.x3),
          _ProviderChoices(
            providers: providers,
            chosenId: chosenId,
            onChoose: choose,
            groupLabel: groupLabel,
            search: search,
            searchFocus: searchFocus,
            searchHint: tr('Search providers'),
            clearLabel: tr('Clear search'),
            noMatch: tr('No matching providers'),
            empty: raftFormat(
              context,
              '{runtime} on this Computer lists no providers.',
              values,
            ),
            alreadyConfigured: tr('Already configured on this Computer'),
          ),
        ],
      );
    }
    final endpoint = _endpoint(c);
    final needsEndpoint = endpoint['kind'] == 'choice';
    final needsBaseUrl = endpoint['kind'] == 'custom';
    final needsModel = c['needsModelIds'] == true;
    final fine = !RaftInteraction.of(context).touch;
    // The first empty field takes the cursor on a pointer; a finger gets no
    // keyboard it did not ask for.
    final first = needsBaseUrl
        ? 'baseUrl'
        : needsModel
        ? 'model'
        : needsEndpoint
        ? 'none'
        : 'apiKey';
    return Column(
      key: const ValueKey('runtime-provider-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${groupLabel(c)} · ${c['label']}',
          key: const ValueKey('runtime-provider-chosen'),
          style: _muted(t).copyWith(color: t.strong),
        ),
        const SizedBox(height: RaftSpace.x4),
        if (needsEndpoint) ...[
          RaftField(
            label: tr('Endpoint'),
            required: true,
            hint: tr('Choose the one your API key belongs to.'),
            child: RaftSelectField<String>(
              key: const ValueKey('runtime-provider-endpoint'),
              label: tr('Endpoint'),
              value: endpointId,
              placeholder: tr('Choose an endpoint'),
              items: [
                for (final option in (endpoint['options'] as List? ?? const []))
                  if (option is Map)
                    RaftSelectItem<String>(
                      value: '${option['id']}',
                      label: '${option['label']}',
                    ),
              ],
              onChanged: connecting
                  ? null
                  : (v) => setState(() => endpointId = v),
            ),
          ),
          const SizedBox(height: RaftSpace.x4),
        ],
        if (needsBaseUrl) ...[
          RaftField(
            label: tr('Base URL'),
            required: true,
            hint: fieldError == ProviderField.baseUrl
                ? null
                : tr("The address of your server's OpenAI-compatible API."),
            error: fieldError == ProviderField.baseUrl
                ? tr(providerFieldSource(ProviderField.baseUrl))
                : null,
            child: RaftTextInput(
              fieldKey: const ValueKey('runtime-provider-base-url'),
              controller: baseUrl,
              semanticLabel: tr('Base URL'),
              hintText: '${endpoint['placeholder'] ?? ''}',
              keyboardType: TextInputType.url,
              enabled: !connecting,
              invalid: fieldError == ProviderField.baseUrl,
              autofocus: fine && first == 'baseUrl',
              onChanged: (_) => setState(() {
                if (fieldError == ProviderField.baseUrl) fieldError = null;
              }),
              onSubmitted: (_) => connect(),
            ),
          ),
          const SizedBox(height: RaftSpace.x4),
        ],
        if (needsModel) ...[
          RaftField(
            label: tr('Model'),
            required: true,
            hint: fieldError == ProviderField.model
                ? null
                : tr("The model's name as your provider spells it."),
            error: fieldError == ProviderField.model
                ? tr(providerFieldSource(ProviderField.model))
                : null,
            child: RaftTextInput(
              fieldKey: const ValueKey('runtime-provider-model'),
              controller: model,
              semanticLabel: tr('Model'),
              enabled: !connecting,
              invalid: fieldError == ProviderField.model,
              autofocus: fine && first == 'model',
              onChanged: (_) => setState(() {
                if (fieldError == ProviderField.model) fieldError = null;
              }),
              onSubmitted: (_) => connect(),
            ),
          ),
          const SizedBox(height: RaftSpace.x4),
        ],
        RaftField(
          label: tr('API key'),
          required: true,
          error: fieldError == ProviderField.apiKey
              ? tr(providerFieldSource(ProviderField.apiKey))
              : null,
          child: RaftTextInput(
            fieldKey: const ValueKey('runtime-provider-api-key'),
            controller: apiKey,
            semanticLabel: tr('API key'),
            obscureText: true,
            mono: true,
            enabled: !connecting,
            invalid: fieldError == ProviderField.apiKey,
            autofocus: fine && first == 'apiKey',
            // Not a sign-in to this site: no password manager.
            autofillHints: const [],
            onChanged: (_) => setState(() {
              if (fieldError == ProviderField.apiKey) fieldError = null;
            }),
            onSubmitted: (_) => connect(),
          ),
        ),
        const SizedBox(height: RaftSpace.x4),
        Text(
          raftFormat(
            context,
            'Saved in the {runtime} settings of the account that runs {computer}. It applies to all its {runtime} agents, and also to {runtime} used outside Raft by that account.',
            values,
          ),
          key: const ValueKey('runtime-provider-scope'),
          style: _muted(t, size: 12),
        ),
        if (failure != null) ...[
          const SizedBox(height: RaftSpace.x4),
          RaftBanner(
            key: const ValueKey('runtime-provider-failed'),
            status: RaftBannerRecipeStatus.warning,
            glyph: RaftGlyph.alertTriangle,
            description: raftFormat(context, failure!.source, values),
          ),
        ],
      ],
    );
  }
}

/// ChoiceList: a searchable, grouped single choice of the Computer's
/// providers, each with its description and "Already configured" note.
class _ProviderChoices extends StatefulWidget {
  const _ProviderChoices({
    required this.providers,
    required this.chosenId,
    required this.onChoose,
    required this.groupLabel,
    required this.search,
    required this.searchFocus,
    required this.searchHint,
    required this.clearLabel,
    required this.noMatch,
    required this.empty,
    required this.alreadyConfigured,
  });
  final List<Map<String, dynamic>> providers;
  final String? chosenId;
  final ValueChanged<String> onChoose;
  final String Function(Map<String, dynamic>) groupLabel;
  final TextEditingController search;
  final FocusNode searchFocus;
  final String searchHint, clearLabel, noMatch, empty, alreadyConfigured;

  @override
  State<_ProviderChoices> createState() => _ProviderChoicesState();
}

class _ProviderChoicesState extends State<_ProviderChoices> {
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (widget.providers.isEmpty) {
      return Text(
        widget.empty,
        key: const ValueKey('runtime-provider-empty'),
        style: RaftTypography.body(
          t,
          size: 14,
          line: 20,
          color: t.colors['foreground-muted'] ?? t.strong,
        ),
      );
    }
    final query = widget.search.text.trim().toLowerCase();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final p in widget.providers) {
      final text = [
        p['label'],
        p['description'],
        widget.groupLabel(p),
      ].where((v) => v != null && '$v'.isNotEmpty).join(' ').toLowerCase();
      if (query.isNotEmpty && !text.contains(query)) continue;
      (groups[widget.groupLabel(p)] ??= []).add(p);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftSearchInput(
          controller: widget.search,
          focusNode: widget.searchFocus,
          hint: widget.searchHint,
          clearLabel: widget.clearLabel,
          onChanged: (_) => setState(() {}),
          onClear: () => setState(widget.search.clear),
        ),
        const SizedBox(height: RaftSpace.x2),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _listMaxHeight),
          child: groups.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: RaftSpace.x4),
                  child: Text(
                    widget.noMatch,
                    textAlign: TextAlign.center,
                    style: RaftTypography.body(
                      t,
                      size: 14,
                      line: 20,
                      color: t.colors['foreground-muted'] ?? t.strong,
                    ),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          RaftSpace.x2,
                          RaftSpace.x2,
                          RaftSpace.x2,
                          RaftSpace.x1,
                        ),
                        child: Text(
                          entry.key,
                          style: RaftTypography.body(
                            t,
                            size: 11,
                            line: 16,
                            weight: FontWeight.w700,
                            color: t.colors['foreground-hint'] ?? t.strong,
                          ),
                        ),
                      ),
                      for (final p in entry.value) _row(context, t, p),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, RaftTokens t, Map<String, dynamic> p) {
    final id = '${p['id']}';
    final selected = id == widget.chosenId;
    final description = [
      if (p['description'] is String && (p['description'] as String).isNotEmpty)
        p['description'] as String,
      if (p['configured'] == true) widget.alreadyConfigured,
    ].join(' · ');
    return RaftInteractive(
      key: ValueKey('runtime-provider-choice-$id'),
      semanticLabel: '${p['label']}',
      selected: selected,
      onPressed: () => widget.onChoose(id),
      builder: (context, state) => Container(
        padding: const EdgeInsets.all(RaftSpace.x2),
        decoration: BoxDecoration(
          color: selected
              ? t.colors['info-soft']
              : state.hovered
              ? t.colors['layer-inset']
              : null,
          border: state.focusVisible
              ? Border.all(color: t.strong, width: t.border)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${p['label']}',
              style: RaftTypography.body(
                t,
                size: 14,
                line: 20,
                weight: FontWeight.w600,
                color: t.strong,
              ),
            ),
            if (description.isNotEmpty)
              Text(
                description,
                key: p['configured'] == true
                    ? ValueKey('runtime-provider-configured-$id')
                    : null,
                style: RaftTypography.body(
                  t,
                  size: 12,
                  line: 16,
                  color: t.colors['foreground-muted'] ?? t.strong,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
