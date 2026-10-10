import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/message_row_recipe.dart';
import 'src/message_translation.dart';

@RaftPreviews('Message translation: pending, translated, bilingual, failed')
Widget messageTranslationPreview() => const _Translation();

class _Translation extends StatefulWidget {
  const _Translation();
  @override
  State<_Translation> createState() => _TranslationState();
}

class _TranslationState extends State<_Translation> {
  bool original = false;
  String result = 'Ready';
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RaftMessageRow(
          author: 'Pending (auto)',
          timestamp: '14:30',
          content: RaftMessageTranslationSkeleton(),
          translation: RaftMessageTranslationStatus(
            tone: RaftMessageTranslationTone.pending,
            message: 'Translating…',
            tooltip: 'Translating',
          ),
        ),
        RaftMessageRow(
          author: 'Translated',
          timestamp: '14:31',
          content: Text(original ? '你好，世界' : 'Hello, world'),
          translation: RaftMessageTranslationStatus(
            tone: RaftMessageTranslationTone.normal,
            actionLabel: original ? 'Show translation' : 'Show original',
            tooltip: original
                ? 'Original shown. Show translation'
                : 'Translated. Show original',
            onAction: () => setState(() => original = !original),
          ),
        ),
        const RaftMessageRow(
          author: 'Bilingual',
          timestamp: '14:32',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Hello, world'),
              RaftMessageTranslationOriginal(
                label: 'Original',
                child: Text('你好，世界'),
              ),
            ],
          ),
        ),
        RaftMessageRow(
          author: 'Failed',
          timestamp: '14:33',
          content: const Text('你好，世界'),
          translation: RaftMessageTranslationStatus(
            tone: RaftMessageTranslationTone.failed,
            message: 'Translation unavailable',
            actionLabel: 'Retry',
            tooltip: 'Translation unavailable',
            onAction: () => setState(() => result = 'Retry callback'),
          ),
        ),
        Text(result),
      ],
    ),
  );
}
