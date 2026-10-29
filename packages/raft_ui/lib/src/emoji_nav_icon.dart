part of 'icons.dart';

/// One category button icon of emoji-picker-react's `CategoryNav.svg` sprite
/// (a 20-unit cell scaled to [size], 30 in the picker). [category] is the
/// package key (`smileys_people`, ..., `suggested`); [state] one of `normal`,
/// `active`, `darkNormal`, `darkActive`.
class RaftEmojiNavIcon extends StatelessWidget {
  const RaftEmojiNavIcon(
    this.category, {
    super.key,
    this.state = 'normal',
    this.size = 30,
  });
  final String category, state;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RaftIconViewport(
      size: size,
      child: CustomPaint(painter: _EmojiNavPainter(category, state)),
    ),
  );
}

class _EmojiNavPainter extends CustomPainter {
  const _EmojiNavPainter(this.category, this.state);
  final String category, state;
  Color color(String hex) => Color(0xff000000 | int.parse(hex, radix: 16));
  @override
  void paint(Canvas canvas, Size size) {
    final column = _emojiNavColumns[category];
    final shapes = column == null ? null : _emojiNavShapes[column]?[state];
    if (shapes == null) return;
    final ink = switch (state) {
      'active' => color('6AA9DD'),
      'darkNormal' => color('C0C0BF'),
      'darkActive' => color('3371B7'),
      _ => color('868686'),
    };
    canvas.save();
    canvas.scale(size.width / 20, size.height / 20);
    canvas.translate(-20.0 * column!, -20.0 * _emojiNavRows[state]!);
    for (final (d, filled, stroked, width) in shapes) {
      final path = _svgPath(d);
      if (filled) canvas.drawPath(path, Paint()..color = ink);
      if (stroked) {
        canvas.drawPath(
          path,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = width,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EmojiNavPainter old) =>
      old.category != category || old.state != state;
}
