// Web ChannelDescription (components/channel/ChannelDescription.tsx): the
// channel description in the header renders http(s) links as links. The
// segmentation is the Web one: a URL candidate loses its trailing sentence
// punctuation and any closing bracket without an opener, and only a candidate
// that parses as http(s) with a real host becomes a link.
library;

/// One piece of a description: plain text or a link target.
class RaftDescriptionSegment {
  const RaftDescriptionSegment.text(this.value) : link = false;
  const RaftDescriptionSegment.link(this.value) : link = true;
  final String value;
  final bool link;

  @override
  bool operator ==(Object other) =>
      other is RaftDescriptionSegment &&
      other.value == value &&
      other.link == link;
  @override
  int get hashCode => Object.hash(value, link);
  @override
  String toString() => link ? 'link($value)' : 'text($value)';
}

final _candidate = RegExp(
  r"https?://[a-z\d\-._~:/?#@!$&'()*+,;=%\[\]]+",
  caseSensitive: false,
);
final _trailing = RegExp(r"""[.,!?;:。，！？；：'"“”‘’]+$""", unicode: true);
const _closing = {')': '(', ']': '[', '}': '{', '）': '（', '】': '【', '》': '《'};

int _count(String value, String character) =>
    character.allMatches(value).length;

String _trimTrailing(String candidate) {
  var value = candidate.replaceFirst(_trailing, '');
  while (value.isNotEmpty) {
    final last = String.fromCharCode(value.runes.last);
    final opening = _closing[last];
    if (opening == null) break;
    if (_count(value, last) <= _count(value, opening)) break;
    value = value.substring(0, value.length - last.length);
  }
  return value;
}

bool _safeHttp(String candidate) {
  final uri = Uri.tryParse(candidate);
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  return (scheme == 'http' || scheme == 'https') &&
      RegExp(r'[a-z\d]', caseSensitive: false).hasMatch(uri.host);
}

/// Splits [description] into text and link segments.
List<RaftDescriptionSegment> raftSegmentChannelDescription(String description) {
  final segments = <RaftDescriptionSegment>[];
  void text(String value) {
    if (value.isEmpty) return;
    if (segments.isNotEmpty && !segments.last.link) {
      segments[segments.length - 1] = RaftDescriptionSegment.text(
        segments.last.value + value,
      );
    } else {
      segments.add(RaftDescriptionSegment.text(value));
    }
  }

  var cursor = 0;
  for (final match in _candidate.allMatches(description)) {
    text(description.substring(cursor, match.start));
    final raw = match[0]!;
    final link = _trimTrailing(raw);
    if (link.isNotEmpty && _safeHttp(link)) {
      segments.add(RaftDescriptionSegment.link(link));
      text(raw.substring(link.length));
    } else {
      text(raw);
    }
    cursor = match.end;
  }
  text(description.substring(cursor));
  return segments;
}
