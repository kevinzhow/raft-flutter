"""Fixture data for the agent Activity / Workspace tab state cases (build-members-pages.py).

Every row kind and variant of Web `AgentActivityLog.tsx` (packages/web/src/components/agent) and every state of
`AgentWorkspace.tsx`, as route sets answered identically by the React provider (tool/parity-ext/run spec appendix)
and the Flutter fixture client (ext_members_pages.dart `_answer`).

Route answers may carry `{"$when": [{"query": {"dirPath": "notes"}, "answer": <answer>}], "$default": <answer>}` to
answer one path differently by query string (the workspace listing root vs a folder).
"""

BASE = 1781872080000   # 20:28:00 in the fixture time zone (the official Activity case rows start here)
CHANNEL = 'swift-workflow'


def _ts(entries):
    """Strictly increasing timestamps (one entry per 3-9 s) so the log order is the list order."""
    out, t = [], BASE
    for i, e in enumerate(entries):
        t += (3 + (i * 4) % 7) * 1000
        out.append({'timestamp': t, 'entry': e})
    return out


def status(activity, detail='', kind=None, activity_kind=None, **extra):
    e = {'kind': 'status', 'activity': activity, 'detail': detail}
    if activity_kind:
        e['activityKind'] = activity_kind
    if kind:
        e['detailKind'] = kind
    e.update(extra)
    return e


def tool(name, tool_input='', **extra):
    return {'kind': 'tool_start', 'toolName': name, 'toolInput': tool_input, **extra}


LONG_THINKING = ('Comparing the React and Flutter Activity tab screenshots row by row: the status rows, the tool rows, '
                 'the output rows and the held-by-freshness details. Next I will check the spacing of the subagent '
                 'badge against the title baseline and then decide whether the channel pill needs its own line.')
LONG_OUTPUT = ('Updating my memory notes with the release workflow. The release gate has three stages: build, '
               'verification and publish. Verification reruns the parity suites on the three themes and compares the '
               'non-text similarity against the 99.5% bar before anything is published to the stable channel.')
LONG_PATH = ('/Users/huanan/.slock/agents/ff9777f7-95a6-46e4-8107-17400d115c15/notes/release-workflow/'
             'handoffs/2026-10-13-agent-activity-parity-review-notes-with-a-very-long-descriptive-name.md')
LONG_COMMAND = ('pnpm --filter @botiverse/raft-visual-testing exec slock-visual diff --case '
                'screens.members.agent-detail.activity --out /tmp/very-long-output-directory-name/without/spaces/'
                'visual-testing-results-2026-10-13T10-39-08Z-flutter-ext-942eab50-and-more-and-more-and-more')

SUBAGENT_STARTED = {'phase': 'started'}

LOGS = {
    # Status rows: every resolveStatusDisplay branch.
    'act-status': _ts([
        status('working', 'Capturing deterministic Activity tab state', 'other', 'working'),
        status('online', '', 'other', 'online'),
        status('online', 'Waiting for the next message', 'other', 'online'),
        status('thinking', 'Planning the next step', 'other', 'thinking'),
        status('working', 'Booting the runtime', 'starting', 'working'),
        status('online', 'Computer started', 'computer_started', 'online'),
        status('online', 'Computer restarted', 'computer_restarted', 'online'),
        status('online', 'Computer upgraded', 'computer_upgraded', 'online'),
        status('offline', 'Computer stopped', 'stopped', 'offline'),
        status('offline', 'Stopped', 'stopped', 'offline'),
        status('offline', 'Computer disconnected', 'machine_disconnected', 'offline'),
        status('offline', 'Process exited with code 1 after a segmentation fault in the runtime', 'runtime_crashed', 'offline'),
        status('offline', 'Idle timeout', 'other', 'offline'),
        status('error', 'Restart failed: the daemon is unreachable', 'computer_operation_failed', 'error'),
        status('error', 'Rate limited by the provider', 'other'),
    ]),
    # Lineage-bearing rows get the inline Subagent badge (status and tool rows only).
    'act-subagent': _ts([
        status('working', 'Subagent started', 'other', 'working', subagent=SUBAGENT_STARTED),
        status('working', 'Subagent update', 'other', 'working', subagent={'phase': 'progress', 'taskId': 'task-1'}),
        status('working', 'Subagent started', 'other', 'working',
               subagent={'subagentType': 'Explore', 'phase': 'started'}),
        status('working', 'Tool finished', 'other', 'working'),
        tool('Read', '/Users/huanan/project/README.md', subagent={'subagentType': 'general-purpose'}),
        tool('Bash', 'git status --short', subagent={'phase': 'active'}),
        {'kind': 'thinking', 'text': 'A thinking row with lineage carries no badge.', 'subagent': {'subagentType': 'Explore'}},
        {'kind': 'text', 'text': 'An output row with lineage carries no badge.', 'subagent': {'subagentType': 'Explore'}},
        status('working', 'Subagent update', 'other', 'working', subagent={'subagentType': 'Explore', 'phase': 'notification'}),
    ]),
    # Humanised tool names (getToolLogLabel), the `send_message` row Web hides, tool input summaries.
    'act-tools': _ts([
        tool('mcp__chat__update_task_status', f'#{CHANNEL} #t2'),
        tool('mcp__chat__send_message', f'#{CHANNEL}'),
        tool('mcp__chat__check_messages'),
        tool('mcp__chat__wait_for_message'),
        tool('mcp__chat__read_history', f'#{CHANNEL}'),
        tool('mcp__chat__list_tasks', f'#{CHANNEL}'),
        tool('mcp__chat__claim_tasks', f'#{CHANNEL} #t3,#t4'),
        tool('Bash', 'pnpm test --filter web'),
        tool('shell', 'git log --oneline -5'),
        tool('Read', '/Users/huanan/project/src/App.tsx'),
        tool('Write', '/Users/huanan/project/notes/summary.md'),
        tool('Edit', '/Users/huanan/project/src/index.ts'),
        tool('Glob', '**/*.test.ts'),
        tool('Grep', 'TODO|FIXME'),
        tool('WebFetch', 'https://example.com/docs/release'),
        tool('WebSearch', 'flutter golden test tolerance'),
        tool('TodoWrite'),
        tool('schedule_reminder', 'Weekly sync'),
        tool('mcp__github__create_issue', 'raft-flutter: activity parity'),
        tool('CustomTool', '{"mode":"dry-run"}'),
    ]),
    # Output / Thinking rows: short, long (two-line clamp + chevron) and multi-line.
    'act-text': _ts([
        {'kind': 'thinking', 'text': 'Comparing React and Android Members Activity screenshots before publishing.'},
        {'kind': 'thinking', 'text': LONG_THINKING},
        {'kind': 'text', 'text': 'Updating my memory notes with the release workflow.'},
        {'kind': 'text', 'text': LONG_OUTPUT},
        {'kind': 'text', 'text': 'Line one of a multi-line output.\n  indented line two\nline three'},
        {'kind': 'thinking', 'text': ''},
    ]),
    # slock_action / system / compaction rows with channel, thread and DM reference pills.
    'act-slock': _ts([
        {'kind': 'slock_action', 'title': 'Updating task status', 'text': ''},
        {'kind': 'slock_action', 'title': f'Updated task #2 to in_review', 'text': f'target: #{CHANNEL}'},
        {'kind': 'slock_action', 'title': 'Task update held by freshness check',
         'text': (f'target: #{CHANNEL}\nnew messages: 1 newer message\n'
                  'decision: local hold; review the newer context before retrying')},
        {'kind': 'slock_action', 'title': 'Posted status update',
         'text': f'Reported capture progress in #{CHANNEL}:d4870bc3 and kept #225 in review.'},
        {'kind': 'slock_action', 'title': 'Sent direct message', 'text': 'target: dm:@Cindy\nthread: dm:@Cindy:a1b2c3d4'},
        {'kind': 'slock_action', 'title': 'Unresolved references', 'text': 'target: #missing-channel and dm:@Nobody stay plain text.'},
        {'kind': 'system', 'title': 'Session resumed', 'text': f'Resumed from the checkpoint written in #{CHANNEL}.'},
        {'kind': 'system', 'title': 'Context reminder', 'text': LONG_OUTPUT},
        {'kind': 'compaction_started'},
        {'kind': 'compaction_finished'},
    ]),
    # Long unbreakable paths / commands (`break-all`).
    'act-long-path': _ts([
        tool('Write', LONG_PATH),
        tool('Read', LONG_PATH, subagent={'subagentType': 'Explore'}),
        tool('Bash', LONG_COMMAND),
        status('working', 'Tool finished', 'other', 'working'),
        {'kind': 'text', 'text': LONG_PATH},
    ]),
}

# GET /channels and /channels/dm: the conversations the reference pills resolve against.
CHANNELS = [{'id': 'ch-swift-workflow', 'serverId': 'visual-server', 'name': CHANNEL, 'description': None,
             'type': 'channel', 'createdAt': '2026-06-19T10:00:00.000Z', 'joined': True}]
DMS = [{'id': 'dm-cindy', 'serverId': 'visual-server', 'name': 'Cindy', 'description': None, 'type': 'dm',
        'peerId': 'agent-cindy', 'peerName': 'Cindy', 'peerType': 'agent', 'createdAt': '2026-06-19T10:00:00.000Z',
        'joined': True}]


def _file(name, path, *, directory=False, size=1240, hidden=False):
    f = {'name': name, 'path': path, 'isDirectory': directory, 'modifiedAt': '2026-06-19T12:28:00.000Z'}
    if not directory:
        f['size'] = size
    if hidden:
        f['isHidden'] = True
    return f


ROWS = [
    _file('memory.md', 'memory.md', size=86),
    _file('MEMORY.md', 'MEMORY.md', size=86),
    _file('notes', 'notes', directory=True),
    _file('release-workflow-handoff-notes-with-a-very-long-descriptive-file-name.md',
          'release-workflow-handoff-notes-with-a-very-long-descriptive-file-name.md'),
    _file('archive-2026-q3-and-earlier-quarters-with-a-long-folder-name', 'archive', directory=True),
    _file('summary.md', 'summary.md'),
]
NOTES = [_file('visual-parity.md', 'notes/visual-parity.md'), _file('plan.md', 'notes/plan.md', size=420)]

PENDING = {'$pending': True}
ERROR = {'$status': 500}


def workspace_routes(agent_id):
    """Route sets of the workspace tab states."""
    listing = f'GET /agents/{agent_id}/workspace-files'
    return {
        'ws-loading': {listing: PENDING},
        'ws-error': {listing: ERROR},
        'ws-empty': {listing: {'files': []}},
        'ws-rows': {listing: {'$when': [{'query': {'dirPath': 'notes'}, 'answer': {'files': NOTES}}],
                              '$default': {'files': ROWS}}},
        'ws-truncated': {listing: {'$when': [{'query': {'dirPath': 'notes'},
                                              'answer': {'files': NOTES, 'truncated': True, 'omitted': 38}}],
                                   '$default': {'files': ROWS[:4], 'truncated': True, 'omitted': 1250}}},
        'ws-dir-loading': {listing: {'$when': [{'query': {'dirPath': 'notes'}, 'answer': PENDING}],
                                     '$default': {'files': ROWS}}},
        'ws-dir-error': {listing: {'$when': [{'query': {'dirPath': 'notes'}, 'answer': ERROR}],
                                   '$default': {'files': ROWS}}},
        'ws-file-loading': {listing: {'files': ROWS}, f'GET /agents/{agent_id}/workspace-files/read': PENDING},
        'ws-file-error': {listing: {'files': ROWS}, f'GET /agents/{agent_id}/workspace-files/read': {'$status': 500, '$body': {}}},
    }


def activity_routes(agent_id):
    log = f'GET /agents/{agent_id}/activity-log'
    base = {'GET /channels': CHANNELS, 'GET /channels/dm': DMS}
    routes = {
        'act-empty': {log: []},
        'act-loading': {log: PENDING},
        'act-error': {log: ERROR},
    }
    for key, rows in LOGS.items():
        routes[key] = {**base, log: rows}
    return routes
