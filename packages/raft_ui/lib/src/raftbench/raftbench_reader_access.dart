// RaftBench "Agent access" (Web raftbench/ReaderAccess.tsx): which agents may
// read the findings. A collapsed section with one grant / revoke button per
// agent; one write at a time.
import 'package:flutter/material.dart';

import '../../raft_ui.dart';
import 'raftbench_parts.dart';

class RaftbenchReaderAccess extends StatelessWidget {
  const RaftbenchReaderAccess({
    super.key,
    required this.controller,
    required this.enabled,
  });
  final RaftbenchReaderPanel controller;

  /// The analysis is enabled: only then can a new agent be granted.
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final t = RaftTokens.of(context), ty = RaftbenchType(t);
      String tr(String s) => raftText(context, s);
      final c = controller;
      return RaftbenchDetails(
        key: const ValueKey('raftbench-reader-access'),
        summaryStyle: ty.callout(weight: FontWeight.w600),
        summary: Text(tr('Agent access')),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tr(
                  'Allow an agent to read findings. It can only see findings whose sources it can already read. The agent’s owner can also see these analyses.',
                ),
                style: ty.caption(color: ty.hint, weight: FontWeight.w400),
              ),
            ),
            if (c.failed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    tr('Could not update agent access. Try again.'),
                    style: ty.callout(),
                  ),
                ),
              ),
            for (final reader in c.readers)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(reader.label, style: ty.callout())),
                    const SizedBox(width: 8),
                    RaftbenchButton(
                      tr(reader.enabled ? 'Revoke access' : 'Allow access'),
                      onPressed: c.busy || (!enabled && !reader.enabled)
                          ? null
                          : () => c.toggle(reader),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
