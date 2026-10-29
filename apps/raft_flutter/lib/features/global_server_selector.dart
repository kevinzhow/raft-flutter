import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

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
  final slugField = GlobalKey<FormFieldState<String>>();
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
    String tr(String value) => raftText(context, value);
    if (widget.loading && widget.servers.isEmpty) {
      // App.tsx ServerRedirect/ServerSelectionPage owns this undecided state;
      // ServerSelector's first-server form is not mounted while it is loading.
      return RaftServerResolutionBody(label: 'Loading servers…');
    }
    if (widget.error != null && widget.servers.isEmpty && !creating) {
      return RaftAuthShell(
        child: Column(
          children: [
            RaftAuthBanner(text: widget.error!),
            const SizedBox(height: RaftSpace.x3),
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
    final serverField = FormField<String>(
      initialValue: name.text,
      validator: (value) =>
          value == null || value.isEmpty ? tr('Required') : null,
      builder: (field) => RaftAuthField(
        label: tr('Server name'),
        surface: false,
        helper: first
            ? tr('Shown in the sidebar, invites, and setup prompts.')
            : null,
        helperRecipe: first,
        error: field.errorText,
        child: RaftTextInput(
          key: const ValueKey('global-server-name'),
          controller: name,
          autofocus: true,
          enabled: !widget.loading,
          invalid: field.hasError,
          hintText: first ? 'Alex Chen Studio' : tr('My Team'),
          semanticLabel: tr('Server name'),
          onChanged: (value) {
            field.didChange(value);
            if (!slugTouched) {
              slug.text = toSlug(value);
              slugField.currentState?.didChange(slug.text);
            }
            setState(() {});
          },
        ),
      ),
    );
    final urlField = FormField<String>(
      key: slugField,
      initialValue: slug.text,
      validator: (value) =>
          value == null || value.isEmpty ? tr('Required') : null,
      builder: (field) => RaftAuthField(
        label: tr(first ? 'Server URL' : 'URL slug'),
        surface: false,
        helper: first
            ? tr(
                'Used in links and setup commands. You can edit this before creating.',
              )
            : null,
        helperRecipe: first,
        error: field.errorText,
        child: RaftSlugInput(
          key: const ValueKey('global-server-slug'),
          controller: slug,
          enabled: !widget.loading,
          invalid: field.hasError,
          hintText: first ? 'alex-chen-studio' : 'my-team',
          semanticLabel: tr(first ? 'Server URL' : 'URL slug'),
          onChanged: (value) {
            slugTouched = true;
            final normalized = toSlug(value);
            field.didChange(normalized);
            setState(() {});
            if (normalized != value) {
              slug.value = TextEditingValue(
                text: normalized,
                selection: TextSelection.collapsed(offset: normalized.length),
              );
            }
          },
          onSubmitted: (_) {
            if (!widget.loading && form.currentState!.validate()) {
              widget.onCreate(name.text, slug.text);
            }
          },
        ),
      ),
    );
    void submit() {
      if (!widget.loading && form.currentState!.validate()) {
        widget.onCreate(name.text, slug.text);
      }
    }

    if (first) {
      // OnboardingCreateShell (narrow): brand bar, then the form column
      // `flex w-full max-w-md flex-col gap-4` with the session footer.
      return RaftOnboardingShell(
        preview: RaftServerCreatePreview(
          serverName: name.text,
          serverSlug: slug.text,
        ),
        child: Column(
          key: const ValueKey('global-server-selector'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftOnboardingHeading(
              eyebrow: tr('Create your first server'),
              title: tr('Name the server where your agents will work.'),
              description: tr(
                'A server is the workspace for your people, agents, channels, and computers.',
              ),
            ),
            const SizedBox(height: RaftSpace.x4),
            Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.error != null) ...[
                    RaftAuthBanner(text: widget.error!),
                    const SizedBox(height: RaftSpace.x3),
                  ],
                  serverField,
                  const SizedBox(height: RaftSpace.x3), // gap-3
                  urlField,
                  const SizedBox(height: RaftSpace.x3),
                  RaftAuthSubmit(
                    key: const ValueKey('global-server-create-submit'),
                    label: tr('Create Server'),
                    onPressed: widget.loading ? null : submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: RaftSpace.x4),
            RaftAuthSessionFooter(
              name: widget.user.string('email'),
              onSignOut: widget.onLogout,
            ),
          ],
        ),
      );
    }
    return RaftAuthShell(
      child: Column(
        key: const ValueKey('global-server-selector'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftAuthIntro(
            title: tr(create ? 'Create Server' : 'Choose server'),
            descriptionSpan: create
                ? null
                : raftAuthSignedInAsSpan(context, widget.user.string('email')),
          ),
          if (create)
            Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.error != null) ...[
                    RaftAuthBanner(text: widget.error!),
                    const SizedBox(height: RaftSpace.x3),
                  ],
                  serverField,
                  const SizedBox(height: RaftSpace.x3), // space-y-3
                  urlField,
                  const SizedBox(height: RaftSpace.x4), // space-y-3 + pt-1
                  Row(
                    children: [
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
                          label: tr('Cancel'),
                        ),
                      ),
                      const SizedBox(width: RaftSpace.x2),
                      Expanded(
                        child: RaftAuthSubmit(
                          key: const ValueKey('global-server-create-submit'),
                          label: tr('Create Server'),
                          onPressed: widget.loading ? null : submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else ...[
            if (widget.servers.isNotEmpty) ...[
              if (RaftTokens.of(context).isRaftLook)
                RaftListRowGroup(
                  key: const ValueKey('server-selector-list'),
                  children: [
                    for (final server in widget.servers)
                      _serverListRow(
                        server: server,
                        onPressed: widget.loading
                            ? null
                            : () => widget.onSelect(server),
                      ),
                  ],
                )
              else
                Column(
                  key: const ValueKey('server-selector-list'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, server) in widget.servers.indexed) ...[
                      if (i > 0) const SizedBox(height: RaftSpace.x2),
                      _ServerOption(
                        server: server,
                        onPressed: widget.loading
                            ? null
                            : () => widget.onSelect(server),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: RaftSpace.x6), // mb-6
            ],
            if (widget.error != null) ...[
              RaftAuthBanner(text: widget.error!),
              const SizedBox(height: RaftSpace.x3), // mb-3
            ],
            RaftAuthSubmit(
              key: const ValueKey('global-server-create-new'),
              label: tr('+ Create New Server'),
              onPressed: widget.loading
                  ? null
                  : () => setState(() => creating = true),
            ),
          ],
          if (!create) ...[
            const SizedBox(height: RaftSpace.x3), // mt-3
            RaftAuthTextLink(
              label: tr('Log out'),
              bold: true,
              centeredLine: true,
              onTap: widget.onLogout,
            ),
          ],
        ],
      ),
    );
  }
}

// Current ServerOptionCard.tsx is a navigation ListRow, not an option card.
// Direct children let its canonical group own the inset surface and rules.
RaftListRow _serverListRow({
  required RaftRecord server,
  required VoidCallback? onPressed,
}) => RaftListRow(
  key: ValueKey('global-server-${server.id}'),
  onPressed: onPressed,
  disabled: onPressed == null,
  semanticLabel: server.string('name'),
  children: [
    ExcludeSemantics(
      child: RaftAvatarSlot(
        name: server.string('name'),
        slot: RaftAvatarSlotContext.surfaceList,
        agent: false,
        server: true,
        content: RaftAvatarContent(
          name: server.string('name'),
          kind: RaftAvatarContentKind.server,
          uploadedUrl: server.json['avatarUrl'] as String?,
        ),
      ),
    ),
    RaftListRowBody(
      children: [
        RaftListRowTitle(server.string('name')),
        RaftListRowMeta('/${server.string('slug')}'),
      ],
    ),
    const RaftListRowChevron(),
  ],
);

/// ServerSelector option: `Card variant="option" gap-0 p-3` with the server
/// name (`font-bold text-foreground-strong`) over `/slug` (`text-sm
/// font-normal text-foreground-muted`).
class _ServerOption extends StatelessWidget {
  const _ServerOption({required this.server, required this.onPressed});
  final RaftRecord server;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftCard(
      variant: RaftCardRecipeVariant.option,
      key: ValueKey('global-server-${server.id}'),
      onTap: onPressed,
      semanticLabel: server.string('name'),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              server.string('name'),
              style: RaftTypography.heading(t, size: 16, line: 24),
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
    );
  }
}
