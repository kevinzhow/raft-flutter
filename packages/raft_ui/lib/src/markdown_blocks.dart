/// Splits a long Markdown document into blocks of roughly [target] characters
/// that render on their own (so a list builds only the blocks on screen).
///
/// Cuts fall only where no construct spans them: never inside a fenced code
/// block, and only before an ATX heading, or after a blank line that is followed by a
/// paragraph, a fence or a thematic break (never inside a list,
/// table, quote or indented block). Link reference definitions are repeated at
/// the end of every block, so `[text][ref]` resolves wherever it appears.
List<String> raftSplitMarkdownBlocks(String markdown, {int target = 6000}) {
  final lines = markdown.split('\n');
  final definition = RegExp(r'^ {0,3}\[[^\]\n]+\]:\s*\S+');
  final fence = RegExp(r'^ {0,3}(`{3,}|~{3,})');
  final heading = RegExp(r'^ {0,3}#{1,6}(\s|$)');
  final rule = RegExp(r'^ {0,3}([-*_])( ?\1){2,}\s*$');
  final plain = RegExp(
    r'^(?! {4}|\t| {0,3}([-*+]|\d+[.)])(\s|$)| {0,3}>| {0,3}\|)\S',
  );

  final definitions = <String>[];
  final cuts = <int>[0]; // Start line of each block.
  var open = '';
  var size = 0, previousBlank = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final marker = fence.firstMatch(line)?.group(1);
    if (open.isNotEmpty) {
      if (marker != null &&
          marker[0] == open[0] &&
          marker.length >= open.length &&
          line.trim() == marker) {
        open = '';
      }
      size += line.length + 1;
      previousBlank = false;
      continue;
    }
    if (marker != null) {
      if (size >= target && previousBlank && i > cuts.last) {
        cuts.add(i);
        size = 0;
      }
      open = marker;
      size += line.length + 1;
      previousBlank = false;
      continue;
    }
    if (definition.hasMatch(line)) definitions.add(line.trim());
    final canCut =
        size >= target &&
        i > cuts.last &&
        (heading.hasMatch(line) ||
            (previousBlank && (rule.hasMatch(line) || plain.hasMatch(line))));
    if (canCut) {
      cuts.add(i);
      size = 0;
    }
    size += line.length + 1;
    previousBlank = line.trim().isEmpty;
  }
  final blocks = <String>[];
  for (var b = 0; b < cuts.length; b++) {
    final end = b + 1 < cuts.length ? cuts[b + 1] : lines.length;
    final text = lines.sublist(cuts[b], end).join('\n').trimRight();
    if (text.isEmpty) continue;
    blocks.add(
      definitions.isEmpty || cuts.length == 1
          ? text
          : '$text\n\n${definitions.join('\n')}',
    );
  }
  return blocks.isEmpty ? [markdown] : blocks;
}
