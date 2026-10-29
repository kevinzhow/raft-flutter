part of 'components.dart';

/// The expanded editor of [RaftComposer]: opens a larger editor over the same
/// draft. The expanded text field uses the composer's own controller, undo
/// history, mention map and suggestion state, so there is one draft whichever
/// view is showing. The presentation primitive picks the form from the window
/// width: a centered dialog on a wide window, a bottom sheet on a narrow one.
extension _RaftComposerExpansion on _RaftComposerState {
  /// Runs a Markdown edit on the draft (toolbar buttons, format shortcuts).
  void applyFormat(TextEditingValue Function(TextEditingValue) op) {
    // A composition belongs to the input method until it commits.
    if (composing) return;
    controller.value = op(controller.value);
  }

  void toggleExpanded() {
    if (composing) return;
    if (expanded) {
      closeExpanded();
    } else {
      openExpanded();
    }
  }

  /// Whether Send is available now; shared by the inline and expanded rows.
  bool get submitReady =>
      widget.enabled &&
      widget.canSend &&
      !sending &&
      !widget.submitBusy &&
      !composing &&
      (controller.text.trim().isNotEmpty || widget.hasAttachments);

  void openExpanded() {
    // An IME composition lives in the inline field's input connection; moving
    // it mid-composition would drop or commit the marked text.
    if (expanded ||
        !presentationActive ||
        !widget.enabled ||
        composing ||
        sending ||
        widget.submitBusy) {
      return;
    }
    // One route for every layout: the presentation primitive picks the form
    // (dialog or bottom sheet) from the live window width, so the editor stays
    // open and keeps its state when the window crosses the breakpoint.
    final route = raftPresentedRoute<void>(
      context,
      policy: RaftPresentationPolicy.editor,
      label: raftText(context, 'Collapse editor'),
      dialogMaxWidth: RaftComposerExpandedView.dialogMaxWidth,
      dialogMaxHeight: RaftComposerExpandedView.dialogMaxHeight,
      dialogFillsHeight: true,
      sheetFillsHeight: true,
      content: (routeContext, form) => Material(
        type: MaterialType.transparency,
        child: _expandedContent(form),
      ),
    );
    expandedRoute = route;
    controller.styled = true;
    // Until the route is gone the inline field is a static stand-in, so
    // exactly one EditableText is attached to the draft.
    expansion = route.completed.whenComplete(_expandedClosed);
    unawaited(Navigator.of(context, rootNavigator: true).push(route));
    rebuild();
    // The expanded field's popup portal mounts with the route: switch the
    // popup over once it is built.
    updateSuggestionPortal(defer: true);
  }

  Widget _expandedContent(RaftSurfaceForm form) => ListenableBuilder(
    listenable: Listenable.merge([controller, expandedChanges]),
    builder: (context, _) {
      final t = RaftTokens.of(context);
      final phone = form != RaftSurfaceForm.dialog;
      final recipe = RaftComposerRecipe(t, desktop: !phone, bottomSafeInset: 0);
      final mac = switch (Theme.of(context).platform) {
        TargetPlatform.macOS || TargetPlatform.iOS => true,
        _ => false,
      };
      return RaftComposerExpandedView(
        form: form,
        title: widget.hint,
        controller: controller,
        onCollapse: closeExpanded,
        attachments: widget.attachments,
        previewBuilder: widget.previewBuilder,
        editor: LayoutBuilder(
          builder: (context, box) => OverlayPortal(
            controller: expandedPortal,
            overlayChildBuilder: (_) =>
                suggestionPopup(recipe, box.maxWidth, link: expandedLink),
            child: CompositedTransformTarget(
              link: expandedLink,
              child: buildEditorField(context, recipe, expanded: true),
            ),
          ),
        ),
        footer: (recipe) => RaftComposerActionRow(
          recipe: recipe,
          enabled: widget.enabled,
          busy: sending || widget.submitBusy,
          onImagePick: widget.onImagePick,
          onAttach: widget.onAttach,
          taskAction: widget.taskAction,
          submitTooltip: widget.submitTooltip,
          spinner: widget.submitSpinner,
          submitEnabled: submitReady,
          onSend: send,
          inset: const EdgeInsets.fromLTRB(
            RaftComposerExpandedLayout.pad,
            0,
            RaftComposerExpandedLayout.pad,
            RaftComposerExpandedLayout.gap,
          ),
          hint: phone || RaftInteraction.of(context).touch
              ? null
              : raftText(
                  context,
                  mac
                      ? 'Enter adds a line · Cmd+Enter sends'
                      : 'Enter adds a line · Ctrl+Enter sends',
                ),
        ),
      );
    },
  );

  /// Collapses the editor; the draft stays as it is.
  void closeExpanded() {
    final route = expandedRoute;
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      route.navigator?.pop();
    } else {
      route.navigator?.removeRoute(route);
    }
  }

  void _expandedClosed() {
    expansion = null;
    expandedRoute = null;
    if (!mounted) return;
    // The expanded field is gone: a composition it held has no input
    // connection any more, and a stale range would block Send and Expand.
    if (composing) controller.clearComposing();
    controller.styled = false;
    updateSuggestionPortal();
    rebuild();
    // The inline field is back on the next frame; focus it then.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !expanded && presentationActive && widget.enabled) {
        focus.requestFocus();
      }
    });
  }

  /// The composer is leaving the tree while its editor is open: the route goes
  /// with it, once the tree is no longer locked.
  void closeExpandedAfterDispose() {
    final route = expandedRoute;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  /// The expanded view follows state the composer holds (busy, enabled,
  /// attachments); it rebuilds after the composer does.
  void queueExpandedRefresh() {
    if (expandedRefreshQueued) return;
    expandedRefreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      expandedRefreshQueued = false;
      if (mounted && expanded) expandedChanges.value++;
    });
  }
}
