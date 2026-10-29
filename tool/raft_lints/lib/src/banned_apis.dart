import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import 'checks.dart';

/// A reference to an API: a class (`member == null`), or a member of a class.
/// [library] is a URI prefix such as `package:flutter/` or `dart:io`; [owner]
/// is the declaring class name (null for a top-level function); [member] is the
/// constructor name (`''` for the unnamed one), method or field name, null for
/// "the class itself and every constructor".
class ApiRef {
  const ApiRef(this.library, this.owner, [this.member]);
  final String library;
  final String? owner;
  final String? member;

  bool matches(Element element) {
    var lib = element.library?.uri.toString();
    // dart:io re-exports its HTTP and WebSocket classes from dart:_http.
    if (lib == 'dart:_http') lib = 'dart:io';
    if (lib == null || !lib.startsWith(library)) return false;
    switch (element) {
      case ConstructorElement():
        if (owner == null || element.enclosingElement.name != owner) {
          return false;
        }
        final name = element.name == 'new' ? '' : (element.name ?? '');
        return member == null || name == member;
      case InterfaceElement():
        return owner == element.name && member == null;
      case ExecutableElement():
        final enclosing = element.enclosingElement;
        final enclosingName = enclosing is InterfaceElement
            ? enclosing.name
            : null;
        return enclosingName == owner && element.name == member;
      case PropertyInducingElement():
        final enclosing = element.enclosingElement;
        return enclosing is InterfaceElement &&
            enclosing.name == owner &&
            element.name == member;
      default:
        return false;
    }
  }
}

/// One banned-API rule: a name, a message and the references it forbids.
/// Constructors are matched where they are called; [typeReferences] also bans
/// the class as a type name (`Slider x`, `extends Slider`).
class BannedApi {
  const BannedApi({
    required this.rule,
    required this.message,
    required this.correction,
    required this.refs,
    this.typeReferences = false,
    this.namedArguments = const [],
    this.custom,
  });
  final String rule;
  final String message;
  final String correction;
  final List<ApiRef> refs;
  final bool typeReferences;

  /// Named-argument labels that are banned outright (`backgroundImage:`).
  final List<String> namedArguments;

  /// A syntactic check on a hooked node, for shapes a reference cannot express
  /// (a zero-delay argument, a callback passed by name).
  final bool Function(AstNode node)? custom;

  bool matches(Element? element) =>
      element != null && refs.any((r) => r.matches(element));

  /// Whether the hooked [node] (resolving to [element]) is a violation.
  bool hit(AstNode node, Element? element) =>
      matches(element) || (custom?.call(node) ?? false);
}

const proxyRule = 'avoid_unproxied_network_client';
const imageRule = 'avoid_raw_image_decode';
const underlineRule = 'avoid_builtin_underline';
const sliderRule = 'avoid_material_slider';
const feedbackRule = 'avoid_material_feedback';
const idleRule = 'avoid_unreviewed_idle_work';
const selectionRule = 'avoid_bare_selection_area';
const sheetRule = 'avoid_raw_bottom_sheet';
const viewDisplayRule = 'avoid_view_display';

String _ignore(String rule) =>
    "add '// ignore: raft_lints/$rule -- <why this site is exempt>'";

final bannedApis = <BannedApi>[
  BannedApi(
    rule: viewDisplayRule,
    message:
        'Reads the display of a FlutterView directly. A view has no display '
        'while the computer sleeps or a screen is being unplugged, and '
        '`FlutterView.display` then throws (v0.1.0+23 crashed in '
        'scheduleFrame on macOS after sleep).',
    correction:
        'Use displayRefreshRateOf (lib/platform/android_performance_hint.dart) '
        'or MediaQuery, or ${_ignore(viewDisplayRule)}.',
    refs: const [ApiRef('dart:ui', 'FlutterView', 'display')],
  ),
  BannedApi(
    rule: proxyRule,
    message:
        'Creates a network client of its own instead of following the shared '
        'proxy decision (system / manual / direct).',
    correction:
        'Build it with createProxiedDio / SystemProxy.createHttpClient / '
        'proxiedWebSocketConnector (docs/system-proxy.md), or '
        '${_ignore(proxyRule)}.',
    refs: const [
      ApiRef('dart:io', 'HttpClient'),
      ApiRef('dart:io', 'HttpClient', 'findProxyFromEnvironment'),
      ApiRef('dart:io', 'WebSocket', 'connect'),
      ApiRef('package:dio/', 'Dio'),
      ApiRef('package:dio/', 'IOHttpClientAdapter'),
      ApiRef('package:http/', 'IOClient'),
      ApiRef('package:http/', 'Client'),
      ApiRef('package:socket_io_client/', null, 'io'),
    ],
  ),
  BannedApi(
    rule: imageRule,
    message:
        'Raw image provider or Image widget keeps the whole source bitmap in '
        'the shared ImageCache.',
    correction:
        'Use RaftSizedImage / raftSizedImage so the decode size is the '
        'display size, or ${_ignore(imageRule)}.',
    namedArguments: const ['backgroundImage'],
    refs: const [
      ApiRef('package:flutter/', 'NetworkImage'),
      ApiRef('package:flutter/', 'MemoryImage'),
      ApiRef('package:flutter/', 'FileImage'),
      ApiRef('package:flutter/', 'AssetImage'),
      ApiRef('package:flutter/', 'ExactAssetImage'),
      ApiRef('package:flutter/', 'DecorationImage'),
      ApiRef('package:flutter/', 'Image'),
      ApiRef('package:flutter/', 'RawImage'),
      ApiRef('package:cached_network_image/', 'CachedNetworkImage'),
      ApiRef('package:cross_cache/', 'CachedNetworkImage'),
      ApiRef('dart:ui', 'ImageDescriptor'),
      ApiRef('dart:ui', null, 'instantiateImageCodec'),
      ApiRef('package:flutter/', null, 'instantiateImageCodec'),
    ],
  ),
  BannedApi(
    rule: underlineRule,
    message:
        "Flutter's TextDecoration.underline hugs the glyphs and cannot be "
        'offset, so it differs from the hyperlink underline.',
    correction:
        'Use RaftUnderlinedText / RaftUnderlineSpan + RaftUnderlines '
        '(raft_underline.dart), or ${_ignore(underlineRule)}.',
    refs: const [ApiRef('package:flutter/', 'TextDecoration', 'underline')],
  ),
  BannedApi(
    rule: idleRule,
    message:
        'Deferred work, a zero-delay timer, a perpetual loop or a frame '
        'request that can spin the CPU while the app is idle.',
    correction:
        'Use RaftIdleTimer / RaftForegroundPeriodic (raft_ui idle_work.dart), '
        'or ${_ignore(idleRule)} saying why it cannot loop or spin.',
    custom: isZeroDelayOrSelfRegistering,
    refs: const [
      ApiRef('package:flutter/', 'SchedulerBinding', 'scheduleTask'),
      ApiRef('package:flutter/', 'Priority', 'idle'),
      ApiRef('dart:async', 'Timer', 'run'),
      ApiRef('dart:async', 'Timer', 'periodic'),
      ApiRef('dart:async', 'Stream', 'periodic'),
      ApiRef('dart:async', 'Future', ''),
      ApiRef('dart:async', 'Future', 'microtask'),
      ApiRef('dart:async', null, 'scheduleMicrotask'),
      ApiRef('package:flutter/', 'AnimationController', 'repeat'),
      ApiRef('package:flutter/', 'SchedulerBinding', 'scheduleFrame'),
      ApiRef('package:flutter/', 'SchedulerBinding', 'ensureVisualUpdate'),
      ApiRef('package:flutter/', 'SchedulerBinding', 'scheduleForcedFrame'),
      ApiRef('package:flutter/', 'SchedulerBinding', 'scheduleFrameCallback'),
      ApiRef(
        'package:flutter/',
        'SchedulerBinding',
        'addPersistentFrameCallback',
      ),
      ApiRef('package:flutter/', 'Ticker'),
      ApiRef('package:flutter/', 'TickerProvider', 'createTicker'),
    ],
  ),
  BannedApi(
    rule: feedbackRule,
    message:
        'Material SnackBar / ScaffoldMessenger / MaterialBanner for feedback '
        'instead of the raft_ui toast and banner.',
    correction:
        'Use showRaftToast / RaftErrorBanner (error_presentation.dart), or '
        '${_ignore(feedbackRule)}.',
    typeReferences: true,
    refs: const [
      ApiRef('package:flutter/', 'SnackBar'),
      ApiRef('package:flutter/', 'MaterialBanner'),
      ApiRef('package:flutter/', 'ScaffoldMessenger'),
      ApiRef('package:flutter/', 'ScaffoldMessenger', 'of'),
      ApiRef('package:flutter/', 'ScaffoldMessenger', 'maybeOf'),
      ApiRef('package:flutter/', 'ScaffoldMessengerState'),
      ApiRef('package:flutter/', 'ScaffoldMessengerState', 'showSnackBar'),
      ApiRef(
        'package:flutter/',
        'ScaffoldMessengerState',
        'showMaterialBanner',
      ),
    ],
  ),
  BannedApi(
    rule: selectionRule,
    message:
        'A bare SelectionArea keeps a touch selection (highlight and handles) '
        'until the same text is tapped again; outside taps only clear it on '
        'Web. Where the platform toolbar is hidden, that is a selected state '
        'a phone user cannot cancel.',
    correction:
        'Use RaftSelectionArea (raft_selection_area.dart: a touch outside '
        'clears the selection), or ${_ignore(selectionRule)}.',
    typeReferences: true,
    refs: const [ApiRef('package:flutter/', 'SelectionArea')],
  ),
  BannedApi(
    rule: sheetRule,
    message:
        'A framework bottom sheet has its own look and gestures per platform; '
        'floating windows share one form decision and one sheet.',
    correction:
        'Open a window with showRaftPresented / raftPresentedRoute and a '
        'RaftPresentationPolicy, and build the sheet content with RaftSheet '
        '(raft_ui presentation.dart, sheet.dart), or ${_ignore(sheetRule)}.',
    typeReferences: true,
    refs: const [
      ApiRef('package:flutter/', null, 'showModalBottomSheet'),
      ApiRef('package:flutter/', null, 'showBottomSheet'),
      ApiRef('package:flutter/', null, 'showCupertinoSheet'),
      ApiRef('package:flutter/', null, 'showCupertinoModalPopup'),
      ApiRef('package:flutter/', 'ModalBottomSheetRoute'),
      ApiRef('package:flutter/', 'BottomSheet'),
      ApiRef('package:flutter/', 'DraggableScrollableSheet'),
      ApiRef('package:flutter/', 'CupertinoSheetRoute'),
    ],
  ),
  BannedApi(
    rule: sliderRule,
    message:
        'The Material slider (yellow thumb, tick marks, its own semantics) '
        'must not come back in media UI.',
    correction:
        'Draw the rail with the shared video controls, or '
        '${_ignore(sliderRule)}.',
    typeReferences: true,
    refs: const [
      ApiRef('package:flutter/', 'Slider'),
      ApiRef('package:flutter/', 'RangeSlider'),
      ApiRef('package:flutter/', 'CupertinoSlider'),
      ApiRef('package:flutter/', 'SliderTheme'),
      ApiRef('package:flutter/', 'SliderThemeData'),
    ],
  ),
];

/// Runs the banned-API checks on one node. [element] is what the node
/// resolves to (a constructor for a creation, the method for an invocation, the
/// accessed member for a property access, the class for a type name).
void checkBannedApi(AstNode node, Element? element, Report report) {
  for (final api in bannedApis) {
    // A type-name ban already reports the creation's type name.
    if (api.typeReferences && node is InstanceCreationExpression) continue;
    if (api.hit(node, element)) report(api.rule, node);
  }
}

/// `backgroundImage: ...` style named arguments.
void checkBannedNamedArgument(NamedArgument node, Report report) {
  for (final api in bannedApis) {
    if (api.namedArguments.contains(node.name.lexeme)) report(api.rule, node);
  }
}

/// Class type names (`Slider x`): only for APIs that ask for it.
void checkBannedTypeName(NamedType node, Report report) {
  final element = node.element;
  for (final api in bannedApis) {
    if (api.typeReferences && api.matches(element)) report(api.rule, node);
  }
}

/// `Timer(Duration.zero, ...)` / `Future.delayed(Duration.zero, ...)` and
/// `addPostFrameCallback(namedFunction)` (a callback that can re-register
/// itself).
bool isZeroDelayOrSelfRegistering(AstNode node) {
  if (node is InstanceCreationExpression) {
    final type = node.constructorName.type.name.lexeme;
    final ctor = node.constructorName.name?.name;
    final isTimer = type == 'Timer' && ctor == null;
    final isDelayed = type == 'Future' && ctor == 'delayed';
    if (!isTimer && !isDelayed) return false;
    final args = node.argumentList.arguments;
    return args.isNotEmpty && _isZeroDuration(args.first);
  }
  final parent = node.parent;
  if (node is SimpleIdentifier &&
      parent is MethodInvocation &&
      parent.methodName == node &&
      node.name == 'addPostFrameCallback') {
    final args = parent.argumentList.arguments;
    return args.isNotEmpty && args.first is SimpleIdentifier;
  }
  return false;
}

bool _isZeroDuration(AstNode arg) {
  var e = arg is NamedArgument ? arg.argumentExpression : arg;
  while (e is ParenthesizedExpression) {
    e = e.expression;
  }
  if (e is PrefixedIdentifier) {
    return e.prefix.name == 'Duration' && e.identifier.name == 'zero';
  }
  if (e is InstanceCreationExpression) {
    final type = e.constructorName.type.name.lexeme;
    return type == 'Duration' &&
        e.constructorName.name == null &&
        e.argumentList.arguments.isEmpty;
  }
  return false;
}
