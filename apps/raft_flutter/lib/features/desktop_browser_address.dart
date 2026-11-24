import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

import 'channel_side_web_preview.dart';
import 'desktop_browser_tabs.dart';

final _scheme = RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false);
final _localHost = RegExp(
  r'^(localhost|127(?:\.\d{1,3}){3}|\[::1\])(?::\d+)?(?:[/?#]|$)',
  caseSensitive: false,
);

final _whitespace = RegExp(r'\s');

Uri? typedBrowserAddress(String text, Set<String> raftHosts) {
  final typed = text.trim();
  if (typed.isEmpty || typed.contains(_whitespace)) return null;
  if (_scheme.hasMatch(typed)) return webPreviewTarget(typed, raftHosts);
  final local = _localHost.hasMatch(typed);
  final uri = webPreviewTarget(
    '${local ? 'http' : 'https'}://$typed',
    raftHosts,
  );
  if (uri == null ||
      (!local && !uri.host.contains('.') && !uri.host.contains(':'))) {
    return null;
  }
  return uri;
}

typedef BrowserHistoryActions = ({
  VoidCallback back,
  VoidCallback forward,
  VoidCallback reload,
});

class DesktopBrowserAddress extends StatefulWidget {
  const DesktopBrowserAddress({
    super.key,
    required this.tab,
    required this.raftHosts,
    required this.navigate,
    required this.openExternal,
    this.history,
  });

  final DesktopBrowserTab tab;
  final Set<String> raftHosts;
  final ValueChanged<Uri> navigate, openExternal;
  final BrowserHistoryActions? history;

  @override
  State<DesktopBrowserAddress> createState() => _DesktopBrowserAddressState();
}

class _DesktopBrowserAddressState extends State<DesktopBrowserAddress> {
  final _text = TextEditingController();
  final _field = FocusNode();
  final _readout = FocusNode();
  bool _editing = false, _invalid = false;

  bool get _empty => widget.tab.url == null;

  @override
  void initState() {
    super.initState();
    _field.addListener(_onFocusChanged);
    if (_empty) _focusField();
  }

  @override
  void dispose() {
    _field.removeListener(_onFocusChanged);
    _field.dispose();
    _readout.dispose();
    _text.dispose();
    super.dispose();
  }

  void _focusField() {
    _field.requestFocus();
    _text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _text.text.length,
    );
  }

  void _edit() {
    if (!_editing && !_empty) {
      setState(() => _editing = true);
      _text.text = widget.tab.url.toString();
    }
    _focusField();
  }

  void _onFocusChanged() {
    if (!_field.hasFocus) _leave();
  }

  void _leave({bool restoreFocus = false}) {
    if (_editing || _invalid) {
      setState(() {
        _editing = false;
        _invalid = false;
      });
    }
    if (restoreFocus && !_empty) _readout.requestFocus();
  }

  void _submit(String value) {
    final url = typedBrowserAddress(value, widget.raftHosts);
    if (url == null) {
      setState(() => _invalid = true);
      _field.requestFocus();
      return;
    }
    RaftHoverDismissScope.maybeOf(context)?.dismiss();
    widget.navigate(url);
    _leave();
    Focus.of(context).requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final tab = widget.tab;
    final url = tab.url;
    final label = raftText(context, 'Address');
    final history = widget.history;
    final editing = _empty || _editing;
    final address = RaftInputGroup(
      size: RaftInputGroupRecipeSize.md,
      semanticLabel: label,
      controller: _text,
      focusNode: _field,
      keyboardType: TextInputType.url,
      invalid: _invalid,
      onSubmitted: _submit,
      onChanged: (_) {
        if (_invalid) setState(() => _invalid = false);
      },
      fieldKey: const ValueKey('browser-address-input'),
      hintText: raftText(context, 'Enter an address'),
      readout: editing ? null : _display(context, label, url!),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors['layer-canvas'],
        border: RaftSidePanelFrame.headerRule(tokens),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: RaftLayoutMetrics.shellHeaderHeight(
            tokens,
            MediaQuery.sizeOf(context).height,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final narrow = box.maxWidth < 250;
            final gap = narrow ? 0.0 : RaftSpace.x1;
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: narrow ? RaftSpace.x1 : RaftSpace.x4,
              ),
              child: Row(
                spacing: gap,
                children: [
                  _action(
                    'history-back',
                    RaftGlyph.arrowLeft,
                    'Go back',
                    tab.page.back ? history?.back : null,
                    narrow,
                  ),
                  _action(
                    'history-forward',
                    RaftGlyph.arrowRight,
                    'Go forward',
                    tab.page.forward ? history?.forward : null,
                    narrow,
                  ),
                  _action(
                    'refresh',
                    RaftGlyph.refreshCw,
                    'Refresh',
                    url == null ? null : () => history?.reload(),
                    narrow,
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: gap),
                      child: editing
                          ? CallbackShortcuts(
                              bindings: {
                                const SingleActivator(
                                  LogicalKeyboardKey.escape,
                                ): () =>
                                    _leave(restoreFocus: true),
                                const SingleActivator(
                                  LogicalKeyboardKey.enter,
                                ): () =>
                                    _submit(_text.text),
                              },
                              child: address,
                            )
                          : address,
                    ),
                  ),
                  _action(
                    'open-tab',
                    RaftGlyph.arrowUpRight,
                    'Open in browser',
                    url == null ? null : () => widget.openExternal(url),
                    narrow,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _display(BuildContext context, String label, Uri url) {
    final tokens = RaftTokens.of(context);
    final parts = webPreviewAddressParts(url.toString());
    return RaftInteractive(
      key: const ValueKey('browser-address'),
      semanticLabel: label,
      semanticHint: url.scheme == 'http'
          ? raftText(context, 'Not secure')
          : null,
      focusNode: _readout,
      onPressed: _edit,
      tooltip: url.scheme == 'http'
          ? '${raftText(context, 'Not secure')}\n$url'
          : url.toString(),
      builder: (context, state) {
        final style = tokens.scale(
          tokens.typeSlot('callout'),
          color: tokens.ui.foregroundMuted,
        );
        return LayoutBuilder(
          builder: (context, box) {
            final insecure = url.scheme == 'http';
            final showWarning = insecure && box.maxWidth >= 80;
            final showAddress = box.maxWidth >= (showWarning ? 125 : 52);
            final inset = box.maxWidth < 125 ? RaftSpace.x1 : RaftSpace.x2;
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: RaftDesktopMetrics.controlHitInset,
              ).copyWith(left: inset, right: inset),
              child: Row(
                spacing: RaftSpace.x2,
                children: [
                  if (showWarning)
                    RaftBadge(
                      label: raftText(context, 'Not secure'),
                      appearance: RaftBadgeRecipeAppearance.soft,
                      variant: RaftBadgeRecipeVariant.warning,
                      fill: raftChromeBlend(
                        tokens.ui['warning-soft'],
                        tokens.ui.layerCard,
                      ),
                    ),
                  if (!showWarning && !showAddress && box.maxWidth >= 24)
                    RaftIcon(
                      insecure ? RaftGlyph.shieldAlert : RaftGlyph.globe,
                      size: 14,
                      color: tokens.ui.foregroundMuted,
                    ),
                  if (showAddress)
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: parts.host,
                              style: tokens.scale(
                                tokens.typeSlot('callout'),
                                weight: FontWeight.w700,
                                color: tokens.ui.foreground,
                              ),
                            ),
                            TextSpan(text: parts.rest),
                          ],
                        ),
                        style: style,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _action(
    String id,
    RaftGlyph glyph,
    String label,
    VoidCallback? action,
    bool narrow,
  ) => RaftPanelAction(
    key: ValueKey('browser-$id'),
    glyph: glyph,
    tooltip: raftText(context, label),
    desktopBar: !narrow,
    ghostSize: narrow ? RaftButtonSize.iconXs : null,
    onPressed: action,
  );
}
