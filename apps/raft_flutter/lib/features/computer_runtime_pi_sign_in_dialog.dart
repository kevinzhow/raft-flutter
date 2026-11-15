// Web v1.24 features/computer/PiSignInDialog.tsx: sign a per-provider
// runtime (Pi, OpenCode) in, one provider at a time (an account or a key)
// from its own provider list. The login runs on the Computer.
//
// The list is every provider the runtime's own login offers, read from the
// Computer, in two groups: "Sign in with an account" (OAuth) and "Use an API
// key". An account goes on to the sign-in view (the same login push flow as
// RuntimeSignInDialog, named after the provider); a key is typed here and
// saved on the Computer. A provider that cannot be added from here (a flow
// that needs a browser on the Computer itself, a key login that asks more
// than the key) is listed, unselectable, with why.
//
// The key lives in the password field until it is sent, and is dropped once
// saved, on Back, or when the dialog closes; it is never shown again, logged
// or traced.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/runtime_auth.dart';
import '../data/workspace_controller.dart';
import 'agent_runtime_labels.dart';
import 'computer_runtime_sign_in_dialog.dart';
import 'computer_runtime_sign_in_parts.dart';

/// Opens the sign-in dialog for [runtime] (a runtime-auth id) on the
/// Computer [machineId]; [runtimeId] is the Raft runtime id it is shown for.
Future<void> showComputerRuntimePiSignInDialog(
  BuildContext context, {
  required WorkspaceController controller,
  required RuntimeAuthClient client,
  required String serverId,
  required String machineId,
  required String runtimeId,
  required String runtime,
}) => showSignInStep(
  context,
  label: raftText(context, 'Sign in'),
  builder: (_) => ComputerRuntimePiSignInView(
    controller: controller,
    client: client,
    serverId: serverId,
    machineId: machineId,
    runtimeId: runtimeId,
    runtime: runtime,
  ),
);

/// One OAuth sign-in of a provider: Pi's one, or each of OpenCode's.
class _OAuthMethod {
  const _OAuthMethod(this.label, this.flow);
  final String label, flow;
}

/// runtimeAuthProviderSchema, the parts the list reads.
class _Provider {
  const _Provider({
    required this.id,
    required this.label,
    required this.methods,
    this.keyLabel,
    this.keyEntry,
    this.stored,
  });
  final String id, label;
  final List<_OAuthMethod> methods;
  final String? keyLabel, keyEntry, stored;

  static _Provider? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id'], label = value['label'];
    if (id is! String || label is! String) return null;
    final signIn = value['signIn'];
    final methods = <_OAuthMethod>[];
    String? keyLabel, keyEntry, stored;
    if (signIn is Map) {
      void add(Object? method) {
        if (method is Map &&
            method['label'] is String &&
            method['flow'] is String) {
          methods.add(_OAuthMethod('${method['label']}', '${method['flow']}'));
        }
      }

      final several = signIn['oauthMethods'];
      if (several is List) {
        several.forEach(add);
      } else {
        add(signIn['oauth']);
      }
      final key = signIn['apiKey'];
      if (key is Map) {
        keyLabel = key['label'] is String ? '${key['label']}' : label;
        keyEntry = key['entry'] is String ? '${key['entry']}' : null;
      }
      stored = signIn['stored'] is String ? '${signIn['stored']}' : null;
    }
    return _Provider(
      id: id,
      label: label,
      methods: methods,
      keyLabel: keyLabel,
      keyEntry: keyEntry,
      stored: stored,
    );
  }
}

/// A row the person chooses: an account sign-in (one provider's method) or a
/// key.
class _Choice {
  const _Choice(this.account, this.provider, this.method);
  final bool account;
  final _Provider provider;
  final _OAuthMethod? method;
  String get value => account
      ? 'account:${provider.id}#${provider.methods.indexOf(method!)}'
      : 'key:${provider.id}';
}

enum _Step { choose, account, key, done }

class ComputerRuntimePiSignInView extends StatefulWidget {
  const ComputerRuntimePiSignInView({
    super.key,
    required this.controller,
    required this.client,
    required this.serverId,
    required this.machineId,
    required this.runtimeId,
    required this.runtime,
  });
  final WorkspaceController controller;
  final RuntimeAuthClient client;
  final String serverId, machineId, runtimeId, runtime;

  @override
  State<ComputerRuntimePiSignInView> createState() => _PiSignInState();
}

class _PiSignInState extends State<ComputerRuntimePiSignInView> {
  final apiKey = TextEditingController();
  final search = TextEditingController();
  final searchFocus = FocusNode();

  /// null while loading; a failure or the listed providers.
  bool loading = true;
  SignInFailure? listFailure;
  List<_Provider> providers = const [];
  String? chosenValue;
  _Step step = _Step.choose;
  bool connecting = false;
  SignInFailure? failure;
  bool keyRefusedByServer = false;

  /// The key the server refused, to tell when it was edited.
  String refusedKey = '';
  int listAttempt = 0;

  bool get opencode => widget.runtime == 'opencode';
  bool get choosesMethod => runtimeAuthChoosesOAuthMethod(widget.runtime);

  @override
  void initState() {
    super.initState();
    // Read once on open and again from Try again, never by a rebuild.
    loadProviders();
    apiKey.addListener(() {
      // A changed key is a new key: the server's refusal of the old one goes.
      if (keyRefusedByServer && apiKey.text != refusedKey) {
        setState(() => keyRefusedByServer = false);
      }
    });
  }

  @override
  void dispose() {
    listAttempt++;
    apiKey.dispose();
    search.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  void loadProviders() {
    final mine = ++listAttempt;
    if (mine > 1) {
      setState(() {
        loading = true;
        listFailure = null;
      });
    }
    widget.client
        .listProviders(widget.serverId, widget.machineId, widget.runtime)
        .then<void>(
          (result) {
            if (!mounted || listAttempt != mine) return;
            setState(() {
              loading = false;
              if (result['kind'] == 'listed') {
                providers = [
                  for (final p in result['providers'] as List)
                    ?_Provider.fromJson(p),
                ];
              } else {
                listFailure = signInProviderResultFailure(
                  result,
                  connect: false,
                );
              }
            });
          },
          onError: (Object error) {
            if (!mounted || listAttempt != mine) return;
            final refused = signInProviderRequestFailure(error, connect: false);
            setState(() {
              loading = false;
              listFailure =
                  refused.failure ??
                  const SignInFailure(
                    'Check the details and try again.',
                    retryable: true,
                  );
            });
          },
        );
  }

  /// Every row of the list, in its two groups.
  List<_Choice> get accountRows => [
    for (final p in providers)
      for (final m in p.methods) _Choice(true, p, m),
  ];
  List<_Choice> get keyRows => [
    for (final p in providers)
      if (p.keyEntry != null) _Choice(false, p, null),
  ];

  _Choice? get chosen {
    final value = chosenValue;
    if (value == null) return null;
    for (final row in [...accountRows, ...keyRows]) {
      if (row.value == value) return row;
    }
    return null;
  }

  bool needsComputer(_Choice row) =>
      row.method!.flow == 'computer_only' ||
      isLoopbackRequired(
        widget.machineId,
        widget.runtime,
        row.provider.id,
        row.method!.label,
      );

  bool enabledRow(_Choice row) =>
      row.account ? !needsComputer(row) : row.provider.keyEntry == 'key';

  void continueChosen() {
    final row = chosen;
    if (row == null || !enabledRow(row)) return;
    setState(() {
      failure = null;
      keyRefusedByServer = false;
      apiKey.clear();
      step = row.account ? _Step.account : _Step.key;
    });
  }

  void back() => setState(() {
    failure = null;
    keyRefusedByServer = false;
    apiKey.clear();
    step = _Step.choose;
  });

  String get trimmedKey => apiKey.text.trim();

  /// Pi would run a key starting with ! as a command and fill in a $ name;
  /// OpenCode is not given an {env:} or {file:} reference: said at once,
  /// never sent.
  bool get keyRefusedHere =>
      trimmedKey.isNotEmpty &&
      !runtimeAuthLiteralApiKeyFits(widget.runtime, trimmedKey);

  void connect() {
    final row = chosen;
    if (row == null || row.account || trimmedKey.isEmpty || connecting) return;
    if (keyRefusedHere) return;
    setState(() {
      connecting = true;
      failure = null;
      keyRefusedByServer = false;
    });
    widget.client
        .connectProvider(widget.serverId, widget.machineId, widget.runtime, {
          'providerId': row.provider.id,
          'apiKey': trimmedKey,
        })
        .then<void>(
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
                return;
              }
              // OpenCode's key save waits for no sign-in: one running or
              // waiting on that Computer makes it busy.
              failure = result['kind'] == 'busy' && opencode
                  ? const SignInFailure(
                      'A sign-in is in progress on this Computer. Finish or cancel it, then try again.',
                      retryable: true,
                    )
                  : signInProviderResultFailure(result, connect: true);
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            final refused = signInProviderRequestFailure(error, connect: true);
            setState(() {
              connecting = false;
              if (refused.field) {
                keyRefusedByServer = true;
                refusedKey = apiKey.text;
              } else {
                failure = refused.failure;
              }
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final runtimeName = runtimeDisplayNameOf(widget.runtimeId);
    final computer =
        computerNameOf(widget.controller, widget.machineId) ??
        raftText(context, 'this Computer');
    final row = chosen;
    // An account: the sign-in view takes over, named after the provider's
    // sign-in.
    if (step == _Step.account && row != null && row.account) {
      final method = row.method!;
      return ComputerRuntimeSignInView(
        controller: widget.controller,
        client: widget.client,
        serverId: widget.serverId,
        machineId: widget.machineId,
        runtimeId: widget.runtimeId,
        runtime: widget.runtime,
        provider: SignInProvider(
          id: row.provider.id,
          // Pi's sign-in names its provider ("Anthropic (Claude Pro/Max)");
          // OpenCode's method does not.
          label: choosesMethod ? row.provider.label : method.label,
          paste: switch (method.flow) {
            'paste_address' => SignInPaste.address,
            'paste_code' => SignInPaste.code,
            _ => null,
          },
          oauthMethod: choosesMethod ? method.label : null,
        ),
      );
    }
    final values = {
      'runtime': row?.provider.label ?? runtimeName,
      'piRuntime': runtimeName,
      'computer': computer,
    };
    return SignInStepDialog(
      title: raftFormat(context, 'Add a provider to {runtime}', {
        'runtime': runtimeName,
      }),
      actions: _actions(context),
      children: _body(context, values),
    );
  }

  List<Widget> _body(BuildContext context, Map<String, Object?> values) {
    if (step == _Step.done) {
      return [
        RaftBanner(
          key: const ValueKey('pi-key-saved'),
          status: RaftBannerRecipeStatus.success,
          glyph: RaftGlyph.circleCheck,
          description: raftFormat(
            context,
            opencode
                ? 'Saved on this Computer. OpenCode checks the key when an agent uses {runtime}.'
                : 'Saved on this Computer. Pi checks the key when an agent uses {runtime}.',
            values,
          ),
        ),
      ];
    }
    if (loading) {
      return [
        signInStatusLine(
          context,
          raftFormat(context, 'Reading the providers on {computer}…', values),
          key: const ValueKey('pi-provider-loading'),
        ),
      ];
    }
    final listed = listFailure;
    if (listed != null) {
      return [
        RaftBanner(
          key: const ValueKey('pi-provider-list-failed'),
          status: RaftBannerRecipeStatus.warning,
          size: RaftBannerRecipeSize.sm,
          glyph: RaftGlyph.alertTriangle,
          description: raftFormat(context, listed.message, values),
        ),
      ];
    }
    if (step == _Step.key && chosen?.account == false) {
      return _keyForm(context, values);
    }
    return [_chooser(context, values)];
  }

  Widget _chooser(BuildContext context, Map<String, Object?> values) {
    final query = search.text.trim().toLowerCase();
    final prompt = raftFormat(
      context,
      'Choose a provider for {piRuntime} on {computer}. Sign in with your account, or paste an API key.',
      values,
    );
    final accounts = accountRows;
    final keys = keyRows;
    bool matches(_Choice row) {
      if (query.isEmpty) return true;
      final text = row.account
          ? '${row.method!.label} ${row.provider.label}'
          : '${row.provider.label} ${row.provider.keyLabel}';
      return text.toLowerCase().contains(query);
    }

    final shownAccounts = accounts.where(matches).toList();
    final shownKeys = keys.where(matches).toList();
    return Column(
      key: const ValueKey('pi-provider-choose'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x3,
      children: [
        signInHint(context, prompt),
        if (accounts.isNotEmpty || keys.isNotEmpty)
          RaftSearchInput(
            controller: search,
            focusNode: searchFocus,
            hint: raftText(context, 'Search providers'),
            clearLabel: raftText(context, 'Clear search'),
            onChanged: (_) => setState(() {}),
            onClear: () => setState(search.clear),
          ),
        if (accounts.isEmpty && keys.isEmpty)
          signInHint(
            context,
            raftFormat(
              context,
              '{runtime} on this Computer lists no providers.',
              values,
            ),
            key: const ValueKey('pi-provider-empty'),
          )
        else if (shownAccounts.isEmpty && shownKeys.isEmpty)
          signInHint(
            context,
            raftText(context, 'No matching providers'),
            key: const ValueKey('pi-provider-no-match'),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              child: RaftRadioGroup<String>(
                value: chosenValue,
                semanticLabel: prompt,
                onChanged: (value) => setState(() => chosenValue = value),
                spacing: 0,
                children: [
                  if (shownAccounts.isNotEmpty)
                    RaftDialogSectionEyebrow(
                      'Sign in with an account',
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  for (final row in shownAccounts) _row(context, row),
                  if (shownKeys.isNotEmpty)
                    RaftDialogSectionEyebrow(
                      'Use an API key',
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  for (final row in shownKeys) _row(context, row),
                ],
              ),
            ),
          ),
        signInHint(
          context,
          raftFormat(
            context,
            'Saved on this Computer for every {piRuntime} agent of this account, and for {piRuntime} run outside Raft.',
            values,
          ),
          caption: true,
        ),
      ],
    );
  }

  Widget _row(BuildContext context, _Choice row) {
    final t = RaftTokens.of(context);
    final provider = row.provider;
    final String label, how;
    if (row.account) {
      // A sign-in that ended as loopback_required on this Computer: greyed
      // out for the session.
      final computerOnly = needsComputer(row);
      how = computerOnly
          ? raftText(
              context,
              'Needs a browser on the Computer itself: sign in there',
            )
          : raftText(context, switch (row.method!.flow) {
              'device_code' => 'Sign in with a device code',
              'paste_code' => 'Sign in, then paste a code',
              'paste_address' => 'Sign in, then paste the page address',
              'link' => "Sign in on the provider's page",
              _ => 'Needs a browser on the Computer itself: sign in there',
            });
      // OpenCode's method labels ("Login with GitHub (device)") do not name
      // the provider.
      label = choosesMethod
          ? raftFormat(context, '{provider} · {method}', {
              'provider': provider.label,
              'method': row.method!.label,
            })
          : row.method!.label;
    } else {
      label = provider.label;
      how = switch (provider.keyEntry) {
        'more_fields' => raftText(
          context,
          'Asks for more than a key: set it up on the Computer',
        ),
        'outside' => raftText(
          context,
          opencode
              ? 'Set up outside OpenCode, on the Computer'
              : 'Set up outside Pi, on the Computer',
        ),
        _ => '',
      };
    }
    final signedIn = provider.stored == (row.account ? 'oauth' : 'api_key');
    final muted = t.colors['foreground-muted'] ?? t.muted;
    final enabled = enabledRow(row);
    return RaftRadioGroupItem<String>(
      key: ValueKey('pi-choice-${row.value}'),
      value: row.value,
      enabled: enabled,
      minHeight: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: RaftTypography.body(
              t,
              size: 14,
              line: 20,
              color: t.strong,
              weight: FontWeight.w600,
            ),
          ),
          if (how.isNotEmpty)
            Text(
              how,
              style: RaftTypography.body(
                t,
                size: 12,
                line: 12 * 1.5,
                color: muted,
              ),
            ),
          if (signedIn)
            Text(
              raftText(context, 'Signed in on this Computer'),
              key: ValueKey('pi-provider-signed-in-${provider.id}'),
              style: RaftTypography.body(
                t,
                size: 12,
                line: 12 * 1.5,
                color: t.colors['success-strong'] ?? muted,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _keyForm(BuildContext context, Map<String, Object?> values) {
    final row = chosen!;
    final refused = raftText(
      context,
      opencode
          ? "OpenCode can't take this as a key. Paste the key itself, not a reference to an environment variable or a file."
          : 'Pi would run a key that starts with ! or fill in a \$ name. Paste the key itself.',
    );
    return [
      Text(
        raftFormat(context, 'API key · {provider}', {
          'provider': row.provider.label,
        }),
        key: const ValueKey('pi-key-provider'),
        style: RaftTypography.body(
          RaftTokens.of(context),
          size: 14,
          line: 14 * 1.625,
          color: RaftTokens.of(context).strong,
        ),
      ),
      ListenableBuilder(
        listenable: apiKey,
        builder: (context, _) {
          final invalid = keyRefusedHere || keyRefusedByServer;
          return RaftProductFormField(
            label: raftText(context, 'API key'),
            required: true,
            hint: invalid
                ? null
                : raftFormat(
                    context,
                    'Find it in your {provider} account settings.',
                    {'provider': row.provider.label},
                  ),
            error: !invalid
                ? null
                : keyRefusedHere
                ? refused
                : raftText(context, 'Paste the whole API key, with no spaces.'),
            child: RaftDialogTextInput(
              fieldKey: const ValueKey('pi-key-input'),
              controller: apiKey,
              obscure: true,
              mono: true,
              enabled: !connecting,
              onSubmitted: (_) => connect(),
            ),
          );
        },
      ),
      signInHint(
        context,
        raftFormat(
          context,
          'Saved on this Computer for every {piRuntime} agent of this account, and for {piRuntime} run outside Raft.',
          values,
        ),
        key: const ValueKey('pi-scope'),
        caption: true,
      ),
      if (failure != null)
        RaftBanner(
          key: const ValueKey('pi-key-failed'),
          status: RaftBannerRecipeStatus.warning,
          size: RaftBannerRecipeSize.sm,
          glyph: RaftGlyph.alertTriangle,
          description: raftFormat(context, failure!.message, values),
        ),
    ];
  }

  List<Widget> _actions(BuildContext context) {
    void close() => Navigator.of(context).pop();
    if (step == _Step.done) {
      return [
        signInCommit(
          context,
          key: const ValueKey('pi-sign-in-done'),
          label: raftText(context, 'Done'),
          onPressed: close,
        ),
      ];
    }
    if (listFailure != null) {
      return [
        signInGhost(
          context,
          key: const ValueKey('pi-sign-in-close'),
          label: raftText(context, 'Close'),
          onPressed: close,
        ),
        if (listFailure!.retryable)
          signInCommit(
            context,
            key: const ValueKey('pi-sign-in-retry'),
            label: raftText(context, 'Try again'),
            onPressed: loadProviders,
          ),
      ];
    }
    if (step == _Step.key && chosen?.account == false) {
      return [
        signInGhost(
          context,
          key: const ValueKey('pi-sign-in-back'),
          label: raftText(context, 'Back'),
          onPressed: connecting ? null : back,
        ),
        ListenableBuilder(
          listenable: apiKey,
          builder: (context, _) => signInCommit(
            context,
            key: const ValueKey('pi-key-connect'),
            label: raftText(context, 'Connect'),
            busy: connecting,
            loadingLabel: raftText(context, 'Connecting'),
            onPressed: trimmedKey.isEmpty || keyRefusedHere ? null : connect,
          ),
        ),
      ];
    }
    final row = chosen;
    return [
      signInGhost(
        context,
        key: const ValueKey('pi-sign-in-cancel'),
        label: raftText(context, 'Cancel'),
        onPressed: close,
      ),
      if (!loading)
        signInCommit(
          context,
          key: const ValueKey('pi-sign-in-continue'),
          label: raftText(context, 'Continue'),
          onPressed: row == null || !enabledRow(row) ? null : continueChosen,
        ),
    ];
  }
}
