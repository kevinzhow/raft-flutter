part of 'dialog.dart';

// DialogContent uses viewport-relative CSS lengths. Resolve those lengths
// from the generated slot instead of copying its inset and wide-form height.
double? _dialogLength(
  CssValue? value,
  Size viewport, {
  bool horizontal = false,
}) {
  double? length(CssValue? v) =>
      _dialogLength(v, viewport, horizontal: horizontal);
  switch (value) {
    case CssNum(:final value, :final unit):
      return switch (unit) {
        'px' || '' => value,
        '%' => value * (horizontal ? viewport.width : viewport.height) / 100,
        'dvh' || 'vh' => value * viewport.height / 100,
        'dvw' || 'vw' => value * viewport.width / 100,
        _ => null,
      };
    case CssCalc(:final expr):
      return length(expr);
    case CssOp(:final op, :final a, :final b):
      final left = length(a), right = length(b);
      if (left == null || right == null) return null;
      return switch (op) {
        '+' => left + right,
        '-' => left - right,
        '*' => left * right,
        '/' when right != 0 => left / right,
        _ => null,
      };
    case CssFunction(:final name, :final args):
      final values = args.map(length).toList();
      if (values.isEmpty || values.any((v) => v == null)) return null;
      final resolved = values.cast<double>();
      return switch (name) {
        'min' => resolved.reduce(math.min),
        'max' => resolved.reduce(math.max),
        'clamp' when resolved.length == 3 =>
          resolved[1].clamp(resolved[0], resolved[2]).toDouble(),
        _ => null,
      };
    default:
      return null;
  }
}
