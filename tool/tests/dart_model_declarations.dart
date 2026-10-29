/// Test-only declaration shapes for the family registry contract.
/// No resolution, network, generated assets or production policy changes.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';

Future<void> main() async {
  try {
    final inputs = jsonDecode(
      await utf8.decoder.bind(stdin).join(),
    ) as Map<String, dynamic>;
    final result = <String, Object>{};
    for (final entry in inputs.entries) {
      final parsed = parseString(
        content: entry.value as String,
        path: 'registry-model-${entry.key}.dart',
        featureSet: FeatureSet.latestLanguageVersion(
          flags: ['primary-constructors'],
        ),
        throwIfDiagnostics: false,
      );
      if (parsed.errors.any((error) => error.severity == Severity.error)) {
        throw FormatException(
          'Model source has Dart parse errors: ${entry.key}',
        );
      }
      final declarations = <Map<String, String>>[];
      for (final node in parsed.unit.declarations) {
        final (name, kind) = switch (node) {
          ClassDeclaration() => (node.namePart.typeName.lexeme, 'value_object'),
          ClassTypeAlias() => (node.name.lexeme, 'value_object'),
          MixinDeclaration() => (node.name.lexeme, 'value_object'),
          EnumDeclaration() => (node.namePart.typeName.lexeme, 'value_object'),
          GenericTypeAlias() => (
            node.name.lexeme,
            node.type is GenericFunctionType
                ? 'callback_typedef'
                : 'type_alias',
          ),
          FunctionTypeAlias() => (node.name.lexeme, 'callback_typedef'),
          FunctionDeclaration() => (node.name.lexeme, 'function'),
          _ => (null, null),
        };
        if (name != null && kind != null) {
          declarations.add({'name': name, 'kind': kind});
        }
      }
      result[entry.key] = declarations;
    }
    stdout.writeln(jsonEncode(result));
  } catch (error) {
    stderr.writeln('registry-model-declarations: $error');
    exitCode = 2;
  }
}
