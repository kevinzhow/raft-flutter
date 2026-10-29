import 'package:flutter/material.dart';

import 'window_chrome.dart';

/// Marks a content preview that closes before the containing desktop window.
///
/// A preview can be a page route on compact windows and still keep this policy
/// after the window grows. Ordinary navigation pages do not carry this marker.
abstract interface class RaftPreviewRoute {}

/// Presents a document preview as a page while retaining preview close behavior.
class RaftPreviewPageRoute<T> extends MaterialPageRoute<T>
    implements RaftPreviewRoute {
  RaftPreviewPageRoute({required WidgetBuilder builder, super.settings})
    : super(
        builder: (context) => RaftWindowChromePadding(child: builder(context)),
      );

  bool _keepWindowChrome = false;

  @override
  void install() {
    _keepWindowChrome = RaftWindowChromeScope.hasHost(navigator!.context);
    super.install();
  }

  @override
  bool get opaque => !_keepWindowChrome;

  // A desktop preview occupies only the content below the window toolbar.
  // Material's whole-page transitions can snapshot or transform that toolbar.
  // Phones retain their native page transition and swipe-back behavior.
  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) =>
      !_keepWindowChrome && super.canTransitionFrom(previousRoute);

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _keepWindowChrome ? null : super.delegatedTransition;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _keepWindowChrome
      ? child
      : super.buildTransitions(context, animation, secondaryAnimation, child);
}
