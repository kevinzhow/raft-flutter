import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Finder findSearchText(String text, {bool containing = false}) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final displayed =
        widget.data ?? widget.textSpan!.toPlainText(includePlaceholders: false);
    return containing ? displayed.contains(text) : displayed == text;
  }, description: 'Search text ${containing ? 'containing ' : ''}"$text"');
}
