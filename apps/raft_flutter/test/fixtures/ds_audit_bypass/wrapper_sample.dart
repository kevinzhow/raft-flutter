// Fixture for tool/tests/test_ds_audit.py: stands in for a designated raft_ui
// wrapper file. The test passes it as allowlisted for text_field; the overlay
// use is not allowlisted and stays enforced.
import 'package:flutter/material.dart';

Widget wrapperSample() {
  OverlayEntry(builder: (_) => const SizedBox());
  return const TextField();
}
