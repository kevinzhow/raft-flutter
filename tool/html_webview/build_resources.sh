#!/bin/sh
# Optional legacy-builder assertion before APT starts. No resource or security mutation.
set -eu
read_value() { if [ -r "$1" ]; then cat "$1"; else printf '%s' unavailable; fi; }
cpu=$(read_value /sys/fs/cgroup/cpu.max)
cpuset=$(read_value /sys/fs/cgroup/cpuset.cpus.effective)
memory=$(read_value /sys/fs/cgroup/memory.max)
process=$(cat /proc/1/stat)
# PID1 is the fixed exec-form nice -> /bin/sh RUN entry point; fields after comm begin at3.
remaining=${process#*) }
set -- $remaining
priority=${17}
printf 'SDK build resource readback: cpu.max=%s cpuset=%s memory.max=%s nice=%s\n' "$cpu" "$cpuset" "$memory" "$priority"
if [ "${RAFT_HTML_SDK_ENFORCE_LIMITS:-0}" = 1 ]; then
  [ "$cpu" = '200000 100000' ]
  case "$cpuset" in 0-1|0,1) ;; *) exit 31 ;; esac
  [ "$memory" = 17179869184 ]
  [ "$priority" = 15 ]
fi
