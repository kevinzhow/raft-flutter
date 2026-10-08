// Web ForwardComposerDialog on a narrow viewport (< md) renders
// ForwardComposerMobile: a full-screen "Select destinations" page (Recent
// targets from the channel + DM stores, search), then an "Add a note" page
// with the forwarded-bundle preview and the note composer.
// Source: packages/web/src/components/message/ForwardComposerMobile.tsx,
// ForwardComposerTargetList.tsx, forwardComposerModel.tsx.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

import '../data/workspace_controller.dart';
import 'forward_messages_dialog.dart';
import 'private_route_guard.dart';

/// One destination: a local channel/DM (`localTarget`) or a search row.
class _Destination {
  _Destination({
    required this.key,
    required this.label,
    this.channel,
    this.search,
  });
  final String key, label;
  final RaftChannel? channel;
  final Map<String, dynamic>? search;
  String? get channelId =>
      channel?.id ??
      (search?['channelId'] is String ? search!['channelId'] : null);
}

/// `targetLabel`: `@peer` for DMs, `#name` otherwise.
String forwardTargetLabel(RaftChannel c) {
  if (c.type == 'dm') {
    final peer = c.json['peerDisplayName'] ?? c.json['peerName'] ?? c.name;
    return '@$peer';
  }
  return '#${c.name}';
}

/// `targetPickerLabel`: DMs keep `@peer`, channels show the bare name.
String forwardTargetPickerLabel(RaftChannel c) =>
    c.type == 'dm' ? forwardTargetLabel(c) : c.name;

/// Approximates `localeCompare(..., {sensitivity: "base", numeric: true})`
/// under the ICU root collation used by Chromium: case-insensitive, ASCII
/// punctuation ordered before digits before letters, `@` before `#`.
int forwardLabelCompare(String a, String b) {
  const punctuation = "_-,;:!?.'\"()[]{}@*/\\&#%`^+<=>|~\$";
  int rank(int code) {
    final ch = String.fromCharCode(code);
    final p = punctuation.indexOf(ch);
    if (p >= 0) return p;
    if (code >= 48 && code <= 57) return 100 + code - 48;
    final lower = ch.toLowerCase().codeUnitAt(0);
    if (lower >= 97 && lower <= 122) return 200 + lower - 97;
    return 1000 + lower;
  }

  final x = a.codeUnits, y = b.codeUnits;
  for (var i = 0; i < x.length && i < y.length; i++) {
    final d = rank(x[i]) - rank(y[i]);
    if (d != 0) return d;
  }
  return x.length - y.length;
}

/// `getForwardTargets` with an empty query: channels then DMs, most recent
/// activity first, ties by label.
List<RaftChannel> forwardRecentTargets(
  List<RaftChannel> channels,
  List<RaftChannel> dms,
) {
  int time(RaftChannel c) =>
      DateTime.tryParse(
        '${c.json['lastMessageAt'] ?? c.json['createdAt'] ?? ''}',
      )?.millisecondsSinceEpoch ??
      0;
  bool forwardable(RaftChannel c) {
    if (c.archived || c.type == 'thread') return false;
    if (c.type == 'dm') return true;
    return c.joined;
  }

  final all = [...channels, ...dms].where(forwardable).toList();
  all.sort((a, b) {
    final t = time(b) - time(a);
    if (t != 0) return t;
    final l = forwardLabelCompare(forwardTargetLabel(a), forwardTargetLabel(b));
    return l != 0 ? l : a.id.compareTo(b.id);
  });
  return all;
}

Future<bool> showForwardComposerPage(
  BuildContext context,
  WorkspaceController controller,
  List<RaftMessage> messages,
) async =>
    await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) =>
            ForwardComposerPage(controller: controller, messages: messages),
      ),
    ) ??
    false;

class ForwardComposerPage extends StatefulWidget {
  const ForwardComposerPage({
    super.key,
    required this.controller,
    required this.messages,
  });
  final WorkspaceController controller;
  final List<RaftMessage> messages;
  @override
  State<ForwardComposerPage> createState() => _ForwardComposerPageState();
}

class _ForwardComposerPageState extends State<ForwardComposerPage> {
  WorkspaceController get w => widget.controller;
  final search = TextEditingController(), note = TextEditingController();
  final searchFocus = FocusNode();
  final selected = <String, _Destination>{};
  List<Map<String, dynamic>> results = [];
  late final String authority;
  Timer? debounce;
  int request = 0;
  bool multi = false, preview = false, loading = false, failed = false;
  bool busy = false;
  String? error;
  ForwardAttempt? attempt;
  bool get current => mounted && authority == workspaceAuthority(w);

  @override
  void initState() {
    super.initState();
    authority = workspaceAuthority(w);
    w.addListener(authorityChanged);
  }

  void authorityChanged() {
    if (authority == workspaceAuthority(w)) return;
    ++request;
    debounce?.cancel();
    if (mounted && ModalRoute.of(context)?.isActive == true) {
      Navigator.of(context).removeRoute(ModalRoute.of(context)!);
    }
  }

  @override
  void dispose() {
    ++request;
    debounce?.cancel();
    w.removeListener(authorityChanged);
    search.dispose();
    note.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  String get sourceLabel {
    final source = w.channels
        .followedBy(w.dms)
        .where((c) => c.id == widget.messages.first.channelId)
        .firstOrNull;
    return source == null
        ? ''
        : source.type == 'dm' || source.type == 'thread'
        ? forwardTargetLabel(source)
        : '#${source.name}';
  }

  void changedSearch(String value) {
    ++request;
    debounce?.cancel();
    final query = value.trim();
    setState(() {
      results = [];
      failed = false;
      loading = query.isNotEmpty;
    });
    if (query.isNotEmpty) {
      debounce = Timer(const Duration(milliseconds: 250), () => load(query));
    }
  }

  Future<void> load(String query) async {
    final ticket = ++request;
    try {
      final value = await w.query(
        '/messages/forward/targets/search',
        query: {'q': query, 'limit': 20},
      );
      if (!current || ticket != request) return;
      setState(() {
        results = (value['targets'] as List)
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        loading = false;
      });
    } catch (_) {
      if (!current || ticket != request) return;
      setState(() {
        loading = false;
        failed = true;
      });
    }
  }

  void choose(_Destination d) {
    if (busy) return;
    setState(() {
      if (multi) {
        if (selected.remove(d.key) == null && selected.length < 10) {
          selected[d.key] = d;
        }
      } else {
        selected
          ..clear()
          ..[d.key] = d;
        preview = true;
      }
    });
  }

  /// Joins / opens a DM for search rows that need it, then forwards.
  Future<void> send() async {
    if (!current || busy || selected.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      for (final d in selected.values) {
        final target = d.search;
        if (target == null ||
            d.channelId != null && target['requiredAction'] == null) {
          continue;
        }
        if (target['requiredAction'] == 'join_channel' &&
            target['channelId'] is String) {
          await w.command('POST', '/channels/${target['channelId']}/join');
        } else if (target['requiredAction'] == 'create_dm') {
          final created = await w.command(
            'POST',
            '/channels/dm',
            data: {
              target['type'] == 'agent' ? 'agentId' : 'userId': target['id'],
            },
          );
          if (created is Map && created['id'] is String) {
            target['channelId'] = created['id'];
          }
        }
      }
      final destinations = [
        for (final d in selected.values)
          if (d.channelId != null) d.channelId!,
      ];
      attempt ??= ForwardAttempt(
        requestId: w.client.newRandomId(),
        sources: widget.messages.map((m) => m.id).toList(),
        destinations: destinations,
        note: note.text,
      );
      final response = await w.command(
        'POST',
        '/messages/forward',
        data: attempt!.payload,
      );
      if (!current || !mounted) return;
      attempt!.apply(response);
      if (attempt!.completed) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(
        () => error = raftText(
          context,
          "We couldn't confirm whether the forward finished. It's safe to try again.",
        ),
      );
    } catch (e) {
      if (current) setState(() => error = '$e');
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && preview && !busy) setState(() => preview = false);
      },
      child: Material(
        // `bg-layer-canvas text-foreground-strong`.
        color: t.colors['layer-canvas'],
        child: SafeArea(child: preview ? previewStep(t) : targetsStep(t)),
      ),
    );
  }

  /// `flex min-h-14 items-center gap-3 border-b px-3 py-2`, brutal
  /// `border-b-2 border-black`, elegant `border-line-hairline`.
  Widget header(
    RaftTokens t, {
    required Widget leading,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) => Container(
    constraints: const BoxConstraints(minHeight: 56),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      border: Border(
        bottom: t.brutal
            ? const BorderSide(color: Colors.black, width: 2)
            : BorderSide(color: t.colors['line-hairline']!),
      ),
    ),
    child: Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: t.headingFont,
                  fontSize: 16,
                  height: 24 / 16,
                  fontWeight: FontWeight.w700,
                  color: t.strong,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: t.monoFont,
                  fontSize: 12,
                  height: 16 / 12,
                  color: t.colors['foreground-muted'],
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing],
      ],
    ),
  );

  Widget targetsStep(RaftTokens t) {
    final selectedFrom = raftFormat(context, '{count} selected from {source}', {
      'count': widget.messages.length,
      'source': sourceLabel,
    });
    final query = search.text.trim();
    final rows = query.isEmpty
        ? [
            for (final c in forwardRecentTargets(w.channels, w.dms))
              localRow(t, c),
          ]
        : searchRows(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header(
          t,
          leading: multi
              ? RaftIconButton(
                  glyph: RaftGlyph.undo2,
                  visualSize: 28,
                  minimumTargetSize: 28,
                  glyphSize: 14,
                  variant: RaftControlVariant.outline,
                  tooltip: 'Cancel',
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          selected.clear();
                          multi = false;
                        }),
                )
              : RaftIconButton(
                  glyph: RaftGlyph.arrowLeft,
                  visualSize: 28,
                  minimumTargetSize: 28,
                  glyphSize: 14,
                  variant: RaftControlVariant.outline,
                  tooltip: 'Close forward target selection',
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
          title: raftText(context, 'Select destinations'),
          subtitle: selectedFrom,
          trailing: multi
              ? RaftIconButton(
                  glyph: RaftGlyph.check,
                  visualSize: 28,
                  minimumTargetSize: 28,
                  glyphSize: 14,
                  variant: RaftControlVariant.accent,
                  tooltip: 'Done',
                  onPressed: selected.isEmpty || busy
                      ? null
                      : () => setState(() => preview = true),
                )
              // raft-ui `Button size=sm variant=outline` (h-7 px-2.5).
              : RaftControl(
                  variant: RaftControlVariant.outline,
                  visualHeight: 28,
                  minimumTargetSize: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  onPressed: () => setState(() {
                    selected.clear();
                    multi = true;
                  }),
                  child: Text(raftText(context, 'Select multiple')),
                ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ForwardSearchInput(
                    controller: search,
                    focusNode: searchFocus,
                    placeholder: raftText(context, 'Search targets'),
                    onChanged: changedSearch,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    height: 24,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            multi
                                ? raftFormat(context, '{count} selected', {
                                    'count': selected.length,
                                  })
                                : raftText(context, 'Recent'),
                            style: TextStyle(
                              fontFamily: t.headingFont,
                              fontSize: 12,
                              height: 16 / 12,
                              fontWeight: FontWeight.w700,
                              color: t.strong,
                            ),
                          ),
                        ),
                        if (multi && selected.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(selected.clear),
                            child: Text(
                              raftText(context, 'Clear'),
                              style: TextStyle(
                                fontFamily: t.headingFont,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                color: t.strong,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        rows[i],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> searchRows(RaftTokens t) {
    final hint = TextStyle(
      fontFamily: t.headingFont,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: t.colors['foreground-hint'] ?? t.colors['foreground-muted'],
    );
    if (loading) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: RaftSpinner()),
        ),
      ];
    }
    if (failed) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(
                raftText(context, "Couldn't search destinations."),
                style: hint,
              ),
              const SizedBox(height: 8),
              RaftButton(
                label: 'Try again',
                variant: RaftControlVariant.outline,
                visualHeight: 24,
                onPressed: () => changedSearch(search.text),
              ),
            ],
          ),
        ),
      ];
    }
    if (results.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            raftText(context, 'No destinations match your search.'),
            textAlign: TextAlign.center,
            style: hint,
          ),
        ),
      ];
    }
    return [
      for (final r in results)
        () {
          final key = r['channelId'] is String
              ? 'channel:${r['channelId']}'
              : '${r['type']}:${r['id']}';
          final unavailable =
              r['canForwardNow'] != true && r['requiredAction'] == null;
          final type = r['type'];
          final channelType = r['channelType'];
          final Widget icon = type == 'channel'
              ? RaftIcon(
                  channelType == 'joint'
                      ? RaftGlyph.gitBranch
                      : channelType == 'private'
                      ? RaftGlyph.lock
                      : RaftGlyph.hash,
                  size: 14,
                )
              : _compactAvatar(
                  '${r['title']}',
                  agent: type == 'agent' || r['subtitle'] == 'agent',
                );
          final action = r['requiredAction'];
          return _TargetRow(
            key: ValueKey('forward-search-target-$type-${r['id']}'),
            icon: icon,
            label: '${r['title']}',
            selected: selected.containsKey(key),
            checkbox: multi,
            unavailable: unavailable,
            trailing: action == 'join_channel' || action == 'create_dm'
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RaftIcon(
                        action == 'join_channel'
                            ? RaftGlyph.logIn
                            : RaftGlyph.userPlus,
                        size: 10,
                        color: hint.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        raftText(
                          context,
                          action == 'join_channel' ? 'Not joined' : 'New DM',
                        ).toUpperCase(),
                        style: hint.copyWith(fontSize: 10),
                      ),
                    ],
                  )
                : null,
            onTap: unavailable
                ? null
                : () => choose(
                    _Destination(key: key, label: '${r['title']}', search: r),
                  ),
          );
        }(),
    ];
  }

  Widget localRow(RaftTokens t, RaftChannel c) {
    final key = 'channel:${c.id}';
    final Widget icon = c.type == 'dm'
        ? _compactAvatar(
            forwardTargetPickerLabel(c),
            agent: c.json['peerType'] == 'agent',
          )
        : RaftIcon(
            c.type == 'joint'
                ? RaftGlyph.gitBranch
                : c.type == 'private'
                ? RaftGlyph.lock
                : RaftGlyph.hash,
            size: 14,
          );
    return _TargetRow(
      key: ValueKey('forward-target-${c.id}'),
      icon: icon,
      label: forwardTargetPickerLabel(c),
      selected: selected.containsKey(key),
      checkbox: multi,
      onTap: () => choose(
        _Destination(key: key, label: forwardTargetLabel(c), channel: c),
      ),
    );
  }

  Widget _compactAvatar(String name, {required bool agent}) => RaftAvatar(
    name: name,
    size: 20,
    kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
    mountedContext: RaftMountedAvatarContext.compactList,
    content: RaftMountedAvatarFallback(
      avatarContext: RaftMountedAvatarContext.compactList,
      identity: agent
          ? RaftMountedAvatarIdentity.agent
          : RaftMountedAvatarIdentity.human,
    ),
  );

  Widget previewStep(RaftTokens t) {
    final labels = selected.values.map((d) => d.label).join(', ');
    final metadata = <String, dynamic>{
      'kind': 'forwarded-bundle',
      'version': 1,
      'forwardedItems': [
        for (final m in widget.messages)
          {
            'contentSnapshot': m.content,
            'provenanceState': 'available',
            'sourceAuthorSnapshot': {
              'type': m.string('senderType') == 'agent' ? 'agent' : 'user',
              'name': m.author,
            },
            'sourceCreatedAt': m.json['createdAt'],
          },
      ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header(
          t,
          leading: RaftIconButton(
            glyph: RaftGlyph.arrowLeft,
            visualSize: 28,
            minimumTargetSize: 28,
            glyphSize: 14,
            variant: RaftControlVariant.outline,
            tooltip: 'Back to destinations',
            onPressed: busy ? null : () => setState(() => preview = false),
          ),
          title: raftText(context, 'Add a note'),
          subtitle: raftFormat(context, 'Send to {targets}', {
            'targets': labels,
          }),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(error!),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  raftText(context, 'Message preview'),
                  style: TextStyle(
                    fontFamily: t.headingFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.strong,
                  ),
                ),
              ),
              RaftForwardedBundle(metadata: metadata),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.brutal ? Colors.white : t.colors['layer-panel'],
            border: Border(
              top: t.brutal
                  ? const BorderSide(color: Colors.black, width: 2)
                  : BorderSide(color: t.colors['line-hairline']!),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                raftText(context, 'Optional note'),
                style: TextStyle(
                  fontFamily: t.headingFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.strong,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('forward-mobile-note'),
                      controller: note,
                      autofocus: true,
                      enabled: !busy && attempt == null,
                      maxLength: 4000,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: raftText(context, 'Add a note'),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RaftIconButton(
                    glyph: RaftGlyph.send,
                    visualSize: 32,
                    variant: RaftControlVariant.accent,
                    tooltip: 'Send forward',
                    busy: busy,
                    onPressed: busy || selected.isEmpty ? null : send,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Target row: `flex w-full items-center gap-2 rounded-md border
/// border-line-muted px-2 py-2 text-sm font-bold` / brutal `rounded-none
/// border-2 border-black`; fill white / `bg-layer-panel`, selected
/// `bg-soft-signal` / `bg-primary-soft`, hover `brutal-cyan/15` / fill-muted.
class _TargetRow extends StatefulWidget {
  const _TargetRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.checkbox,
    this.unavailable = false,
    this.trailing,
    this.onTap,
  });
  final Widget icon;
  final String label;
  final bool selected, checkbox, unavailable;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  State<_TargetRow> createState() => _TargetRowState();
}

class _TargetRowState extends State<_TargetRow> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final fill = widget.unavailable
        ? t.colors['fill-muted']!.withValues(
            alpha: t.colors['fill-muted']!.a * .4,
          )
        : widget.selected
        ? (t.brutal
              ? t.colors['color-soft-signal']!
              : t.colors['primary-soft']!)
        : hovered
        ? (t.brutal
              ? t.colors['color-brutal-cyan']!.withValues(alpha: .15)
              : t.colors['fill-muted']!)
        : (t.brutal ? Colors.white : t.colors['layer-panel']!);
    return Semantics(
      button: !widget.checkbox,
      checked: widget.checkbox ? widget.selected : null,
      enabled: widget.onTap != null,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: widget.onTap == null
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Opacity(
            opacity: widget.unavailable ? .5 : 1,
            child: Container(
              // CSS `p-2` inside the border (Container adds the border inset).
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: fill,
                border: t.brutal
                    ? Border.all(color: Colors.black, width: 2)
                    : Border.all(color: t.colors['line-muted']!),
                borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
              ),
              child: Row(
                children: [
                  if (widget.checkbox) ...[
                    SizedBox.square(
                      dimension: 16,
                      child: Checkbox(
                        value: widget.selected,
                        onChanged: null,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  widget.icon,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: t.headingFont,
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w700,
                        color: t.strong,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 8),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// raft-ui `Input` with `pl-9 placeholder:text-foreground-placeholder` and the
/// absolutely positioned 14px Search icon at `left-3`.
class _ForwardSearchInput extends StatefulWidget {
  const _ForwardSearchInput({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final ValueChanged<String> onChanged;
  @override
  State<_ForwardSearchInput> createState() => _ForwardSearchInputState();
}

class _ForwardSearchInputState extends State<_ForwardSearchInput> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(changed);
    // `autoFocus`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.focusNode.requestFocus();
    });
  }

  void changed() => setState(() {});

  @override
  void dispose() {
    widget.focusNode.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final resolver = RaftRecipeTokens(t);
    final focused = widget.focusNode.hasFocus;
    final s = RaftInputRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      states: RaftRecipeStates({
        if (focused) RaftRecipeStates.focus,
        if (focused) RaftRecipeStates.focusVisible,
      }),
      tokens: resolver,
    ).root;
    final text = s
        .textStyle(resolver)
        .copyWith(
          color: t.colors['foreground'],
          leadingDistribution: TextLeadingDistribution.even,
        );
    final border = s.borderWidth;
    return Container(
      decoration: s.decoration(resolver),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            onChanged: widget.onChanged,
            style: text,
            cursorColor: t.strong,
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: widget.placeholder,
              hintStyle: text.copyWith(
                color: t.colors['foreground-placeholder'],
              ),
              contentPadding: EdgeInsets.fromLTRB(
                36,
                s.padding.top,
                s.padding.right,
                s.padding.bottom,
              ),
            ),
          ),
          Positioned(
            left: 12 - border.left,
            child: IgnorePointer(
              child: RaftIcon(
                RaftGlyph.search,
                size: 14,
                color: t.colors['foreground-muted'],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
