import 'dart:convert';
import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

// Probe: logs every DropDoneDetails (paths, rawText, error) as JSON lines to $PROBE_OUT.
void main() => runApp(const MaterialApp(home: Probe()));

class Probe extends StatelessWidget {
  const Probe({super.key});
  @override
  Widget build(BuildContext context) {
    final out = Platform.environment['PROBE_OUT'] ?? '/tmp/desktop_drop_probe.out';
    File(out).writeAsStringSync('${jsonEncode({'ready': true})}\n', mode: FileMode.append);
    return Scaffold(
      body: DropTarget(
        onDragDone: (d) {
          File(out).writeAsStringSync(
              '${jsonEncode({'files': d.files.map((e) => e.path).toList(), 'rawText': d.rawText, 'error': d.error})}\n',
              mode: FileMode.append);
        },
        child: const SizedBox.expand(child: ColoredBox(color: Colors.teal)),
      ),
    );
  }
}
