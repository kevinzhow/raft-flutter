"""Fetch only the two source-reviewed libwpe archives into the isolated builder cache."""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request


def fetch(destination):
    pins = json.loads(Path(__file__).with_name('libwpe-pins.json').read_text())
    destination = Path(destination)
    for name, pin in pins['packages'].items():
        filename = f"{name}_{pins['version']}_{pins['architecture']}.deb"
        target = destination / filename
        if target.exists():
            raise ValueError('Refusing to replace an existing libwpe download')
        with urllib.request.urlopen(pins['baseUrl'] + filename, timeout=30) as response:
            if not response.url.startswith('https://'):
                raise ValueError('libwpe download redirected away from HTTPS')
            body = response.read(pin['size'] + 1)
        if len(body) != pin['size'] or hashlib.sha256(body).hexdigest() != pin['sha256']:
            raise ValueError('libwpe archive differs from its source-reviewed byte pin')
        with target.open('xb') as stream:
            stream.write(body)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', type=Path)
    fetch(parser.parse_args().destination)
