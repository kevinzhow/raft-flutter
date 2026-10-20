import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web `markdownSanitizeSchema.ts` `MARKDOWN_EXTRA_HREF_PROTOCOLS`: the custom
/// URL schemes a message body may link to, on top of http, https and mailto.
/// Adding a scheme is a separate review upstream; this list mirrors it.
const customLinkProtocols = {'obsidian'};

/// Web `isCustomProtocolHref` for an allowed scheme: an `obsidian://` link
/// hands off to another application, so the reader confirms first. Every other
/// scheme (javascript:, file:, ...) is not a link at all.
bool isAllowedCustomProtocol(Uri uri) =>
    customLinkProtocols.contains(uri.scheme.toLowerCase());

/// Web `CustomProtocolLink` confirmation: names the protocol and shows the
/// target before the OS handler receives it. True when the reader confirms.
Future<bool> confirmCustomProtocolLink(BuildContext context, Uri uri) {
  final tokens = RaftTokens.of(context);
  return showRaftAlertDialog(
    context: context,
    title: raftText(context, 'Open external link?'),
    content: Column(
      key: const ValueKey('custom-protocol-link-confirm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      // `mt-1` between the sentence and the address.
      spacing: RaftSpace.x1,
      children: [
        RaftDialogDescription(
          raftFormat(
            context,
            'This link uses the {protocol} protocol and will open in an external application:',
            {'protocol': uri.scheme.toLowerCase()},
          ),
        ),
        // `mt-1 block break-all font-mono text-[0.875em]`.
        Text(
          uri.toString(),
          style: RaftTypography.mono(tokens, size: 12.25, line: 18),
        ),
      ],
    ),
    confirmLabel: raftText(context, 'Open link'),
    cancelLabel: raftText(context, 'Cancel'),
    // Web `AlertDialog`: Escape and Cancel close it, an outside press does not.
    barrierDismissible: false,
  );
}

/// Opens a link of a message body (Web MessageItem anchor): http, https and
/// mailto go to the system; an allowlisted custom scheme asks first (task
/// #734); every other scheme is not a link.
Future<void> openMessageLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (['https', 'http', 'mailto'].contains(uri.scheme)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (isAllowedCustomProtocol(uri) &&
      await confirmCustomProtocolLink(context, uri) &&
      context.mounted) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
