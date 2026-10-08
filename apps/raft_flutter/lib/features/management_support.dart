import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_client/raft_client.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/workspace_controller.dart';

Map<String, dynamic> managementMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> managementRows(dynamic value) => value is List
    ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
    : [];
List<String> managementStrings(dynamic value) =>
    value is List ? value.whereType<String>().toList() : [];
String? managementHttpUrl(String value) {
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  return uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty
      ? null
      : 'Enter a complete HTTP or HTTPS address.';
}

Future<void> managementLaunch(String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw StateError('Could not open this address.');
  }
}

/// Management screens never write API payloads or one-time credentials to cache.
/// An account or workspace generation change invalidates every pending result.
abstract class ManagementState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver {
  WorkspaceController get w;
  bool loading = true, busy = false;
  String? error;
  int _request = 0;
  String? _authority;
  String? _operationAuthority;
  String get authority =>
      '${w.client.generation}|${w.client.user?.id}|${w.server?.id}|${w.server?.string("role")}';
  Future<void> loadData(int request, int generation);
  void clearData();
  void startManagement() {
    _authority = authority;
    WidgetsBinding.instance.addObserver(this);
    w.addListener(_workspaceChanged);
    reload();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  void _workspaceChanged() {
    if (_authority == authority) return;
    _authority = authority;
    _request++;
    clearData();
    if (mounted) {
      setState(() {
        error = null;
        loading = true;
      });
      reload();
    }
  }

  /// Reevaluate authority after a source event invalidates a page-specific scope.
  void refreshAuthority() => _workspaceChanged();

  Future<void> reload() async {
    final request = ++_request, generation = w.client.generation;
    try {
      await loadData(request, generation);
      if (!mounted ||
          request != _request ||
          generation != w.client.generation) {
        return;
      }
      setState(() {
        loading = false;
        error = null;
      });
    } catch (e) {
      if (mounted && request == _request && generation == w.client.generation) {
        if (e is RaftApiException && [401, 403].contains(e.status)) {
          clearData();
        }
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  /// A loader must check this before assigning results to its page projection.
  bool accepts(int generation, [int? request]) =>
      mounted &&
      generation == w.client.generation &&
      _authority == authority &&
      (request == null || request == _request);
  Future<void> run(
    Future<void> Function() action, {
    bool refresh = true,
  }) async {
    if (busy) return;
    final generation = w.client.generation, sourceAuthority = authority;
    _operationAuthority = sourceAuthority;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (accepts(generation) && authority == sourceAuthority && refresh) {
        await reload();
      }
    } catch (e) {
      if (accepts(generation) && authority == sourceAuthority) {
        invalidateDeniedMutation(e);
        setState(() => error = '$e');
      }
    } finally {
      _operationAuthority = null;
      if (mounted) setState(() => busy = false);
    }
  }

  bool invalidateDeniedMutation(Object error) {
    if (error is! RaftApiException || ![401, 403].contains(error.status)) {
      return false;
    }
    _request++;
    clearData();
    if (mounted) {
      setState(() {
        loading = false;
        this.error = '$error';
      });
    }
    return true;
  }

  Future<V?> scopedDialog<V>(Widget Function(BuildContext) builder) async {
    final sourceAuthority = _operationAuthority ?? authority;
    if (!mounted || sourceAuthority != authority) return null;
    BuildContext? routeContext;
    void dismissOnScopeChange() {
      if (sourceAuthority == authority) return;
      final current = routeContext;
      if (current != null && current.mounted) {
        final route = ModalRoute.of(current);
        if (route != null && route.isActive) {
          Navigator.of(current).removeRoute(route);
        }
      }
    }

    w.addListener(dismissOnScopeChange);
    try {
      return await showDialog<V>(
        context: context,
        builder: (context) {
          routeContext = context;
          if (sourceAuthority != authority) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              dismissOnScopeChange();
            });
            return const SizedBox.shrink();
          }
          return builder(context);
        },
      );
    } finally {
      w.removeListener(dismissOnScopeChange);
    }
  }

  Future<void> launchManaged(String value) async {
    if (!mounted ||
        (_operationAuthority != null && _operationAuthority != authority)) {
      return;
    }
    await managementLaunch(value);
  }

  Future<bool> form(
    String title,
    List<RaftFormField> fields,
    Future<void> Function(Map<String, String>) save, {
    String submit = 'Save',
    String? description,
    bool destructive = false,
  }) async {
    final generation = w.client.generation, sourceAuthority = authority;
    return await scopedDialog<bool>(
          (dialogContext) => RaftFormDialog(
            title: title,
            fields: fields,
            onSubmit: (values) async {
              if (!accepts(generation) || sourceAuthority != authority) {
                throw StateError(
                  'The active workspace changed. Reopen this form.',
                );
              }
              try {
                await save(values);
              } catch (e) {
                if (accepts(generation) &&
                    sourceAuthority == authority &&
                    invalidateDeniedMutation(e) &&
                    dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(false);
                }
                rethrow;
              }
            },
            submitLabel: submit,
            description: description,
            destructive: destructive,
          ),
        ) ==
        true;
  }

  Future<bool> confirm(
    String title,
    String description,
    Future<void> Function() save, {
    String submit = 'Confirm',
    bool destructive = false,
  }) => form(
    title,
    [],
    (_) => save(),
    submit: submit,
    description: description,
    destructive: destructive,
  );
  Future<void> secret(
    String value, {
    String label = 'One-time credential',
  }) async {
    if (!mounted) return;
    await scopedDialog<void>(
      (context) => AlertDialog(
        title: Text(raftText(context, label)),
        content: SizedBox(
          width: 480,
          child: RaftSecretView(
            value: value,
            label: 'Save this credential before closing.',
            onCopy: (value) => Clipboard.setData(ClipboardData(text: value)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(raftText(context, 'Close')),
          ),
        ],
      ),
    );
  }

  Widget page(
    String title,
    List<Widget> children, {
    List<Widget> actions = const [],
  }) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final titleWidget = Text(
              raftText(context, title),
              style: Theme.of(context).textTheme.headlineSmall,
            );
            final refresh = IconButton(
              onPressed: busy ? null : reload,
              tooltip: raftText(context, 'Refresh'),
              icon: const Icon(Icons.refresh),
            );
            if (constraints.maxWidth < 600) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: titleWidget),
                      refresh,
                    ],
                  ),
                  if (actions.isNotEmpty)
                    Wrap(spacing: 4, runSpacing: 4, children: actions),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: titleWidget),
                ...actions,
                refresh,
              ],
            );
          },
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      if (loading) const LinearProgressIndicator(),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: children),
      ),
    ],
  );
  Widget heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      raftText(context, title),
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );
  Widget action(String label, VoidCallback? callback, {IconData? icon}) =>
      TextButton.icon(
        onPressed: busy ? null : callback,
        icon: Icon(icon ?? Icons.chevron_right),
        label: Text(raftText(context, label)),
      );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    w.removeListener(_workspaceChanged);
    _request++;
    super.dispose();
  }
}
