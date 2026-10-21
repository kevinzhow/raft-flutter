// The runtime form's searchable select, like Web's `RuntimeChoiceCombobox`:
// the field itself is the search input (type to filter, the selected choice is
// shown while closed), and the list opens under it. The rows are a
// [RaftComboboxPanel] without its own header or search box.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'agent_create_form.dart';
import 'anchored_popup.dart';
import 'combobox_panel.dart';
import 'dismiss_scope.dart';
import 'form_presentation.dart' show RaftUnsavedGuard;
import 'icons.dart';
import 'theme.dart';

class RaftAgentCombobox extends StatefulWidget {
  const RaftAgentCombobox({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onSelected,
    this.onCustom,
    this.customLabel,
    this.placeholder,
    this.invalid = false,
    this.enabled = true,
    this.semanticLabel,
  });

  /// Names the list for assistive technology.
  final String label;
  final List<RaftComboboxItem> items;

  /// The stored value (an item id, or text the list does not offer); empty for none.
  final String value;
  final ValueChanged<String> onSelected;

  /// With [customLabel]: typed text that matches no row can be used as is.
  final ValueChanged<String>? onCustom;
  final String Function(String typed)? customLabel;
  final String? placeholder, semanticLabel;
  final bool invalid, enabled;

  @override
  State<RaftAgentCombobox> createState() => _RaftAgentComboboxState();
}

class _RaftAgentComboboxState extends State<RaftAgentCombobox> {
  final panel = RaftComboboxController();
  final focus = FocusNode();
  // Rows are not focusable: choosing one never takes focus from the input.
  final popupScope = FocusScopeNode(
    debugLabel: 'RaftAgentCombobox popup',
    canRequestFocus: false,
  );
  final portal = OverlayPortalController();
  final anchorKey = GlobalKey();
  final group = Object();
  bool open = false;
  double width = 0;

  /// What the field shows while closed: the chosen row's name, else the value.
  String get selectedLabel {
    if (widget.value.isEmpty) return '';
    for (final item in widget.items) {
      if (item.id == widget.value) return item.label;
    }
    return widget.value;
  }

  @override
  void initState() {
    super.initState();
    panel.query.text = selectedLabel;
    focus.addListener(focusChanged);
  }

  @override
  void didUpdateWidget(RaftAgentCombobox old) {
    super.didUpdateWidget(old);
    if (!open && panel.query.text != selectedLabel) {
      panel.query.text = selectedLabel;
      RaftUnsavedGuard.maybeOf(context)?.rebase(panel.query);
    }
    if (open && !widget.enabled) close();
  }

  @override
  void dispose() {
    focus.removeListener(focusChanged);
    focus.dispose();
    popupScope.dispose();
    panel.dispose();
    super.dispose();
  }

  void focusChanged() {
    if (focus.hasFocus) {
      openList();
      return;
    }
    // Focus moving into the list (a tap on a row) keeps it open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && open && !focus.hasFocus && !popupScope.hasFocus) close();
    });
  }

  void openList() {
    if (open || !widget.enabled) return;
    setState(() => open = true);
    // Typing filters; the chosen name stays visible as the placeholder.
    panel.query.clear();
    portal.show();
  }

  void close() {
    if (!open) return;
    portal.hide();
    setState(() => open = false);
    panel.query.text = selectedLabel;
  }

  KeyEventResult keys(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;
    if (open) return panel.handleKey(event);
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.arrowUp)) {
      openList();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final label = selectedLabel;
    return OverlayPortal(
      controller: portal,
      overlayChildBuilder: raftBackDismissed(
        close,
        (context) => Positioned.fill(
          child: Stack(
            children: [
              RaftAnchoredPopup(
                anchorKey: anchorKey,
                movement: Scrollable.maybeOf(context)?.position,
                gap: 4,
                child: SizedBox(
                  width: width,
                  child: TapRegion(
                    groupId: group,
                    // Rows are part of the input for tap-outside purposes.
                    child: TextFieldTapRegion(
                      child: FocusScope(
                        node: popupScope,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: _maxHeight(context),
                          ),
                          child: RaftComboboxPanel.items(
                            label: widget.label,
                            controller: panel,
                            currentId: widget.value,
                            enabled: widget.enabled,
                            items: widget.items,
                            onSelected: (id) {
                              close();
                              widget.onSelected(id);
                            },
                            onDismiss: close,
                            customLabel: widget.customLabel,
                            onCustom: widget.onCustom == null
                                ? null
                                : (typed) {
                                    close();
                                    widget.onCustom!(typed);
                                  },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      child: TapRegion(
        groupId: group,
        onTapOutside: (_) {
          if (open) close();
        },
        child: LayoutBuilder(
          builder: (context, box) {
            width = box.maxWidth.isFinite ? box.maxWidth : 192;
            return Semantics(
              key: anchorKey,
              expanded: open,
              child: RaftAgentTextInput(
                controller: panel.query,
                focusNode: focus,
                semanticLabel: widget.semanticLabel ?? widget.label,
                // The chosen name stays readable while the list is open.
                placeholder: open && label.isNotEmpty
                    ? label
                    : widget.placeholder,
                invalid: widget.invalid,
                enabled: widget.enabled,
                onTap: openList,
                onKeyEvent: keys,
                trailing: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.enabled
                      ? () {
                          if (open) {
                            close();
                          } else {
                            focus.requestFocus();
                            openList();
                          }
                        }
                      : null,
                  child: RaftIcon(
                    RaftGlyph.chevronDown,
                    size: 14,
                    strokeWidth: 1.5,
                    color: t.muted,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  double _maxHeight(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * .5;
    return height < 360 ? height : 360;
  }
}
