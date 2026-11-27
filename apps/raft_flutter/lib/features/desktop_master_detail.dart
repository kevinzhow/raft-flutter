import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'desktop_detail_host.dart';

/// MainLayout1777/masterDetailPanelSizing.ts executable classic-panel bounds.
/// These values are independent of chat sidebar preferences.
abstract final class DesktopMasterPanelBounds {
  static const wideDefault = 560.0, wideMin = 400.0, wideMax = 720.0;
  static const compactDefault = 320.0, compactMin = 320.0, compactMax = 480.0;

  /// The narrowest the classic detail (a conversation, an activity target) and
  /// the Web ProfilePanel column get. The master trades its width for them
  /// down to its own minimum; below that the split does not fit at all.
  static const detailMin = 320.0, profileMin = 300.0;

  /// The classic directory master is the independently persisted Sidebar,
  /// with the Sidebar's own bounds (`RaftAdaptiveWorkspace` clamps them too).
  static const directoryMin = 180.0, directoryMax = 320.0;
  static double resolve({
    required double available,
    required bool compact,
    required double wideWidth,
    required double compactWidth,
  }) {
    final desired = compact
        ? compactWidth.clamp(compactMin, compactMax)
        : wideWidth.clamp(wideMin, wideMax);
    return desired.clamp(0, (available - detailMin).clamp(0, available));
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

  /// Web ProfilePanel beside a page (Members, Agents): the detail is a column of
  /// this width (at least 300) that the page's own list leaves room for, and
  /// its left edge is the seam (Web `ColumnResizeHandle column="detail"`). The
  /// seam trades the list's width for the panel's, down to the list's
  /// [listFloor]. Null keeps the classic split where the handle resizes the
  /// master (Search, Activity).
  final double? detailPanelWidth;

  /// The narrowest the list beside a profile column gets: Web's planned row
  /// trades the conversation like any column down to SEAM_COLUMN_MIN_WIDTH
  /// (rowSeams.ts startSeamDrag, seamCascade.ts).
  static const listFloor = 160.0;
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
  late double panel =
      widget.detailPanelWidth ?? RaftAdaptiveWorkspace.profileDefaultWidth;

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
    // A profile opening on a page that first built without one: its saved width.
    final saved = widget.detailPanelWidth;
    if (saved != null && saved != oldWidget.detailPanelWidth) panel = saved;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final split = widget.detail != null;
      final panelMode = widget.detailPanelWidth != null;
      // This shell's own box, never the window: it is a column of the
      // workspace (rail, sidebar, docked thread or profile), so the window is
      // always the wider of the two. Reading the window left the master at
      // 64-107 px beside a 320 detail inside a 384-427 content column.
      final compact = widget.compact || size.maxWidth < 1024;
      // Each column keeps its own minimum, or the detail covers the master as
      // it does on a phone. The master's minimum depends on which split this
      // is: the list beside a ProfilePanel trades down to [listFloor], the
      // classic directory to the Sidebar's own floor, the classic results
      // column to its panel bounds.
      final masterMin = panelMode
          ? DesktopMasterDetail.listFloor
          : directoryWidth != null
          ? DesktopMasterPanelBounds.directoryMin
          : compact
          ? DesktopMasterPanelBounds.compactMin
          : DesktopMasterPanelBounds.wideMin;
      final folded =
          size.maxWidth <
          masterMin +
              (panelMode
                  ? DesktopMasterPanelBounds.profileMin
                  : DesktopMasterPanelBounds.detailMin);
      final panelMax = (size.maxWidth - DesktopMasterDetail.listFloor).clamp(
        DesktopMasterPanelBounds.profileMin,
        double.infinity,
      );
      final desiredPanelWidth = RaftAdaptiveWorkspace.fitDefaultProfileWidth(
        available: size.maxWidth,
        preferred: panel,
      );
      final panelWidth = desiredPanelWidth.clamp(
        DesktopMasterPanelBounds.profileMin,
        panelMax,
      );
      final detailEdge = panelMode && !folded
          ? RaftPanelEdge.left(context)
          : null;
      final width = panelMode && split
          ? (size.maxWidth - panelWidth).clamp(0.0, size.maxWidth)
          : split && directoryWidth != null
          ? directoryWidth!
                .clamp(
                  DesktopMasterPanelBounds.directoryMin,
                  DesktopMasterPanelBounds.directoryMax,
                )
                .clamp(
                  0,
                  (size.maxWidth - DesktopMasterPanelBounds.detailMin).clamp(
                    0,
                    size.maxWidth,
                  ),
                )
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
            ? next.clamp(
                DesktopMasterPanelBounds.directoryMin,
                DesktopMasterPanelBounds.directoryMax,
              )
            : compact
            ? next.clamp(
                DesktopMasterPanelBounds.compactMin,
                DesktopMasterPanelBounds.compactMax,
              )
            : next.clamp(
                DesktopMasterPanelBounds.wideMin,
                DesktopMasterPanelBounds.wideMax,
              );
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
                        // Web ProfilePanel `edge="attached"`: the profile
                        // draws the seam on its own left edge, over its
                        // opaque page.
                        child: panelMode
                            ? Container(
                                key: const ValueKey('desktop-profile-detail'),
                                decoration: BoxDecoration(border: detailEdge),
                                child: widget.detail,
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
                // The handle's line lies on the seam: the profile's first
                // pixel, or the list's last one (its own right border).
                left:
                    width -
                    RaftPanelResizeHandle.seamOffset -
                    (!panelMode && widget.masterEdge ? 1 : 0),
                top: 0,
                bottom: 0,
                width: RaftPanelResizeHandle.hitExtent,
                child: RaftPanelResizeHandle(
                  key: const Key('desktop-master-resize-handle'),
                  seamLine: panelMode || widget.masterEdge,
                  label: panelMode
                      ? raftText(context, 'Resize profile')
                      : 'Resize results',
                  value: panelMode ? panelWidth : width.toDouble(),
                  reversed: panelMode,
                  min: panelMode ? DesktopMasterPanelBounds.profileMin : null,
                  max: panelMode ? panelMax : null,
                  defaultValue: panelMode
                      ? RaftAdaptiveWorkspace.profileDefaultWidth
                      : null,
                  onChanged: panelMode
                      ? (next) => setState(
                          () => panel = next.clamp(
                            DesktopMasterPanelBounds.profileMin,
                            panelMax,
                          ),
                        )
                      : resize,
                  onChangeEnd: panelMode
                      ? () => widget.onDetailPanelWidthChanged?.call(
                          panel.clamp(
                            DesktopMasterPanelBounds.profileMin,
                            panelMax,
                          ),
                        )
                      : null,
                ),
              ),
          ],
        ),
      );
    },
  );
}
