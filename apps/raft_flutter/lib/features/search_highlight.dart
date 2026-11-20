import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

class SearchHighlight extends StatelessWidget {
  const SearchHighlight({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    this.maxLines = 2,
  });

  final String text, query;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final recipe = RaftSearchRecipe(RaftTokens.of(context), mobile: false);
    final terms = query.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final pattern = terms.isEmpty
        ? null
        : RegExp(terms.map(RegExp.escape).join('|'), caseSensitive: false);
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in pattern?.allMatches(text) ?? const <RegExpMatch>[]) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.addAll(recipe.match(match.group(0)!));
      start = match.end;
    }
    spans.add(TextSpan(text: text.substring(start)));
    return RaftCssLineBox(
      style: style,
      textScaler: MediaQuery.textScalerOf(context),
      physicalBaseline: true,
      child: RaftUnderlines(
        child: Text.rich(
          TextSpan(children: spans),
          semanticsLabel: text,
          style: style,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
