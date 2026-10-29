import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:raft_lints/src/ignores.dart';
import 'package:test/test.dart';

Ignores parse(String source) =>
    Ignores.of(parseString(content: source).unit, source);

void main() {
  test('a comment on its own line covers the next line', () {
    final i = parse('''
void f() {
  // ignore: raft_lints/avoid_render_single -- reason here
  a.single;
  b.single;
}
''');
    expect(i.isIgnored('avoid_render_single', 3), isTrue);
    expect(i.isIgnored('avoid_render_single', 4), isFalse);
    expect(i.isIgnored('avoid_render_index_assertion', 3), isFalse);
  });

  test('a trailing comment covers its own line', () {
    final i = parse('''
void f() {
  a.single; // ignore: raft_lints/avoid_render_single
  b.single;
}
''');
    expect(i.isIgnored('avoid_render_single', 2), isTrue);
    expect(i.isIgnored('avoid_render_single', 3), isFalse);
  });

  test('several rules, reason suffix, and the plugin prefix is required', () {
    final i = parse('''
void f() {
  // ignore: raft_lints/avoid_render_single, raft_lints/avoid_render_index_assertion -- why
  a;
  // ignore: avoid_render_single
  b;
}
''');
    expect(i.isIgnored('avoid_render_single', 3), isTrue);
    expect(i.isIgnored('avoid_render_index_assertion', 3), isTrue);
    expect(i.isIgnored('avoid_render_single', 5), isFalse);
  });

  test('ignore_for_file covers the whole file', () {
    final i = parse('''
// ignore_for_file: raft_lints/avoid_render_single
void f() {}
''');
    expect(i.isIgnored('avoid_render_single', 99), isTrue);
    expect(i.isIgnored('avoid_render_index_assertion', 99), isFalse);
  });
}
