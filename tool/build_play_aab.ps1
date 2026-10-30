# Builds the Google Play App Bundle with Dart debug information split out of
# libapp.so. Dropping the symbols from the shipped snapshot is the biggest size
# win available to a Flutter app, and obfuscating the remaining symbols squeezes
# a little more out. The extracted files are what you need to deobfuscate and
# symbolicate crash reports, so archive build/symbols with the release.
#
# Android native (.so) symbols stay in the bundle's BUNDLE-METADATA on purpose:
# Flutter's tooling refuses to finish a release appbundle without libflutter.so
# symbols there, and Play uses them for native crash reports. They are never
# downloaded to devices, so they do not affect the Play Store size. The bundle
# also carries the R8 mapping for the same reason.
#
# Usage:  powershell -File tool/build_play_aab.ps1
$ErrorActionPreference = 'Stop'

Push-Location (Join-Path $PSScriptRoot '..')
try {
    flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build appbundle failed with exit code $LASTEXITCODE."
    }

    $aab = 'build/app/outputs/bundle/release/app-release.aab'
    if (-not (Test-Path $aab)) {
        throw "Build finished but $aab was not produced."
    }

    $sizeMb = [math]::Round((Get-Item $aab).Length / 1MB, 2)

    # Report what is inside the upload so the next person does not mistake the
    # AAB size for the size users download (Play serves one compressed ABI
    # slice per device).
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $aab))
    try {
        $libs = ($zip.Entries | Where-Object FullName -like 'base/lib/*' |
            Measure-Object CompressedLength -Sum).Sum
        $dex = ($zip.Entries | Where-Object FullName -like 'base/dex/*' |
            Measure-Object CompressedLength -Sum).Sum
        $resources = ($zip.Entries | Where-Object FullName -like 'base/res/*' |
            Measure-Object CompressedLength -Sum).Sum
        $assets = ($zip.Entries | Where-Object FullName -like 'base/assets/*' |
            Measure-Object CompressedLength -Sum).Sum
        $metadata = ($zip.Entries | Where-Object FullName -like 'BUNDLE-METADATA/*' |
            Measure-Object CompressedLength -Sum).Sum
        $symbols = ($zip.Entries | Where-Object FullName -like 'BUNDLE-METADATA/com.android.tools.build.debugsymbols/*' |
            Measure-Object CompressedLength -Sum).Sum
        $mapping = ($zip.Entries | Where-Object FullName -like 'BUNDLE-METADATA/com.android.tools.build.obfuscation/*' |
            Measure-Object CompressedLength -Sum).Sum
    } finally {
        $zip.Dispose()
    }

    Write-Host ""
    Write-Host "AAB:      $aab ($sizeMb MB, upload only - not the Play download size)"
    Write-Host ("  lib/     {0,6:N2} MB" -f ($libs / 1MB))
    Write-Host ("  dex/     {0,6:N2} MB" -f ($dex / 1MB))
    Write-Host ("  res/     {0,6:N2} MB" -f ($resources / 1MB))
    Write-Host ("  assets/  {0,6:N2} MB" -f ($assets / 1MB))
    Write-Host ("  metadata {0,6:N2} MB  (native symbols {1:N2} + R8 mapping {2:N2}; never downloaded)" -f ($metadata / 1MB), ($symbols / 1MB), ($mapping / 1MB))
    Write-Host ""
    Write-Host "Play download size is the compressed arm64-v8a slice: lib/arm64-v8a"
    Write-Host "+ dex + res + assets, split per ABI by Play. Check Play Console for the"
    Write-Host "exact figure, or run: bundletool get-size total --apks=app-release.apks"
    Write-Host ""
    Write-Host "Symbols: build/symbols (Dart). The native .so symbols and the R8 mapping"
    Write-Host "         are already inside the AAB for Play; archive build/symbols too."
} finally {
    Pop-Location
}
