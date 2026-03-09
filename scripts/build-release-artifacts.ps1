[CmdletBinding()]
param(
  [string]$ArtifactRoot = '',
  [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RequiredCommand {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -eq $command) {
    throw "Required command '$Name' was not found on PATH."
  }

  return $command.Source
}

function Invoke-External {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    [string[]]$ArgumentList = @(),
    [string]$WorkingDirectory = ''
  )

  Push-Location $WorkingDirectory
  try {
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
      $renderedArgs = if ($ArgumentList.Count -gt 0) {
        $ArgumentList -join ' '
      } else {
        ''
      }
      throw "Command failed: $FilePath $renderedArgs"
    }
  } finally {
    Pop-Location
  }
}

function Get-AndroidVersion {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PubspecPath
  )

  $versionLine = Select-String -Path $PubspecPath -Pattern '^\s*version:\s*(.+?)\s*$' | Select-Object -First 1
  if ($null -eq $versionLine) {
    throw "Could not find a version entry in '$PubspecPath'."
  }

  return $versionLine.Matches[0].Groups[1].Value.Trim()
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$agentDir = Join-Path $repoRoot 'agent'
$androidDir = Join-Path $repoRoot 'android'
$pubspecPath = Join-Path $androidDir 'pubspec.yaml'

if ([string]::IsNullOrWhiteSpace($ArtifactRoot)) {
  $ArtifactRoot = Join-Path $repoRoot 'release-artifacts'
}

$artifactRoot = [System.IO.Path]::GetFullPath($ArtifactRoot)
$agentArtifactDir = Join-Path $artifactRoot 'agent'
$androidArtifactDir = Join-Path $artifactRoot 'android'
$manifestPath = Join-Path $artifactRoot 'manifest.json'
$hashPath = Join-Path $artifactRoot 'SHA256SUMS.txt'
$agentOutputPath = Join-Path $agentArtifactDir 'openremote-agent-windows-amd64.exe'
$apkOutputPath = Join-Path $androidArtifactDir 'openremote-android-release.apk'
$apkSourcePath = Join-Path $androidDir 'build\app\outputs\flutter-apk\app-release.apk'

$go = Get-RequiredCommand 'go'
$flutter = Get-RequiredCommand 'flutter'
$git = Get-RequiredCommand 'git'

if ($Clean -and (Test-Path $artifactRoot)) {
  Remove-Item -Recurse -Force $artifactRoot
}

New-Item -ItemType Directory -Path $agentArtifactDir -Force | Out-Null
New-Item -ItemType Directory -Path $androidArtifactDir -Force | Out-Null

Write-Host "Restoring Go modules and building the Windows agent..."
Invoke-External -FilePath $go -ArgumentList @('mod', 'download') -WorkingDirectory $agentDir
Invoke-External -FilePath $go -ArgumentList @('build', '-o', $agentOutputPath, './cmd/openremote-agent') -WorkingDirectory $agentDir

Write-Host "Restoring Flutter packages and building the Android release APK..."
Invoke-External -FilePath $flutter -ArgumentList @('pub', 'get') -WorkingDirectory $androidDir
Invoke-External -FilePath $flutter -ArgumentList @('build', 'apk', '--release') -WorkingDirectory $androidDir

if (-not (Test-Path $apkSourcePath)) {
  throw "Expected APK was not produced at '$apkSourcePath'."
}

Copy-Item -Path $apkSourcePath -Destination $apkOutputPath -Force

$gitCommit = (& $git -C $repoRoot rev-parse --short HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
  throw 'Could not resolve the current git commit.'
}

$androidVersion = Get-AndroidVersion -PubspecPath $pubspecPath
$builtAt = (Get-Date).ToUniversalTime().ToString('o')

$artifacts = @(
  [pscustomobject]@{
    name = 'openremote-agent-windows-amd64.exe'
    path = $agentOutputPath
    kind = 'agent'
  },
  [pscustomobject]@{
    name = 'openremote-android-release.apk'
    path = $apkOutputPath
    kind = 'android'
  }
)

$hashLines = foreach ($artifact in $artifacts) {
  $hash = Get-FileHash -Algorithm SHA256 -Path $artifact.path
  '{0} *{1}' -f $hash.Hash.ToLowerInvariant(), $artifact.name
}
$hashLines | Set-Content -Path $hashPath -Encoding ASCII

$manifest = [pscustomobject]@{
  built_at        = $builtAt
  git_commit      = $gitCommit
  android_version = $androidVersion
  artifact_root   = $artifactRoot
  checksums_path  = $hashPath
  artifacts       = $artifacts
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding ASCII

Write-Host "Artifacts staged in $artifactRoot"
Write-Host "  Agent : $agentOutputPath"
Write-Host "  APK   : $apkOutputPath"
Write-Host "  Hashes: $hashPath"
Write-Host "  Meta  : $manifestPath"
