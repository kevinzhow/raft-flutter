import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'action_card_spec.dart';
import 'integrations_views.dart' show integrationScopeCopy;
import 'resource_cards.dart' show resourceRelativeTime;

bool actionCardExpired(CardJson metadata, [DateTime? now]) {
  if (metadata['state'] == 'expired') return true;
  final expiresAt = DateTime.tryParse('${metadata['expiresAt']}');
  return metadata['state'] == 'prepared' &&
      expiresAt != null &&
      (now ?? DateTime.now()).isAfter(expiresAt);
}

class ActionCardSpecView extends StatefulWidget {
  const ActionCardSpecView({
    super.key,
    required this.spec,
    required this.metadata,
    required this.entityName,
    required this.hasEntity,
    required this.formatTimestamp,
    required this.resolvePress,
    required this.onPress,
    this.onEntity,
    this.blocked,
    this.error,
    this.busy = false,
    this.inlineForm,
    this.trailing,
    this.hiddenButton,
    this.inlineQuestionFields = const {},
    this.canOpenFeedbackTicket = false,
    this.completedOnCurrentPlan,
  });

  final ActionCardSpec spec;
  final CardJson metadata;
  final ActionCardEntityName entityName;
  final bool Function(CardJson) hasEntity;
  final String Function(DateTime) formatTimestamp;
  final ActionCardPress Function(ActionCardElement) resolvePress;
  final void Function(ActionCardPress, ActionCardElement)? onPress;
  final ValueChanged<CardJson>? onEntity;
  final String? blocked, error;
  final bool busy;
  final bool canOpenFeedbackTicket;
  final Widget? inlineForm, trailing;
  final String? hiddenButton, completedOnCurrentPlan;
  final Set<String> inlineQuestionFields;

  @override
  State<ActionCardSpecView> createState() => _ActionCardSpecViewState();
}

class _ActionCardSpecViewState extends State<ActionCardSpecView> {
  bool? _expanded;

  @override
  void didUpdateWidget(covariant ActionCardSpecView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.metadata['state'] != oldWidget.metadata['state'] ||
        widget.completedOnCurrentPlan != oldWidget.completedOnCurrentPlan) {
      _expanded = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.metadata;
    final card = widget.spec;
    String copy(Object? value) =>
        actionCardCopy(context, value, widget.entityName);
    final state = metadata['state'];
    final expired = actionCardExpired(metadata);
    final done = state == 'executed' || widget.completedOnCurrentPlan != null;
    final withdrawn = state == 'withdrawn';
    final known = const {
      'prepared',
      'executed',
      'expired',
      'withdrawn',
      'frozen',
      'reconfirm_required',
    }.contains(state);
    final ended = expired || withdrawn || !known;
    final status = done
        ? 'Done'
        : expired
        ? 'Expired'
        : withdrawn
        ? 'Withdrawn'
        : state == 'frozen'
        ? 'Frozen'
        : state == 'reconfirm_required'
        ? 'Reconfirm'
        : !known || widget.blocked != null
        ? 'View only'
        : null;
    final setup = cardObject(metadata['result'])['setupUrl'];
    final defaultExpanded =
        !ended &&
        (done
            ? setup is String && setup.isNotEmpty
            : widget.blocked == null ||
                  state == 'frozen' ||
                  state == 'reconfirm_required');
    final expanded = status == null || (_expanded ?? defaultExpanded);
    final title = copy(card.title);
    final result = card.result;
    final headline = result?.nodes
        .where(
          (element) => element.type == 'Text' || element.type == 'EntityRef',
        )
        .map(
          (element) => element.type == 'Text'
              ? copy(element.props['text'])
              : widget.entityName(element.props),
        )
        .where((text) => text.isNotEmpty && !title.contains(text))
        .firstOrNull;
    final by = cardString(metadata['executedByUserName']);
    final question = cardObject(metadata['action'])['type'] == 'question:ask';
    final at = DateTime.tryParse(
      '${metadata['expiresAt'] ?? cardObject(metadata['action'])['expiresAt']}',
    );
    final committedAt = DateTime.tryParse('${metadata['executedAt']}');
    final description = done
        ? widget.completedOnCurrentPlan
        : expired && at != null
        ? raftFormat(
            context,
            'Expired on {date}. Ask the agent to send a new request.',
            {'date': widget.formatTimestamp(at)},
          )
        : widget.blocked;
    final content = RaftSpecActionCardContent(context);
    final completionLabel = raftText(
      context,
      question ? 'Answered by {name}' : 'Committed by {name}',
    );
    final completionCopy = completionLabel.split('{name}');
    final resultSummary = !expanded && !question ? headline : null;
    final descriptionSpan =
        done &&
            widget.completedOnCurrentPlan == null &&
            (by != null || resultSummary != null)
        ? TextSpan(
            children: [
              if (by != null) ...[
                TextSpan(text: completionCopy.first),
                content.completionName(by),
                if (completionCopy.length > 1)
                  TextSpan(text: completionCopy.skip(1).join(by)),
                if (committedAt != null)
                  TextSpan(
                    text:
                        '\u00a0·\u00a0${widget.formatTimestamp(committedAt).replaceAll(' ', '\u00a0')}',
                    style: content.tokens.scale(
                      RaftTypeScale.monoMeta,
                      mono: true,
                    ),
                  ),
              ],
              if (resultSummary != null)
                TextSpan(text: ' →\u00a0$resultSummary'),
            ],
          )
        : null;
    final serverName = cardString(metadata['targetServerName']);
    final body = ActionCardSpecTree(
      root: card.body,
      entityName: widget.entityName,
      hasEntity: widget.hasEntity,
      onEntity: widget.onEntity,
      button: done || ended ? null : _button,
      hiddenFields: widget.inlineQuestionFields,
      fitLabels: widget.inlineForm != null,
    );
    return RaftSpecActionCard(
      title: title,
      icon: const {
        'hash': RaftGlyph.hash,
        'bot': RaftGlyph.bot,
        'user_plus': RaftGlyph.userPlus,
        'key': RaftGlyph.keyRound,
        'app': RaftGlyph.appWindow,
        'package': RaftGlyph.package,
        'plug': RaftGlyph.plug,
        'message': RaftGlyph.message,
        'sparkles': RaftGlyph.sparkles,
        'shield': RaftGlyph.shield,
        'credit_card': RaftGlyph.creditCard,
      }[card.icon],
      status: status == null ? null : raftText(context, status),
      statusVariant: done
          ? RaftStatusVariant.success
          : state == 'reconfirm_required'
          ? RaftStatusVariant.accent
          : RaftStatusVariant.muted,
      description: description == null || description.isEmpty
          ? null
          : description,
      descriptionSpan: descriptionSpan,
      expanded: expanded,
      completed: done,
      onToggle: status == null || widget.onPress == null
          ? null
          : () => setState(() => _expanded = !expanded),
      body: content.column([
        if (serverName != null)
          content.notice(
            raftFormat(context, 'Runs on {server}', {'server': serverName}),
          ),
        ...body.sections(context, content),
        if (!done && !ended) ?widget.inlineForm,
        if (done && result != null)
          ...ActionCardSpecTree(
            root: result,
            entityName: widget.entityName,
            hasEntity: widget.hasEntity,
            onEntity: widget.onEntity,
            button: (context, node) => _button(context, node, result: true),
          ).sections(context, content),
        ?widget.trailing,
        if (!done && widget.error != null)
          RaftErrorBanner(widget.error ?? '', small: true),
      ]),
    );
  }

  Widget? _button(
    BuildContext context,
    ActionCardElement node, {
    bool result = false,
  }) {
    if (widget.hiddenButton == node.id && !result) return null;
    final press = widget.resolvePress(node);
    if (press.command == ActionCardCommand.intent &&
        press.argument == 'feedback_ticket' &&
        (!result || !widget.canOpenFeedbackTicket)) {
      return null;
    }
    final mutates = switch (press.command) {
      ActionCardCommand.form || ActionCardCommand.execute => true,
      ActionCardCommand.intent => !const {
        'feedback_ticket',
        'upgrade_dialog',
        'add_seats',
      }.contains(press.argument),
      _ => false,
    };
    if (result && mutates) return null;
    if (mutates && widget.blocked != null) return null;
    final props = node.props;
    final state = widget.metadata['state'];
    final fallback = press.command == ActionCardCommand.browser;
    final reason = props['disabledReason'] == null
        ? null
        : actionCardCopy(context, props['disabledReason'], widget.entityName);
    final disabled =
        reason != null || (mutates && (widget.busy || state == 'frozen'));
    return RaftButton(
      key: ValueKey('action-card-button-${node.id}'),
      label: fallback
          ? 'Open in browser'
          : mutates && state == 'reconfirm_required'
          ? 'Reconfirm'
          : actionCardCopy(context, props['label'], widget.entityName),
      uiVariant: props['emphasis'] == 'destructive' && !fallback
          ? RaftButtonVariant.danger
          : RaftButtonVariant.outline,
      uiSize: RaftButtonSize.md,
      tooltip: reason,
      autoHeight: true,
      onPressed: disabled || widget.onPress == null
          ? null
          : () => widget.onPress?.call(press, node),
    );
  }
}

class ActionCardSpecTree extends StatelessWidget {
  const ActionCardSpecTree({
    super.key,
    required this.root,
    required this.entityName,
    required this.hasEntity,
    this.onEntity,
    this.button,
    this.hiddenFields = const {},
    this.fitLabels = false,
  });

  final ActionCardElement root;
  final ActionCardEntityName entityName;
  final bool Function(CardJson) hasEntity;
  final ValueChanged<CardJson>? onEntity;
  final Widget? Function(BuildContext, ActionCardElement)? button;
  final Set<String> hiddenFields;
  final bool fitLabels;

  @override
  Widget build(BuildContext context) {
    final content = RaftSpecActionCardContent(context);
    return content.column(sections(context, content));
  }

  List<Widget> sections(
    BuildContext context,
    RaftSpecActionCardContent content,
  ) {
    String copy(Object? raw) => actionCardCopy(context, raw, entityName);
    final valueStyle = content.text(content.slots.propertyValue);

    String name(CardJson ref) {
      final label = entityName(ref);
      return ref['kind'] == 'channel' &&
              hasEntity(ref) &&
              label.isNotEmpty &&
              !label.startsWith('#')
          ? '#$label'
          : label;
    }

    bool chip(CardJson ref) =>
        (ref['kind'] == 'computer' || ref['kind'] == 'channel') &&
        hasEntity(ref);

    InlineSpan reference(CardJson ref) {
      final label = name(ref);
      final resolved = hasEntity(ref);
      if (!resolved) {
        return ref['kind'] == 'computer'
            ? TextSpan(text: label)
            : content.entityReference(context, label);
      }
      final kind = switch (ref['kind']) {
        'channel' => RaftReferenceKind.channel,
        'computer' => RaftReferenceKind.thread,
        _ => null,
      };
      final press = onEntity;
      return content.entityReference(
        context,
        label,
        kind: kind,
        onTap: press == null ? null : () => press(ref),
      );
    }

    RaftDescriptionEntry field(ActionCardElement element) {
      final props = element.props;
      final value = props['value'];
      final refs = value is List ? value.map(cardObject).toList() : null;
      final plain = refs == null ? copy(value) : refs.map(name).join(', ');
      final maxLines = _clamp(props['clamp']);
      final style = valueStyle.copyWith(
        fontFamily: refs == null && props['mono'] == true
            ? content.tokens.monoFont
            : null,
        color: props['muted'] == true
            ? content.tokens.ui.foregroundMuted
            : null,
      );
      final span = refs == null
          ? TextSpan(text: plain)
          : TextSpan(
              children: [
                for (final (index, ref) in refs.indexed) ...[
                  if (index > 0) const TextSpan(text: ', '),
                  reference(ref),
                ],
              ],
            );
      return RaftDescriptionEntry(
        copy(props['label']),
        plain,
        detailsChild: refs != null && refs.any(chip)
            ? Transform.translate(
                offset: Offset(refs.length == 1 ? -RaftSpace.x1_5 : 0, 0),
                child: Text.rich(
                  span,
                  style: style,
                  maxLines: maxLines,
                  overflow: maxLines == null ? null : TextOverflow.ellipsis,
                ),
              )
            : RaftCssText.rich(
                span,
                style: style,
                maxLines: maxLines,
                overflow: maxLines == null ? null : TextOverflow.ellipsis,
              ),
      );
    }

    Widget generic(RaftCardElement element) => RaftMessageCard(
      root: element,
      relativeTime: (at) => resourceRelativeTime(
        at.toIso8601String(),
        chinese: Localizations.localeOf(context).languageCode == 'zh',
      ),
      duration: (start, end) {
        final seconds = ((end ?? DateTime.now()).difference(start).inSeconds)
            .clamp(0, 1 << 31);
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
      },
    ).buildBody(context);

    List<Widget> render(ActionCardElement element, {bool top = false}) {
      final props = element.props;
      switch (element.type) {
        case 'Stack':
          final children = element.children;
          final role = props['role'];
          final row = props['direction'] == 'row';
          if (role == 'actions' ||
              (row &&
                  children.isNotEmpty &&
                  children.every((child) => child.type == 'Button'))) {
            final controls = children.expand(render).toList();
            return controls.isEmpty ? [] : [content.actions(controls)];
          }
          if (row) {
            final controls = children.expand(render).toList();
            return controls.isEmpty
                ? []
                : [
                    Wrap(
                      spacing: RaftSpace.x2,
                      runSpacing: RaftSpace.x1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: controls,
                    ),
                  ];
          }
          final reason =
              role == 'reason' ||
              (role == null &&
                  !top &&
                  children.lastOrNull?.props['tone'] == 'default' &&
                  (children.length == 1 ||
                      children.length == 2 &&
                          children.first.props['tone'] == 'muted'));
          if (reason &&
              children.isNotEmpty &&
              children.length <= 2 &&
              children.every((child) => child.type == 'Text')) {
            return [
              content.hint(
                label: children.length == 2
                    ? copy(children.first.props['text'])
                    : null,
                body: copy(children.last.props['text']),
                maxLines: _clamp(children.last.props['clamp']),
              ),
            ];
          }
          final visible = children
              .where(
                (node) =>
                    node.type != 'Field' || !hiddenFields.contains(node.id),
              )
              .toList();
          final groups = <Widget>[];
          for (var index = 0; index < visible.length;) {
            final node = visible[index++];
            if (node.type == 'Field' || node.type == 'Button') {
              final run = [node];
              while (index < visible.length &&
                  visible[index].type == node.type) {
                run.add(visible[index++]);
              }
              if (node.type == 'Field') {
                groups.add(
                  content.properties(
                    run.map(field).toList(),
                    fitLabels: fitLabels,
                  ),
                );
              } else {
                final controls = run.expand(render).toList();
                if (controls.isNotEmpty) groups.add(content.actions(controls));
              }
            } else {
              groups.addAll(render(node));
            }
          }
          return groups;
        case 'Text':
          return [
            generic(
              RaftCardText(
                copy(props['text']),
                mono: props['mono'] == true,
                clamp: _clamp(props['clamp']),
                tone: switch (props['tone']) {
                  'muted' => RaftCardTextTone.muted,
                  'warning' => RaftCardTextTone.warning,
                  _ => RaftCardTextTone.normal,
                },
              ),
            ),
          ];
        case 'Badge':
          return [generic(RaftCardBadge(copy(props['text'])))];
        case 'RelativeTime':
          final at = DateTime.tryParse('${props['at']}');
          return at == null ? [] : [generic(RaftCardRelativeTime(at))];
        case 'Duration':
          final start = DateTime.tryParse('${props['start']}');
          final end = DateTime.tryParse('${props['end']}');
          return start == null ? [] : [generic(RaftCardDuration(start, end))];
        case 'Field':
          return hiddenFields.contains(element.id)
              ? []
              : [
                  content.properties([field(element)], fitLabels: fitLabels),
                ];
        case 'EntityRef':
          return [RaftCssText.rich(reference(props), style: valueStyle)];
        case 'Notice':
          return [content.notice(copy(props['text']))];
        case 'ScopeList':
          final scopes = cardList(props['scopes'])
              .whereType<String>()
              .map((scope) => scope.trim())
              .where((scope) => scope.isNotEmpty)
              .toSet();
          return [
            content.scopes(context, [
              for (final scope in scopes)
                (scope: scope, copy: integrationScopeCopy[scope]),
            ]),
          ];
        case 'Button':
          final control = button?.call(context, element);
          return control == null ? [] : [control];
      }
      return [];
    }

    return render(root, top: true);
  }

  static int? _clamp(Object? value) => switch (value) {
    final int lines when lines >= 1 && lines <= 6 => lines,
    _ => null,
  };
}
