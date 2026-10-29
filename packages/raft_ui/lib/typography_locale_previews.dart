import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('English UI · Chinese glyphs')
Widget chineseGlyphsPreview() => const _GlyphPreview(Locale('zh', 'CN'));

@RaftPreviews('English UI · Traditional Chinese glyphs')
Widget traditionalGlyphsPreview() => const _GlyphPreview(Locale('zh', 'TW'));

@RaftPreviews('English UI · Japanese glyphs')
Widget japaneseGlyphsPreview() => const _GlyphPreview(Locale('ja', 'JP'));

@RaftPreviews('English UI · Korean glyphs')
Widget koreanGlyphsPreview() => const _GlyphPreview(Locale('ko', 'KR'));

class _GlyphPreview extends StatelessWidget {
  const _GlyphPreview(this.locale);
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final original = RaftTokens.of(context);
    final theme = raftTheme(
      dark: original.dark,
      locale: const Locale('en'),
      textLocale: locale,
    );
    return Theme(
      data: theme,
      child: Padding(
        padding: const EdgeInsets.all(RaftSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: theme.textTheme.titleMedium),
            Text('骨 直 令 遍 返 中文 日本語 한국어', style: theme.textTheme.bodyMedium),
            const RaftTextInput(hintText: 'Message'),
          ],
        ),
      ),
    );
  }
}
