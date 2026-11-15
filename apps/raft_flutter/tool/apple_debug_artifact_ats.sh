#!/bin/sh
# Debug builds only: let the WebView load Artifact frames over plain http from
# a local content Worker on *.artifacts.localhost (tool/raft-stack). WebKit's
# App Transport Security refuses that cleartext even with
# NSAllowsLocalNetworking (CodexMac, iOS 27 simulator and macOS, 2026-11-14);
# a narrow exception for artifacts.localhost and its subdomains is enough.
# Release and profile builds are never changed: production frames are https
# on the official content domain. The Dart side allows http frames only in
# debug builds as well (artifactFrameContentSource, allowLoopback).
set -eu
[ "${CONFIGURATION:-}" = "Debug" ] || exit 0
plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
[ -f "$plist" ] || exit 0
buddy=/usr/libexec/PlistBuddy
key=":NSAppTransportSecurity:NSExceptionDomains:artifacts.localhost"
"$buddy" -c "Add :NSAppTransportSecurity dict" "$plist" 2>/dev/null || true
"$buddy" -c "Add :NSAppTransportSecurity:NSExceptionDomains dict" "$plist" 2>/dev/null || true
"$buddy" -c "Add $key dict" "$plist" 2>/dev/null || true
"$buddy" -c "Delete $key:NSIncludesSubdomains" "$plist" 2>/dev/null || true
"$buddy" -c "Add $key:NSIncludesSubdomains bool true" "$plist"
"$buddy" -c "Delete $key:NSExceptionAllowsInsecureHTTPLoads" "$plist" 2>/dev/null || true
"$buddy" -c "Add $key:NSExceptionAllowsInsecureHTTPLoads bool true" "$plist"
