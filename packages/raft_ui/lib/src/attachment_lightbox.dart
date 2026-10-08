import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'theme.dart';

/// Source Lightbox viewport shell. The caller owns route scope and private media.
/// SafeArea keeps interactive controls above native system bars and gestures.
class RaftAttachmentLightbox extends StatelessWidget {
  const RaftAttachmentLightbox({super.key, required this.title, required this.child,
    required this.onClose, this.actions = const [], this.footer, this.titleBold = false, this.closeLabel = 'Close preview'});
  final String title, closeLabel;
  final Widget child;
  final VoidCallback onClose;
  final List<Widget> actions;
  final Widget? footer;
  final bool titleBold;
  @override
  Widget build(BuildContext context) {
    final recipe = RaftLightboxRecipe(RaftTokens.of(context));
    return Dialog.fullscreen(backgroundColor: recipe.backdrop,
      child: CallbackShortcuts(bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onClose,
        const SingleActivator(LogicalKeyboardKey.keyW, control: true): onClose,
        const SingleActivator(LogicalKeyboardKey.keyW, meta: true): onClose,
      }, child: Focus(autofocus: true, child: SafeArea(child: Column(children: [
        DecoratedBox(decoration: BoxDecoration(color: recipe.surface,
          border: Border(bottom: recipe.navigationBorder)),
          child: SizedBox(height: recipe.toolbarHeight, child: Padding(
            padding: EdgeInsets.symmetric(horizontal: recipe.headerInset.left),
            child: Row(children: [
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: recipe.title.copyWith(fontWeight: titleBold ? FontWeight.w700 : FontWeight.w400))),
              for (final action in actions) ...[SizedBox(width: recipe.actionsGap), action],
              SizedBox(width: recipe.actionsGap),
              RaftIconButton(glyph: RaftGlyph.x, tooltip: closeLabel, visualSize: 32,
                minimumTargetSize: 48, variant: RaftControlVariant.ghost, onPressed: onClose),
            ]),
          )),
        ),
        Expanded(child: child),
        if (footer != null) ColoredBox(color: recipe.surface, child: SizedBox(width: double.infinity, child: footer!)),
      ])))));
  }
}
