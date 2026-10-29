/// Bypass scan: raw Material/Cupertino controls and overlays used instead of
/// the Raft design-system components (packages/raft_ui).
///
/// Counts constructor calls, static `styleFrom` calls, function calls and
/// tear-offs of the widgets and functions in [bypassFamilies], plus classes
/// that `extend` one of them. Decisions come from resolved elements: the
/// declaring library must be the Flutter material/cupertino library (or the
/// widgets library for the few widgets-layer names), so a Raft or app class
/// with the same name never counts. Categories are `bypass.<family>`; the exact
/// rule is documented in docs/ds-migration.md ("Bypass rules").
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import 'ds_audit.dart';

/// Material/Cupertino/widgets class or function name -> bypass family.
const Map<String, String> bypassFamilies = {
  // Dialogs and route hosts.
  'AlertDialog': 'dialog',
  'SimpleDialog': 'dialog',
  'SimpleDialogOption': 'dialog',
  'Dialog': 'dialog', // includes Dialog.fullscreen
  'AboutDialog': 'dialog',
  'CupertinoAlertDialog': 'dialog',
  'CupertinoDialogAction': 'dialog',
  'showDialog': 'dialog',
  'showAdaptiveDialog': 'dialog',
  'showCupertinoDialog': 'dialog',
  'showAboutDialog': 'dialog',
  'showGeneralDialog': 'dialog', // widgets library
  // Bottom sheets.
  'BottomSheet': 'bottom_sheet',
  'CupertinoActionSheet': 'bottom_sheet',
  'CupertinoActionSheetAction': 'bottom_sheet',
  'showModalBottomSheet': 'bottom_sheet',
  'showBottomSheet': 'bottom_sheet',
  'showCupertinoModalPopup': 'bottom_sheet',
  // Menus.
  'PopupMenuButton': 'menu',
  'PopupMenuItem': 'menu',
  'PopupMenuDivider': 'menu',
  'CheckedPopupMenuItem': 'menu',
  'MenuAnchor': 'menu',
  'MenuItemButton': 'menu',
  'SubmenuButton': 'menu',
  'MenuBar': 'menu',
  'CheckboxMenuButton': 'menu',
  'RadioMenuButton': 'menu',
  'CupertinoContextMenu': 'menu',
  'CupertinoContextMenuAction': 'menu',
  'showMenu': 'menu',
  // Selects.
  'DropdownButton': 'select',
  'DropdownButtonFormField': 'select',
  'DropdownMenuItem': 'select',
  'DropdownMenu': 'select',
  'DropdownMenuEntry': 'select',
  'DropdownButtonHideUnderline': 'select',
  // Tooltips.
  'Tooltip': 'tooltip',
  // Buttons.
  'TextButton': 'button',
  'OutlinedButton': 'button',
  'ElevatedButton': 'button',
  'FilledButton': 'button',
  'MaterialButton': 'button',
  'RawMaterialButton': 'button',
  'FloatingActionButton': 'button',
  'CupertinoButton': 'button',
  'IconButton': 'icon_button',
  'BackButton': 'icon_button',
  'CloseButton': 'icon_button',
  // Toggles.
  'Checkbox': 'toggle',
  'CheckboxListTile': 'toggle',
  'Switch': 'toggle',
  'SwitchListTile': 'toggle',
  'Radio': 'toggle',
  'RadioListTile': 'toggle',
  'CupertinoSwitch': 'toggle',
  'CupertinoCheckbox': 'toggle',
  'CupertinoRadio': 'toggle',
  // Chips.
  'Chip': 'chip',
  'ActionChip': 'chip',
  'FilterChip': 'chip',
  'ChoiceChip': 'chip',
  'InputChip': 'chip',
  'RawChip': 'chip',
  // List rows.
  'ListTile': 'list_tile',
  'ExpansionTile': 'list_tile',
  'CupertinoListTile': 'list_tile',
  // Progress and refresh.
  'CircularProgressIndicator': 'progress',
  'LinearProgressIndicator': 'progress',
  'RefreshProgressIndicator': 'progress',
  'CupertinoActivityIndicator': 'progress',
  'RefreshIndicator': 'refresh',
  // Dividers.
  'Divider': 'divider',
  'VerticalDivider': 'divider',
  // Text input.
  'TextField': 'text_field',
  'TextFormField': 'text_field',
  'EditableText': 'text_field', // widgets library
  'CupertinoTextField': 'text_field',
  'CupertinoSearchTextField': 'text_field',
  'SearchBar': 'text_field',
  // Date and time pickers.
  'showDatePicker': 'picker',
  'showTimePicker': 'picker',
  'showDateRangePicker': 'picker',
  'DatePickerDialog': 'picker',
  'TimePickerDialog': 'picker',
  'CalendarDatePicker': 'picker',
  'CupertinoDatePicker': 'picker',
  'CupertinoTimerPicker': 'picker',
  // Snackbars and banners.
  'SnackBar': 'snackbar',
  'MaterialBanner': 'snackbar',
  'showSnackBar': 'snackbar',
  'showMaterialBanner': 'snackbar',
  // Hand-built popover hosts (widgets library).
  'OverlayEntry': 'overlay',
  'OverlayPortal': 'overlay',
};

/// Names declared in the widgets library instead of material/cupertino.
const Set<String> bypassWidgetsLibraryNames = {
  'showGeneralDialog',
  'EditableText',
  'OverlayEntry',
  'OverlayPortal',
};

/// Methods on Material state objects that open raw surfaces.
const Map<String, Set<String>> bypassStateMethods = {
  'ScaffoldMessengerState': {'showSnackBar', 'showMaterialBanner'},
  'ScaffoldState': {'showBottomSheet'},
};

String? _flutterDir(Element? e) {
  final uri = e?.library?.uri.toString() ?? '';
  const prefix = 'package:flutter/src/';
  if (!uri.startsWith(prefix)) return null;
  return uri.substring(prefix.length).split('/').first;
}

/// The bypass family of the Flutter declaration [e] named [name], or null.
String? bypassFamilyOf(Element? e, String name) {
  final family = bypassFamilies[name];
  if (family == null) return null;
  final dir = _flutterDir(e);
  final wanted = bypassWidgetsLibraryNames.contains(name)
      ? dir == 'widgets'
      : dir == 'material' || dir == 'cupertino';
  return wanted ? family : null;
}

/// Collects `bypass.<family>` findings from one resolved unit.
///
/// [wrapperAllow] maps a family to the reason this file may use it (the file is
/// a designated raft_ui wrapper); those findings are reported as allowlisted
/// instead of enforced.
class BypassAuditVisitor extends AuditVisitorBase {
  BypassAuditVisitor(
    super.relativePath,
    super.unit, {
    this.wrapperAllow = const {},
  });

  final Map<String, String> wrapperAllow;

  void _report(AstNode node, String family, String name) => add(
    node,
    'bypass.$family',
    name,
    forcedAllow: wrapperAllow[family] == null
        ? null
        : 'raft_ui wrapper: ${wrapperAllow[family]}',
  );

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final cls = node.constructorName.element?.enclosingElement;
    if (cls is InterfaceElement) {
      final name = cls.name ?? '';
      final family = bypassFamilyOf(cls, name);
      if (family != null) {
        final ctor = node.constructorName.name?.name;
        _report(node, family, ctor == null ? name : '$name.$ctor');
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitConstructorReference(ConstructorReference node) {
    final cls = node.constructorName.element?.enclosingElement;
    if (cls is InterfaceElement) {
      final name = cls.name ?? '';
      final family = bypassFamilyOf(cls, name);
      if (family != null) _report(node, family, '$name.new');
    }
    super.visitConstructorReference(node);
  }

  @override
  void visitExtendsClause(ExtendsClause node) {
    final element = node.superclass.element;
    if (element is InterfaceElement) {
      final name = element.name ?? '';
      final family = bypassFamilyOf(element, name);
      if (family != null) _report(node, family, 'extends $name');
    }
    super.visitExtendsClause(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final element = node.methodName.element;
    final name = node.methodName.name;
    if (element is TopLevelFunctionElement) {
      final family = bypassFamilyOf(element, name);
      if (family != null) _report(node, family, '$name()');
    } else if (element is MethodElement) {
      final owner = element.enclosingElement;
      if (owner is InterfaceElement) {
        final ownerName = owner.name ?? '';
        if (name == 'styleFrom') {
          final family = bypassFamilyOf(owner, ownerName);
          if (family != null) _report(node, family, '$ownerName.styleFrom()');
        } else if (bypassStateMethods[ownerName]?.contains(name) ?? false) {
          if (_flutterDir(owner) == 'material') {
            _report(node, bypassFamilies[name]!, '$ownerName.$name()');
          }
        }
      }
    }
    super.visitMethodInvocation(node);
  }

  /// A function used as a value (`onTap: showDialog`) is a reference too.
  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;
    if (element is TopLevelFunctionElement &&
        !node.inDeclarationContext() &&
        !(node.parent is MethodInvocation &&
            (node.parent as MethodInvocation).methodName == node)) {
      final family = bypassFamilyOf(element, node.name);
      if (family != null) _report(node, family, '${node.name} (reference)');
    }
    super.visitSimpleIdentifier(node);
  }
}
