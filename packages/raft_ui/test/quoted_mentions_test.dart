import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/message_tokens.dart';

void main() {
  test('quotes preserve written mentions while new prose can mention', () {
    const source =
        '> @agent <@agent> [helper](<@agent>) #design\n'
        '> > **@agent**\n\n'
        '@agent';
    expect(
      tokenized(
        source,
        references: const [
          RaftTextReference(
            text: '@agent',
            href: 'raft-ref://mention/agent/helper',
            identityBacked: true,
          ),
          RaftTextReference(text: '#design', href: 'raft-ref://channel/design'),
        ],
      ),
      '> @agent <@agent> [helper](<@agent>) [#design](<raft-ref://channel/design>)\n'
      '> \n'
      '> > **@agent**\n\n'
      '[@agent](<raft-ref://mention/agent/helper>)',
    );
  });
}
