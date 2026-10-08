/// Resolved-AST scanner for design-system drift in the Raft Flutter app.
///
/// Every finding is decided from resolved elements (the declaring library of
/// a constructor, getter or function), not from source text, so names in
/// strings/comments, app-local classes and raft_ui subclasses are never
/// miscounted. The categories and their exact rules are documented in
/// docs/ds-migration.md ("Audit rules").
library;

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/line_info.dart';

/// One design-system violation (or allowlisted exception).
class Finding {
  Finding({
    required this.file,
    required this.line,
    required this.column,
    required this.category,
    required this.name,
    this.allowReason,
    this.allowError,
    this.shape,
  });

  final String file;
  final int line;
  final int column;

  /// `widget.<group>` or `style.<kind>`.
  final String category;

  /// The material class / function / member or literal kind that triggered it.
  final String name;

  /// Non-null when a `// ds-allow: <reason>` comment covers this finding.
  final String? allowReason;

  /// Non-null when a ds-allow comment is present but malformed (no reason).
  final String? allowError;

  /// For widget findings: named arguments passed, with the constructed class
  /// of widget-valued ones (e.g. `leading=RaftAvatar`). Used by the migration
  /// map to split one Material class into its replacement shapes.
  final List<String>? shape;

  bool get allowed => allowReason != null;

  Map<String, Object?> toJson() => {
    'file': file,
    'line': line,
    'column': column,
    'category': category,
    'name': name,
    'allowed': allowed,
    if (allowReason != null) 'allowReason': allowReason,
    if (allowError != null) 'allowError': allowError,
    if (shape != null) 'shape': shape,
  };
}

/// Material/Cupertino class or function name -> replacement group.
///
/// Groups are reported as `widget.<group>`. Any other Material/Cupertino
/// Widget subclass that is constructed is reported as `widget.other`.
const Map<String, String> materialGroups = {
  // Buttons.
  'TextButton': 'button',
  'ElevatedButton': 'button',
  'FilledButton': 'button',
  'OutlinedButton': 'button',
  'MaterialButton': 'button',
  'RawMaterialButton': 'button',
  'FloatingActionButton': 'button',
  'BackButton': 'button',
  'CloseButton': 'button',
  'DrawerButton': 'button',
  'EndDrawerButton': 'button',
  'CupertinoButton': 'button',
  'ButtonStyle': 'button',
  'ButtonBar': 'button',
  'IconButton': 'icon_button',
  'BackButtonIcon': 'icon_button',
  'CloseButtonIcon': 'icon_button',
  // List rows.
  'ListTile': 'list_tile',
  'CheckboxListTile': 'list_tile',
  'SwitchListTile': 'list_tile',
  'RadioListTile': 'list_tile',
  'ExpansionTile': 'list_tile',
  'CupertinoListTile': 'list_tile',
  'CupertinoListSection': 'list_tile',
  // Dialogs.
  'AlertDialog': 'dialog',
  'SimpleDialog': 'dialog',
  'SimpleDialogOption': 'dialog',
  'Dialog': 'dialog',
  'AboutDialog': 'dialog',
  'CupertinoAlertDialog': 'dialog',
  'CupertinoDialogAction': 'dialog',
  'showDialog': 'dialog',
  'showAdaptiveDialog': 'dialog',
  'showCupertinoDialog': 'dialog',
  'showAboutDialog': 'dialog',
  'showLicensePage': 'dialog',
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
  // Text input.
  'TextField': 'text_field',
  'TextFormField': 'text_field',
  'InputDecoration': 'text_field',
  'InputDecorator': 'text_field',
  'OutlineInputBorder': 'text_field',
  'UnderlineInputBorder': 'text_field',
  'CupertinoTextField': 'text_field',
  'CupertinoSearchTextField': 'text_field',
  'SearchBar': 'text_field',
  'SearchAnchor': 'text_field',
  'Autocomplete': 'text_field',
  'showSearch': 'text_field',
  // Progress.
  'CircularProgressIndicator': 'progress',
  'LinearProgressIndicator': 'progress',
  'RefreshProgressIndicator': 'progress',
  'RefreshIndicator': 'progress',
  'CupertinoActivityIndicator': 'progress',
  // Tooltip.
  'Tooltip': 'tooltip',
  // Chips / badges.
  'Chip': 'chip',
  'ActionChip': 'chip',
  'FilterChip': 'chip',
  'ChoiceChip': 'chip',
  'InputChip': 'chip',
  'RawChip': 'chip',
  'Badge': 'chip',
  // Navigation.
  'TabBar': 'navigation',
  'Tab': 'navigation',
  'TabBarView': 'navigation',
  'DefaultTabController': 'navigation',
  'NavigationBar': 'navigation',
  'NavigationDestination': 'navigation',
  'NavigationRail': 'navigation',
  'NavigationRailDestination': 'navigation',
  'BottomNavigationBar': 'navigation',
  'Drawer': 'navigation',
  'NavigationDrawer': 'navigation',
  'NavigationDrawerDestination': 'navigation',
  'CupertinoTabBar': 'navigation',
  'CupertinoTabScaffold': 'navigation',
  // Segmented controls.
  'SegmentedButton': 'segmented',
  'ButtonSegment': 'segmented',
  'ToggleButtons': 'segmented',
  'CupertinoSegmentedControl': 'segmented',
  'CupertinoSlidingSegmentedControl': 'segmented',
  // Toggles.
  'Checkbox': 'toggle',
  'Switch': 'toggle',
  'Radio': 'toggle',
  'CupertinoSwitch': 'toggle',
  'CupertinoCheckbox': 'toggle',
  'CupertinoRadio': 'toggle',
  // Snackbars / banners.
  'SnackBar': 'snackbar',
  'SnackBarAction': 'snackbar',
  'MaterialBanner': 'snackbar',
  'showSnackBar': 'snackbar',
  'showMaterialBanner': 'snackbar',
  // Bottom sheets.
  'BottomSheet': 'bottom_sheet',
  'CupertinoActionSheet': 'bottom_sheet',
  'CupertinoActionSheetAction': 'bottom_sheet',
  'showModalBottomSheet': 'bottom_sheet',
  'showBottomSheet': 'bottom_sheet',
  'showCupertinoModalPopup': 'bottom_sheet',
  // App bars.
  'AppBar': 'app_bar',
  'SliverAppBar': 'app_bar',
  'BottomAppBar': 'app_bar',
  'CupertinoNavigationBar': 'app_bar',
  'CupertinoSliverNavigationBar': 'app_bar',
  // Dividers.
  'Divider': 'divider',
  'VerticalDivider': 'divider',
  // Surfaces.
  'Card': 'surface',
  'Material': 'surface',
  // Raw ink interaction.
  'InkWell': 'ink',
  'InkResponse': 'ink',
  'Ink': 'ink',
  // Page scaffolds.
  'Scaffold': 'scaffold',
  'CupertinoPageScaffold': 'scaffold',
};

/// Material/Cupertino app-root infrastructure that has no design-system role.
const Set<String> ignoredMaterialClasses = {
  'MaterialApp',
  'CupertinoApp',
  'ScaffoldMessenger',
};

/// Methods on Material state objects that open design-system surfaces.
const Map<String, Set<String>> materialStateMethods = {
  'ScaffoldMessengerState': {'showSnackBar', 'showMaterialBanner'},
  'ScaffoldState': {'showBottomSheet'},
};

/// Widget-library functions that open raw surfaces.
const Map<String, String> widgetsFunctionGroups = {
  'showGeneralDialog': 'dialog',
};

/// Named arguments on framework constructors that carry hand-written sizes.
const Set<String> dimensionArguments = {
  'width',
  'height',
  'size',
  'dimension',
  'minWidth',
  'maxWidth',
  'minHeight',
  'maxHeight',
  'iconSize',
  'strokeWidth',
  'thickness',
  'indent',
  'endIndent',
  'spacing',
  'runSpacing',
  'elevation',
  'radius',
  'splashRadius',
};

const Set<String> textMetricArguments = {
  'height',
  'letterSpacing',
  'wordSpacing',
};

final RegExp _allowPattern = RegExp(r'//\s*ds-allow:(.*)$');

bool _isFlutterLib(Element? e, String dir) =>
    e?.library?.uri.toString().startsWith('package:flutter/src/$dir/') ?? false;

bool _isMaterialLike(Element? e) =>
    _isFlutterLib(e, 'material') || _isFlutterLib(e, 'cupertino');

bool _isFramework(Element? e) =>
    e?.library?.uri.toString().startsWith('package:flutter/') ?? false;

bool _isClass(Element? e, String name, String libraryPrefix) =>
    e is InterfaceElement &&
    e.name == name &&
    (e.library.uri.toString().startsWith(libraryPrefix));

bool _isWidget(InterfaceElement cls) {
  bool isWidgetType(InterfaceType t) =>
      t.element.name == 'Widget' &&
      t.element.library.uri.toString() ==
          'package:flutter/src/widgets/framework.dart';
  return cls.allSupertypes.any(isWidgetType);
}

/// True when [node] contains an int/double literal that is not inside a
/// closure, an index expression, or a nested creation that [skip] excludes.
bool containsNumericLiteral(
  AstNode node, {
  bool Function(InstanceCreationExpression)? skip,
}) {
  final finder = _NumericLiteralFinder(skip);
  node.accept(finder);
  return finder.found;
}

class _NumericLiteralFinder extends RecursiveAstVisitor<void> {
  _NumericLiteralFinder(this.skip);
  final bool Function(InstanceCreationExpression)? skip;
  bool found = false;

  @override
  void visitIntegerLiteral(IntegerLiteral node) => found = true;

  @override
  void visitDoubleLiteral(DoubleLiteral node) => found = true;

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitIndexExpression(IndexExpression node) => node.target?.accept(this);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (skip != null && skip!(node)) return;
    super.visitInstanceCreationExpression(node);
  }
}

/// Collects findings from one resolved compilation unit.
class DsAuditVisitor extends RecursiveAstVisitor<void> {
  DsAuditVisitor(this.relativePath, ResolvedUnitResult unit)
    : _lineInfo = unit.lineInfo,
      _lines = unit.content.split('\n');

  final String relativePath;
  final LineInfo _lineInfo;
  final List<String> _lines;
  final List<Finding> findings = [];

  void _add(AstNode node, String category, String name, {List<String>? shape}) {
    final location = _lineInfo.getLocation(node.offset);
    final line = location.lineNumber;
    String? reason;
    String? error;
    for (final candidate in [line, line - 1]) {
      if (candidate < 1 || candidate > _lines.length) continue;
      final text = _lines[candidate - 1];
      if (candidate == line - 1 && !text.trimLeft().startsWith('//')) continue;
      final match = _allowPattern.firstMatch(text);
      if (match == null) continue;
      final value = match.group(1)!.trim();
      if (value.isEmpty) {
        error = 'ds-allow comment needs a reason';
      } else {
        reason = value;
      }
      break;
    }
    findings.add(
      Finding(
        file: relativePath,
        line: line,
        column: location.columnNumber,
        category: category,
        name: name,
        allowReason: reason,
        allowError: error,
        shape: shape,
      ),
    );
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructor = node.constructorName.element;
    final cls = constructor?.enclosingElement;
    if (cls != null) _checkCreation(node, cls);
    super.visitInstanceCreationExpression(node);
  }

  void _checkCreation(InstanceCreationExpression node, InterfaceElement cls) {
    final name = cls.name ?? '';
    final ctor = node.constructorName.name?.name;
    final display = ctor == null ? name : '$name.$ctor';
    final library = cls.library.uri.toString();

    if (_isMaterialLike(cls)) {
      final group = materialGroups[name];
      if (group != null) {
        _add(node, 'widget.$group', display, shape: _shape(node.argumentList));
      } else if (name == 'Theme' ||
          name == 'ColorScheme' ||
          name == 'TextTheme' ||
          name.endsWith('ThemeData') ||
          name.endsWith('Theme')) {
        _add(node, 'style.material_theme', display);
      } else if (!ignoredMaterialClasses.contains(name) && _isWidget(cls)) {
        _add(node, 'widget.other', display, shape: _shape(node.argumentList));
      }
    }

    final args = node.argumentList.arguments;
    if (library == 'package:flutter/src/painting/edge_insets.dart' &&
        (name == 'EdgeInsets' || name == 'EdgeInsetsDirectional')) {
      if (args.any(containsNumericLiteral)) {
        _add(node, 'style.edge_insets', display);
      }
      return;
    }
    if (name == 'SizedBox' &&
        library == 'package:flutter/src/widgets/basic.dart') {
      final sized = args.any(
        (a) =>
            a is NamedExpression &&
            const {
              'width',
              'height',
              'dimension',
            }.contains(a.name.label.name) &&
            containsNumericLiteral(a.expression),
      );
      if (sized) _add(node, 'style.sized_box', display);
      return;
    }
    if (name == 'TextStyle' &&
        library == 'package:flutter/src/painting/text_style.dart') {
      _add(node, 'style.text_style', display);
      return;
    }
    if (name == 'StrutStyle') return;
    if (name == 'Color' && library == 'dart:ui') {
      _add(node, 'style.color_literal', display);
      return;
    }
    if (const {
              'BorderRadius',
              'BorderRadiusDirectional',
              'Radius',
            }.contains(name) &&
            library == 'package:flutter/src/painting/border_radius.dart' ||
        name == 'Radius' && library == 'dart:ui') {
      bool nestedRadius(InstanceCreationExpression inner) {
        final innerName = inner.constructorName.element?.enclosingElement.name;
        return const {
          'BorderRadius',
          'BorderRadiusDirectional',
          'Radius',
        }.contains(innerName);
      }

      if (args.any((a) => containsNumericLiteral(a, skip: nestedRadius))) {
        _add(node, 'style.border_radius', display);
      }
      return;
    }
    if (name == 'Duration' && library == 'dart:core') {
      if (args.any(containsNumericLiteral) && _isAnimationDuration(node)) {
        _add(node, 'style.duration', display);
      }
      return;
    }
    if (_isFramework(cls)) {
      for (final arg in args.whereType<NamedExpression>()) {
        final label = arg.name.label.name;
        if (dimensionArguments.contains(label) &&
            containsNumericLiteral(arg.expression)) {
          _add(arg, 'style.dimension', '$name($label:)');
        }
      }
    }
  }

  List<String> _shape(ArgumentList arguments) => [
    for (final arg in arguments.arguments.whereType<NamedExpression>())
      switch (arg.expression) {
        InstanceCreationExpression(:final constructorName) =>
          '${arg.name.label.name}=${constructorName.type.name.lexeme}',
        _ => arg.name.label.name,
      },
  ];

  /// A Duration literal counts when it feeds a parameter whose name contains
  /// "duration" (AnimatedFoo, AnimationController, animateTo, Tooltip,
  /// SnackBar, page transitions).
  /// Conditional/parenthesized/`??` wrappers are looked through, so
  /// `duration: reduceMotion ? Duration.zero : const Duration(...)` counts.
  bool _isAnimationDuration(InstanceCreationExpression node) {
    AstNode? parent = node.parent;
    while (parent is ConditionalExpression ||
        parent is ParenthesizedExpression ||
        parent is BinaryExpression) {
      parent = parent!.parent;
    }
    return parent is NamedExpression &&
        parent.name.label.name.toLowerCase().contains('duration');
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    final label = node.name.label.name;
    if (label == 'fontSize' && containsNumericLiteral(node.expression)) {
      _add(node, 'style.font_size', 'fontSize:');
    } else if (label == 'fontWeight' && _mentionsFontWeight(node.expression)) {
      _add(node, 'style.font_weight', 'fontWeight:');
    } else if (textMetricArguments.contains(label) &&
        _isTextStyleInvocation(node) &&
        containsNumericLiteral(node.expression)) {
      _add(node, 'style.text_metrics', '$label:');
    }
    super.visitNamedExpression(node);
  }

  bool _mentionsFontWeight(Expression expression) {
    var found = false;
    expression.accept(
      _IdentifierVisitor((id) {
        final element = id.element;
        if (element != null &&
            _isClass(element.enclosingElement, 'FontWeight', 'dart:ui')) {
          found = true;
        }
      }),
    );
    return found;
  }

  bool _isTextStyleInvocation(NamedExpression node) {
    final owner = node.parent?.parent;
    Element? cls;
    if (owner is InstanceCreationExpression) {
      cls = owner.constructorName.element?.enclosingElement;
    } else if (owner is MethodInvocation) {
      cls = owner.methodName.element?.enclosingElement;
    }
    return cls is InterfaceElement &&
        const {'TextStyle', 'StrutStyle'}.contains(cls.name) &&
        _isFramework(cls);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final element = node.methodName.element;
    final name = node.methodName.name;
    if (element is TopLevelFunctionElement) {
      if (_isMaterialLike(element)) {
        _add(node, 'widget.${materialGroups[name] ?? 'other'}', '$name()');
      } else if (_isFlutterLib(element, 'widgets') &&
          widgetsFunctionGroups.containsKey(name)) {
        _add(node, 'widget.${widgetsFunctionGroups[name]}', '$name()');
      }
    } else if (element is MethodElement) {
      final owner = element.enclosingElement;
      if (owner is InterfaceElement && _isMaterialLike(owner)) {
        final ownerName = owner.name ?? '';
        final group = materialGroups[ownerName];
        if (name == 'styleFrom' && group != null) {
          _add(node, 'widget.$group', '$ownerName.styleFrom()');
        } else if (materialStateMethods[ownerName]?.contains(name) ?? false) {
          _add(node, 'widget.${materialGroups[name]}', '$name()');
        } else if (name == 'of' &&
            const {'ColorScheme', 'TextTheme'}.contains(ownerName)) {
          _add(node, 'style.material_theme', '$ownerName.of()');
        }
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;
    if (element is PropertyAccessorElement || element is FieldElement) {
      final owner = element!.enclosingElement;
      if (owner is InterfaceElement) {
        final ownerName = owner.name;
        if ((ownerName == 'Colors' && _isFlutterLib(owner, 'material')) ||
            (ownerName == 'CupertinoColors' &&
                _isFlutterLib(owner, 'cupertino'))) {
          _add(node, 'style.material_colors', '$ownerName.${node.name}');
        } else if ((ownerName == 'Icons' && _isFlutterLib(owner, 'material')) ||
            (ownerName == 'CupertinoIcons' &&
                _isFlutterLib(owner, 'cupertino'))) {
          _add(node, 'style.material_icons', '$ownerName.${node.name}');
        } else if (ownerName == 'Durations' &&
            _isFlutterLib(owner, 'material')) {
          _add(node, 'style.duration', 'Durations.${node.name}');
        } else if (ownerName == 'ThemeData' &&
            _isFlutterLib(owner, 'material') &&
            !const {'extensions', 'platform'}.contains(node.name)) {
          _add(node, 'style.material_theme', 'ThemeData.${node.name}');
        }
      }
    } else if (element is MethodElement &&
        element.enclosingElement?.name == 'ThemeData' &&
        _isFlutterLib(element, 'material') &&
        node.name != 'extension') {
      _add(node, 'style.material_theme', 'ThemeData.${node.name}()');
    }
    super.visitSimpleIdentifier(node);
  }
}

class _IdentifierVisitor extends RecursiveAstVisitor<void> {
  _IdentifierVisitor(this.onIdentifier);
  final void Function(SimpleIdentifier) onIdentifier;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) => onIdentifier(node);
}
