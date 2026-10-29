#Requires -RunAsAdministrator
<#!
Collect a bounded, local ETW trace while a notification is sent by a separate
non-elevated process. This script does not send notifications: desktop Toast
notifications must be tested with the application's normal user identity.

Does not change notification preferences, registry registrations, services,
event-log configuration, app data, or existing trace sessions. Raw trace data is
private local diagnostic material and must not be committed or published.
!#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RunDirectory,
    [ValidateRange(5, 45)]
    [int]$DurationSeconds = 20
)

$ErrorActionPreference = 'Stop'
$notificationRepo = Split-Path -Parent $PSScriptRoot
$notificationLocalRoot = [IO.Path]::GetFullPath((Join-Path $notificationRepo '.local'))
$notificationRunPath = [IO.Path]::GetFullPath($RunDirectory)
if (-not $notificationRunPath.StartsWith(
    $notificationLocalRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw 'The trace directory must be a new directory inside this repository .local.'
}
if (Test-Path -LiteralPath $notificationRunPath) {
    throw 'The trace directory already exists. Choose a new directory to preserve evidence.'
}
New-Item -ItemType Directory -Path $notificationRunPath | Out-Null

$notificationSession = 'RaftNotificationDiagnosis-' + [Guid]::NewGuid().ToString('N')
$notificationTrace = Join-Path $notificationRunPath 'notifications.etl'
$notificationProviders = Join-Path $notificationRunPath 'providers.txt'
@(
    # Manifest providers and the display-side TraceLogging providers registered
    # by this Windows build's notification center, toast center and controller.
    '{88CD9180-4491-4640-B571-E3BEE2527943} 0xFFFFFFFFFFFFFFFF 5'
    '{315A8872-923E-4EA2-9889-33CD4754BF64} 0xFFFFFFFFFFFFFFFF 5'
    '{30336ED4-E327-447C-9DE0-51B652C86108} 0xFFFFFFFFFFFFFFFF 5'
    '{BF406804-6AFA-46E7-8A48-6C357E1D6D61} 0xFFFFFFFFFFFFFFFF 5'
    '{815A1F4A-3F8D-4B37-9B31-5142F9D724A5} 0xFFFFFFFFFFFFFFFF 5'
    '{5CAD3597-5FEC-4C62-9CE1-9D7ABC723D3A} 0xFFFFFFFFFFFFFFFF 5'
    '{4BFE0FDE-99D6-5630-8A47-DA7BFAEFD876} 0xFFFFFFFFFFFFFFFF 5'
    '{5FDF98FA-26F1-5F6E-95F6-DFD920760351} 0xFFFFFFFFFFFFFFFF 5'
    '{EB3540F2-1909-5D51-B72D-A3ECB0B9BF08} 0xFFFFFFFFFFFFFFFF 5'
    '{791ABEB3-6442-4189-87DD-A8144EE34B1C} 0xFFFFFFFFFFFFFFFF 5'
    '{53E167D9-E368-4150-9563-4ED25700CCC7} 0xFFFFFFFFFFFFFFFF 5'
) | Set-Content -LiteralPath $notificationProviders -Encoding ASCII

$notificationStarted = $false
try {
    & logman.exe start $notificationSession -pf $notificationProviders `
        -o $notificationTrace -f bincirc -max 16 -ets *> (Join-Path $notificationRunPath 'start.log')
    if ($LASTEXITCODE -ne 0) {
        throw 'Windows refused to start the trace; see start.log. No existing trace was stopped.'
    }
    $notificationStarted = $true
    [pscustomobject]@{
        session = $notificationSession
        startedAt = [DateTimeOffset]::Now.ToString('o')
        durationSeconds = $DurationSeconds
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $notificationRunPath 'ready.json')
    Start-Sleep -Seconds $DurationSeconds
} finally {
    if ($notificationStarted) {
        & logman.exe stop $notificationSession -ets *> (Join-Path $notificationRunPath 'stop.log')
        [pscustomobject]@{
            stoppedAt = [DateTimeOffset]::Now.ToString('o')
            stopExitCode = $LASTEXITCODE
            traceExists = Test-Path -LiteralPath $notificationTrace
        } | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $notificationRunPath 'finished.json')
    }
}
