// Resolved reviewer regressions: local factories and annotation-only wrappers.
import 'package:flutter/widgets.dart';

class LocalBuilderSample extends StatelessWidget {
  const LocalBuilderSample({super.key});

  @override
  Widget build(BuildContext context) {
    Widget localPanel() => const Text('new');
    return localPanel();
  }
}

Widget firstScope() {
  Widget localPanel() {
    Widget localPanel() => const Text('nested');
    return localPanel();
  }

  return localPanel();
}

Widget secondScope(bool first) {
  if (first) {
    Widget localPanel() => const Text('first block');
    return localPanel();
  } else {
    Widget localPanel() => const Text('second block');
    return localPanel();
  }
}

class CanonicalLeaf extends StatelessWidget {
  const CanonicalLeaf({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class AnnotationOnlyWrapper extends StatelessWidget {
  const AnnotationOnlyWrapper({super.key, this.marker});
  final CanonicalLeaf? marker;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class ActualWrapper extends StatelessWidget {
  const ActualWrapper({super.key});

  @override
  Widget build(BuildContext context) => const CanonicalLeaf();
}
