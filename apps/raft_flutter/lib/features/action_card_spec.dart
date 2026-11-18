import 'package:flutter/widgets.dart';

typedef CardJson = Map<String, Object?>;

CardJson cardObject(Object? raw) => switch (raw) {
  final Map<String, Object?> value => value,
  _ => const {},
};

List<Object?> cardList(Object? raw) => raw is List ? raw : const [];
String? cardString(Object? raw) => raw is String && raw.isNotEmpty ? raw : null;

enum ActionCardCommand { execute, form, intent, target, url, browser }

typedef ActionCardPress = ({
  ActionCardCommand command,
  String? argument,
  String? gate,
  CardJson? target,
});

const actionCardBrowser = (
  command: ActionCardCommand.browser,
  argument: null,
  gate: null,
  target: null,
);

class ActionCardElement {
  const ActionCardElement(this.id, this.type, this.props, this.children);

  final String id, type;
  final CardJson props;
  final List<ActionCardElement> children;

  Iterable<ActionCardElement> get nodes sync* {
    yield this;
    for (final child in children) {
      yield* child.nodes;
    }
  }

  ActionCardPress get press {
    final raw = cardObject(props['action']);
    if (props.keys.any(
      (key) => !const {
        'label',
        'emphasis',
        'action',
        'disabledReason',
      }.contains(key),
    )) {
      return actionCardBrowser;
    }
    bool keys(Set<String> allowed) => raw.keys.every(allowed.contains);
    final form = cardString(raw['form']);
    final intent = cardString(raw['intent']);
    final confirm = cardString(raw['confirm']);
    final url = cardString(raw['url']);
    final target = cardObject(raw['target']);
    final gate = cardString(raw['gate']);
    return switch (raw['kind']) {
      'execute'
          when keys({'kind', 'confirm'}) &&
              (!raw.containsKey('confirm') || confirm != null) =>
        (
          command: ActionCardCommand.execute,
          argument: confirm,
          gate: null,
          target: null,
        ),
      'open_form' when keys({'kind', 'form'}) && form != null => (
        command: ActionCardCommand.form,
        argument: form,
        gate: null,
        target: null,
      ),
      'open'
          when keys({'kind', 'intent', 'gate'}) &&
              intent != null &&
              (!raw.containsKey('gate') ||
                  intent == 'upgrade_dialog' && gate != null) =>
        (
          command: ActionCardCommand.intent,
          argument: intent,
          gate: gate,
          target: null,
        ),
      'navigate' when keys({'kind', 'target'}) && target.isNotEmpty => (
        command: ActionCardCommand.target,
        argument: null,
        gate: null,
        target: target,
      ),
      'navigate' when keys({'kind', 'url'}) && url != null => (
        command: ActionCardCommand.url,
        argument: url,
        gate: null,
        target: null,
      ),
      _ => actionCardBrowser,
    };
  }
}

class ActionCardSpec {
  const ActionCardSpec._(
    this.title,
    this.icon,
    this.body,
    this.result,
    this.confirms,
    this.forms,
  );

  final CardJson title;
  final String? icon;
  final ActionCardElement body;
  final ActionCardElement? result;
  final CardJson confirms, forms;

  static ActionCardSpec? read(Object? raw) {
    final value = cardObject(raw);
    final title = cardObject(value['title']);
    if (value['catalog'] != 'action-card.v1' || !_isCopy(title)) return null;
    final body = readTree(value['spec']);
    final result = readTree(value['result']);
    if (body == null || value['result'] != null && result == null) return null;
    final confirms = cardObject(value['confirms']);
    final forms = cardObject(value['forms']);
    if (confirms.length > 2 || forms.length > 2) return null;
    return ActionCardSpec._(
      title,
      cardString(value['icon']),
      body,
      result,
      confirms,
      forms,
    );
  }

  ({CardJson data, ActionCardElement body})? confirmation(String id) {
    final value = cardObject(confirms[id]);
    if (value.keys.any(
          (key) => !const {'title', 'confirmLabel', 'spec'}.contains(key),
        ) ||
        !_isCopy(value['title']) ||
        !_isCopy(value['confirmLabel'])) {
      return null;
    }
    final body = readTree(value['spec'], confirmation: true);
    return body == null ? null : (data: value, body: body);
  }

  static bool _isCopy(Object? raw) =>
      cardString(cardObject(cardObject(raw)['text'])['en']) != null;

  static ActionCardElement? readTree(Object? raw, {bool confirmation = false}) {
    final tree = cardObject(raw);
    final elements = cardObject(tree['elements']);
    if (elements.isEmpty || elements.length > (confirmation ? 12 : 24)) {
      return null;
    }
    final seen = <String>{};
    var buttonCount = 0;
    ActionCardElement? read(Object? id, int depth) {
      if (id is! String ||
          const {'constructor', 'prototype', '__proto__'}.contains(id) ||
          depth > 4 ||
          !seen.add(id)) {
        return null;
      }
      final raw = cardObject(elements[id]);
      final type = cardString(raw['type']);
      if (type == null ||
          !const {
            'Stack',
            'Text',
            'Badge',
            'RelativeTime',
            'Duration',
            'Field',
            'EntityRef',
            'ScopeList',
            'Notice',
            'Button',
          }.contains(type)) {
        return null;
      }
      if (type == 'Button' && (confirmation || ++buttonCount > 2)) return null;
      final rawChildren = raw['children'];
      final children = <ActionCardElement>[];
      if (rawChildren != null) {
        if (type != 'Stack' ||
            rawChildren is! List ||
            rawChildren.length > 12) {
          return null;
        }
        for (final child in rawChildren) {
          final element = read(child, depth + 1);
          if (element == null) return null;
          children.add(element);
        }
      }
      final props = cardObject(raw['props']);
      if (type == 'Button' && !_isCopy(props['label'])) return null;
      return ActionCardElement(id, type, props, children);
    }

    final root = read(tree['root'], 0);
    return seen.length == elements.length ? root : null;
  }
}

typedef ActionCardEntityName = String Function(CardJson reference);

String actionCardCopy(
  BuildContext context,
  Object? raw,
  ActionCardEntityName entityName,
) {
  if (raw is String) return raw;
  final copy = cardObject(raw);
  final translations = cardObject(copy['text']);
  final locale = Localizations.localeOf(context);
  final language = locale.languageCode.toLowerCase();
  final template =
      cardString(translations[locale.toLanguageTag().toLowerCase()]) ??
      (language == 'zh' ? cardString(translations['zh-cn']) : null) ??
      cardString(translations[language]) ??
      cardString(translations['en']) ??
      '';
  final params = cardObject(copy['params']);
  return template.replaceAllMapped(RegExp(r'\{\{|\}\}|\{([A-Za-z][\w]*)\}'), (
    match,
  ) {
    if (match[0] == '{{') return '{';
    if (match[0] == '}}') return '}';
    final value = params[match[1]];
    return switch (value) {
      String() || num() => '$value',
      Map() => entityName(cardObject(value)),
      _ => match[0] ?? '',
    };
  });
}
