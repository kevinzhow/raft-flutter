import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'channel_side_web_preview.dart';
import 'desktop_browser_tabs.dart';

const _tabMin = 70.0, _tabMax = 168.0, _tabGap = 2.0;
const _edge = 13.0, _action = RaftDesktopMetrics.barButtonSize, _gap = 4.0;
const _chipPad = 34.0, _chipDivider = 17.0;
const _webAction = 32.0;

typedef BrowserHeaderFit = ({int visible, double chipTitle});

BrowserHeaderFit fitBrowserHeader({
  required double width,
  required double activeWidth,
  required int count,
  required int controls,
  required bool artifact,
}) {
  const bar = _webAction + _gap;
  final strip =
      width - 2 * _edge - controls * bar - (artifact ? _chipDivider : 0);
  double need(int visible) =>
      activeWidth +
      (visible - 1) * (_tabMin + _tabGap) +
      (visible < count ? bar : 0);
  final titleRoom = artifact ? strip - _chipPad - need(count) - bar : 0.0;
  final title = titleRoom >= 48 ? math.min(132.0, titleRoom) : 0.0;
  final room =
      strip -
      (artifact ? (title > 0 ? _chipPad + title : _webAction) : 0) -
      bar;
  var visible = count;
  while (visible > 1 && need(visible) > room) {
    visible--;
  }
  return (visible: visible, chipTitle: title);
}

String browserTabLabel(BuildContext context, DesktopBrowserTab tab) {
  if (tab.title.isNotEmpty) return tab.title;
  final url = tab.url;
  return url == null
      ? raftText(context, 'New tab')
      : webPreviewAddressParts(url.toString()).host;
}

RaftGlyph _tabGlyph(DesktopBrowserTab tab) {
  final host = tab.url?.host;
  if (host == null) return RaftGlyph.globe;
  if (host == 'localhost' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local') ||
      host == '::1') {
    return RaftGlyph.laptop;
  }
  final parts = host.split('.').map(int.tryParse).toList();
  if (parts.length != 4 ||
      parts.any((part) => part == null || part < 0 || part > 255)) {
    return RaftGlyph.globe;
  }
  final [first, second, ...] = parts;
  final local =
      first == 127 ||
      first == 10 ||
      (first == 192 && second == 168) ||
      (first == 172 && second! >= 16 && second <= 31) ||
      (first == 169 && second == 254);
  return local ? RaftGlyph.laptop : RaftGlyph.globe;
}

double browserTabWidth(
  BuildContext context,
  DesktopBrowserTab tab, {
  bool active = false,
}) {
  final tokens = RaftTokens.of(context);
  final painter = TextPainter(
    text: TextSpan(
      text: browserTabLabel(context, tab),
      style: tokens.scale(
        tokens.typeSlot('callout'),
        weight: active ? FontWeight.w700 : FontWeight.w600,
      ),
    ),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final width = (painter.width.ceilToDouble() + (active ? 62 : 44)).clamp(
    active ? 60.0 : _tabMin,
    _tabMax,
  );
  painter.dispose();
  return width;
}

class DesktopBrowserTabStrip extends StatefulWidget {
  const DesktopBrowserTabStrip({
    super.key,
    required this.browser,
    required this.shown,
    required this.onNew,
    required this.onClose,
    required this.onSelect,
    required this.onFrontWidth,
    this.frontWidth,
  });

  final DesktopBrowser browser;
  final int shown;
  final VoidCallback onNew;
  final ValueChanged<int> onClose, onSelect;
  final ValueChanged<double> onFrontWidth;
  final double? frontWidth;

  @override
  State<DesktopBrowserTabStrip> createState() => _DesktopBrowserTabStripState();
}

class _DesktopBrowserTabStripState extends State<DesktopBrowserTabStrip> {
  final _nodes = <int, FocusNode>{};
  final _front = GlobalKey();
  final _more = RaftMenuController();

  FocusNode _focus(int id) => _nodes.putIfAbsent(id, FocusNode.new);

  @override
  void didUpdateWidget(DesktopBrowserTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.browser.tabs.map((tab) => tab.id).toSet();
    for (final gone in _nodes.keys.where((id) => !ids.contains(id)).toList()) {
      _nodes.remove(gone)!.dispose();
    }
  }

  @override
  void dispose() {
    _more.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _key(KeyEvent event, List<DesktopBrowserTab> row) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final index = row.indexWhere((tab) => _nodes[tab.id]?.hasFocus == true);
    if (index < 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      widget.onClose(row[index].id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus(widget.browser.activeId).requestFocus();
      });
      return KeyEventResult.handled;
    }
    final direction = Directionality.of(context) == TextDirection.ltr ? 1 : -1;
    final next = switch (key) {
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => row.length - 1,
      LogicalKeyboardKey.arrowLeft => (index - direction) % row.length,
      LogicalKeyboardKey.arrowRight => (index + direction) % row.length,
      _ => null,
    };
    if (next == null) return KeyEventResult.ignored;
    _focus(row[next].id).requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.browser.tabs;
    final activeId = widget.browser.activeId;
    final visible = tabs.take(widget.shown).map((tab) => tab.id).toSet();
    if (!visible.contains(activeId)) {
      visible.remove(visible.last);
      visible.add(activeId);
    }
    final row = tabs.where((tab) => visible.contains(tab.id)).toList();
    final more = tabs.where((tab) => !visible.contains(tab.id)).toList();
    final full = tabs.length == desktopBrowserTabLimit;
    final moreLabel = raftText(context, 'More tabs');
    final newLabel = raftText(context, 'New tab');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final render = _front.currentContext?.findRenderObject();
      if (render is RenderBox && render.hasSize) {
        final width = render.getMaxIntrinsicWidth(render.size.height);
        widget.onFrontWidth(width.clamp(60.0, _tabMax));
      }
    });
    return LayoutBuilder(
      builder: (context, box) {
        final tiny = box.maxWidth < 122;
        final actionWidth = tiny
            ? RaftDesktopMetrics.controlEmbeddedSize
            : _action;
        final gap = tiny ? 0.0 : _gap;
        final reserve = (more.isEmpty ? 1 : 2) * (actionWidth + gap);
        final room = math.max(0.0, box.maxWidth - reserve);
        final backCount = row.length - 1;
        final tabRoom = math.max(0.0, room - backCount * _tabGap);
        final activeTabWidth = math.min(
          widget.frontWidth ??
              browserTabWidth(context, widget.browser.active, active: true),
          tabRoom,
        );
        final backRoom = tabRoom - activeTabWidth;
        final minimum = backCount == 0
            ? 0.0
            : math.min(_tabMin, backRoom / backCount);
        final excess = [
          for (final tab in row)
            tab.id == activeId ? 0.0 : browserTabWidth(context, tab) - minimum,
        ];
        final wanted = excess.fold(0.0, (sum, width) => sum + width);
        final fit = wanted == 0
            ? 1.0
            : ((backRoom - minimum * backCount) / wanted).clamp(0.0, 1.0);
        double width(int index) => row[index].id == activeId
            ? activeTabWidth
            : minimum + excess[index] * fit;
        return Row(
          spacing: gap,
          children: [
            Flexible(
              child: Focus(
                canRequestFocus: false,
                onKeyEvent: (_, event) => _key(event, row),
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: raftText(context, 'Web preview tabs'),
                  child: ClipRect(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: _tabGap,
                      children: [
                        for (final (index, tab) in row.indexed)
                          SizedBox(
                            width: width(index),
                            child: _BrowserTab(
                              key: ValueKey(tab.id),
                              tab: tab,
                              active: tab.id == activeId,
                              width: width(index),
                              focus: _focus(tab.id),
                              close: () => widget.onClose(tab.id),
                              select: () => widget.onSelect(tab.id),
                              measureKey: tab.id == activeId ? _front : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (more.isNotEmpty)
              RaftDropdownMenu(
                key: const ValueKey('browser-more-tabs'),
                controller: _more,
                surfaceKey: const ValueKey('browser-more-tabs-menu'),
                label: moreLabel,
                kind: RaftMenuKind.dropdownMenu,
                flipAlignment: true,
                entries: [
                  for (final tab in more)
                    RaftMenuEntry(
                      label: browserTabLabel(context, tab),
                      glyph: _tabGlyph(tab),
                      onPressed: () => widget.onSelect(tab.id),
                    ),
                ],
                triggerBuilder: (context, focus, press) => SizedBox(
                  width: actionWidth,
                  child: ListenableBuilder(
                    listenable: _more,
                    builder: (context, _) => RaftPanelAction(
                      glyph: RaftGlyph.chevronDown,
                      tooltip: moreLabel,
                      desktopBar: !tiny,
                      ghostSize: tiny ? RaftButtonSize.iconXs : null,
                      focusNode: focus,
                      onPressed: press,
                      pressed: _more.isOpen,
                    ),
                  ),
                ),
              ),
            Semantics(
              label: newLabel,
              enabled: !full,
              child: SizedBox(
                width: actionWidth,
                child: RaftPanelAction(
                  key: const ValueKey('browser-new-tab'),
                  glyph: RaftGlyph.plus,
                  tooltip: full
                      ? raftFormat(
                          context,
                          'You can have up to {count} tabs open',
                          {'count': '$desktopBrowserTabLimit'},
                        )
                      : newLabel,
                  desktopBar: !tiny,
                  ghostSize: tiny ? RaftButtonSize.iconXs : null,
                  focusableWhenDisabled: full,
                  onPressed: full ? null : widget.onNew,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BrowserTab extends StatefulWidget {
  const _BrowserTab({
    super.key,
    required this.tab,
    required this.active,
    required this.width,
    required this.focus,
    required this.close,
    required this.select,
    this.measureKey,
  });

  final DesktopBrowserTab tab;
  final bool active;
  final double width;
  final FocusNode focus;
  final VoidCallback close, select;
  final Key? measureKey;

  @override
  State<_BrowserTab> createState() => _BrowserTabState();
}

class _BrowserTabState extends State<_BrowserTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final active = widget.active;
    final compact = widget.width < (active ? 76 : 42);
    final hoverClose = !active && _hovered;
    final label = browserTabLabel(context, tab);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTertiaryTapUp: (_) => widget.close(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            KeyedSubtree(
              key: compact ? null : widget.measureKey,
              child: RaftTabButton(
                key: ValueKey('browser-tab-${tab.id}'),
                label: label,
                semanticLabel: label,
                focusNode: widget.focus,
                tooltip: tab.url?.toString(),
                selected: active,
                fitLabel: true,
                labelOverflow: active && widget.width < 48
                    ? TextOverflow.clip
                    : null,
                padding: compact
                    ? EdgeInsetsDirectional.only(
                        start: RaftSpace.half,
                        end: active ? RaftSpace.x4 : RaftSpace.half,
                      )
                    : EdgeInsetsDirectional.only(
                        start: RaftSpace.x2 + RaftSpace.half,
                        end: active
                            ? RaftDesktopMetrics.barButtonSize
                            : RaftSpace.x2 + RaftSpace.half,
                      ),
                icon: compact && active
                    ? null
                    : (size, color, weight) => Opacity(
                        opacity: hoverClose ? 0 : 1,
                        child: RaftIcon(
                          _tabGlyph(tab),
                          size: size,
                          color: color,
                        ),
                      ),
                onPressed: widget.select,
              ),
            ),
            if (active || hoverClose)
              PositionedDirectional(
                start: hoverClose ? 7 : null,
                end: active ? (compact ? 0 : 6) : null,
                child: FocusTraversalGroup(
                  descendantsAreTraversable: false,
                  child: RaftButton(
                    key: ValueKey('browser-tab-close-${tab.id}'),
                    label: '',
                    semanticLabel: raftFormat(context, 'Close {title}', {
                      'title': label,
                    }),
                    glyph: RaftGlyph.x,
                    uiVariant: RaftButtonVariant.ghost,
                    uiSize: RaftButtonSize.iconXs,
                    visualWidth: compact ? RaftSpace.x4 : RaftSpace.x5,
                    padding: compact ? EdgeInsets.zero : null,
                    physicalHeight: 20,
                    glyphSize: compact ? RaftSpace.x3 : 14,
                    onPressed: widget.close,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
