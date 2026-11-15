import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'desktop_detail_host.dart';

/// MainLayout1777/masterDetailPanelSizing.ts executable classic-panel bounds.
/// These values are independent of chat sidebar preferences.
abstract final class DesktopMasterPanelBounds {
  static const wideDefault = 560.0, wideMin = 400.0, wideMax = 720.0;
  static const compactDefault = 320.0, compactMin = 320.0, compactMax = 480.0;
  static double resolve({
    required double available,
    required bool compact,
    required double wideWidth,
    required double compactWidth,
  }) {
    final desired = compact
        ? compactWidth.clamp(compactMin, compactMax)
        : wideWidth.clamp(wideMin, wideMax);
    return desired.clamp(0, (available - 320).clamp(0, available));
  }
}

/// Keeps the master in the same child slot when details open/close. The caller
/// supplies only current-authority content; this shell performs no requests.
class DesktopMasterDetail extends StatefulWidget {
  const DesktopMasterDetail({
    super.key,
    required this.master,
    this.detail,
    this.wideWidth = DesktopMasterPanelBounds.wideDefault,
    this.compactWidth = DesktopMasterPanelBounds.compactDefault,
    this.compact = false,
    this.directoryWidth,
    this.masterEdge = false,
    this.onWidthChanged,
    this.detailPanelWidth,
    this.onDetailPanelWidthChanged,
  });

  /// Web ProfilePanel beside a page (Members, Agents): the detail is a panel of
  /// this width (the profile panel's 300 to 600) that the page's own list
  /// leaves room for, and its left edge is the resize handle (Web
  /// `ColumnResizeHandle column="detail"`). Null keeps the classic split where
  /// the handle resizes the master (Search, Activity).
  final double? detailPanelWidth;
  final ValueChanged<double>? onDetailPanelWidthChanged;
  final Widget master;
  final Widget? detail;
  final double wideWidth, compactWidth;
  final bool compact;

  /// Classic directory uses the independently persisted Sidebar width.
  final double? directoryWidth;

  /// Web's master column divider (`MainLayout` col-2 `border-r border-line-muted`)
  /// beside an open detail: false for a master that draws its own (the
  /// directory sidebar frame). Shown by [RaftPanelEdge]'s rule, never on a
  /// phone page.
  final bool masterEdge;
  final void Function(double width, bool compact)? onWidthChanged;
  @override
  State<DesktopMasterDetail> createState() => _DesktopMasterDetailState();
}

class _DesktopMasterDetailState extends State<DesktopMasterDetail> {
  late double wideWidth = widget.wideWidth;
  late double compactWidth = widget.compactWidth;
  late double? directoryWidth = widget.directoryWidth;
  late double panel = widget.detailPanelWidth ?? 380;

  // While a detail covers the folded master (phones), the framework is handed
  // the master widget it last built when it was visible, so the hidden list is
  // not rebuilt on every navigation frame. Its own listeners keep it current,
  // and showing it again builds the fresh widget.
  Widget? lastVisibleMaster;
  @override
  void didUpdateWidget(DesktopMasterDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wideWidth != oldWidget.wideWidth) {
      wideWidth = widget.wideWidth;
    }
    if (widget.compactWidth != oldWidget.compactWidth) {
      compactWidth = widget.compactWidth;
    }
    if (widget.directoryWidth != oldWidget.directoryWidth) {
      directoryWidth = widget.directoryWidth;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final split = widget.detail != null;
      final folded = RaftAdaptiveWorkspace.compactOf(context);
      final compact = widget.compact || MediaQuery.sizeOf(context).width < 1024;
      final panelMode = widget.detailPanelWidth != null;
      final panelWidth = panel.clamp(300.0, 600.0);
      final width = panelMode && split
          ? (size.maxWidth - panelWidth).clamp(0.0, size.maxWidth)
          : split && directoryWidth != null
          ? directoryWidth!
                .clamp(180, 320)
                .clamp(0, (size.maxWidth - 320).clamp(0, size.maxWidth))
          : split
          ? DesktopMasterPanelBounds.resolve(
              available: size.maxWidth,
              compact: compact,
              wideWidth: wideWidth,
              compactWidth: compactWidth,
            )
          : size.maxWidth;
      final masterHidden = folded && split;
      final previous = lastVisibleMaster;
      final master =
          masterHidden &&
              previous != null &&
              previous.runtimeType == widget.master.runtimeType &&
              previous.key == widget.master.key
          ? previous
          : lastVisibleMaster = widget.master;
      void resize(double next) {
        final accepted = directoryWidth != null
            ? next.clamp(180.0, 320.0)
            : compact
            ? next.clamp(320.0, 480.0)
            : next.clamp(400.0, 720.0);
        setState(() {
          if (directoryWidth != null) {
            directoryWidth = accepted;
          } else if (compact) {
            compactWidth = accepted;
          } else {
            wideWidth = accepted;
          }
        });
        widget.onWidthChanged?.call(accepted, compact);
      }

      final Widget column = widget.masterEdge
          ? RaftPanelMasterEdge(split: split, child: master)
          : master;
      return DesktopDetailFocus(
        // Web moves focus into the ProfilePanel only; the Search / Activity
        // slots keep it where the user clicked (their find shortcuts live there).
        open: split && !folded && panelMode,
        builder: (scope) => Stack(
          fit: StackFit.expand,
          children: [
            Row(
              children: [
                Offstage(
                  offstage: folded && split,
                  child: ExcludeFocus(
                    excluding: folded && split,
                    child: TickerMode(
                      enabled: !folded || !split,
                      child: SizedBox(
                        key: const Key('desktop-master-panel'),
                        width: folded ? size.maxWidth : width.toDouble(),
                        child: column,
                      ),
                    ),
                  ),
                ),
                if (split) ...[
                  Expanded(
                    child: KeyedSubtree(
                      key: const Key('desktop-content-detail'),
                      child: FocusScope(
                        node: scope,
                        child: panelMode
                            ? KeyedSubtree(
                                key: const ValueKey('desktop-profile-detail'),
                                child: widget.detail!,
                              )
                            : widget.detail!,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (split && !folded)
              Positioned(
                left: width - 4,
                top: 0,
                bottom: 0,
                width: 8,
                child: RaftPanelResizeHandle(
                  key: const Key('desktop-master-resize-handle'),
                  label: panelMode
                      ? raftText(context, 'Resize profile')
                      : 'Resize results',
                  value: panelMode ? panelWidth : width.toDouble(),
                  reversed: panelMode,
                  min: panelMode ? 300 : null,
                  max: panelMode ? 600 : null,
                  defaultValue: panelMode ? 380 : null,
                  onChanged: panelMode
                      ? (next) =>
                            setState(() => panel = next.clamp(300.0, 600.0))
                      : resize,
                  onChangeEnd: panelMode
                      ? () => widget.onDetailPanelWidthChanged?.call(panel)
                      : null,
                ),
              ),
          ],
        ),
      );
    },
  );
}
