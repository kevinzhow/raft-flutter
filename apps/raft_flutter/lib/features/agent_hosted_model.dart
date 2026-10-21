// Web components/agent/AgentHostedRuntimeModel.tsx: the "Model" card of a
// hosted (provider-backed) external agent. GET/PUT /agents/:id/hosted-runtime/
// model. The provider offers a fixed list and a default; a pick is stored by
// the provider and used from the agent's next turn (no restart). While an
// administrator decides the model (`locked`) it is shown read-only. Hidden when
// the agent is not hosted or the caller may not see it (4xx on load, but 429).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

/// Item id of "follow the provider's default"; stored as `model: null`.
const hostedModelDefaultChoice = '__hosted_default__';

String hostedRuntimeModelPath(String agentId) =>
    '/agents/${Uri.encodeComponent(agentId)}/hosted-runtime/model';

/// `HostedAgentModelView`.
class HostedModelView {
  const HostedModelView({
    required this.models,
    required this.defaultModel,
    required this.defaultLabel,
    required this.model,
    required this.label,
    required this.source,
    required this.locked,
  });

  /// The offered models: `(id, label)`.
  final List<(String, String)> models;
  final String? defaultModel, defaultLabel, model, label;

  /// `default` (nothing picked), `chosen` (a pick) or `admin` (an
  /// administrator's row decides).
  final String source;
  final bool locked;

  static HostedModelView? parse(dynamic json) {
    if (json is! Map) return null;
    final models = <(String, String)>[];
    final list = json['models'];
    if (list is List) {
      for (final m in list) {
        if (m is Map && m['id'] is String) {
          models.add((m['id'] as String, '${m['label'] ?? m['id']}'));
        }
      }
    }
    String? text(String key) =>
        json[key] is String ? json[key] as String : null;
    return HostedModelView(
      models: models,
      defaultModel: text('default'),
      defaultLabel: text('defaultLabel'),
      model: text('model'),
      label: text('label'),
      source: json['source'] is String ? json['source'] as String : 'default',
      locked: json['locked'] == true,
    );
  }

  /// The id stored for this agent, `null` while it follows the default.
  String? get chosen => source == 'default' ? null : model;

  /// The pick shown at once, before the provider answers.
  HostedModelView picked(String? id) {
    if (id == null) {
      return copyWith(
        model: defaultModel,
        label: defaultLabel,
        source: 'default',
      );
    }
    var label = id;
    for (final m in models) {
      if (m.$1 == id) label = m.$2;
    }
    return copyWith(model: id, label: label, source: 'chosen');
  }

  HostedModelView copyWith({String? model, String? label, String? source}) =>
      HostedModelView(
        models: models,
        defaultModel: defaultModel,
        defaultLabel: defaultLabel,
        model: model,
        label: label,
        source: source ?? this.source,
        locked: locked,
      );
}

enum _Load { loading, hidden, error, ready }

enum _Notice { saved, notOffered, locked, failed }

/// Mounted by the agent detail where the viewer manages an external agent
/// whose `hostedRuntime.state` is `active`. Keyed by agent at the call site.
class AgentHostedRuntimeModel extends StatefulWidget {
  const AgentHostedRuntimeModel({
    super.key,
    required this.controller,
    required this.agentId,
  });
  final WorkspaceController controller;
  final String agentId;
  @override
  State<AgentHostedRuntimeModel> createState() =>
      _AgentHostedRuntimeModelState();
}

class _AgentHostedRuntimeModelState extends State<AgentHostedRuntimeModel> {
  RaftClient get _client => widget.controller.client;

  _Load _load = _Load.loading;
  HostedModelView? _view;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next pick starts (Web `setNotice(null)`); the card is keyed by agent so it never outlives its agent.
  _Notice? _notice;
  bool _saving = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  void didUpdateWidget(AgentHostedRuntimeModel old) {
    super.didUpdateWidget(old);
    if (old.agentId != widget.agentId) {
      _generation++;
      _load = _Load.loading;
      _view = null;
      _notice = null;
      _saving = false;
      unawaited(_read());
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _read() async {
    final run = _generation;
    final id = widget.agentId;
    try {
      final view = HostedModelView.parse(
        await _client.get(hostedRuntimeModelPath(id)),
      );
      if (!mounted || run != _generation) return;
      setState(() {
        _view = view;
        _load = view == null ? _Load.error : _Load.ready;
      });
    } on RaftApiException catch (e) {
      if (!mounted || run != _generation || e.staleScope) return;
      // 409 = not provisioned yet: show nothing until it is.
      final s = e.status;
      setState(
        () => _load = s != null && s < 500 && s != 429
            ? _Load.hidden
            : _Load.error,
      );
    } catch (_) {
      if (!mounted || run != _generation) return;
      setState(() => _load = _Load.error);
    }
  }

  Future<void> _pick(String id) async {
    final view = _view;
    if (view == null) return;
    final model = id == hostedModelDefaultChoice ? null : id;
    if (model == view.chosen) return;
    final run = _generation;
    // Show the pick at once (a save takes a few seconds); roll back if refused.
    setState(() {
      _saving = true;
      _notice = null;
      _view = view.picked(model);
    });
    _Notice? outcome;
    var refreshed = false;
    try {
      final saved = HostedModelView.parse(
        await _client.request(
          'PUT',
          hostedRuntimeModelPath(widget.agentId),
          data: {'model': model},
        ),
      );
      if (!mounted || run != _generation) return;
      setState(() {
        if (saved != null) _view = saved;
        _notice = _Notice.saved;
      });
    } on RaftApiException catch (e) {
      if (!mounted || run != _generation || e.staleScope) return;
      final s = e.status;
      outcome = s == 422
          ? _Notice.notOffered
          : s == 409
          ? _Notice.locked
          : _Notice.failed;
      refreshed = s == 422 || s == 409;
    } catch (_) {
      if (!mounted || run != _generation) return;
      outcome = _Notice.failed;
    }
    if (outcome != null) {
      setState(() {
        _view = view;
        _notice = outcome;
      });
      // The list or the lock changed under us: show what the provider has now.
      if (refreshed) await _read();
    }
    if (mounted && run == _generation) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_load == _Load.hidden) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    final view = _view;
    final muted = RaftPanelText.caption(t).copyWith(
      color: t.brutal
          ? raftPanelInk(t, .6, t.colors['foreground-muted']!)
          : t.colors['foreground-muted'],
    );
    final Widget body;
    if (_load == _Load.loading) {
      body = Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          label: raftText(context, 'Loading...'),
          child: const RaftSpinner(),
        ),
      );
    } else if (_load == _Load.error || view == null) {
      body = RaftCssText(
        raftText(
          context,
          'The model settings could not be loaded. Try again later.',
        ),
        style: RaftPanelText.warningCaption(t),
      );
    } else if (view.locked) {
      body = RaftGapColumn(
        key: const ValueKey('agent-hosted-runtime-model-locked'),
        gap: 4,
        children: [
          RaftCssText(
            view.label ?? view.model ?? '',
            style: RaftPanelText.value(t),
          ),
          RaftCssText(
            raftText(
              context,
              "An administrator has set this agent's model, so it can't be changed here.",
            ),
            style: muted,
          ),
        ],
      );
    } else {
      body = _picker(context, view, muted);
    }
    return RaftPanelSection(
      key: const ValueKey('agent-hosted-runtime-model'),
      gap: 8,
      children: [RaftSectionEyebrow(raftText(context, 'Model')), body],
    );
  }

  Widget _picker(BuildContext context, HostedModelView view, TextStyle muted) {
    final stored = view.chosen ?? '';
    final unlisted =
        stored.isNotEmpty && !view.models.any((m) => m.$1 == stored);
    final defaultLabel = view.defaultLabel;
    final notice = _saving
        ? 'Saving…'
        : switch (_notice) {
            _Notice.saved =>
              'Saved. The agent uses this model from its next turn.',
            _Notice.notOffered => 'That model is no longer offered. The list has been refreshed; pick another one.',
            _Notice.locked => "An administrator has set this agent's model, so the change was not saved.",
            _Notice.failed => 'The model could not be changed. Try again.',
            null => 'The agent uses the chosen model from its next turn; it does not restart.',
          };
    return RaftGapColumn(
      gap: 6,
      children: [
        RaftAgentCombobox(
          key: const ValueKey('agent-hosted-runtime-model-select'),
          label: 'Model',
          semanticLabel: raftText(context, 'Model'),
          placeholder: raftText(context, 'Model'),
          value: stored.isEmpty ? hostedModelDefaultChoice : stored,
          // Web `emptyOption`: "Default ({label})", else "Provider default".
          items: [
            RaftComboboxItem(
              hostedModelDefaultChoice,
              defaultLabel != null && defaultLabel.isNotEmpty
                  ? raftFormat(context, 'Default ({label})', {
                      'label': defaultLabel,
                    })
                  : raftText(context, 'Provider default'),
            ),
            if (unlisted)
              RaftComboboxItem(
                stored,
                stored,
                description: raftText(context, 'Not in the current list'),
              ),
            for (final m in view.models)
              RaftComboboxItem(
                m.$1,
                m.$2,
                hint: m.$2 == m.$1 ? null : m.$1,
                keywords: m.$1,
              ),
          ],
          onSelected: (id) => unawaited(_pick(id)),
        ),
        if (unlisted)
          RaftAgentFieldNote(
            raftFormat(
              context,
              'The saved value {value} is not in the current list. It stays selected until you pick another.',
              {'value': stored},
            ),
          ),
        if (view.source == 'admin')
          RaftCssText(
            raftText(
              context,
              'Set by the hosting administrator for now. Pick a model to use another one.',
            ),
            style: muted,
          ),
        Semantics(
          liveRegion: true,
          child: RaftCssText(
            raftText(context, notice),
            key: const ValueKey('agent-hosted-runtime-model-notice'),
            style: muted,
          ),
        ),
      ],
    );
  }
}
