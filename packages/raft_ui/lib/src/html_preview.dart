import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;

import 'components.dart';
import 'localization.dart';
import 'theme.dart';

/// Pure native HTML presentation. No script interpreter, iframe, local-file
/// loader, remote image request or URL launcher belongs to this component.
String raftStaticHtml(String source) {
  if (source.length > 2 * 1024 * 1024) {
    throw const FormatException('The HTML is too large for a native preview.');
  }
  final document = parser.parse(source);
  final body = document.body!;
  const removed = {
    'script',
    'style',
    'iframe',
    'object',
    'embed',
    'link',
    'meta',
    'base',
    'input',
    'button',
    'select',
    'textarea',
    'canvas',
    'svg',
    'audio',
    'video',
    'source',
    'track',
    'applet',
    'template',
  };
  const attributes = {
    'href',
    'title',
    'dir',
    'colspan',
    'rowspan',
    'start',
    'type',
  };
  var count = 0;
  final pending = <dom.Element>[body];
  while (pending.isNotEmpty) {
    final element = pending.removeLast();
    if (++count > 4000) {
      throw const FormatException(
        'The HTML is too complex for a native preview.',
      );
    }
    if (removed.contains(element.localName)) {
      element.remove();
      continue;
    }
    if (element.localName == 'img') {
      final alt = element.attributes['alt']?.trim();
      element.replaceWith(
        dom.Element.tag('span')
          ..text = alt == null || alt.isEmpty ? '[Image]' : '[Image: $alt]',
      );
      continue;
    }
    element.attributes.removeWhere((name, value) => !attributes.contains(name));
    // No relative/base-resolved URL can authorize an application operation.
    if (element.attributes['href'] case final String href) {
      final uri = Uri.tryParse(href);
      if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
        element.attributes.remove('href');
      }
    }
    pending.addAll(element.children);
  }
  return body.innerHtml;
}

class RaftHtmlPreview extends StatelessWidget {
  const RaftHtmlPreview({
    super.key,
    required this.html,
    this.onLink,
    this.onInteractive,
    this.busy = false,
  });
  final String html;
  final void Function(String)? onLink;
  final VoidCallback? onInteractive;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftPanel(
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                raftText(context, 'Static HTML preview'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                raftText(
                  context,
                  'Scripts and images open in the interactive browser preview.',
                ),
              ),
              if (onInteractive != null)
                RaftButton(
                  label: 'Open interactive preview in browser',
                  onPressed: busy ? null : onInteractive,
                  busy: busy,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Material(
            color: t.panel,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectionArea(
                child: SingleChildScrollView(
                  child: HtmlWidget(
                    raftStaticHtml(html),
                    textStyle: TextStyle(color: t.ink, fontSize: 14),
                    onTapUrl: (url) {
                      onLink?.call(url);
                      return true;
                    },
                    // Defense in depth: sanitized data has no image source,
                    // and unexpected image elements render only text.
                    customWidgetBuilder: (element) {
                      if (element.localName == 'img') {
                        return Text(element.attributes['alt'] ?? '[Image]');
                      }
                      final href = element.attributes['href'];
                      if (element.localName == 'a' && href != null) {
                        return InlineCustomWidget(
                          child: Semantics(
                            link: true,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: onLink == null
                                  ? null
                                  : () => onLink!(href),
                              child: Text(element.text),
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
