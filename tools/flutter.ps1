param([Parameter(ValueFromRemainingArguments=$true)][string[]]$FlutterArguments)
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# Dart native hooks on Windows currently fail when the executable path contains spaces.
# The existing Windows short path addresses the same directory; no copy or drive mapping.
$fileSystem = New-Object -ComObject Scripting.FileSystemObject
$taskRoot = $fileSystem.GetFolder($taskRoot).ShortPath
$env:PUB_CACHE = Join-Path $taskRoot '.tooling/pub-cache'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:GRADLE_USER_HOME = Join-Path $taskRoot '.tooling/gradle'
$env:ANDROID_HOME = Join-Path $taskRoot '.tooling/android-sdk'
$env:ANDROID_USER_HOME = Join-Path $taskRoot '.tooling/android-user'
New-Item -ItemType Directory -Force -Path $env:ANDROID_USER_HOME | Out-Null
if (Test-Path (Join-Path $taskRoot '.tooling/java')) { $env:JAVA_HOME = (Get-ChildItem (Join-Path $taskRoot '.tooling/java') -Directory | Select-Object -First 1).FullName }
& (Join-Path $taskRoot '.tooling/flutter/bin/flutter.bat') @FlutterArguments
exit $LASTEXITCODE
