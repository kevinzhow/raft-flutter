import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

import '../data/workspace_controller.dart';
import 'private_route_guard.dart';

/// Mounted Sidebar.tsx selection popover: right-aligned below the 24px action,
/// checked on the right, immediate close. Every route belongs to its authority.
Future<String?> showSidebarSortMenu(
  BuildContext context,
  WorkspaceController controller,
  GlobalKey anchor,
  String current,
) async {
  final anchorContext = anchor.currentContext;
  if (anchorContext == null) return null;
  final box = anchorContext.findRenderObject();
  if (box is! RenderBox || !box.attached) return null;
  final scope = workspaceAuthority(controller);
  final previousFocus = FocusManager.instance.primaryFocus;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  final navigator = Navigator.of(context);
  final themes = captureRaftPopoverThemes(anchorContext, navigator: navigator);
  final currentPopover = RaftTokens.of(anchorContext).isRaftLook;
  late final RawDialogRoute<String> route;
  void revoke() {
    if (scope != workspaceAuthority(controller) && route.isActive) {
      navigator.removeRoute(route);
    }
  }

  route = RawDialogRoute<String>(
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (context, _, _) {
      if (scope != workspaceAuthority(controller)) {
        return const SizedBox.shrink();
      }
      if (currentPopover) {
        return themes.wrap(
          Builder(
            builder: (context) {
              final tokens = RaftTokens.of(context);
              final surface = RaftWebSidebarSortMenuRecipe.resolve(
                tokens: tokens.recipeTokens,
                states: tokens.recipeStates(),
              ).root;
              void close([String? mode]) {
                if (scope == workspaceAuthority(controller) &&
                    route.isCurrent) {
                  navigator.pop(mode);
                }
              }

              return Stack(
                children: [
                  RaftAnchoredPopup(
                    anchorKey: anchor,
                    alignRight: true,
                    gap: 8,
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.escape): () =>
                            close(),
                      },
                      child: Focus(
                        autofocus: true,
                        child: RaftSelectionPopover(
                          key: const Key('sidebar-sort-popover'),
                          title: raftText(context, 'Sort'),
                          showHeader: false,
                          width: surface.minWidth,
                          surfaceStyle: surface,
                          options: [
                            for (final entry in const {
                              'manual': 'Manual',
                              'recent': 'Recent',
                              'az': 'A-Z',
                            }.entries)
                              RaftSelectionOption(
                                rowKey: ValueKey('sidebar-sort-${entry.key}'),
                                label: raftText(context, entry.value),
                                checked: entry.key == current,
                                onTap: () => close(entry.key),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }
      final size = MediaQuery.sizeOf(context);
      final width = math.min(136.0, size.width - 16);
      final touch = RaftDensityScope.of(context) == RaftDensity.touch;
      final height = (touch ? 48.0 : 36.0) * 3 + 8;
      final left = (rect.right - width).clamp(
        8.0,
        math.max(8.0, size.width - width - 8),
      );
      final top = (rect.bottom + 8).clamp(
        8.0,
        math.max(8.0, size.height - height - 8),
      );
      void close([String? mode]) {
        if (scope == workspaceAuthority(controller) && route.isCurrent) {
          navigator.pop(mode);
        }
      }

      return Stack(
        children: [
          Positioned(
            left: left.toDouble(),
            top: top.toDouble(),
            child: Material(
              color: Colors.transparent,
              child: RaftMenuPanel(
                key: const Key('sidebar-sort-popover'),
                width: width,
                kind: RaftMenuKind.selectionPopover,
                onDismiss: () => close(),
                children: [
                  for (final entry in const {
                    'manual': 'Manual',
                    'recent': 'Recent',
                    'az': 'A-Z',
                  }.entries)
                    RaftMenuItem(
                      key: ValueKey('sidebar-sort-${entry.key}'),
                      label: raftText(context, entry.value),
                      kind: RaftMenuKind.selectionPopover,
                      selected: entry.key == current,
                      autofocus: entry.key == current,
                      onPressed: () => close(entry.key),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
  controller.addListener(revoke);
  try {
    final result = await navigator.push(route);
    return scope == workspaceAuthority(controller) ? result : null;
  } finally {
    controller.removeListener(revoke);
    if (scope == workspaceAuthority(controller) &&
        previousFocus?.context != null) {
      previousFocus!.requestFocus();
    }
  }
}
