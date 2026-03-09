[CmdletBinding()]
param(
  [int]$Port = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$agentDir = Join-Path $repoRoot 'agent'
$remotesDir = Join-Path $repoRoot 'remotes'
$runId = [guid]::NewGuid().ToString('N')
$tempRoot = Join-Path $env:TEMP ("openremote-smoke-" + $runId)
$dataDir = Join-Path $tempRoot 'data'
$uploadDir = Join-Path $dataDir 'uploads'
$binaryPath = Join-Path $tempRoot ("openremote-agent-smoke-" + $runId + '.exe')
$launcherPath = Join-Path $tempRoot 'run-agent.ps1'

$agentProcess = $null
$pingProcess = $null

function Invoke-Json {
  param(
    [string]$Method,
    [string]$Uri,
    [hashtable]$Headers = @{},
    [object]$Body
  )

  $params = @{
    Method = $Method
    Uri    = $Uri
  }
  if ($Headers.Count -gt 0) {
    $params['Headers'] = $Headers
  }
  if ($PSBoundParameters.ContainsKey('Body')) {
    $params['ContentType'] = 'application/json'
    $params['Body'] = $Body | ConvertTo-Json -Depth 32
  }

  Invoke-RestMethod @params
}

try {
  if ($Port -le 0) {
    $Port = Get-Random -Minimum 19000 -Maximum 29000
  }
  $healthUri = "http://127.0.0.1:$Port/healthz"
  $baseUri = "http://127.0.0.1:$Port"

  New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
  New-Item -ItemType Directory -Path $uploadDir -Force | Out-Null

  Push-Location $agentDir
  go build -o $binaryPath ./cmd/openremote-agent
  Pop-Location

  @"
`$env:OPENREMOTE_PORT = '$Port'
`$env:OPENREMOTE_PUBLIC_HOST = '127.0.0.1'
`$env:OPENREMOTE_DEVICE_NAME = 'Smoke Agent'
`$env:OPENREMOTE_DATA_DIR = '$($dataDir -replace "'", "''")'
`$env:OPENREMOTE_REMOTES_DIR = '$($remotesDir -replace "'", "''")'
`$env:OPENREMOTE_UPLOADS_DIR = '$($uploadDir -replace "'", "''")'
& '$($binaryPath -replace "'", "''")'
"@ | Set-Content -Path $launcherPath -Encoding ASCII

  $agentProcess = Start-Process powershell `
    -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $launcherPath) `
    -PassThru `
    -WorkingDirectory $agentDir `
    -WindowStyle Hidden

  $healthy = $false
  for ($attempt = 0; $attempt -lt 40; $attempt++) {
    try {
      $health = Invoke-RestMethod -Method Get -Uri $healthUri
      if ($health.status -eq 'ok') {
        $healthy = $true
        break
      }
    } catch {
      Start-Sleep -Milliseconds 250
    }
  }

  if (-not $healthy) {
    throw "Agent did not become healthy on $healthUri."
  }

  $pairSession = Invoke-Json -Method Get -Uri "$baseUri/api/v1/pairing/session"
  $pairResult = Invoke-Json -Method Post -Uri "$baseUri/api/v1/pairing/complete" -Body @{
    device_name   = 'Smoke Client'
    pairing_token = $pairSession.token
  }
  $token = [string]$pairResult.access_token
  $headers = @{ Authorization = "Bearer $token" }

  $catalog = Invoke-Json -Method Get -Uri "$baseUri/api/v1/remotes/catalog"
  $filesBefore = Invoke-Json -Method Get -Uri "$baseUri/api/v1/files" -Headers $headers
  $rootEntries = Invoke-Json -Method Get -Uri "$baseUri/api/v1/filesystem" -Headers $headers

  $uploadResult = Invoke-Json -Method Post -Uri "$baseUri/api/v1/files/upload" -Headers $headers -Body @{
    name        = 'smoke.txt'
    base64_data = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('smoke upload'))
  }
  $filesAfter = Invoke-Json -Method Get -Uri "$baseUri/api/v1/files" -Headers $headers

  $filesystemUriBuilder = [System.UriBuilder]::new("$baseUri/api/v1/filesystem")
  $filesystemUriBuilder.Query = "path=$([uri]::EscapeDataString($uploadDir))"
  $uploadEntries = Invoke-Json -Method Get -Uri $filesystemUriBuilder.Uri.AbsoluteUri -Headers $headers

  $processesBefore = Invoke-Json -Method Get -Uri "$baseUri/api/v1/processes" -Headers $headers
  $pingProcess = Start-Process ping -ArgumentList @('127.0.0.1', '-t') -PassThru -WindowStyle Hidden
  Start-Sleep -Milliseconds 400
  $terminateResult = Invoke-Json -Method Post -Uri "$baseUri/api/v1/processes/terminate" -Headers $headers -Body @{
    pid = $pingProcess.Id
  }
  try {
    Wait-Process -Id $pingProcess.Id -Timeout 5 -ErrorAction Stop
  } catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
  }
  $pingProcess = $null

  $macroResult = Invoke-Json -Method Post -Uri "$baseUri/api/v1/commands" -Headers $headers -Body @{
    remote_id  = 'smoke'
    name       = 'macro_run'
    type       = 'macro'
    action     = 'run'
    arguments  = @{
      steps = @(
        @{
          name = 'volume_set'
          arguments = @{
            value = 30
          }
        },
        @{
          name = 'media_toggle'
        }
      )
    }
  }

  $webSocket = [System.Net.WebSockets.ClientWebSocket]::new()
  try {
    $null = $webSocket.ConnectAsync([Uri]"ws://127.0.0.1:$Port/ws?access_token=$token", [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    $commandJson = @{
      remote_id = 'smoke'
      name      = 'mouse_move'
      type      = 'mouse'
      action    = 'move'
      arguments = @{
        dx = 1
        dy = 1
      }
    } | ConvertTo-Json -Compress

    $sendBuffer = [Text.Encoding]::UTF8.GetBytes($commandJson)
    $null = $webSocket.SendAsync(
      [ArraySegment[byte]]::new($sendBuffer),
      [System.Net.WebSockets.WebSocketMessageType]::Text,
      $true,
      [Threading.CancellationToken]::None
    ).GetAwaiter().GetResult()

    $receiveBuffer = New-Object byte[] 4096
    $receiveResult = $webSocket.ReceiveAsync(
      [ArraySegment[byte]]::new($receiveBuffer),
      [Threading.CancellationToken]::None
    ).GetAwaiter().GetResult()

    $ackJson = [Text.Encoding]::UTF8.GetString($receiveBuffer, 0, $receiveResult.Count)
    $ack = $ackJson | ConvertFrom-Json
  } finally {
    if ($webSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
      $null = $webSocket.CloseAsync(
        [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure,
        'done',
        [Threading.CancellationToken]::None
      ).GetAwaiter().GetResult()
    }
    $webSocket.Dispose()
  }

  [pscustomobject]@{
    health_status       = $health.status
    paired_device_id    = $pairResult.device_id
    remote_count        = @($catalog.remotes).Count
    files_before        = @($filesBefore.files).Count
    files_after         = @($filesAfter.files).Count
    root_entry_count    = @($rootEntries.entries).Count
    upload_entry_count  = @($uploadEntries.entries).Count
    process_count       = @($processesBefore.processes).Count
    terminated_pid      = $terminateResult.pid
    macro_status        = $macroResult.status
    websocket_ack       = $ack.type
    websocket_command   = $ack.command
  } | ConvertTo-Json
} finally {
  if ($null -ne $pingProcess) {
    try {
      Stop-Process -Id $pingProcess.Id -Force -ErrorAction SilentlyContinue
    } catch {
    }
  }

  if ($null -ne $agentProcess) {
    try {
      Stop-Process -Id $agentProcess.Id -Force -ErrorAction SilentlyContinue
    } catch {
    }
  }

  $binaryProcessName = [System.IO.Path]::GetFileNameWithoutExtension($binaryPath)
  if (-not [string]::IsNullOrWhiteSpace($binaryProcessName)) {
    try {
      Get-Process -Name $binaryProcessName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    } catch {
    }
  }

  if (Test-Path $tempRoot) {
    Start-Sleep -Milliseconds 500
    try {
      Remove-Item -Recurse -Force $tempRoot -ErrorAction Stop
    } catch {
      Write-Warning "Could not remove temporary smoke directory ${tempRoot}: $($_.Exception.Message)"
    }
  }
}
