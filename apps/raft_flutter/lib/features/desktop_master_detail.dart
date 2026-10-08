import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

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
    this.onWidthChanged,
  });
  final Widget master;
  final Widget? detail;
  final double wideWidth, compactWidth;
  final bool compact;

  /// Classic directory uses the independently persisted Sidebar width.
  final double? directoryWidth;
  final void Function(double width, bool compact)? onWidthChanged;
  @override
  State<DesktopMasterDetail> createState() => _DesktopMasterDetailState();
}

class _DesktopMasterDetailState extends State<DesktopMasterDetail> {
  late double wideWidth = widget.wideWidth;
  late double compactWidth = widget.compactWidth;
  late double? directoryWidth = widget.directoryWidth;
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
      final compact = widget.compact || MediaQuery.sizeOf(context).width < 1024;
      final width = split && directoryWidth != null
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

      return Stack(
        fit: StackFit.expand,
        children: [
          Row(
            children: [
              SizedBox(
                key: const Key('desktop-master-panel'),
                width: width.toDouble(),
                child: widget.master,
              ),
              if (split) ...[
                Expanded(
                  child: KeyedSubtree(
                    key: const Key('desktop-content-detail'),
                    child: widget.detail!,
                  ),
                ),
              ],
            ],
          ),
          if (split)
            Positioned(
              left: width - 4,
              top: 0,
              bottom: 0,
              width: 8,
              child: RaftPanelResizeHandle(
                key: const Key('desktop-master-resize-handle'),
                label: 'Resize results',
                value: width.toDouble(),
                onChanged: resize,
              ),
            ),
        ],
      );
    },
  );
}
