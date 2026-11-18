import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'app_link_models.dart';
import 'app_link_store.dart';
import 'artifacts/artifact_api.dart' show ArtifactDeployment;
import 'artifacts/artifact_models.dart' show artifactLinkTarget;
import 'resource_cards.dart' show resourceRelativeTime;

bool mayReadAppLinks(String content, WorkspaceController workspace) {
  if (!content.contains('https://')) return false;
  final appHosts = ArtifactDeployment.resolve(
    workspace.client.origin,
    null,
  ).appHosts;
  return RaftMessageBody.bareLinks(content).any(
    (href) =>
        appLinkKey(href) != null && artifactLinkTarget(href, appHosts) == null,
  );
}

typedef AppLinkInline = Widget? Function(BuildContext, String);

class AppLinkMessageView extends StatefulWidget {
  const AppLinkMessageView({
    super.key,
    required this.workspace,
    required this.message,
    required this.visibleContent,
    required this.openBrowser,
    required this.body,
  });

  final WorkspaceController workspace;
  final RaftMessage message;
  final String visibleContent;
  final ValueChanged<String> openBrowser;
  final Widget Function(AppLinkInline, AppLinkInline?, Object) body;

  @override
  State<AppLinkMessageView> createState() => _AppLinkMessageViewState();
}

class _AppLinkMessageViewState extends State<AppLinkMessageView> {
  AppLinkMessage? _message;
  ScrollPosition? _scroll;
  bool _visible = false, _queued = false;

  @override
  void initState() {
    super.initState();
    widget.workspace.addListener(_authorityChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
    _observe();
  }

  @override
  void didUpdateWidget(AppLinkMessageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace != widget.workspace) {
      oldWidget.workspace.removeListener(_authorityChanged);
      widget.workspace.addListener(_authorityChanged);
    }
    _bind();
    _observe();
  }

  void _authorityChanged() {
    if (_message?.current == false) setState(_bind);
  }

  void _bind() {
    final next = AppLinkStore.of(
      widget.workspace,
    ).message(widget.message, Localizations.localeOf(context).toLanguageTag());
    if (identical(next, _message)) return;
    if (_visible) {
      _message?.detach();
      _scroll?.addListener(_checkViewport);
    }
    _message?.removeListener(_showNotice);
    _message = next;
    next.addListener(_showNotice);
    _visible = false;
    _checkViewport();
  }

  void _showNotice() {
    if (!_visible || _message?.current != true) return;
    final toast = RaftToastHost.maybeOf(context);
    if (toast == null) return;
    final notice = _message!.takeNotice();
    if (notice == null) return;
    toast.show(
      notice.tone == null
          ? raftFormat(context, notice.text, notice.args)
          : notice.text,
      tone: switch (notice.tone) {
        'success' => RaftToastRecipeTone.success,
        'warning' => RaftToastRecipeTone.warning,
        _ => RaftToastRecipeTone.info,
      },
    );
  }

  void _observe() {
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scroll) {
      _scroll?.removeListener(_checkViewport);
      _scroll = position;
      if (!_visible) _scroll?.addListener(_checkViewport);
    }
    _checkViewport();
  }

  void _checkViewport() {
    if (_visible || _queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted || _visible) return;
      final object = context.findRenderObject();
      if (object == null || !object.attached) return;
      final viewport = RenderAbstractViewport.maybeOf(object);
      if (viewport != null) {
        final row = MatrixUtils.transformRect(
          object.getTransformTo(viewport),
          object.paintBounds,
        );
        if (!row.overlaps(viewport.paintBounds)) return;
      }
      _visible = true;
      _scroll?.removeListener(_checkViewport);
      setState(() => _message!.attach());
    });
  }

  @override
  void dispose() {
    widget.workspace.removeListener(_authorityChanged);
    _scroll?.removeListener(_checkViewport);
    _message?.removeListener(_showNotice);
    if (_visible) _message?.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _message!;
    return ListenableBuilder(
      listenable: message,
      builder: (context, _) {
        final links = message.current
            ? message.links
            : const <String, AppLinkResult>{};
        final visibleLinks = widget.visibleContent == widget.message.content
            ? null
            : RaftMessageBody.bareLinks(widget.visibleContent)
                  .map(appLinkKey)
                  .toSet();
        final blocks = {
          for (final link
              in links.values
                  .whereType<AppLinkPreview>()
                  .where((link) => link.placement == AppLinkPlacement.block)
                  .take(3))
            link.url: link,
        };
        final body = widget.body(
          (_, href) {
            final link = links[appLinkKey(href)];
            if (link == null ||
                link is AppLinkPreview && link.chipTitle == null) {
              return null;
            }
            if (link is AppLinkConsent &&
                !message.store.ownsPrompt(message, link.app.id)) {
              return null;
            }
            return AppLinkChip(
              key: ValueKey(link.url),
              link: link,
              message: message,
              openBrowser: widget.openBrowser,
            );
          },
          blocks.isEmpty
              ? null
              : (_, href) {
                  final link = blocks[appLinkKey(href)];
                  return link == null ? null : _blockCard(link, message);
                },
          links,
        );
        final prompts = <String>{};
        final extras = <Widget>[
          if (visibleLinks != null)
            for (final link in blocks.values)
              if (!visibleLinks.contains(link.url)) _blockCard(link, message),
          for (final link in links.values)
            if (link is AppLinkConsent &&
                message.store.ownsPrompt(message, link.app.id) &&
                prompts.add(link.app.id))
              AppLinkPrompt(message: message, link: link),
        ];
        if (extras.isEmpty) return body;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: RaftScale.spacing,
          children: [body, ...extras],
        );
      },
    );
  }

  Widget _blockCard(AppLinkPreview link, AppLinkMessage message) => _LinkCard(
    key: ValueKey('app-link-block-${link.url}'),
    link: link,
    message: message,
    openBrowser: widget.openBrowser,
  );
}

class AppLinkChip extends StatefulWidget {
  const AppLinkChip({
    super.key,
    required this.link,
    required this.message,
    required this.openBrowser,
  });

  final AppLinkResult link;
  final AppLinkMessage message;
  final ValueChanged<String> openBrowser;

  @override
  State<AppLinkChip> createState() => _AppLinkChipState();
}

class _AppLinkChipState extends State<AppLinkChip> {
  final _hover = RaftHoverCardController();

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final gap = RaftScale.space(2);
    final width = RaftScale.container['sm'] ?? RaftScale.space(96);
    final touch = RaftInteraction.of(context).touch;
    final domain = Uri.parse(link.url).host;
    final path = Uri.parse(link.url).path;
    final label = switch (link) {
      AppLinkPreview(:final chipTitle) => chipTitle ?? domain,
      _ => path == '/' ? domain : '$domain$path',
    };
    final consent = link is AppLinkConsent;
    final hasHover =
        consent ||
        link is AppLinkConnect ||
        link is AppLinkPreview && link.placement == AppLinkPlacement.hover;
    final chip = RaftAppLinkChip(
      key: ValueKey('app-link-chip-${link.url}'),
      label: label,
      icon: _linkIcon(link.app),
      prompt: consent,
      domain: touch && link is AppLinkPreview ? domain : null,
      onPressed: () {
        if (consent) {
          if (_hover.isOpen && _hover.pinned) {
            _hover.close();
          } else {
            _hover.open(pinned: true);
          }
        } else {
          _hover.close();
          widget.openBrowser(link.url);
        }
      },
      semanticLabel: link is AppLinkPreview
          ? raftFormat(context, '{title}, on {domain}', {
              'title': label,
              'domain': domain,
            })
          : label,
    );
    if (!hasHover || touch && !consent) return chip;
    return RaftHoverCard(
      controller: _hover,
      closeOnTriggerPress: !consent,
      openOnKeyboardFocus: !consent,
      width: width,
      child: chip,
      card: (context) {
        if (link is AppLinkConsent) {
          return Column(
            key: const ValueKey('app-link-consent-popover'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppLinkPrompt(
                message: widget.message,
                link: link,
                embedded: false,
              ),
              Padding(
                padding: EdgeInsets.all(gap),
                child: RaftButton(
                  label: raftText(context, 'Open link'),
                  onPressed: () {
                    _hover.close();
                    widget.openBrowser(link.url);
                  },
                ),
              ),
            ],
          );
        }
        return _LinkCard(
          key: const ValueKey('app-link-hover-card'),
          link: link,
          message: widget.message,
          openBrowser: widget.openBrowser,
        );
      },
    );
  }
}

Widget _linkIcon(LinkApp app, {bool large = false}) =>
    RaftAppLinkLogo(name: app.name, logoUrl: app.icon, large: large);

class AppLinkPrompt extends StatelessWidget {
  const AppLinkPrompt({
    super.key,
    required this.message,
    required this.link,
    this.embedded = true,
  });

  final AppLinkMessage message;
  final AppLinkConsent link;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final choice = message.store.choice(link.app.id);
    if (choice == AppLinkChoice.declined) return const SizedBox.shrink();
    final tokens = RaftTokens.of(context);
    final gap = RaftScale.space(2);
    final inset = RaftScale.space(3);
    final padding = EdgeInsets.all(inset);
    final params = {'app': link.app.name};
    final allowing = choice == AppLinkChoice.allowing;
    final declining = choice == AppLinkChoice.declining;
    final failed = choice == AppLinkChoice.failed;
    final Widget content;
    if (choice == AppLinkChoice.allowed) {
      content = Semantics(
        liveRegion: true,
        label: raftText(context, 'Loading link preview'),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: gap,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              RaftSkeleton(width: 80, height: 12),
              RaftSkeleton(width: 220, height: 12),
              RaftSkeleton(width: 60, height: 20),
            ],
          ),
        ),
      );
    } else {
      content = Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: gap,
          children: [
            _linkIcon(link.app, large: true),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: RaftScale.spacing,
                children: [
                  Text(
                    raftFormat(
                      context,
                      '{app} wants to show link previews here',
                      params,
                    ),
                    style: tokens.scale(RaftTypeScale.subhead),
                  ),
                  Text(
                    raftFormat(
                      context,
                      failed
                          ? 'Couldn’t allow {app}. Check your connection and try again.'
                          : 'After you allow, {app} will know which of its links you view.',
                      params,
                    ),
                    style: tokens.scale(
                      RaftTypeScale.footnote,
                      color: tokens.ui.foregroundMuted,
                    ),
                  ),
                  Wrap(
                    spacing: gap,
                    runSpacing: RaftScale.spacing,
                    children: [
                      RaftButton(
                        label: raftText(context, failed ? 'Retry' : 'Allow'),
                        disabled: declining,
                        busy: allowing,
                        loadingLabel: raftText(context, 'Allowing…'),
                        onPressed: () => _choose(context, allow: true),
                      ),
                      RaftButton(
                        label: raftText(context, 'Don’t allow'),
                        tone: RaftButtonRecipeVariant.ghost,
                        disabled: allowing,
                        busy: declining,
                        loadingLabel: raftText(context, 'Saving…'),
                        onPressed: () => _choose(context, allow: false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return embedded
        ? RaftMessageEmbedFrame(
            key: ValueKey('app-link-prompt-${link.app.id}'),
            size: RaftMessageEmbedSize.item,
            child: content,
          )
        : content;
  }

  Future<void> _choose(BuildContext context, {required bool allow}) async {
    final toast = RaftToastHost.maybeOf(context);
    final declined = raftFormat(
      context,
      '{app} links stay as they are. You can change this in Settings.',
      {'app': link.app.name},
    );
    final failed = raftFormat(
      context,
      'Couldn’t save your choice for {app}. Check your connection and try again.',
      {'app': link.app.name},
    );
    await message.store.choose(link, allow: allow);
    if (allow || !message.current) return;
    if (message.store.choice(link.app.id) == AppLinkChoice.declined) {
      toast?.show(declined, tone: RaftToastRecipeTone.info);
    } else {
      toast?.show(failed, tone: RaftToastRecipeTone.error);
    }
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    super.key,
    required this.link,
    required this.message,
    required this.openBrowser,
  });

  final AppLinkResult link;
  final AppLinkMessage message;
  final ValueChanged<String> openBrowser;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final gap = RaftScale.space(2);
    final inset = RaftScale.space(3);
    final preview = link;
    final connect = preview is AppLinkConnect;
    final domain = Uri.parse(link.url).host;
    final title = connect
        ? raftFormat(context, 'Connect your {app} account', {
            'app': link.app.name,
          })
        : (preview as AppLinkPreview).title;
    return ListenableBuilder(
      listenable: message,
      builder: (context, _) {
        final operation = message.operation(link.url);
        final cardBody = switch (preview) {
          AppLinkPreview(:final tree?) => RaftMessageCard(
            root: tree,
            contentOnly: true,
            relativeTime: (at) => resourceRelativeTime(
              at.toIso8601String(),
              chinese: Localizations.localeOf(context).languageCode == 'zh',
            ),
            duration: (start, end) =>
                _duration(context, (end ?? DateTime.now()).difference(start)),
          ),
          _ => null,
        };
        final actions = preview is AppLinkPreview && preview.buttons.isNotEmpty
            ? _actionRow(context, preview, operation)
            : null;
        if (preview is AppLinkPreview &&
            preview.placement == AppLinkPlacement.block) {
          return RaftAppLinkCard(
            title: title,
            appName: link.app.name,
            domain: domain,
            icon: _linkIcon(link.app),
            onOpen: () => openBrowser(link.url),
            body: cardBody,
            actions: actions,
          );
        }
        return Padding(
          padding: EdgeInsets.all(inset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: gap,
            children: [
              Text(title, style: tokens.scale(RaftTypeScale.subhead)),
              if (connect) ...[
                Text(
                  raftFormat(
                    context,
                    '{app} shows what this link is once you connect your account there.',
                    {'app': link.app.name},
                  ),
                  style: tokens.scale(RaftTypeScale.footnote),
                ),
                RaftButton(
                  label: raftText(context, 'Connect account'),
                  onPressed: () {
                    RaftHoverCard.dismiss(context);
                    openBrowser(preview.connectUrl);
                  },
                ),
              ],
              ?cardBody,
              Text(
                '${link.app.name} · $domain',
                style: tokens.scale(
                  RaftTypeScale.footnote,
                  color: tokens.ui.foregroundMuted,
                ),
              ),
              ?actions,
            ],
          ),
        );
      },
    );
  }

  Widget _actionRow(
    BuildContext context,
    AppLinkPreview preview,
    AppLinkOperation operation,
  ) {
    final entries = preview.buttons.entries.toList();
    final block = preview.placement == AppLinkPlacement.block;
    final primary = block
        ? entries
              .where(
                (entry) =>
                    entry.value is! AppLinkOpen || entry.key.url != preview.url,
              )
              .take(2)
        : entries.where((entry) => entry.value is AppLinkExecute).take(2);
    final row = primary.toList();
    if (!block && row.isEmpty) {
      row.addAll(entries.where((entry) => entry.value is AppLinkOpen).take(1));
    }
    final overflow = entries.where((entry) => !row.contains(entry)).toList();
    final tokens = RaftTokens.of(context);
    final gap = RaftScale.space(2);
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: gap,
      runSpacing: gap,
      children: [
        if (operation.phase case final phase?)
          Semantics(
            liveRegion: true,
            child: Text(
              raftText(context, switch (phase) {
                AppLinkPhase.holding => 'Runs when the countdown ends',
                AppLinkPhase.pending || AppLinkPhase.executing => 'In progress',
                _ => 'Working…',
              }),
              style: tokens.scale(
                RaftTypeScale.footnote,
                color: tokens.ui.foregroundMuted,
              ),
            ),
          ),
        if (overflow.isNotEmpty)
          RaftDropdownMenu(
            key: const ValueKey('app-link-more-trigger'),
            surfaceKey: const ValueKey('app-link-more-menu'),
            label: raftText(context, 'More actions'),
            tooltip: raftText(context, 'More actions'),
            glyph: RaftGlyph.ellipsis,
            align: RaftDropdownAlign.end,
            entries: [
              for (final entry in overflow)
                RaftMenuEntry(
                  label: _label(context, entry.key, entry.value),
                  onPressed: _blocked(entry.key, entry.value, operation)
                      ? null
                      : () => _activate(
                          context,
                          preview,
                          operation,
                          entry.key,
                          entry.value,
                        ),
                ),
            ],
          ),
        for (final entry in [
          ...row.where((entry) => entry.key.ghost),
          ...row.where((entry) => !entry.key.ghost),
        ])
          _button(context, preview, operation, entry.key, entry.value),
      ],
    );
  }

  bool _fallback(AppLinkAction action) =>
      action is AppLinkExecute && action.handle == null;

  bool _blocked(
    RaftCardButton button,
    AppLinkAction action,
    AppLinkOperation operation,
  ) =>
      button.disabledReason != null ||
      (action is! AppLinkOpen && !_fallback(action) && operation.busy);

  String _label(
    BuildContext context,
    RaftCardButton button,
    AppLinkAction action,
  ) => _fallback(action) ? raftText(context, 'Open in browser') : button.label;

  Widget _button(
    BuildContext context,
    AppLinkPreview preview,
    AppLinkOperation operation,
    RaftCardButton button,
    AppLinkAction action,
  ) {
    return RaftButton(
      label: _label(context, button, action),
      tone: button.ghost ? RaftButtonRecipeVariant.ghost : null,
      tooltip: button.disabledReason,
      disabled: _blocked(button, action, operation),
      busy: operation.busy && operation.label == button.label,
      loadingLabel: raftText(context, 'Working…'),
      onPressed: () => _activate(context, preview, operation, button, action),
    );
  }

  void _activate(
    BuildContext context,
    AppLinkPreview preview,
    AppLinkOperation operation,
    RaftCardButton button,
    AppLinkAction action,
  ) {
    if (action is AppLinkOpen || _fallback(action)) {
      RaftHoverCard.dismiss(context);
      openBrowser(action is AppLinkOpen ? action.url : preview.url);
      return;
    }
    _press(context, preview, operation, button, action);
  }

  void _press(
    BuildContext context,
    AppLinkPreview preview,
    AppLinkOperation operation,
    RaftCardButton button,
    AppLinkAction action,
  ) {
    final toast = RaftToastHost.maybeOf(context);
    final title = raftFormat(context, '{action} runs in a moment.', {
      'action': button.label,
    });
    final undo = raftText(context, 'Undo');
    final countdown = raftText(context, '{seconds}s to undo');
    RaftToastHandle? handle;
    int? seconds;
    var holding = false;
    void update() {
      if (operation.phase == AppLinkPhase.holding) {
        holding = true;
        if (seconds == operation.undoSeconds) return;
        seconds = operation.undoSeconds;
        handle = toast?.show(
          title,
          description: countdown.replaceAll('{seconds}', '$seconds'),
          actionLabel: undo,
          onAction: operation.undo,
          tone: RaftToastRecipeTone.info,
        );
        return;
      }
      handle?.dismiss();
      if (!operation.busy) message.removeListener(update);
    }

    message.addListener(update);
    unawaited(
      operation
          .press(
            preview,
            button,
            action,
            (description) => context.mounted
                ? showAppLinkConfirmation(context, preview, description)
                : Future.value(false),
          )
          .whenComplete(() {
            if (!holding && !operation.busy) message.removeListener(update);
          }),
    );
  }
}

Future<bool> showAppLinkConfirmation(
  BuildContext context,
  AppLinkPreview preview,
  Map description,
) {
  final gap = RaftScale.space(2);
  return showRaftAlertDialog(
    context: context,
    barrierDismissible: false,
    title: description['title'] is String ? description['title'] as String : '',
    confirmLabel: description['confirm_label'] is String
        ? description['confirm_label'] as String
        : raftText(context, 'Confirm'),
    cancelLabel: description['cancel_label'] is String
        ? description['cancel_label'] as String
        : raftText(context, 'Cancel'),
    content: Column(
      key: const ValueKey('app-link-confirmation'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: gap,
      children: [
        RaftDialogDescription(
          '${preview.app.name} · ${Uri.parse(preview.url).host}',
        ),
        if (description['body'] case final String body)
          RaftDialogDescription(body),
        if (description['rows'] case final List rows)
          for (final row in rows.take(8))
            if (row case {
              'label': final String label,
              'value': final String value,
            })
              RaftDialogDescription('$label: $value'),
        if (description['fine_print'] case final String finePrint)
          RaftDialogDescription(finePrint),
      ],
    ),
  );
}

String _duration(BuildContext context, Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 1 << 31);
  if (seconds < 60) {
    return raftFormat(context, '{seconds}s', {'seconds': seconds});
  }
  if (seconds < 3600) {
    return raftFormat(context, '{minutes}m {seconds}s', {
      'minutes': seconds ~/ 60,
      'seconds': seconds % 60,
    });
  }
  return raftFormat(context, '{hours}h {minutes}m', {
    'hours': seconds ~/ 3600,
    'minutes': seconds ~/ 60 % 60,
  });
}
