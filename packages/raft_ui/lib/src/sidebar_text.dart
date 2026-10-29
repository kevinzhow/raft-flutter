import 'package:flutter/widgets.dart';

import 'panel_layout.dart' show RaftCssText;
import 'theme.dart';

/// Sidebar line boxes follow the mounted CSS; frozen packs keep their
/// original Flutter paragraph metrics. Content still follows system text size.
class RaftSidebarText extends StatelessWidget {
  const RaftSidebarText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
    this.textScaler,
  }) : span = null;
  const RaftSidebarText.rich(
    InlineSpan this.span, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
    this.textScaler,
  }) : data = null;

  final String? data;
  final InlineSpan? span;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    final css =
        RaftTokens.of(context).option('sidebar.textLayout', or: 'natural') ==
        'css';
    final Widget text;
    if (css) {
      text = span == null
          ? RaftCssText(
              data!,
              style: style,
              maxLines: maxLines,
              overflow: overflow,
              textAlign: textAlign,
              softWrap: softWrap,
            )
          : RaftCssText.rich(
              span!,
              style: style,
              maxLines: maxLines,
              overflow: overflow,
              textAlign: textAlign,
              softWrap: softWrap,
            );
    } else {
      text = span == null
          ? Text(
              data!,
              style: style,
              maxLines: maxLines,
              overflow: overflow,
              textAlign: textAlign,
              softWrap: softWrap,
            )
          : Text.rich(
              span!,
              style: style,
              maxLines: maxLines,
              overflow: overflow,
              textAlign: textAlign,
              softWrap: softWrap,
            );
    }
    return textScaler == null
        ? text
        : MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: text,
          );
  }
}
