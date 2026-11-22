import 'package:flutter/material.dart';

import 'components.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'theme.dart';

class RaftServerAccessDeniedPage extends StatelessWidget {
  const RaftServerAccessDeniedPage({
    super.key,
    required this.onContinue,
    this.serverName,
  });

  final String? serverName;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Material(
      color: t.sidebar,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            primary: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: RaftEmptyState(
                title: raftText(context, 'Server not found'),
                titleHeading: true,
                detail: raftTextZh(
                  context,
                  'The link may be out of date, or you haven’t joined this server.',
                  '链接可能已失效，或者你没有加入这个服务器。',
                ),
                glyph: RaftGlyph.serverOff,
                action: RaftButton(
                  key: const ValueKey('server-denied-continue'),
                  label: serverName == null
                      ? raftTextZh(context, 'Choose a server', '选择一个服务器')
                      : raftTextZh(
                          context,
                          'Back to {name}',
                          '回到 {name}',
                        ).replaceAll('{name}', serverName!),
                  size: RaftButtonRecipeSize.md,
                  onPressed: onContinue,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
