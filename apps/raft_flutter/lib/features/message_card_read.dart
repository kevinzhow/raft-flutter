import 'package:raft_ui/raft_ui.dart';

// Card messages (Web 1.24 RFC 082, components/message/messageCardRead.ts and
// shared messageCard.ts): the card is `actionMetadata.card` of a message
// whose kind is `message-card`, read with the stored-card schema every time
// it arrives. A message this client cannot draw (another kind, a card it
// cannot read, a revision it does not understand) is drawn as its `content`,
// the fallback text: never a blank card.

const messageCardKind = 'message-card';

/// A card this client can draw.
typedef ReadMessageCard = ({
  RaftCardHeader? header,
  RaftCardElement root,
  int revision,
  DateTime? updatedAt,
});

const _maxElements = 16, _maxDepth = 4, _maxButtons = 4, _maxChildren = 12;
final _elementId = RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]{0,63}$');
const _reservedIds = {'constructor', 'prototype', '__proto__'};
final _rfc3339Utc = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?Z$',
);
const _badgeTones = {
  'neutral',
  'review',
  'progress',
  'warning',
  'action',
  'done',
  'closed',
};

class _Invalid implements Exception {
  const _Invalid();
}

Never _invalid() => throw const _Invalid();

int _codePoints(String value) => value.runes.length;

String _text(Object? value, int min, int max) {
  if (value is! String) _invalid();
  final n = _codePoints(value);
  if (n < min || n > max) _invalid();
  return value;
}

/// Refuses a key the schema has no place for (`z.strictObject`).
Map<String, dynamic> _object(Object? value, Set<String> keys) {
  if (value is! Map) _invalid();
  for (final key in value.keys) {
    if (!keys.contains(key)) _invalid();
  }
  return Map<String, dynamic>.from(value);
}

bool _bool(Object? value) => switch (value) {
  null => false,
  final bool b => b,
  _ => _invalid(),
};

DateTime _time(Object? value) {
  if (value is! String || value.length > 40) _invalid();
  final m = _rfc3339Utc.firstMatch(value);
  if (m == null) _invalid();
  final [year, month, day, hour, minute, second] = [
    for (var i = 1; i <= 6; i++) int.parse(m[i]!),
  ];
  if (month < 1 || month > 12 || hour > 23 || minute > 59 || second > 59) {
    _invalid();
  }
  final days = DateTime.utc(year, month + 1, 0).day;
  if (day < 1 || day > days) _invalid();
  return DateTime.parse(value);
}

/// A public HTTPS URL: no credentials, port, fragment or IP literal, a
/// dotted host, at most 2000 characters (shared `publicPreviewUrl`).
Uri? publicCardUrl(String raw) {
  final url = Uri.tryParse(raw);
  if (url == null ||
      url.scheme != 'https' ||
      url.userInfo.isNotEmpty ||
      url.hasFragment ||
      url.hasPort ||
      !url.host.contains('.') ||
      RegExp(r'[\[\]:]').hasMatch(url.host) ||
      RegExp(r'^\d+(\.\d+){3}$').hasMatch(url.host) ||
      raw.length > 2000) {
    return null;
  }
  return url;
}

RaftCardHeader _header(Object? value) {
  final header = _object(value, {'title', 'subtitle', 'tags'});
  final subtitle = header['subtitle'] == null
      ? null
      : _text(header['subtitle'], 1, 100);
  if (subtitle != null &&
      RegExp(r'\r\n|[\n\r\v\f\x1c\x1d\x1e\x85  ]').hasMatch(subtitle)) {
    _invalid();
  }
  final tags = header['tags'];
  if (tags != null && (tags is! List || tags.length > 3)) _invalid();
  return RaftCardHeader(
    title: _text(header['title'], 1, 100),
    subtitle: subtitle,
    tags: [
      for (final tag in (tags as List?) ?? const [])
        () {
          final t = _object(tag, {'text', 'tone'});
          final tone = RaftCardTagTone.values
              .where((v) => v.name == t['tone'])
              .firstOrNull;
          if (tone == null) _invalid();
          return (_text(t['text'], 1, 24), tone);
        }(),
    ],
  );
}

/// The card to draw for a message's `actionMetadata`; null: draw `content`.
ReadMessageCard? readMessageCard(Object? actionMetadata) {
  if (actionMetadata is! Map || actionMetadata['kind'] != messageCardKind) {
    return null;
  }
  final revision = actionMetadata['revision'];
  if (revision is! int || revision < 1 || actionMetadata['card'] is! Map) {
    return null;
  }
  try {
    final card = _object(actionMetadata['card'], {
      'version',
      'header',
      'root',
      'elements',
    });
    if (card['version'] != 1) _invalid();
    final rootId = card['root'];
    final elements = card['elements'];
    if (rootId is! String || !_elementId.hasMatch(rootId)) _invalid();
    if (elements is! Map || elements.length > _maxElements) _invalid();
    for (final id in elements.keys) {
      if (id is! String ||
          !_elementId.hasMatch(id) ||
          _reservedIds.contains(id)) {
        _invalid();
      }
    }
    var buttons = 0;
    final visited = <String>{};
    RaftCardElement build(String id, int depth) {
      final raw = elements[id];
      if (raw == null || visited.contains(id) || depth > _maxDepth) _invalid();
      visited.add(id);
      final node = _object(raw, {'type', 'props', 'children'});
      final type = node['type'];
      if (type != 'Stack' && node.containsKey('children')) _invalid();
      Map<String, dynamic> props(Set<String> keys) =>
          _object(node['props'], keys);
      switch (type) {
        case 'Stack':
          final p = props({'direction', 'wrap'});
          final direction = p['direction'] ?? 'column';
          if (direction != 'column' && direction != 'row') _invalid();
          final wrap = _bool(p['wrap']);
          if (wrap && direction != 'row') _invalid();
          final children = node['children'];
          if (children != null &&
              (children is! List || children.length > _maxChildren)) {
            _invalid();
          }
          return RaftCardStack(
            row: direction == 'row',
            wrap: wrap,
            children: [
              for (final child in (children as List?) ?? const [])
                if (child is String && _elementId.hasMatch(child))
                  build(child, depth + 1)
                else
                  _invalid(),
            ],
          );
        case 'Text':
          final p = props({'text', 'tone', 'mono'});
          final tone = switch (p['tone'] ?? 'default') {
            'default' => RaftCardTextTone.normal,
            'muted' => RaftCardTextTone.muted,
            'warning' => RaftCardTextTone.warning,
            _ => _invalid(),
          };
          return RaftCardText(
            _text(p['text'], 1, 500),
            tone: tone,
            mono: _bool(p['mono']),
          );
        case 'Badge':
          final p = props({'text', 'tone'});
          if (!_badgeTones.contains(p['tone'] ?? 'neutral')) _invalid();
          return RaftCardBadge(_text(p['text'], 1, 60));
        case 'RelativeTime':
          return RaftCardRelativeTime(_time(props({'at'})['at']));
        case 'Duration':
          final p = props({'start', 'end'});
          final start = _time(p['start']);
          final end = p['end'] == null ? null : _time(p['end']);
          if (end != null && end.isBefore(start)) _invalid();
          return RaftCardDuration(start, end);
        case 'Button':
          buttons++;
          final p = props({
            'label',
            'variant',
            'action',
            'disabledReason',
            'open',
          });
          final action = _object(p['action'], {'kind', 'url'});
          if (action['kind'] != 'navigate' || action['url'] is! String) {
            _invalid();
          }
          final url = publicCardUrl(action['url'] as String);
          if (url == null) _invalid();
          final variant = p['variant'] ?? 'default';
          if (variant != 'default' && variant != 'ghost') _invalid();
          final open = p['open'];
          if (open != null && open != 'tab' && open != 'beside') _invalid();
          return RaftCardButton(
            label: _text(p['label'], 1, 40),
            url: url.toString(),
            domain: url.host,
            ghost: variant == 'ghost',
            disabledReason: p['disabledReason'] == null
                ? null
                : _text(p['disabledReason'], 1, 200),
          );
        case 'Markdown':
          return RaftCardMarkdown(
            _text(props({'content'})['content'], 1, 2000),
          );
        case 'Fields':
          final items = props({'items'})['items'];
          if (items is! List || items.isEmpty || items.length > 8) _invalid();
          return RaftCardFields([
            for (final item in items)
              () {
                final i = _object(item, {'label', 'value', 'mono'});
                return (
                  _text(i['label'], 1, 40),
                  _text(i['value'], 1, 200),
                  _bool(i['mono']),
                );
              }(),
          ]);
        case 'Divider':
          props(const {});
          return const RaftCardDivider();
      }
      _invalid();
    }

    final root = build(rootId, 0);
    if (visited.length != elements.length || buttons > _maxButtons) _invalid();
    final updated = actionMetadata['updatedAt'];
    return (
      header: card['header'] == null ? null : _header(card['header']),
      root: root,
      revision: revision,
      updatedAt: updated is String ? DateTime.tryParse(updated) : null,
    );
  } on _Invalid {
    return null;
  }
}
