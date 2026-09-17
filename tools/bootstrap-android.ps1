$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sdkPath = Join-Path $taskRoot '.tooling/android-sdk'
$archive = Join-Path $taskRoot '.tooling/android-commandline.zip'
Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip' -OutFile $archive
New-Item -ItemType Directory -Force -Path $sdkPath | Out-Null
$toolsTarget = Join-Path $sdkPath 'cmdline-tools/latest'
if (-not (Test-Path -LiteralPath $toolsTarget)) {
    $unpacked = Join-Path $taskRoot '.tooling/android-unpacked'
    Expand-Archive -LiteralPath $archive -DestinationPath $unpacked -Force
    $moveSource = [IO.Path]::GetFullPath((Join-Path $unpacked 'cmdline-tools'))
    $moveTarget = [IO.Path]::GetFullPath($toolsTarget)
    $allowedRoot = [IO.Path]::GetFullPath((Join-Path $taskRoot '.tooling')) + [IO.Path]::DirectorySeparatorChar
    if (-not $moveSource.StartsWith($allowedRoot) -or -not $moveTarget.StartsWith($allowedRoot)) { throw 'Chemin SDK refuse' }
    New-Item -ItemType Directory -Force -Path (Split-Path $moveTarget) | Out-Null
    Move-Item -LiteralPath $moveSource -Destination $moveTarget
}
$env:JAVA_HOME = (Get-ChildItem -LiteralPath (Join-Path $taskRoot '.tooling/java') -Directory | Select-Object -First 1).FullName
$env:ANDROID_HOME = $sdkPath
$manager = Join-Path $sdkPath 'cmdline-tools/latest/bin/sdkmanager.bat'
# Explicit owner authorization received in this session, 17 September 2026.
1..20 | ForEach-Object { 'y' } | & $manager "--sdk_root=$sdkPath" 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0'
if ($LASTEXITCODE -ne 0) { throw 'Echec installation SDK Android' }
Get-FileHash -LiteralPath $archive -Algorithm SHA256 | Format-List | Out-File (Join-Path $taskRoot 'docs/evidence/android-tools-sha256.txt')
