import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews('Agent form · recipe and caller chrome', size: Size(440, 560))
Widget agentSurfacePreview() => const AgentSurfacePreview();

/// Shared form consumers with live input, disabled submit, and the explicit
/// CreateAgent capacity colors. No API or domain state is part of this demo.
class AgentSurfacePreview extends StatefulWidget {
  const AgentSurfacePreview({super.key});
  @override
  State<AgentSurfacePreview> createState() => _AgentSurfacePreviewState();
}

class _AgentSurfacePreviewState extends State<AgentSurfacePreview> {
  final name = TextEditingController();
  String? computer;
  bool caller = false;
  String result = 'Ready';
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final emphasized = caller && tokens.dark;
    return RaftAgentDialogCard(
      title: 'Create Agent',
      onClose: () => setState(() => result = 'Closed'),
      children: [
        RaftAgentBanner(
          status: RaftAgentBannerStatus.warning,
          description: 'Agent limit reached.',
          action: 'Upgrade',
          onAction: () => setState(() => result = 'Upgrade'),
          backgroundColor: emphasized ? tokens.colors['warning-soft'] : null,
          foregroundColor: emphasized ? tokens.colors['warning-strong'] : null,
          actionForeground: emphasized ? tokens.colors['warning-strong'] : null,
        ),
        const SizedBox(height: 8),
        RaftStableField(
          label: 'Name',
          required: true,
          child: RaftAgentTextInput(
            controller: name,
            semanticLabel: 'Agent name',
            invalid: name.text.contains(' '),
            placeholder: 'Product-QA-Bot',
            onChanged: (_) => setState(() {}),
          ),
        ),
        RaftStableField(
          label: 'Computer',
          child: RaftAgentSelect<String>(
            semanticLabel: 'Computer',
            value: computer,
            options: const [
              RaftAgentSelectOption('laptop', 'Laptop'),
              RaftAgentSelectOption('offline', 'Offline', enabled: false),
            ],
            onChanged: (value) => setState(() => computer = value),
          ),
        ),
        RaftAgentDialogFooter(
          children: [
            RaftButton(
              label: caller ? 'Use recipe' : 'Use capacity caller',
              onPressed: () => setState(() => caller = !caller),
            ),
            RaftAgentDialogButton(
              label: 'Create',
              primary: true,
              foreground: emphasized
                  ? tokens.colors['foreground-inverse']
                  : null,
              onPressed: name.text.isEmpty || computer == null
                  ? null
                  : () => setState(() => result = 'Created'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(result),
      ],
    );
  }
}
