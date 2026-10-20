import 'package:flutter/widgets.dart';

/// How a link in rendered markdown opens, for every host that has no handler
/// of its own (forwarded bundles, documents, attachment comments, release
/// notes). Web's `MarkdownLink` is the one canonical renderer: ordinary links
/// open in a new tab, custom-protocol links ask first. A subtree with no scope
/// keeps links inert, as previews and tests do.
class RaftLinkScope extends InheritedWidget {
  const RaftLinkScope({super.key, required this.open, required super.child});

  /// Opens [href]; the context is the link's own, for a confirmation dialog.
  final Future<void> Function(BuildContext context, String href) open;

  /// The handler to use in [context], or null without a scope.
  static ValueChanged<String>? handlerOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<RaftLinkScope>();
    if (scope == null) return null;
    return (href) => scope.open(context, href);
  }

  @override
  bool updateShouldNotify(RaftLinkScope old) => open != old.open;
}
