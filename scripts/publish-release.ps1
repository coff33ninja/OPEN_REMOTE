[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)]
  [string]$Tag,
  [string]$Title = '',
  [string]$Target = '',
  [string]$ArtifactRoot = '',
  [string]$Notes = '',
  [string]$NotesFile = '',
  [switch]$Draft,
  [switch]$Prerelease,
  [switch]$Rebuild
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

  if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) {
    & $FilePath @ArgumentList
  } else {
    Push-Location $WorkingDirectory
    try {
      & $FilePath @ArgumentList
    } finally {
      Pop-Location
    }
  }

  if ($LASTEXITCODE -ne 0) {
    $renderedArgs = if ($ArgumentList.Count -gt 0) {
      $ArgumentList -join ' '
    } else {
      ''
    }
    throw "Command failed: $FilePath $renderedArgs"
  }
}

function Test-GhAuth {
  param(
    [Parameter(Mandatory = $true)]
    [string]$GhPath,
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot
  )

  Push-Location $RepoRoot
  try {
    & $GhPath auth status
  } finally {
    Pop-Location
  }

  if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated. Run 'gh auth login' on this host first."
  }
}

function Get-ReleaseAssetPaths {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath
  )

  if (-not (Test-Path $ManifestPath)) {
    throw "Build manifest '$ManifestPath' does not exist. Run build-release-artifacts.ps1 first or pass -Rebuild."
  }

  $manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json
  $assetPaths = New-Object System.Collections.Generic.List[string]
  foreach ($artifact in $manifest.artifacts) {
    $fullPath = [string]$artifact.path
    if (-not (Test-Path $fullPath)) {
      throw "Expected artifact '$fullPath' is missing."
    }
    $assetPaths.Add($fullPath)
  }

  $checksumsPath = [string]$manifest.checksums_path
  if (-not [string]::IsNullOrWhiteSpace($checksumsPath)) {
    if (-not (Test-Path $checksumsPath)) {
      throw "Expected checksum file '$checksumsPath' is missing."
    }
    $assetPaths.Add($checksumsPath)
  }

  return $assetPaths
}

function Test-ReleaseExists {
  param(
    [Parameter(Mandatory = $true)]
    [string]$GhPath,
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot
  )

  $captureId = [guid]::NewGuid().ToString('N')
  $stdoutPath = Join-Path $env:TEMP "openremote-gh-release-$captureId.out"
  $stderrPath = Join-Path $env:TEMP "openremote-gh-release-$captureId.err"

  try {
    $process = Start-Process `
      -FilePath $GhPath `
      -ArgumentList @('release', 'view', $Tag, '--json', 'url') `
      -WorkingDirectory $RepoRoot `
      -NoNewWindow `
      -PassThru `
      -Wait `
      -RedirectStandardOutput $stdoutPath `
      -RedirectStandardError $stderrPath

    return $process.ExitCode -eq 0
  } finally {
    foreach ($capturePath in @($stdoutPath, $stderrPath)) {
      if (Test-Path $capturePath) {
        Remove-Item -Force -WhatIf:$false $capturePath
      }
    }
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ArtifactRoot)) {
  $ArtifactRoot = Join-Path $repoRoot 'release-artifacts'
}
$artifactRoot = [System.IO.Path]::GetFullPath($ArtifactRoot)
$manifestPath = Join-Path $artifactRoot 'manifest.json'
$buildScriptPath = Join-Path $PSScriptRoot 'build-release-artifacts.ps1'

$gh = Get-RequiredCommand 'gh'
$git = Get-RequiredCommand 'git'

if ([string]::IsNullOrWhiteSpace($Title)) {
  $Title = $Tag
}

if ([string]::IsNullOrWhiteSpace($Target)) {
  $Target = (& $git -C $repoRoot rev-parse HEAD).Trim()
  if ($LASTEXITCODE -ne 0) {
    throw 'Could not resolve the current git commit.'
  }
}

if ($Rebuild) {
  Write-Host 'Rebuilding release artifacts before publishing...'
  & $buildScriptPath -ArtifactRoot $artifactRoot -Clean
}

$assetPaths = Get-ReleaseAssetPaths -ManifestPath $manifestPath
Test-GhAuth -GhPath $gh -RepoRoot $repoRoot
$releaseExists = Test-ReleaseExists -GhPath $gh -Tag $Tag -RepoRoot $repoRoot

if (-not $PSCmdlet.ShouldProcess("GitHub release $Tag", 'push tag and publish release assets')) {
  return
}

$localTag = (& $git -C $repoRoot tag --list $Tag).Trim()
if ($localTag -ne $Tag) {
  Write-Host "Creating local tag $Tag at $Target"
  Invoke-External -FilePath $git -ArgumentList @('-C', $repoRoot, 'tag', $Tag, $Target)
}

Write-Host "Pushing tag $Tag to origin"
Invoke-External -FilePath $git -ArgumentList @('-C', $repoRoot, 'push', 'origin', $Tag)

if (-not $releaseExists) {
  $createArgs = @(
    'release',
    'create',
    $Tag,
    '--target',
    $Target,
    '--title',
    $Title
  )
  if ($Draft) {
    $createArgs += '--draft'
  }
  if ($Prerelease) {
    $createArgs += '--prerelease'
  }
  if (-not [string]::IsNullOrWhiteSpace($NotesFile)) {
    $createArgs += @('--notes-file', $NotesFile)
  } elseif (-not [string]::IsNullOrWhiteSpace($Notes)) {
    $createArgs += @('--notes', $Notes)
  } else {
    $createArgs += '--generate-notes'
  }
  $createArgs += $assetPaths

  Write-Host "Creating GitHub release $Tag"
  Invoke-External -FilePath $gh -ArgumentList $createArgs -WorkingDirectory $repoRoot
} else {
  $editArgs = @(
    'release',
    'edit',
    $Tag,
    '--title',
    $Title,
    "--draft=$($Draft.ToString().ToLowerInvariant())"
  )
  if ($Prerelease) {
    $editArgs += '--prerelease'
  }
  if (-not [string]::IsNullOrWhiteSpace($NotesFile)) {
    $editArgs += @('--notes-file', $NotesFile)
  } elseif (-not [string]::IsNullOrWhiteSpace($Notes)) {
    $editArgs += @('--notes', $Notes)
  }

  Write-Host "Updating GitHub release $Tag"
  Invoke-External -FilePath $gh -ArgumentList $editArgs -WorkingDirectory $repoRoot

  $uploadArgs = @(
    'release',
    'upload',
    $Tag
  )
  $uploadArgs += $assetPaths
  $uploadArgs += '--clobber'

  Write-Host "Uploading staged assets to $Tag"
  Invoke-External -FilePath $gh -ArgumentList $uploadArgs -WorkingDirectory $repoRoot
}
