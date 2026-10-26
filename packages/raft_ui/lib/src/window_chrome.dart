import 'package:flutter/widgets.dart';

/// Native window controls can occupy part of a full-size Flutter view. The
/// desktop host declares that region once; root previews keep their content
/// outside it, regardless of which page opened them. Ordinary page layout is
/// unchanged. Hosts whose title bar is already outside Flutter use zero.
class RaftWindowChromeScope extends InheritedWidget {
  const RaftWindowChromeScope({
    super.key,
    required this.overlayInsets,
    required super.child,
  });

  final EdgeInsets overlayInsets;

  static EdgeInsets overlayInsetsOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<RaftWindowChromeScope>()
          ?.overlayInsets ??
      EdgeInsets.zero;

  @override
  bool updateShouldNotify(RaftWindowChromeScope oldWidget) =>
      overlayInsets != oldWidget.overlayInsets;
}

/// Consumes the host's window-control region once, including while resizing or
/// entering fullscreen. Nested preview content must not reserve it again.
class RaftWindowChromePadding extends StatelessWidget {
  const RaftWindowChromePadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: RaftWindowChromeScope.overlayInsetsOf(context),
    child: RaftWindowChromeScope(overlayInsets: EdgeInsets.zero, child: child),
  );
}
