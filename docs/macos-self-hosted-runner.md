# Retired dedicated macOS release runner (historical)

The dedicated repository runner was retired on 2026-10-27. Active releases and
original-source backfills now use GitHub-hosted `macos-15` ARM64 and
`ubuntu-24.04` x64 runners; see [release CI](release-ci.md). The provisioning,
storage and removal notes below describe the retired setup and are retained
for historical operations. They are not instructions to register a new runner.

The `raft-macos-arm64-data` label selects a repository runner with its work,
temporary files, toolchains and caches on a mounted data volume. Register it
without default labels so unrelated `self-hosted` jobs cannot select it. It
processes one job at a time. Release workflows run on tags or explicit manual
dispatch; do not route pull-request jobs to this machine.

The service environment defines `RAFT_MACOS_RUNNER_ROOT` under `/Volumes/Data`.
Install a separate arm64 Flutter SDK matching `.fvmrc`, Python 3.12, Ruby 3.3,
CocoaPods 1.16.2 and JSON gem 2.18.0 beneath that root. The Python executable
must be copied into its environment (`venv --copies`). Do not reuse another
runner's registration or writable Flutter cache, and do not change global
Ruby, CocoaPods or SDK selections. The data-volume environment must set every
cache variable listed in `tool/macos_runner.py`, plus `RAFT_FLUTTER_BIN` and
the matching `PATH`. The service startup checks that the volume is mounted
before creating directories. Runner output and diagnostics also belong beneath the data root. A small
startup log and launcher may stay in the agent's control directory; macOS
launchd cannot open external-volume log paths before the service starts. The
small LaunchAgent definition belongs in the user's Library.

If launchd is denied external-volume access, use a small, identifiable launcher
app. Select only the dedicated runner directory through the system folder
picker, and retain its security-scoped bookmark in the small control directory.
Restore that bookmark before starting `runsvc.sh`; do not grant Full Disk Access
or borrow another application's permission. Verify that a service restart
reconnects without another directory selection. The active service can hold an
idle-sleep assertion with `caffeinate -is`; stopping it releases that assertion
without changing the computer's power settings.

Use GitHub's official runner package and compare its SHA-256 with the release
asset digest. Register with a short-lived token supplied through
`ACTIONS_RUNNER_INPUT_TOKEN`; never put the token into scripts, reports or
command history. Run the official `runsvc.sh` from the service launcher. Keep
runner credential files owner-readable only. A user LaunchAgent resumes after
login; it does not run while the computer is shut down or the user is logged
out. Existing runner services remain separate.

Before a build, `python tool/macos_runner.py` verifies the mounted data volume,
resolved checkout/cache/toolchain locations and exact package versions. It
stops on a mismatch rather than installing a fallback on the system volume.
The hosted setup-python and setup-ruby macOS distributions use fixed install
prefixes, so this runner uses its independently provisioned tools instead.

## Backfill an existing release

After merging the workflow, run **Backfill an existing platform release** with the
`macos`, the existing release tag, its full original commit and its original build number.
For `v1.21.23+10`, these are
`5e7f6f56863e5af2cf6fae174b795880dffa3ca9` and `87`.
The workflow revision supplies only orchestration. A separate checkout of the
original tag supplies all compiled product source and build/package inputs.
Both the tag and checked-out commit must match the published release's stored
provenance. Build artifacts are checked again against that identity.

The default run uploads an Actions artifact without publishing. Selecting
`publish` enables a separate hosted job with write permission and the update
signing secret. That job rechecks the original source and release provenance,
then appends only macOS assets. Existing different assets cause a failure;
neither tags nor sibling platform assets are replaced. The regular publisher's
tag-push guard is unchanged.

## Operations and removal

Keep a resource receipt with the registered runner name, data root, service
label, accountable owner and next maintenance review. During review, check
runner updates, free disk space and the pinned toolchain. Preserve pending
builds and review evidence during cleanup. To stop this runner, use its own
`svc.sh stop`; to remove it, use its own `svc.sh uninstall`, then remove its
GitHub registration using a newly issued removal token. Confirm that no worker
is active before deleting its owned cache or work directories. Never operate
on another runner's service or credentials.

References: [GitHub service configuration](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/configure-the-application),
[runner environment arguments](https://github.com/actions/runner/blob/v2.338.2/src/Runner.Listener/CommandSettings.cs),
[setup-python self-hosted limits](https://github.com/actions/setup-python/blob/main/docs/advanced-usage.md),
[setup-ruby self-hosted runners](https://github.com/ruby/setup-ruby/blob/master/README.md).
