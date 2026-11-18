import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'action_card_spec.dart';
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
    required this.resolvePress,
    required this.onPress,
    this.onEntity,
    this.blocked,
    this.error,
    this.busy = false,
    this.inlineForm,
    this.trailing,
    this.hiddenButton,
    this.completedOnCurrentPlan,
  });

  final ActionCardSpec spec;
  final CardJson metadata;
  final ActionCardEntityName entityName;
  final ActionCardPress Function(ActionCardElement) resolvePress;
  final void Function(ActionCardPress, ActionCardElement)? onPress;
  final ValueChanged<CardJson>? onEntity;
  final String? blocked, error;
  final bool busy;
  final Widget? inlineForm, trailing;
  final String? hiddenButton, completedOnCurrentPlan;

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
    final at = DateTime.tryParse(
      '${metadata['expiresAt'] ?? cardObject(metadata['action'])['expiresAt']}',
    );
    final committedAt = DateTime.tryParse('${metadata['executedAt']}');
    final description = done
        ? widget.completedOnCurrentPlan ??
              [
                if (by != null)
                  raftFormat(context, 'Committed by {name}', {'name': by}),
                if (committedAt != null) _formatDate(context, committedAt),
                if (!expanded && headline != null) '→ $headline',
              ].join(' ')
        : expired && at != null
        ? raftFormat(
            context,
            'Expired on {date}. Ask the agent to send a new request.',
            {'date': _formatDate(context, at)},
          )
        : widget.blocked;
    final serverName = cardString(metadata['targetServerName']);
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
      expanded: expanded,
      onToggle: status == null || widget.onPress == null
          ? null
          : () => setState(() => _expanded = !expanded),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: RaftSpace.x2,
        children: [
          if (serverName != null)
            RaftActionNote(
              raftFormat(context, 'Runs on {server}', {'server': serverName}),
            ),
          ActionCardSpecTree(
            root: card.body,
            entityName: widget.entityName,
            onEntity: widget.onEntity,
            button: done || ended ? null : _button,
          ),
          if (!done && !ended) ?widget.inlineForm,
          if (done && result != null)
            ActionCardSpecTree(
              root: result,
              entityName: widget.entityName,
              onEntity: widget.onEntity,
              button: (context, node) => _button(context, node, result: true),
            ),
          ?widget.trailing,
          if (!done && widget.error != null)
            RaftErrorBanner(widget.error ?? '', small: true),
        ],
      ),
    );
  }

  Widget? _button(
    BuildContext context,
    ActionCardElement node, {
    bool result = false,
  }) {
    if (widget.hiddenButton == node.id && !result) return null;
    final press = widget.resolvePress(node);
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

String _formatDate(BuildContext context, DateTime at) {
  final local = at.toLocal();
  final dates = MaterialLocalizations.of(context);
  return '${dates.formatShortMonthDay(local)} '
      '${dates.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

class ActionCardSpecTree extends StatelessWidget {
  const ActionCardSpecTree({
    super.key,
    required this.root,
    required this.entityName,
    this.onEntity,
    this.button,
  });

  final ActionCardElement root;
  final ActionCardEntityName entityName;
  final ValueChanged<CardJson>? onEntity;
  final Widget? Function(BuildContext, ActionCardElement)? button;

  @override
  Widget build(BuildContext context) {
    String copy(Object? raw) => actionCardCopy(context, raw, entityName);
    RaftCardElement? node(ActionCardElement element) {
      final props = element.props;
      switch (element.type) {
        case 'Stack':
          final row = props['direction'] == 'row';
          final children = element.children.map(node).nonNulls.toList();
          if (children.isEmpty) return null;
          return RaftCardStack(
            children: children,
            row: row && props['role'] != 'actions',
            wrap: props['wrap'] == true,
            actions: row && props['role'] == 'actions',
          );
        case 'Text':
          return RaftCardText(
            copy(props['text']),
            mono: props['mono'] == true,
            clamp: switch (props['clamp']) {
              final int value when value >= 1 && value <= 6 => value,
              _ => null,
            },
            tone: switch (props['tone']) {
              'muted' => RaftCardTextTone.muted,
              'warning' => RaftCardTextTone.warning,
              _ => RaftCardTextTone.normal,
            },
          );
        case 'Badge':
          return RaftCardBadge(copy(props['text']));
        case 'RelativeTime':
          final at = DateTime.tryParse('${props['at']}');
          return at == null ? null : RaftCardRelativeTime(at);
        case 'Duration':
          final start = DateTime.tryParse('${props['start']}');
          final end = DateTime.tryParse('${props['end']}');
          return start == null ? null : RaftCardDuration(start, end);
        case 'Field':
          final value = props['value'];
          return RaftCardSlot(
            RaftActionField(
              label: copy(props['label']),
              value: value is List
                  ? value.map((item) => entityName(cardObject(item))).join(', ')
                  : copy(value),
            ),
          );
        case 'EntityRef':
          final label = entityName(props);
          return onEntity == null
              ? RaftCardText(label)
              : RaftCardSlot(
                  RaftButton(
                    label: label,
                    uiVariant: RaftButtonVariant.ghost,
                    uiSize: RaftButtonSize.sm,
                    onPressed: () => onEntity?.call(props),
                  ),
                );
        case 'Notice':
          return RaftCardSlot(
            props['tone'] == 'warning'
                ? RaftActionWarningBox(copy(props['text']))
                : RaftActionNote(copy(props['text'])),
          );
        case 'ScopeList':
          return RaftCardSlot(
            RaftActionScopeList(
              scopes: [
                for (final scope in cardList(
                  props['scopes'],
                ).whereType<String>())
                  (scope: scope, copy: ''),
              ],
            ),
          );
        case 'Button':
          final control = button?.call(context, element);
          return control == null ? null : RaftCardSlot(control);
      }
      return null;
    }

    final element = node(root);
    if (element == null) return const SizedBox.shrink();
    return RaftMessageCard(
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
  }
}
