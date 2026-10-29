"""Private KEY=VALUE env files for the local Raft stack and local antiproton (mode 600)."""
import base64
import os
from pathlib import Path
import secrets


def read_env_file(path):
    values = {}
    path = Path(path)
    if path.exists():
        for line in path.read_text().splitlines():
            if line.strip() and not line.lstrip().startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                values[key.strip()] = value
    return values


def write_env_file(path, values):
    """Write KEY=VALUE lines to a file created with mode 600 (never wider, even transiently)."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    text = ''.join(f'{key}={value}\n' for key, value in values.items())
    tmp = path.with_name(path.name + '.tmp')
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as handle:
        handle.write(text)
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def random_b64(size=32):
    return base64.b64encode(secrets.token_bytes(size)).decode()
