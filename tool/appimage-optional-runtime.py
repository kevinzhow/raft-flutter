#!/usr/bin/env python3
"""Run a source-bound AppImage in a preprovisioned disposable missing-library case."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

import linux_optional_runtime as optional


def run(args):
    if os.environ.get('GITHUB_ACTIONS') != 'true' or not Path('/.dockerenv').is_file():
        raise ValueError('Optional-runtime checks require a disposable CI Docker container')
    distribution = dict(line.split('=', 1) for line in Path('/etc/os-release').read_text().splitlines()
                        if '=' in line)['ID'].strip('"')
    if distribution not in optional.PACKAGES:
        raise ValueError('Only declared Ubuntu/Fedora runtime cases are supported')
    args.output.mkdir(parents=True, exist_ok=False)
    receipt = optional.artifact_receipt(args.artifact)
    expected = optional.SCENARIOS[args.scenario]
    before = optional.feature_state()
    before['packages'] = optional.package_state(distribution)
    before.update(artifact=receipt['sha256'], commit=receipt['commit'],
                  scenario=args.scenario, expected=expected,
                  osRelease=Path('/etc/os-release').read_text())
    before_path = args.output / 'environment-before.json'
    before_path.write_text(json.dumps(before, indent=2) + '\n')
    optional.require_state(before, expected, before['packages'])
    command = ['dbus-run-session', '--', sys.executable, str(Path(__file__).with_name('appimage-smoke.py')),
               '--artifact', str(args.artifact.resolve()), '--output', str(args.output / 'startup'),
               '--mode', 'extract']
    for feature, state in expected.items():
        command += ['--expect-' + feature, state]
    with (args.output / 'startup.log').open('w') as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
    result = {'artifact': receipt['sha256'], 'commit': receipt['commit'], 'scenario': args.scenario,
              'startup': 'PASS', 'targetedUseCase': 'NOT_RUN',
              'scope': 'first screen and environment only; login/messages/prompts/recovery NOT_RUN'}
    if args.driver:
        driver = args.driver.resolve(strict=True)
        if driver.name != 'linux_optional_runtime_driver.py':
            raise ValueError('Expected the reviewed native-use-case driver')
        driver_command = [sys.executable, str(driver), '--artifact', str(args.artifact.resolve()),
                          '--output', str(args.output / 'native'), '--scenario', args.scenario,
                          '--environment-before', str(before_path.resolve()),
                          '--restore-command-json', args.restore_command_json]
        result['driverSourceSha256'] = hashlib.sha256(driver.read_bytes()).hexdigest()
        with (args.output / 'native-driver.log').open('w') as log:
            subprocess.run(driver_command, stdout=log, stderr=subprocess.STDOUT, check=True)
        # The driver owns actual GTK inputs and API/data readback. This runner
        # deliberately does not infer native PASS merely from its exit status.
        result.update(targetedUseCase='DRIVER_COMPLETED_REQUIRES_EVIDENCE_REVIEW',
                      scope='native driver completed; inspect its assertion-bound report')
    (args.output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifact', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--scenario', choices=optional.SCENARIOS, required=True)
    parser.add_argument('--driver', type=Path)
    parser.add_argument('--restore-command-json', default='[]')
    run(parser.parse_args())
