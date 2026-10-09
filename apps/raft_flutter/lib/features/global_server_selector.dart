import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

/// Mounted Source ServerSelector.tsx. The app root owns authorized discovery,
/// selection, creation and stale-result fences; this page owns only form input.
class GlobalServerSelector extends StatefulWidget {
  const GlobalServerSelector({
    super.key,
    required this.servers,
    required this.user,
    required this.loading,
    required this.onSelect,
    required this.onCreate,
    required this.onLogout,
    required this.onRetry,
    this.error,
  });
  final List<RaftRecord> servers;
  final RaftRecord user;
  final bool loading;
  final String? error;
  final Future<void> Function(RaftRecord) onSelect;
  final Future<void> Function(String, String) onCreate;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRetry;
  @override
  State<GlobalServerSelector> createState() => _GlobalServerSelectorState();
}

class _GlobalServerSelectorState extends State<GlobalServerSelector> {
  final name = TextEditingController(), slug = TextEditingController();
  final form = GlobalKey<FormState>();
  bool creating = false, slugTouched = false;
  @override
  void dispose() {
    name.dispose();
    slug.dispose();
    super.dispose();
  }

  String toSlug(String value) =>
      value.toLowerCase().replaceAll(RegExp('[^a-z0-9-]'), '-');
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String value) => raftText(context, value);
    if (widget.loading && widget.servers.isEmpty) {
      // App.tsx ServerRedirect/ServerSelectionPage owns this undecided state;
      // ServerSelector's first-server form is not mounted while it is loading.
      return Material(
        color: t.canvas,
        child: SafeArea(
          child: Center(
            child: Text(
              tr('Loading servers…'),
              style: RaftTypography.heading(t, size: 20, line: 28),
            ),
          ),
        ),
      );
    }
    if (widget.error != null && widget.servers.isEmpty && !creating) {
      return RaftAuthShell(
        child: Column(
          children: [
            RaftAuthBanner(text: widget.error!),
            const SizedBox(height: 12),
            RaftAuthSubmit(
              label: tr('Retry'),
              onPressed: widget.loading ? null : widget.onRetry,
            ),
          ],
        ),
      );
    }
    final first = widget.servers.isEmpty;
    final create = first || creating;
    return RaftAuthShell(
      child: Column(
        key: const ValueKey('global-server-selector'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftAuthIntro(
            title: tr(
              create
                  ? (first ? 'Create your first server' : 'Create server')
                  : 'Choose server',
            ),
            description: create
                ? null
                : '${tr('Signed in as')} ${widget.user.string('email')}',
          ),
          if (widget.error != null) ...[
            RaftAuthBanner(text: widget.error!),
            const SizedBox(height: 12),
          ],
          if (create)
            Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RaftAuthField(
                    label: tr('Server name'),
                    child: TextFormField(
                      key: const ValueKey('global-server-name'),
                      controller: name,
                      autofocus: true,
                      enabled: !widget.loading,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'My team',
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? tr('Required')
                          : null,
                      onChanged: (value) {
                        if (!slugTouched) slug.text = toSlug(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  RaftAuthField(
                    label: tr('URL slug'),
                    child: TextFormField(
                      key: const ValueKey('global-server-slug'),
                      controller: slug,
                      enabled: !widget.loading,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'my-team',
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? tr('Required')
                          : null,
                      onChanged: (value) {
                        slugTouched = true;
                        final normalized = toSlug(value);
                        if (normalized != value) {
                          slug.value = TextEditingValue(
                            text: normalized,
                            selection: TextSelection.collapsed(
                              offset: normalized.length,
                            ),
                          );
                        }
                      },
                      onFieldSubmitted: (_) {
                        if (!widget.loading && form.currentState!.validate()) {
                          widget.onCreate(name.text, slug.text);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (!first) ...[
                        Expanded(
                          child: RaftAuthWideButton(
                            variant: RaftControlVariant.outline,
                            onPressed: widget.loading
                                ? null
                                : () => setState(() {
                                    creating = false;
                                    name.clear();
                                    slug.clear();
                                    slugTouched = false;
                                  }),
                            child: Text(tr('Cancel')),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: RaftAuthSubmit(
                          label: tr('Create server'),
                          onPressed: widget.loading
                              ? null
                              : () {
                                  if (form.currentState!.validate()) {
                                    widget.onCreate(name.text, slug.text);
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else ...[
            for (final server in widget.servers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RaftInteractive(
                  key: ValueKey('global-server-${server.id}'),
                  onPressed: widget.loading
                      ? null
                      : () => widget.onSelect(server),
                  semanticLabel: server.string('name'),
                  builder: (context, state) => RaftRecipeBox(
                    style: RaftCardRecipe.resolve(
                      theme: t.recipeTheme,
                      variant: RaftCardRecipeVariant.option,
                      states: t.recipeStates(
                        hovered: state.hovered,
                        pressed: state.pressed,
                        focusVisible: state.focusVisible,
                        disabled: !state.enabled,
                      ),
                      tokens: t.recipeTokens,
                    ).root,
                    tokens: t.recipeTokens,
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            server.string('name'),
                            style: RaftTypography.heading(
                              t,
                              size: 16,
                              line: 24,
                            ),
                          ),
                          Text(
                            '/${server.string('slug')}',
                            style: RaftTypography.heading(
                              t,
                              size: 14,
                              line: 20,
                              weight: FontWeight.w400,
                            ).copyWith(color: t.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            RaftAuthSubmit(
              label: tr('+ Create New Server'),
              onPressed: widget.loading
                  ? null
                  : () => setState(() => creating = true),
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: RaftAuthTextLink(
              label: tr('Log out'),
              onTap: widget.onLogout,
            ),
          ),
        ],
      ),
    );
  }
}
