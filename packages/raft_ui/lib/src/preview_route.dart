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
}
