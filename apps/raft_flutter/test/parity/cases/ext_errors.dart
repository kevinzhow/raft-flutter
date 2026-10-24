// raft-flutter parity EXTENSION suite builders (tool/parity-ext): error
// presentation. Ids `components.errors.<surface>.<variant>.<theme>`,
// dispatched on props.surface like tool/parity-ext/host/ErrorCases.tsx.
//
//   toast      RaftToast (tone + icon + close), 384px wide like the viewport
//   banner     RaftErrorBanner (warning, bold; small; with Try again action)
//   field      RaftProductFormField(error: / hint:)
//   dialog     RaftCreateTaskDialogView after a failed submit
//   loaderror  RaftLoadError (expand / embedded)
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';

Color _panel(BuildContext context) {
  final t = RaftTokens.of(context);
  return t.panel;
}

String _message(ParityContext ctx) => '${ctx.props['message']}';

Widget _toast(ParityContext ctx) {
  final variant = '${ctx.props['variant']}'.split('-').first;
  return Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384),
        child: KeyedSubtree(
          key: const ValueKey('errors-toast'),
          child: RaftToast(
            title: _message(ctx),
            icon: true,
            onClose: () {},
            tone: switch (variant) {
              'error' => RaftToastRecipeTone.error,
              'info' => RaftToastRecipeTone.info,
              _ => RaftToastRecipeTone.success,
            },
          ),
        ),
      ),
    ),
  );
}

Widget _framed(ParityContext ctx, double height, Widget Function() child) =>
    Builder(
      builder: (context) => ctx.frame(
        width: double.parse('${ctx.props['width']}'),
        height: height,
        background: _panel(context),
        child: child(),
      ),
    );

Widget _banner(ParityContext ctx) {
  final variant = '${ctx.props['variant']}';
  final tall = variant == 'long' || variant == 'action';
  return _framed(
    ctx,
    tall ? 140 : 100,
    () => RaftErrorBanner(
      _message(ctx),
      small: variant == 'sm',
      bold: true,
      onRetry: variant == 'action' ? () {} : null,
      // The Web host's own button copy.
      retryLabel: 'Try again',
    ),
  );
}

Widget _field(ParityContext ctx) {
  final error = ctx.props['variant'] == 'error';
  final controller = TextEditingController(
    text: error ? 'alex@' : 'Design Lab',
  );
  return _framed(
    ctx,
    140,
    () => RaftProductFormField(
      label: error ? 'Email' : 'Server name',
      error: error ? _message(ctx) : null,
      hint: error ? null : _message(ctx),
      child: RaftDialogTextInput(controller: controller),
    ),
  );
}

class _DialogHost extends StatefulWidget {
  const _DialogHost({required this.message});
  final String message;
  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  final titles = [
    TextEditingController(text: 'Wire the Tasks board to the new status lanes'),
  ];
  String? error;

  @override
  void dispose() {
    for (final c in titles) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftCreateTaskDialogView(
    titles: titles,
    filledCount: 1,
    error: error,
    onClose: () {},
    onSubmit: () => setState(() => error = widget.message),
    onAddRow: () {},
    onRemoveRow: (_) {},
  );
}

Widget _dialog(ParityContext ctx) => Align(
  alignment: Alignment.topLeft,
  child: ctx.target(
    SizedBox(
      width: ctx.width,
      height: ctx.height,
      child: Material(
        type: MaterialType.transparency,
        child: _DialogHost(message: _message(ctx)),
      ),
    ),
  ),
);

Widget _loadError(ParityContext ctx) {
  final embedded = ctx.props['variant'] == 'embedded';
  final error = RaftLoadError(_message(ctx), onRetry: () {}, expand: !embedded);
  return Builder(
    builder: (context) => ctx.frame(
      width: double.parse('${ctx.props['width']}'),
      height: 200,
      padding: EdgeInsets.zero,
      background: _panel(context),
      child: embedded
          ? Align(alignment: Alignment.topLeft, child: error)
          : error,
    ),
  );
}

final ParityCase _case = ParityCase(
  widgets: const [
    'raft_ui:RaftToast',
    'raft_ui:RaftErrorBanner',
    'raft_ui:RaftProductFormField',
    'raft_ui:RaftCreateTaskDialogView',
    'raft_ui:RaftLoadError',
  ],
  notes: 'Extension suite (not official). Error presentation components.',
  settle: const Duration(milliseconds: 400),
  build: (ctx) => Material(
    type: MaterialType.transparency,
    child: SizedBox.expand(
      child: switch (ctx.props['surface']) {
        'toast' => _toast(ctx),
        'banner' => _banner(ctx),
        'field' => _field(ctx),
        'dialog' => _dialog(ctx),
        _ => _loadError(ctx),
      },
    ),
  ),
);

const _surfaces = {
  'toast': ['error', 'error-long', 'success', 'info'],
  'banner': ['line', 'long', 'sm', 'action'],
  'field': ['error', 'hint'],
  'dialog': ['error', 'error-long'],
  'loaderror': ['page', 'embedded'],
};

/// Every error presentation case, keyed by id (3 themes each).
final Map<String, ParityCase> extErrorsCases = {
  for (final e in _surfaces.entries)
    for (final variant in e.value)
      for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
        'components.errors.${e.key}.$variant.$theme': _case,
};
