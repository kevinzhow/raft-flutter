"""Shared gate event log: one line per event so anyone can `tail -f` the shared gate.

Format: `<UTC ISO time> <EVENT> branch=<branch> sha=<short sha> wt=<worktree> <key=value ...>`.
Events: WAITING START FAIL-FIRST ABORT RETRY FLAKY PASS FAIL ERROR (+ NOTIFY-FAILED). The log never raises: a
broken log must not break (or hide the result of) a gate run.
"""
import datetime
import json
import os
import pathlib
import signal
import subprocess
import threading

EVENTS_LOG = '/tmp/raft-flutter-gate-events.log'  # RAFT_GATE_EVENTS_LOG overrides (tests)
MAX_VALUE = 300


def log_path():
    return pathlib.Path(os.environ.get('RAFT_GATE_EVENTS_LOG') or EVENTS_LOG)


def _value(value):
    text = ' '.join(str(value).split())
    if len(text) > MAX_VALUE:
        text = text[:MAX_VALUE - 3] + '...'
    return json.dumps(text, ensure_ascii=False) if not text or any(c in text for c in ' "=') else text


def format_event(event, branch, sha, worktree, now=None, **details):
    """One log line (with trailing newline); values containing spaces are JSON-quoted."""
    stamp = (now or datetime.datetime.now(datetime.timezone.utc)).strftime('%Y-%m-%dT%H:%M:%SZ')
    fields = {'branch': branch, 'sha': sha, 'wt': worktree, **details}
    return f'{stamp} {event} ' + ' '.join(f'{k}={_value(v)}' for k, v in fields.items()) + '\n'


def append_line(line, path=None):
    """Append with a single write + flush (O_APPEND) so concurrent writers do not interleave."""
    path = pathlib.Path(path) if path else log_path()
    try:
        new = not path.exists()
        with open(path, 'a', encoding='utf-8') as out:
            out.write(line)
            out.flush()
        if new:
            os.chmod(path, 0o666)  # other users' gates append too
    except OSError:
        pass


def identity(repo):
    """(branch, short sha) of the checkout; '?' when git cannot say."""
    def git(*args):
        try:
            return subprocess.check_output(['git', *args], cwd=repo, text=True, stderr=subprocess.DEVNULL).strip() or '?'
        except (OSError, subprocess.CalledProcessError):
            return '?'
    branch = git('branch', '--show-current')
    return ('(detached)' if branch == '?' else branch), git('rev-parse', '--short', 'HEAD')


NOTIFY_EVENTS = ('ABORT', 'FAIL', 'ERROR')
NOTIFY_TIMEOUT = 20
_pending = []


def send_notification(text, target):
    """Pipe `text` into `raft message send`; returns an error string, or None on success.

    The body goes through stdin only (never argv or a shell) and a hang is cut off
    after NOTIFY_TIMEOUT seconds.
    """
    try:
        sent = subprocess.run(['raft', 'message', 'send', '--target', target], input=text, text=True,
                              capture_output=True, timeout=NOTIFY_TIMEOUT)
    except (OSError, subprocess.SubprocessError) as error:
        return type(error).__name__
    return None if sent.returncode == 0 else f'exit {sent.returncode}'


def flush_notifications():
    """Wait for background notifications (each is bounded by NOTIFY_TIMEOUT)."""
    while _pending:
        _pending.pop().join(NOTIFY_TIMEOUT + 5)


class Events:
    """Emit gate events for one checkout. `notify` text is sent on ABORT/FAIL/ERROR only
    when RAFT_GATE_NOTIFY_TARGET is set; a failed send becomes a NOTIFY-FAILED event and
    never changes the gate result."""

    def __init__(self, repo):
        self.repo = repo
        self.branch, self.sha = identity(repo)

    def __call__(self, event, /, notify=None, **details):
        append_line(format_event(event, self.branch, self.sha, str(self.repo), **details))
        target = os.environ.get('RAFT_GATE_NOTIFY_TARGET', '').strip()
        if notify and target and event in NOTIFY_EVENTS:
            def send():
                error = send_notification(notify, target)
                if error:
                    self('NOTIFY-FAILED', failed=event, error=error)
            thread = threading.Thread(target=send, daemon=True)  # never delay killing the shards
            thread.start()
            _pending.append(thread)

    def message(self, reason, *lines):
        """Short Chinese notification body: headline, reason, then detail lines (log path last)."""
        return '\n'.join([f'全量检查失败：{self.branch} {self.sha}', f'原因：{reason}', *lines])


class Interrupted(BaseException):
    """SIGTERM/SIGINT as an exception, so try/finally can clean up and log a terminal event."""

    def __init__(self, signum):
        super().__init__(signum)
        self.signum = signum

    @property
    def name(self):
        return signal.Signals(self.signum).name


def raise_on_signals():
    def handler(signum, _frame):
        raise Interrupted(signum)
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, handler)
