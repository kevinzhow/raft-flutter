import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'artifact_dashboard_data.dart';
import 'artifact_text.dart';

class ArtifactDashboardFilter extends StatefulWidget {
  const ArtifactDashboardFilter({
    super.key,
    required this.api,
    required this.authors,
    required this.onSelected,
    this.selection,
    this.serverName,
    this.labelHidden = false,
  });

  final ArtifactDashboardApi api;
  final bool authors, labelHidden;
  final ArtifactDashboardPlace? selection;
  final String? serverName;
  final ValueChanged<ArtifactDashboardPlace?> onSelected;

  @override
  State<ArtifactDashboardFilter> createState() =>
      _ArtifactDashboardFilterState();
}

class _ArtifactDashboardFilterState extends State<ArtifactDashboardFilter> {
  final menu = MenuController();
  final anchor = GlobalKey();
  final focus = FocusNode();
  final conversationChoices = _ConversationChoiceCache();

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;
    final label =
        selection?.label ??
        raftText(context, widget.authors ? 'Author' : 'By conversation');
    return RaftPopoverAnchor(
      controller: menu,
      anchorKey: anchor,
      collisionPadding: widget.authors ? RaftSpace.x4 : RaftSpace.x2,
      // ArtifactFilterCombobox fixes the vertical side and shifts horizontally.
      flipVertically: widget.authors,
      scrollChild: widget.authors,
      childFocusNode: focus,
      builder: (_, controller, _) => Row(
        key: anchor,
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftPickerTriggerButton(
            key: ValueKey(
              widget.authors
                  ? 'artifacts-filter-author'
                  : 'artifacts-filter-conversation',
            ),
            label: label,
            labelHidden: widget.labelHidden && selection == null,
            trailingGlyph: selection == null ? RaftGlyph.chevronDown : null,
            inlineIndicator: true,
            tooltip: widget.labelHidden ? label : null,
            glyph: widget.authors
                ? RaftGlyph.userRound
                : RaftGlyph.directMessage,
            selected: selection != null,
            focusNode: focus,
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
          if (selection != null)
            RaftButton(
              glyph: RaftGlyph.x,
              semanticLabel: raftText(
                context,
                widget.authors ? 'Clear author' : 'Clear conversation',
              ),
              size: RaftButtonRecipeSize.iconMd,
              tone: RaftButtonRecipeVariant.ghost,
              onPressed: () => widget.onSelected(null),
            ),
        ],
      ),
      popup: _ArtifactFilterOptions(
        api: widget.api,
        authors: widget.authors,
        conversationChoices: widget.authors ? null : conversationChoices,
        selection: selection,
        serverName: widget.serverName,
        close: menu.close,
        onSelected: (choice) {
          menu.close();
          widget.onSelected(choice);
        },
      ),
    );
  }
}

class _ConversationChoiceCache {
  List<ArtifactDashboardChoice> base = const [];
  List<ArtifactDashboardChoice> last = const [];
  bool missing = false;

  void save(String query, List<ArtifactDashboardChoice> choices) {
    last = choices;
    if (query.isEmpty) base = choices;
  }

  Iterable<ArtifactDashboardChoice> matching(String query) {
    final bare = query.startsWith('#') ? query.substring(1) : query;
    final known = {
      for (final choice in last) choice.id: choice,
      for (final choice in base) choice.id: choice,
    };
    return known.values.where(
      (choice) =>
          choice.name.toLowerCase().contains(bare) ||
          choice.peerDisplayName.toLowerCase().contains(bare),
    );
  }
}

class _ArtifactFilterOptions extends StatefulWidget {
  const _ArtifactFilterOptions({
    required this.api,
    required this.authors,
    required this.conversationChoices,
    required this.selection,
    required this.serverName,
    required this.close,
    required this.onSelected,
  });

  final ArtifactDashboardApi api;
  final bool authors;
  final _ConversationChoiceCache? conversationChoices;
  final ArtifactDashboardPlace? selection;
  final String? serverName;
  final VoidCallback close;
  final ValueChanged<ArtifactDashboardPlace> onSelected;

  @override
  State<_ArtifactFilterOptions> createState() => _ArtifactFilterOptionsState();
}

class _ArtifactFilterOptionsState extends State<_ArtifactFilterOptions> {
  final combobox = RaftComboboxController();
  final inputFocus = FocusNode();
  final popupFocus = FocusNode();
  Timer? debounce;
  int attempt = 0;
  String query = '';
  List<ArtifactDashboardChoice>? choices;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    failed = widget.conversationChoices?.missing == true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (RaftInteraction.of(context).pointer) {
        inputFocus.requestFocus();
      } else {
        popupFocus.requestFocus();
      }
    });
    unawaited(read());
  }

  @override
  void dispose() {
    debounce?.cancel();
    inputFocus.dispose();
    popupFocus.dispose();
    combobox.dispose();
    super.dispose();
  }

  Future<void> read({bool retry = false}) async {
    debounce?.cancel();
    final current = ++attempt;
    final cache = widget.conversationChoices;
    if (cache?.missing == true && !retry) return;
    final search = query;
    if (cache == null || retry) {
      setState(() {
        choices = null;
        failed = false;
        if (cache != null) cache.missing = false;
      });
    }
    try {
      final next = await widget.api.choices(search, authors: widget.authors);
      if (!mounted || current != attempt) return;
      setState(() {
        choices = next;
        cache?.save(search, next);
      });
    } catch (error) {
      if (!mounted || current != attempt) return;
      setState(() {
        failed = true;
        if (cache != null) {
          cache.missing = error is RaftApiException && error.status == 404;
        }
      });
    }
  }

  void queryChanged(String text) {
    final cache = widget.conversationChoices;
    final next = text.trim();
    if (cache != null && next == query) return;
    query = next;
    ++attempt;
    debounce?.cancel();
    setState(() {
      if (cache != null) {
        choices = null;
        failed = cache.missing;
      }
    });
    if (cache?.missing == true) return;
    debounce = Timer(
      Duration(milliseconds: cache == null ? 300 : 250),
      () => unawaited(read()),
    );
  }

  Widget _mark(
    BuildContext context,
    ArtifactDashboardPlace row,
    ArtifactDashboardChoice? choice,
  ) {
    if (choice?.actor case final actor?) {
      return RaftAvatar(
        name: artifactActorName(context, actor),
        imageUrl: actor.avatarUrl,
        kind: actor.type == 'agent'
            ? RaftAvatarKind.agent
            : RaftAvatarKind.human,
        uiSize: RaftAvatarSize.xxxs,
      );
    }
    final glyph = switch (choice?.kind) {
      'private' => RaftGlyph.lock,
      'dm' => RaftGlyph.directMessage,
      _ when row.home => row.id == 'public' ? RaftGlyph.globe : RaftGlyph.users,
      _ => RaftGlyph.hash,
    };
    return RaftIcon(glyph, size: RaftSpace.x4);
  }

  @override
  Widget build(BuildContext context) {
    String tr(String value) => raftText(context, value);
    final t = RaftTokens.of(context);
    final authors = widget.authors;
    final server = widget.serverName;
    final lowerQuery = query.toLowerCase();
    final visible = choices ?? widget.conversationChoices?.matching(lowerQuery);
    final matches = {
      for (final choice in visible ?? const <ArtifactDashboardChoice>[])
        choice.id: choice,
    };
    final rows =
        <ArtifactDashboardPlace>[
              if (!authors) ...[
                (id: 'public', label: tr('Anyone with the link'), home: true),
                (
                  id: 'server',
                  label: server == null
                      ? tr('Everyone in this server')
                      : raftFormat(context, 'Everyone in {server}', {
                          'server': server,
                        }),
                  home: true,
                ),
              ],
              for (final item in matches.values)
                (id: item.id, label: item.label, home: false),
            ]
            .where(
              (row) =>
                  !row.home || row.label.toLowerCase().contains(lowerQuery),
            )
            .toList();
    final searchStyle = t.scale(RaftTypeScale.callout);
    return SizedBox(
      key: const Key('artifact-dashboard-filter'),
      width: authors
          ? RaftComboboxPanel.filterWidth
          : RaftComboboxPanel.filterWidthForViewport(
              MediaQuery.sizeOf(context).width,
            ),
      child: Focus(
        focusNode: popupFocus,
        onKeyEvent: (_, event) {
          final composing = combobox.query.value.composing;
          if (!authors &&
              rows.isEmpty &&
              (inputFocus.hasFocus || popupFocus.hasPrimaryFocus) &&
              (!composing.isValid || composing.isCollapsed) &&
              const SingleActivator(
                LogicalKeyboardKey.enter,
                includeRepeats: false,
              ).accepts(event, HardwareKeyboard.instance)) {
            widget.close();
            return KeyEventResult.handled;
          }
          return combobox.handleKey(event);
        },
        child: RaftComboboxPanel.items(
          label: tr(authors ? 'Author' : 'By conversation'),
          controller: combobox,
          currentId: widget.selection?.id,
          highlightFirst: true,
          filterLocally: false,
          separateGroups: !authors,
          emptyLabel: authors
              ? 'No one found'
              : choices == null
              ? null
              : 'No conversations found',
          input: RaftBareInput(
            style: searchStyle,
            hintStyle: searchStyle.copyWith(color: t.ui.foregroundHint),
            controller: combobox.query,
            focusNode: inputFocus,
            hintText: tr(
              authors ? 'Search people or agents' : 'Search channels and DMs',
            ),
            onChanged: queryChanged,
          ),
          footer: failed
              ? RaftButton(
                  label: tr('Try again'),
                  onPressed: () => unawaited(read(retry: true)),
                )
              : choices == null && (authors ? rows.isEmpty : matches.isEmpty)
              ? const RaftListRowSkeleton()
              : null,
          items: [
            for (final row in rows)
              RaftComboboxItem(
                row.id,
                row.label,
                group: authors
                    ? null
                    : tr(row.home ? 'Who can see it' : 'Channels & DMs'),
                leadingGap: RaftSpace.x1_5,
                leading: SizedBox.square(
                  dimension: RaftSpace.x4,
                  child: Center(child: _mark(context, row, matches[row.id])),
                ),
              ),
          ],
          onSelected: (id) {
            final choice = rows.where((row) => row.id == id).firstOrNull;
            if (choice != null) widget.onSelected(choice);
          },
          onDismiss: widget.close,
        ),
      ),
    );
  }
}
