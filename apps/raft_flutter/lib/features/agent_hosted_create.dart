// The "Cloud agent" choice of the create-agent dialog (Web CreateAgentDialog
// `HOSTED_COMPUTER_CHOICE`, `useAgentRuntimeProvider`, `useHostedRuntimeModels`):
// one more entry in the Computer picker, offered only where the server's
// `antiproton_hosted_runtime` flag is on and the deployment has the provider
// configured. A cloud agent has no computer, runtime or model fields: it asks
// for the model (unless the server decides) and is created as an external
// agent on the provider. With no computer connected the cloud is the only
// place the agent can run.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_hosted_runtime.dart';
import '../data/workspace_controller.dart';
import 'agent_hosted_model_choice.dart';
import 'agent_hosted_provider.dart';

/// The Computer picker's value for "hosted by Raft": no computer.
const hostedComputerChoice = '__hosted_runtime__';

/// `agent:create` card `hosting` value that preselects the cloud.
const hostedCardHosting = 'antiproton';

class HostedCreateChoice extends ChangeNotifier {
  HostedCreateChoice(
    WorkspaceController controller, {
    required this.enabled,
    required this.noComputers,
    String? prefilledHosting,
    this.prefilledModel,
  }) : availability = HostedRuntimeAvailability(controller),
       models = HostedModelsLoader(controller),
       selected = prefilledHosting == hostedCardHosting {
    availability.addListener(_changed);
    models.addListener(_changed);
  }

  /// Not for onboarding, nor a card that requires a computer.
  final bool enabled;

  /// No computer is connected, so the cloud is the only choice (kept current
  /// by the dialog as its computer list changes).
  bool noComputers;

  /// An action card's model, kept only while the provider still offers it.
  final String? prefilledModel;

  final HostedRuntimeAvailability availability;
  final HostedModelsLoader models;

  bool selected;
  String? _pick;
  bool _picked = false, _disposed = false;

  /// Reads the flag and the probe once (the dialog's mount).
  void start() {
    if (enabled) unawaited(availability.load());
  }

  /// The Computer picker offers the cloud.
  bool get offered => enabled && availability.available;

  /// The dialog is in cloud mode: no computer, runtime or model fields.
  bool get active => offered && (selected || noComputers);

  /// Create waits for the list (an unavailable list still allows the default).
  bool get loading => active && models.status == HostedModelsStatus.loading;

  /// The pick shown: the creator's, else the card's while offered, else null.
  String? get model {
    final view = models.view;
    if (view == null || view.locked || !hostedModelPickerShown(view)) {
      return null;
    }
    if (_picked) return _pick;
    final card = prefilledModel;
    return card != null && view.models.any((m) => m.id == card) ? card : null;
  }

  /// `hostedModel` of the create call: null follows the provider's default.
  String? get modelToSend => hostedModelToSend(models.view, model);

  void select(bool value) {
    if (selected == value) return;
    selected = value;
    _changed();
  }

  void pick(String? id) {
    _pick = id;
    _picked = true;
    _changed();
  }

  /// `POST /agents` fields of a cloud agent.
  Map<String, Object?> get submission => {
    'external': true,
    'provider': hostedRuntimeProviderKind,
    'hostedModel': ?modelToSend,
  };

  RaftAgentSelectOption<String> option(BuildContext context) =>
      RaftAgentSelectOption(
        hostedComputerChoice,
        raftText(
          context,
          'Cloud agent, runs in the cloud · Free for a limited time',
        ),
      );

  /// The fields below the name and description of a cloud agent.
  List<Widget> fields(BuildContext context, {required bool busy}) {
    return [
      if (hostedModelPickerShown(models.view))
        RaftStableField(
          label: 'Model',
          child: HostedModelChoice(
            loader: models,
            value: model,
            onChanged: pick,
            enabled: !busy,
          ),
        ),
    ];
  }

  /// The hint under the Computer picker.
  Widget hint(BuildContext context) => RaftAgentFieldNote(
    'Raft creates the agent in the cloud and connects it for you. No command line needed.',
    key: const ValueKey('create-agent-hosted-runtime'),
  );

  void _changed() {
    if (_disposed) return;
    // The list is read the first time the dialog is in cloud mode.
    models.ensure(active);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    availability.removeListener(_changed);
    models.removeListener(_changed);
    availability.dispose();
    models.dispose();
    super.dispose();
  }
}
