// Web MessageInput "unfinished uploads" banner
// (`message.composer.recoverableUploadsTitle`): a warning Banner listing the
// viewer's direct uploads this device can no longer continue, each with a
// "Cancel upload" action. The app owns the list and the cancellation.
import 'package:flutter/widgets.dart';

import 'banner.dart';
import 'dialog_card.dart' show RaftRecipeButton;
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'theme.dart';

@immutable
class RaftComposerRecoverableUpload {
  const RaftComposerRecoverableUpload({required this.id, required this.name});
  final String id, name;
}

class RaftComposerRecoverableUploads extends StatelessWidget {
  const RaftComposerRecoverableUploads({
    super.key,
    required this.items,
    required this.onCancel,
  });
  final List<RaftComposerRecoverableUpload> items;
  final ValueChanged<RaftComposerRecoverableUpload> onCancel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    return RaftBanner(
      size: RaftBannerRecipeSize.sm,
      title: items.length == 1
          ? 'One unfinished upload'
          : raftFormat(context, '{count} unfinished uploads', {
              'count': items.length,
            }),
      description: 'This app no longer has the original file, so it cannot safely continue the upload. Cancel it here, or let the original window finish uploading.',
      footer: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items)
              Container(
                key: ValueKey('recoverable-upload-${item.id}'),
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: t.colors['line-hairline']!),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      label: raftFormat(
                        context,
                        'Cancel unfinished upload {file}',
                        {'file': item.name},
                      ),
                      child: RaftRecipeButton(
                        label: raftText(context, 'Cancel upload'),
                        variant: RaftButtonRecipeVariant.outline,
                        size: RaftButtonRecipeSize.sm,
                        onPressed: () => onCancel(item),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
