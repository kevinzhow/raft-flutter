import 'composer_suggestions.dart';
import 'collapsible.dart';

import 'package:flutter/material.dart';

import 'localization.dart';

import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'theme.dart';

class RaftPanel extends StatelessWidget {
  const RaftPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.shadow = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool shadow;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(color: t.line, width: t.border),
        borderRadius: BorderRadius.circular(t.radius),
        boxShadow: shadow ? t.shadows : null,
      ),
      child: Material(color: t.panel, child: child),
    );
  }
}

class RaftButton extends StatelessWidget {
  const RaftButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.busy = false,
    this.secondary = false,
    this.destructive = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool secondary, destructive;
  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: 18),
        if (busy || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(raftText(context, label), textAlign: TextAlign.center),
        ),
      ],
    );
    return MergeSemantics(
      child: Semantics(
        label: busy ? ', loading' : null,
        child: secondary
            ? OutlinedButton(onPressed: busy ? null : onPressed, child: content)
            : FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: RaftTokens.of(context)
                            .colors['danger-strong'],
                        foregroundColor: RaftTokens.of(context).dark
                            ? Colors.black
                            : Colors.white,
                      )
                    : null,
                onPressed: busy ? null : onPressed,
                child: content,
              ),
      ),
    );
  }
}

class RaftAvatar extends StatelessWidget {
  const RaftAvatar({
    super.key,
    required this.name,
    this.size = 34,
    this.imageUrl,
  });
  final String name;
  final double size;
  final String? imageUrl;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final fallback = Center(
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          color: t.ink,
          fontWeight: FontWeight.w800,
          fontSize: size * .4,
        ),
      ),
    );
    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.accentSoft,
          border: Border.all(color: t.line, width: t.brutal ? 2 : 0.5),
          borderRadius: BorderRadius.circular(t.brutal ? 0 : 8),
        ),
        child: imageUrl == null
            ? fallback
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class RaftNavItem extends StatelessWidget {
  const RaftNavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.unread = 0,
    this.trailing,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final int unread;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    onTap: onTap,
    button: true,
    label: unread > 0
        ? raftFormat(context, '{label}, {count} unread', {
            'label': label,
            'count': unread,
          })
        : label,
    excludeSemantics: true,
    child: Material(
      color: RaftTokens.of(context).sidebar,
      child: ListTile(
        tileColor: RaftTokens.of(context).sidebar,
        dense: true,
        minVerticalPadding: 10,
        selected: selected,
        leading: Icon(icon, size: 19),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: selected || unread > 0
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        onTap: onTap,
        trailing:
            trailing ??
            (unread > 0
                ? Badge(label: Text(unread > 99 ? '99+' : '$unread'))
                : null),
      ),
    ),
  );
}

class RaftMessageTile extends StatelessWidget {
  const RaftMessageTile({
    super.key,
    required this.author,
    required this.content,
    required this.timestamp,
    this.onThread,
    this.onActions,
    this.onLink,
    this.threadLabel,
    this.threadPreview,
    this.badge,
    this.attachments = const [],
    this.onAttachment,
    this.attachmentBuilder,
    this.reactions = const [],
    this.reactedEmojis = const {},
    this.onReaction,
    this.onReact,
    this.collapseLongMessages = true,
    this.bodyFontSize = 14,
    this.body,
  });
  final String author, content, timestamp;
  final String? threadLabel, badge;
  final bool collapseLongMessages;
  final double bodyFontSize;

  /// Business adapters may supply a richer body without replacing message
  /// actions, thread controls, attachments, or reactions.
  final Widget? body, threadPreview;
  final VoidCallback? onThread, onActions, onReact;
  final void Function(String href)? onLink;
  final List<Map<String, dynamic>> attachments, reactions;
  final Set<String> reactedEmojis;
  final void Function(Map<String, dynamic>)? onAttachment;
  final Widget Function(Map<String, dynamic>)? attachmentBuilder;
  final void Function(String)? onReaction;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return GestureDetector(
      onLongPress: onActions,
      onSecondaryTap: onActions,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RaftAvatar(name: author),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        author,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        timestamp,
                        style: TextStyle(color: t.muted, fontSize: 11),
                      ),
                      if (badge != null)
                        Text(
                          badge!,
                          style: TextStyle(
                            color: t.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  RaftCollapsible(
                    enabled: collapseLongMessages,
                    child:
                        body ??
                        SelectionArea(
                          child: MarkdownBody(
                            data: content,
                            onTapLink: (_, href, _) {
                              if (href != null) onLink?.call(href);
                            },
                            styleSheet:
                                MarkdownStyleSheet.fromTheme(
                                  Theme.of(context),
                                ).copyWith(
                                  p: TextStyle(
                                    fontSize: bodyFontSize,
                                    height: 1.5,
                                    color: t.ink,
                                  ),
                                  code: TextStyle(
                                    fontFamily: 'packages/raft_ui/GeistMono',
                                    fontSize: 12,
                                    color: t.ink,
                                    backgroundColor: t.sidebar,
                                  ),
                                  codeblockDecoration: BoxDecoration(
                                    color: t.sidebar,
                                    borderRadius: BorderRadius.circular(
                                      t.radius,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                  ),
                  if (attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: attachments
                            .map(
                              (a) =>
                                  attachmentBuilder?.call(a) ??
                                  OutlinedButton.icon(
                                    onPressed: () => onAttachment?.call(a),
                                    icon: const Icon(
                                      Icons.attach_file,
                                      size: 16,
                                    ),
                                    label: Text(
                                      '${a['filename'] ?? a['name'] ?? 'Attachment'}',
                                    ),
                                  ),
                            )
                            .toList(),
                      ),
                    ),
                  if (reactions.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      children: reactions
                          .map(
                            (r) => FilterChip(
                              selected: reactedEmojis.contains(r['emoji']),
                              showCheckmark: false,
                              label: Text('${r['emoji']} ${r['count'] ?? 1}'),
                              onSelected: onReaction == null
                                  ? null
                                  : (_) => onReaction?.call('${r['emoji']}'),
                            ),
                          )
                          .toList(),
                    ),
                  if (threadPreview != null)
                    threadPreview!
                  else if (onThread != null)
                    TextButton.icon(
                      onPressed: onThread,
                      icon: const Icon(Icons.forum_outlined, size: 15),
                      label: Text(
                        threadLabel ?? raftText(context, 'Reply in thread'),
                      ),
                    ),
                ],
              ),
            ),
            if (onActions != null)
              IconButton(
                tooltip: raftText(context, 'Message actions'),
                onPressed: onActions,
                icon: const Icon(Icons.more_horiz, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class RaftComposer extends StatefulWidget {
  const RaftComposer({
    super.key,
    required this.onSend,
    this.onAttach,
    this.hint = 'Message',
    this.enabled = true,
    this.canSend = true,
    this.pendingLabel,
    this.initialDraft = '',
    this.onDraftChanged,
    this.suggestions = const [],
    this.onSendWithMentions,
    this.onSuggestionsRequested,
  });
  final List<RaftComposerSuggestion> suggestions;
  final Future<bool> Function(String, List<Map<String, dynamic>>)?
  onSendWithMentions;
  final ValueChanged<String>? onSuggestionsRequested;
  final Future<bool> Function(String) onSend;
  final VoidCallback? onAttach;
  final String hint;
  final bool enabled, canSend;
  final String? pendingLabel;
  final String initialDraft;
  final ValueChanged<String>? onDraftChanged;
  @override
  State<RaftComposer> createState() => _RaftComposerState();
}

class _RaftComposerState extends State<RaftComposer> {
  late final TextEditingController controller;
  final focus = FocusNode();
  final suggestionScroll = ScrollController();
  bool sending = false;
  bool restoringDraft = false;
  RaftComposerTrigger? trigger;
  int suggestionIndex = 0;
  String? dismissedValue;
  final mentions = <String, Map<String, dynamic>>{};
  bool get composing =>
      controller.value.composing.isValid &&
      !controller.value.composing.isCollapsed;
  List<RaftComposerSuggestion> get matches {
    if (trigger == null || composing || sending || !widget.enabled) return [];
    final q = trigger!.query.toLowerCase();
    final result = widget.suggestions
        .where(
          (s) =>
              (trigger!.prefix == '#'
                  ? s.type == 'channel'
                  : s.type != 'channel') &&
              ('${s.name} ${s.title ?? ''} ${s.detail ?? ''}')
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
    result.sort((a, b) {
      if (a.inChannel != b.inChannel) return a.inChannel ? -1 : 1;
      final ap = a.name.toLowerCase().startsWith(q),
          bp = b.name.toLowerCase().startsWith(q);
      return ap != bp
          ? ap
                ? -1
                : 1
          : 0;
    });
    return result.take(10).toList();
  }

  void changed() {
    if (dismissedValue != null && dismissedValue != controller.text)
      dismissedValue = null;
    if (!restoringDraft) widget.onDraftChanged?.call(controller.text);
    mentions.removeWhere(
      (name, _) => !raftStructuredMentionAppears(controller.text, name),
    );
    final next = composing || dismissedValue == controller.text
        ? null
        : raftComposerTrigger(controller.text, controller.selection.baseOffset);
    if (next?.query != trigger?.query || next?.prefix != trigger?.prefix)
      suggestionIndex = 0;
    trigger = next;
    if (next != null) widget.onSuggestionsRequested?.call(next.prefix);
    if (mounted) setState(() {});
  }

  void insert(RaftComposerSuggestion suggestion) {
    final range = trigger;
    if (range == null || composing || sending) return;
    final next = controller.text.replaceRange(
      range.start,
      range.end,
      '${suggestion.insertion} ',
    );
    if (suggestion.isMention) mentions[suggestion.name] = suggestion.mention;
    dismissedValue = next;
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: range.start + suggestion.insertion.length + 1,
      ),
    );
    focus.requestFocus();
  }

  KeyEventResult suggestionKey(FocusNode node, KeyEvent event) {
    final options = matches;
    if (event is! KeyDownEvent ||
        composing ||
        options.isEmpty ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      setState(
        () => suggestionIndex =
            (suggestionIndex + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)) %
            options.length,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && suggestionScroll.hasClients)
          suggestionScroll.jumpTo(
            (suggestionIndex * 56.0).clamp(
              0.0,
              suggestionScroll.position.maxScrollExtent,
            ),
          );
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab ||
        (key == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed)) {
      insert(options[suggestionIndex.clamp(0, options.length - 1)]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      setState(() {
        dismissedValue = controller.text;
        trigger = null;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialDraft);
    controller.addListener(changed);
  }

  @override
  void didUpdateWidget(covariant RaftComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDraft != widget.initialDraft &&
        controller.text.isEmpty &&
        !focus.hasFocus &&
        !sending) {
      restoringDraft = true;
      controller.text = widget.initialDraft;
      restoringDraft = false;
    }
  }

  Future<void> send() async {
    final draft = controller.text;
    final text = draft.trim();
    if (sending ||
        composing ||
        !widget.enabled ||
        !widget.canSend ||
        (text.isEmpty && widget.pendingLabel == null))
      return;
    setState(() => sending = true);
    try {
      final selected = mentions.values
          .where((m) => raftStructuredMentionAppears(text, m['name'] as String))
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      final succeeded = widget.onSendWithMentions == null
          ? await widget.onSend(text)
          : await widget.onSendWithMentions!(text, selected);
      if (succeeded && mounted && controller.text == draft) {
        mentions.clear();
        controller.clear();
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    suggestionScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final options = matches;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: RaftPanel(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (options.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  controller: suggestionScroll,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final s = options[index];
                    return Semantics(
                      selected: index == suggestionIndex,
                      child: ListTile(
                        key: ValueKey('composer-suggestion-${s.type}-${s.id}'),
                        selected: index == suggestionIndex,
                        tileColor: t.panel,
                        dense: true,
                        minTileHeight: 48,
                        leading: Icon(
                          s.type == 'channel'
                              ? Icons.tag
                              : s.type == 'agent'
                              ? Icons.smart_toy_outlined
                              : s.type == 'computer'
                              ? Icons.computer
                              : s.type == 'app'
                              ? Icons.extension_outlined
                              : Icons.person_outline,
                        ),
                        title: Text(
                          '${s.type == 'channel' ? '#' : '@'}${s.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            raftText(context, switch (s.type) {
                              'agent' => 'Agent',
                              'user' => 'Human',
                              'channel' => 'Channel',
                              'computer' => 'Computer',
                              _ => 'App',
                            }),
                            if (s.title != null && s.title != s.name) s.title!,
                            if (!s.inChannel && s.isMention)
                              raftText(context, 'Not in this conversation'),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => insert(s),
                      ),
                    );
                  },
                ),
              ),
            if (widget.pendingLabel != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  widget.pendingLabel!,
                  style: TextStyle(color: t.accent),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.onAttach != null)
                  IconButton(
                    tooltip: raftText(context, 'Attach file'),
                    onPressed: sending || !widget.enabled
                        ? null
                        : widget.onAttach,
                    icon: const Icon(Icons.add),
                  ),
                Expanded(
                  child: Focus(
                    onKeyEvent: suggestionKey,
                    child: Shortcuts(
                      shortcuts: const {
                        SingleActivator(
                          LogicalKeyboardKey.enter,
                          control: true,
                        ): ActivateIntent(),
                        SingleActivator(LogicalKeyboardKey.enter, meta: true):
                            ActivateIntent(),
                      },
                      child: Actions(
                        actions: {
                          ActivateIntent: CallbackAction<ActivateIntent>(
                            onInvoke: (_) {
                              if (controller.value.composing.isValid &&
                                  !controller.value.composing.isCollapsed)
                                return null;
                              send();
                              return null;
                            },
                          ),
                        },
                        child: TextField(
                          controller: controller,
                          focusNode: focus,
                          enabled: widget.enabled,
                          minLines: 1,
                          maxLines: 6,
                          decoration: InputDecoration(
                            hintText: widget.hint,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton.filled(
                  tooltip: raftText(context, 'Send message (Ctrl+Enter)'),
                  onPressed: widget.enabled && widget.canSend && !sending
                      ? send
                      : null,
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_upward),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RaftEmptyState extends StatelessWidget {
  const RaftEmptyState({
    super.key,
    required this.title,
    required this.detail,
    this.icon = Icons.forum_outlined,
    this.action,
  });
  final String title, detail;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 18), child: action),
        ],
      ),
    ),
  );
}

class RaftUploadChip extends StatelessWidget {
  const RaftUploadChip({
    super.key,
    required this.name,
    required this.onRemove,
    this.progress = 0,
    this.ready = false,
    this.error,
    this.onRetry,
  });
  final String name;
  final VoidCallback onRemove;
  final double progress;
  final bool ready;
  final String? error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => RaftPanel(
    padding: const EdgeInsets.only(left: 12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error != null)
          const Icon(Icons.error_outline, size: 18)
        else if (ready)
          const Icon(Icons.attach_file, size: 18)
        else
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              strokeWidth: 2,
              semanticsLabel: 'Uploading $name',
            ),
          ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            error == null ? name : '$name · Upload failed',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (error != null && onRetry != null)
          IconButton(
            tooltip: raftText(context, 'Retry upload'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
          ),
        IconButton(
          tooltip: ready || error != null
              ? raftText(context, 'Remove attachment')
              : raftText(context, 'Cancel upload'),
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    ),
  );
}
