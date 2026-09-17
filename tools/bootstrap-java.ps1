$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$assets = Invoke-RestMethod -Uri 'https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse'
$asset = $assets[0]
$zipPath = Join-Path $taskRoot '.tooling/jdk.zip'
Invoke-WebRequest -Uri $asset.binary.package.link -OutFile $zipPath
if ((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $asset.binary.package.checksum) { throw 'Empreinte JDK incorrecte' }
Expand-Archive -LiteralPath $zipPath -DestinationPath (Join-Path $taskRoot '.tooling/java') -Force
$asset | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $taskRoot 'docs/evidence/java-release.json') -Encoding utf8
Write-Output $asset.release_name
