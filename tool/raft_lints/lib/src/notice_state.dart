import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/type.dart';

import 'checks.dart';

const noticeStateRule = 'avoid_imperative_notice_state';
const noticeStateMessage =
    'A notice, error row or inline warning held as a plain mutable value can '
    'outlive its cause.';
const noticeStateCorrection =
    'Hold it in a CauseNotice / CauseNotices (lib/data/cause_notice.dart) so '
    'it expires with its cause, or '
    "add '// ignore: raft_lints/$noticeStateRule -- <the conditions that clear it>'.";

final _noticeName = RegExp(r'(?:[eE]rror|[nN]otice|[wW]arning|[fF]ailure)s?$');
const _setters = {'setError', 'setComposerError'};

/// A mutable (non-final, non-static) String / bool / Map-of-String variable
/// named `...error`, `...notice`, `...warning` or `...failure`.
void checkNoticeField(VariableDeclarationList list, Report report) {
  if (list.isFinal || list.isConst) return;
  final parent = list.parent;
  if (parent is FieldDeclaration && parent.isStatic) return;
  if (list.keyword?.type == Keyword.CONST) return;
  for (final variable in list.variables) {
    if (!_noticeName.hasMatch(variable.name.lexeme)) continue;
    final type = variable.declaredFragment?.element.type;
    if (!_holdsMessage(type, list)) continue;
    report(noticeStateRule, variable);
  }
}

bool _holdsMessage(DartType? type, VariableDeclarationList list) {
  if (type == null) return false;
  if (type is DynamicType) return list.type == null; // `var x;`
  if (type.isDartCoreString || type.isDartCoreBool) return true;
  if (type is InterfaceType && type.isDartCoreMap) {
    return type.typeArguments.any((a) => a.isDartCoreString);
  }
  return false;
}

/// A call of the controller setters `setError(...)` / `setComposerError(...)`.
void checkNoticeSetter(MethodInvocation node, Report report) {
  if (_setters.contains(node.methodName.name)) {
    report(noticeStateRule, node.methodName);
  }
}
