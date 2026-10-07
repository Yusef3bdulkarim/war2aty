<#
.SYNOPSIS
    Builds a release artifact for War2aty with every flag a release needs.

.DESCRIPTION
    F27-T13. This script exists because a release build is a list of flags that
    are easy to forget and silent when forgotten:

      --dart-define-from-file   forgotten, the app launches unconfigured and
                                tells every user the service is unavailable
      --obfuscate               forgotten, Dart class and function names ship
      --split-debug-info        forgotten, there is no mapping to read a
                                future obfuscated stack trace with
      -t lib/main_prod.dart     forgotten, `flutter build` fails on a missing
                                lib/main.dart (there is no default entrypoint)

    The one thing it does NOT have to check is the release key: the prod
    release build fails on its own without it (android/app/build.gradle.kts,
    F27-H7).

    Symbols are written to build/symbols/<version>+<build>/ and must be kept
    for as long as that build is installed anywhere. See docs/BUILD.md.

.PARAMETER Artifact
    apk (default) or aab. The .aab is what Play takes.

.PARAMETER Flavor
    prod (default) or dev. A dev build uses config/dev defaults and may be
    signed with the debug key.

.PARAMETER Arm64Only
    Build arm64 only, which halves the APK. Use for a direct install on a
    64-bit phone; never for the Play bundle, which must keep every ABI so Play
    can split per device.

.EXAMPLE
    ./tool/build_release.ps1 -Artifact aab
.EXAMPLE
    ./tool/build_release.ps1 -Artifact apk -Arm64Only
#>
[CmdletBinding()]
param(
    [ValidateSet('apk', 'aab')]
    [string]$Artifact = 'apk',

    [ValidateSet('prod', 'dev')]
    [string]$Flavor = 'prod',

    [switch]$Arm64Only
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
Push-Location $repo

try {
    # `version: <name>+<build>` in pubspec.yaml. The symbols directory is named after
    # it, so a crash from a known build has exactly one mapping to look in.
    $versionLine = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$' |
        Select-Object -First 1
    if (-not $versionLine) { throw 'Could not read `version:` from pubspec.yaml.' }
    $version = $versionLine.Matches[0].Groups[1].Value.Trim()

    # Only prod takes a config file. The dev flavor's URL and key are compiled
    # in by `AppEnvironment.dev()`; `config/dev.usb.json` exists to point a
    # physical device at the local stack over the LAN, and is a deliberate
    # choice the developer passes themselves rather than a build default.
    $configFile = if ($Flavor -eq 'prod') { 'config/prod.json' } else { $null }
    if ($Flavor -eq 'prod' -and -not (Test-Path $configFile)) {
        throw "$configFile does not exist. A prod build without it launches unconfigured and tells every user the service is unavailable."
    }

    $symbols = "build/symbols/$version"
    $target = if ($Flavor -eq 'prod') { 'lib/main_prod.dart' } else { 'lib/main_dev.dart' }
    $command = if ($Artifact -eq 'aab') { 'appbundle' } else { 'apk' }

    $flutterArgs = @(
        'build', $command,
        '--flavor', $Flavor,
        '--release',
        '-t', $target,
        '--obfuscate',
        "--split-debug-info=$symbols"
    )

    if ($configFile) {
        $flutterArgs += "--dart-define-from-file=$configFile"
    }

    if ($Arm64Only) {
        if ($Artifact -eq 'aab') {
            throw 'Refusing -Arm64Only for an .aab: Play splits per device itself, and pinning one ABI would drop every 32-bit device from the listing.'
        }
        $flutterArgs += @('--target-platform', 'android-arm64')
    }

    Write-Host "Building $Flavor $Artifact $version" -ForegroundColor Cyan
    Write-Host "  flutter $($flutterArgs -join ' ')"

    & flutter @flutterArgs
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed with exit code $LASTEXITCODE." }

    Write-Host ''
    Write-Host 'Built:' -ForegroundColor Green
    Get-ChildItem -Path 'build/app/outputs' -Recurse -Include '*.apk', '*.aab' |
        Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-30) } |
        ForEach-Object {
            '  {0}  ({1:N1} MB)' -f $_.FullName.Replace("$repo\", ''), ($_.Length / 1MB)
        }

    Write-Host ''
    Write-Host "Symbols (keep these for as long as this build exists anywhere):" -ForegroundColor Yellow
    Get-ChildItem -Path $symbols -ErrorAction SilentlyContinue |
        ForEach-Object { '  {0}  ({1:N1} MB)' -f $_.FullName.Replace("$repo\", ''), ($_.Length / 1MB) }
}
finally {
    Pop-Location
}
