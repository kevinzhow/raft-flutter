// Text-scale / line-height inventory (read-only, syntactic).
//
// Scans lib/ Dart files with the unresolved parser (no analysis context, a few
// seconds for the whole repo) and prints one JSON object per finding:
//
//   dart run bin/text_scale_inventory.dart [dir-or-file ...] > findings.jsonl
//
// Categories (field "cat"):
//   fixed_height      SizedBox/Container/ConstrainedBox/... with a tight or
//                     maximum height whose subtree contains text
//   strut             StrutStyle (forceStrutHeight) / TextHeightBehavior
//   text_height       TextStyle(height: <number literal>)
//   css_linebox       RaftCssLineBox / RaftCssText
//   text_painter      TextPainter(...) construction (field "scaler": whether a
//                     textScaler argument is present)
//   custom_text_paint CustomPainter / RenderBox subclass that lays out text
//   max_lines         Text/RaftCssText with maxLines (field "overflow")
//   nudge             Transform.translate / Baseline / Positioned with a
//                     negative or literal offset around text
//   extent_estimate   itemExtent / "estimate" identifiers
//
// This is the measuring tool behind the proposed `avoid_fixed_height_text`
// lint; it is deliberately not registered as a rule yet.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:path/path.dart' as p;

const _textBase = {
  'Text',
  'RichText',
  'SelectableText',
  'RaftCssText',
  'TextField',
  'TextFormField',
  'EditableText',
  'DefaultTextStyle',
};
const _heightBoxes = {
  'SizedBox',
  'Container',
  'AnimatedContainer',
  'ConstrainedBox',
  'LimitedBox',
};
const _clipWidgets = {'ClipRect', 'ClipRRect', 'ClipPath', 'ClipOval'};

/// (type name, constructor name or '') of a widget-like call.
(String, String)? _callName(AstNode n) {
  if (n is InstanceCreationExpression) {
    final t = n.constructorName.type.name.lexeme;
    return (t, n.constructorName.name?.name ?? '');
  }
  if (n is MethodInvocation) {
    final target = n.target;
    if (target is SimpleIdentifier) {
      // Foo.named(...) parses as target.method when unresolved.
      if (RegExp(r'^[A-Z]').hasMatch(target.name)) {
        return (target.name, n.methodName.name);
      }
      return null;
    }
    if (target == null && RegExp(r'^_?[A-Z]').hasMatch(n.methodName.name)) {
      return (n.methodName.name, '');
    }
  }
  return null;
}

ArgumentList? _args(AstNode n) => n is InstanceCreationExpression
    ? n.argumentList
    : n is MethodInvocation
    ? n.argumentList
    : null;

Expression? _named(AstNode n, String name) {
  final a = _args(n);
  if (a == null) return null;
  for (final e in a.arguments) {
    if (e is NamedArgument && e.name.lexeme == name)
      return e.argumentExpression;
  }
  return null;
}

bool _isNum(Expression? e) =>
    e is IntegerLiteral ||
    e is DoubleLiteral ||
    (e is PrefixExpression &&
        (e.operand is IntegerLiteral || e.operand is DoubleLiteral));

String _kind(Expression? e) {
  if (e == null) return 'none';
  if (_isNum(e)) return 'literal';
  final s = e.toSource();
  if (s.contains('textScaler') ||
      s.contains('TextScaler') ||
      s.contains('textScale')) {
    return 'scaled';
  }
  return 'token';
}

class _Index {
  /// Class / function names whose body (transitively) lays out text.
  final textNames = <String>{..._textBase};
}

class _Collect extends RecursiveAstVisitor<void> {
  _Collect(this.index);
  final _Index index;
  final names = <String, Set<String>>{}; // decl name -> called names
  String? _current;

  void _decl(String name, AstNode node) {
    if (name == 'build' || name.isEmpty) return;
    final prev = _current;
    _current = name;
    names.putIfAbsent(name, () => {});
    node.visitChildren(this);
    _current = prev;
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) =>
      _decl(node.namePart.typeName.lexeme, node);

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) =>
      _decl(node.name.lexeme, node);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == 'build') {
      // Attributed to the enclosing class (kept as _current).
      node.visitChildren(this);
      return;
    }
    _decl(node.name.lexeme, node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _record(node.methodName.name);
    final c = _callName(node);
    if (c != null) _record(c.$1);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _record(node.constructorName.type.name.lexeme);
    super.visitInstanceCreationExpression(node);
  }

  void _record(String name) {
    final cur = _current;
    if (cur != null && cur != name) names[cur]!.add(name);
  }
}

void _fixpoint(_Index index, Map<String, Set<String>> calls) {
  var changed = true;
  while (changed) {
    changed = false;
    calls.forEach((name, called) {
      if (index.textNames.contains(name)) return;
      if (called.any(index.textNames.contains)) {
        index.textNames.add(name);
        changed = true;
      }
    });
  }
}

class _Scan extends RecursiveAstVisitor<void> {
  _Scan(this.file, this.unitText, this.index, this.lineOf, this.out);
  final String file;
  final String unitText;
  final _Index index;
  final int Function(int offset) lineOf;
  final void Function(Map<String, Object?>) out;

  void emit(String cat, AstNode n, Map<String, Object?> extra) =>
      out({'cat': cat, 'file': file, 'line': lineOf(n.offset), ...extra});

  /// Text widgets reached in [n]'s subtree: direct, or via project widgets.
  ({bool direct, bool indirect}) _textIn(AstNode n) {
    var direct = false, indirect = false;
    n.accept(
      _Finder((name) {
        if (_textBase.contains(name)) {
          direct = true;
        } else if (index.textNames.contains(name)) {
          indirect = true;
        }
      }),
    );
    return (direct: direct, indirect: indirect);
  }

  bool _hasClipBelow(AstNode n) {
    var found = false;
    n.accept(
      _Finder(
        (name) {
          if (_clipWidgets.contains(name)) found = true;
        },
        args: (arg) {
          if (arg.name.lexeme == 'clipBehavior' &&
              !arg.argumentExpression.toSource().endsWith('Clip.none')) {
            found = true;
          }
        },
      ),
    );
    return found;
  }

  bool _clipAbove(AstNode n) {
    for (var a = n.parent; a != null; a = a.parent) {
      final c = _callName(a);
      if (c != null && _clipWidgets.contains(c.$1)) return true;
      final cb = _named(a, 'clipBehavior');
      if (cb != null && !cb.toSource().endsWith('Clip.none')) {
        // Only widgets that actually clip with it.
        if (c != null && c.$1 != 'Text') return true;
      }
      if (a is FunctionDeclaration || a is MethodDeclaration) break;
    }
    return false;
  }

  void _visitCall(AstNode node) {
    final c = _callName(node);
    if (c == null) return;
    final (type, ctor) = c;

    // ---- fixed height --------------------------------------------------
    if (_heightBoxes.contains(type) && (ctor.isEmpty || ctor == 'fromSize')) {
      Expression? h = _named(node, 'height');
      var form = 'height';
      if (type == 'ConstrainedBox' || type == 'Container') {
        final cons = _named(
          node,
          type == 'Container' ? 'constraints' : 'constraints',
        );
        if (cons != null) {
          final cs = cons.toSource();
          if (RegExp(r'(maxHeight|height):').hasMatch(cs) ||
              cs.contains('.tight')) {
            h = cons;
            form = cs.contains('maxHeight')
                ? 'maxHeight'
                : cs.contains('.tight')
                ? 'tight'
                : 'height';
          } else if (cs.contains('minHeight') && h == null) {
            // minHeight only: the recommended shape, count separately.
            final child = _named(node, 'child');
            if (child != null && _textIn(child).direct) {
              emit('min_height_text', node, {'type': type, 'expr': cs});
            }
          }
        }
      }
      final child = _named(node, 'child');
      if (h != null && child != null) {
        final t = _textIn(child);
        if (t.direct || t.indirect) {
          emit('fixed_height', node, {
            'type': type,
            'form': form,
            'height': h.toSource(),
            'hkind': _kind(h),
            'text': t.direct ? 'direct' : 'indirect',
            'clipAbove': _clipAbove(node),
            'clipBelow': _hasClipBelow(child),
            'multiline': child.toSource().contains('maxLines: 1') ? 'm1' : '',
          });
        }
      }
    }

    // ---- strut / height behaviour --------------------------------------
    if (type == 'StrutStyle') {
      emit('strut', node, {
        'src': node.toSource().replaceAll(RegExp(r'\s+'), ' '),
        'force': _named(node, 'forceStrutHeight')?.toSource() ?? '',
        'height': _named(node, 'height')?.toSource() ?? '',
      });
    }
    if (type == 'TextHeightBehavior') {
      emit('strut', node, {
        'src': node.toSource().replaceAll(RegExp(r'\s+'), ' '),
        'force': 'TextHeightBehavior',
        'height': '',
      });
    }
    if (type == 'TextStyle' && ctor.isEmpty) {
      final h = _named(node, 'height');
      final fs = _named(node, 'fontSize');
      if (h != null || fs != null) {
        emit('text_height', node, {
          'height': h?.toSource() ?? '',
          'hkind': _kind(h),
          'fontSize': fs?.toSource() ?? '',
          'fkind': _kind(fs),
          'even': node.toSource().contains('TextLeadingDistribution.even'),
        });
      }
    }
    if (type == 'RaftCssLineBox' || type == 'RaftCssText') {
      emit('css_linebox', node, {'type': type, 'ctor': ctor});
    }

    // ---- TextPainter ----------------------------------------------------
    if (type == 'TextPainter' && ctor.isEmpty) {
      emit('text_painter', node, {
        'scaler': _named(node, 'textScaler') != null,
        'scalerExpr': _named(node, 'textScaler')?.toSource() ?? '',
        'method': _enclosing(node),
      });
    }

    // ---- maxLines -------------------------------------------------------
    if (type == 'Text' || type == 'RaftCssText' || type == 'RichText') {
      final ml = _named(node, 'maxLines');
      if (ml != null) {
        emit('max_lines', node, {
          'type': type,
          'maxLines': ml.toSource(),
          'overflow': _named(node, 'overflow')?.toSource() ?? 'none',
        });
      }
    }

    // ---- nudges ----------------------------------------------------------
    if (type == 'Transform' && ctor == 'translate') {
      emit('nudge', node, {
        'what': 'Transform.translate',
        'src': (_named(node, 'offset')?.toSource() ?? ''),
        'text': _textIn(node).direct || _textIn(node).indirect,
      });
    }
    if (type == 'Baseline') {
      emit('nudge', node, {
        'what': 'Baseline',
        'src': node.toSource().split('\n').first,
        'text': true,
      });
    }
    if (type == 'Positioned' && ctor.isEmpty) {
      final t = _named(node, 'top');
      final b = _named(node, 'bottom');
      final child = _named(node, 'child');
      if (child != null &&
          (_isNum(t) || _isNum(b)) &&
          (_textIn(child).direct || _textIn(child).indirect)) {
        emit('nudge', node, {
          'what': 'Positioned',
          'src': 'top: ${t?.toSource()} bottom: ${b?.toSource()}',
          'text': true,
        });
      }
    }
  }

  String _enclosing(AstNode n) {
    for (var a = n.parent; a != null; a = a.parent) {
      if (a is MethodDeclaration) return a.name.lexeme;
      if (a is FunctionDeclaration) return a.name.lexeme;
    }
    return '';
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _visitCall(node);
    final n = node.methodName.name;
    if (n == 'drawParagraph' || n == 'getBoxesForSelection') {
      emit('custom_text_paint', node, {'what': n, 'method': _enclosing(node)});
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _visitCall(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final n = node.name;
    if (n == 'itemExtent' ||
        n == 'prototypeItem' ||
        n == 'itemExtentBuilder' ||
        RegExp(r'[eE]stimate').hasMatch(n)) {
      emit('extent_estimate', node, {'name': n});
    }
    super.visitSimpleIdentifier(node);
  }
}

class _Finder extends RecursiveAstVisitor<void> {
  _Finder(this.onName, {this.args});
  final void Function(String) onName;
  final void Function(NamedArgument)? args;

  @override
  void visitNamedArgument(NamedArgument node) {
    args?.call(node);
    super.visitNamedArgument(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final c = _callName(node);
    if (c != null) onName(c.$1);
    onName(node.methodName.name);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    onName(node.constructorName.type.name.lexeme);
    super.visitInstanceCreationExpression(node);
  }
}

List<File> _files(List<String> roots) {
  final out = <File>[];
  for (final r in roots) {
    final t = FileSystemEntity.typeSync(r);
    if (t == FileSystemEntityType.file) {
      out.add(File(r));
    } else if (t == FileSystemEntityType.directory) {
      out.addAll(
        Directory(r)
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'),
            ),
      );
    }
  }
  out.sort((a, b) => a.path.compareTo(b.path));
  return out;
}

Future<void> main(List<String> args) async {
  final repo =
      Platform.environment['RAFT_LINTS_REPO'] ??
      p.normalize(
        p.join(p.dirname(p.fromUri(Platform.script)), '..', '..', '..'),
      );
  final roots = args.isNotEmpty
      ? args
      : [
          p.join(repo, 'apps', 'raft_flutter', 'lib'),
          for (final e in Directory(p.join(repo, 'packages')).listSync())
            if (e is Directory && Directory(p.join(e.path, 'lib')).existsSync())
              p.join(e.path, 'lib'),
        ];
  final files = _files(roots);
  final parsed = <(File, ParseStringResult)>[];
  for (final f in files) {
    final text = f.readAsStringSync();
    parsed.add((
      f,
      parseString(
        content: text,
        throwIfDiagnostics: false,
        featureSet: FeatureSet.latestLanguageVersion(),
      ),
    ));
  }
  final index = _Index();
  final calls = <String, Set<String>>{};
  for (final (_, r) in parsed) {
    final c = _Collect(index);
    r.unit.accept(c);
    c.names.forEach((k, v) => (calls[k] ??= {}).addAll(v));
  }
  _fixpoint(index, calls);
  stderr.writeln('text-bearing names: ${index.textNames.length}');
  for (final (f, r) in parsed) {
    final rel = p.relative(f.path, from: repo);
    final scan = _Scan(
      rel,
      r.content,
      index,
      (o) => r.lineInfo.getLocation(o).lineNumber,
      (m) {
        stdout.writeln(jsonEncode(m));
      },
    );
    r.unit.accept(scan);
    // Subclasses of CustomPainter / RenderBox that lay out text.
    for (final d in r.unit.declarations.whereType<ClassDeclaration>()) {
      final ext = d.extendsClause?.superclass.name.lexeme ?? '';
      final impl =
          d.implementsClause?.interfaces.map((e) => e.name.lexeme) ?? const [];
      final isPainter =
          ext == 'CustomPainter' || impl.contains('CustomPainter');
      final isRender = ext.startsWith('Render');
      if (!isPainter && !isRender) continue;
      final src = d.toSource();
      if (src.contains('TextPainter') ||
          src.contains('drawParagraph') ||
          src.contains('ParagraphBuilder')) {
        stdout.writeln(
          jsonEncode({
            'cat': 'custom_text_paint',
            'file': rel,
            'line': r.lineInfo.getLocation(d.offset).lineNumber,
            'what': d.namePart.typeName.lexeme,
            'base': ext,
            'scaler': src.contains('textScaler') || src.contains('TextScaler'),
          }),
        );
      }
    }
  }
}
