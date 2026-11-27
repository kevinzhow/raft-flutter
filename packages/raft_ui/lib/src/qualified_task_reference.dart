typedef RaftQualifiedTaskReference = ({
  String text,
  String conversation,
  bool dm,
  int number,
  int start,
  int end,
});

const raftReferenceNamePattern = r'[\p{L}\p{N}_-]+';
const raftDmPeerPattern = r'[\w.-]+(?:~(?:agent|human))?(?![\w.~-])';
const raftTaskReferenceSeparator = ':#';

const raftQualifiedTaskPattern =
    '(?:#($raftReferenceNamePattern)|dm:@($raftDmPeerPattern))'
    '$raftTaskReferenceSeparator([1-9][0-9]*)(?![\\p{L}\\p{N}_/-]|$raftTaskReferenceSeparator)';

final _qualifiedTask = RegExp(
  raftQualifiedTaskPattern,
  unicode: true,
  caseSensitive: false,
);

Iterable<RaftQualifiedTaskReference> raftQualifiedTaskReferences(
  String text,
) sync* {
  if (!text.contains(raftTaskReferenceSeparator)) return;
  for (final match in _qualifiedTask.allMatches(text)) {
    final number = int.tryParse(match[3]!);
    if (number == null) continue;
    yield (
      text: match[0]!,
      conversation: (match[1] ?? match[2])!,
      dm: match[2] != null,
      number: number,
      start: match.start,
      end: match.end,
    );
  }
}
