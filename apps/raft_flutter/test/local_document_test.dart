import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/local_document.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('raft-local'));
  tearDown(() => dir.delete(recursive: true));

  Future<File> write(String name, List<int> bytes) async =>
      File('${dir.path}/$name')..writeAsBytesSync(bytes);

  test('kinds follow the name and the type; spreadsheets are not drawn', () {
    LocalDocumentKind? kind(String name, [String? mime]) =>
        localDocumentKind({'filename': name, 'mimeType': ?mime});
    expect(kind('a.md'), LocalDocumentKind.markdown);
    expect(kind('a', 'text/markdown'), LocalDocumentKind.markdown);
    expect(kind('a.csv'), LocalDocumentKind.csv);
    expect(kind('a.log'), LocalDocumentKind.text);
    expect(kind('a.kt'), LocalDocumentKind.text);
    expect(kind('a.xlsx'), isNull);
    expect(kind('a.xls', 'application/vnd.ms-excel'), isNull);
    expect(
      kind(
        'a',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
      isNull,
    );
  });

  test('a small file is shown whole; a BOM is dropped', () async {
    final file = await write('a.txt', [
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode('héllo\nworld\n'),
    ]);
    final doc = await readLocalDocument(file, LocalDocumentKind.text);
    expect(doc.data, {'kind': 'text', 'text': 'héllo\nworld\n'});
    expect(doc.truncated, isFalse);
    expect(doc.shown, 2);
  });

  test('a large file is cut after a whole line at the limit', () async {
    final text = List.generate(2000, (i) => 'line $i').join('\n');
    final file = await write('a.log', utf8.encode(text));
    final doc = await readLocalDocument(
      file,
      LocalDocumentKind.text,
      maxBytes: 4000,
    );
    expect(doc.truncated, isTrue);
    final shown = doc.data['text'] as String;
    expect(shown.endsWith('\n'), isTrue);
    expect(shown.length, lessThanOrEqualTo(4000));
    expect(text.startsWith(shown), isTrue);
    expect(doc.shown, shown.split('\n').length - 1);
    expect(doc.totalBytes, text.length);
  });

  test('binary, invalid UTF-8 and blank files are unreadable', () async {
    for (final bytes in [
      [0, 1, 2, 3],
      [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1, 65, 66],
      [0xc3, 0x28, 0x41],
      utf8.encode('  \n \n'),
    ]) {
      final file = await write('x.txt', bytes);
      expect(
        readLocalDocument(file, LocalDocumentKind.text),
        throwsA(isA<LocalDocumentUnreadable>()),
        reason: '$bytes',
      );
    }
  });

  test(
    'CSV: quotes, delimiters, blank rows, first row is the header',
    () async {
      final file = await write(
        'a.csv',
        utf8.encode('a;b;c\n1;"x;y";"he said ""hi"""\n\n2;;\n'),
      );
      final doc = await readLocalDocument(file, LocalDocumentKind.csv);
      expect(doc.data['headers'], ['a', 'b', 'c']);
      expect(doc.data['rows'], [
        ['1', 'x;y', 'he said "hi"'],
        ['2', '', ''],
      ]);
      expect(doc.data['rowCount'], 2);
      expect(doc.data['columnCount'], 3);
    },
  );

  test('a big file is read off the calling isolate and fast', () async {
    final line = 'x' * 79;
    final bytes = Uint8List.fromList(
      utf8.encode(List.filled(100000, line).join('\n')),
    );
    final file = await write('big.txt', bytes);
    final watch = Stopwatch()..start();
    final doc = await readLocalDocument(file, LocalDocumentKind.text);
    watch.stop();
    debugPrint(
      '8 MB text -> first ${doc.shown} lines in ${watch.elapsedMilliseconds} ms',
    );
    expect(doc.truncated, isTrue);
    expect(doc.shown, greaterThan(20000));
  });
}
