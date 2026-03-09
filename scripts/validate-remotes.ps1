[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$remoteDir = Join-Path $repoRoot 'remotes'
$assetDir = Join-Path $repoRoot 'android\assets\remotes'

$allowedTypes = @(
  'button',
  'toggle',
  'slider',
  'touchpad',
  'text_input',
  'dpad',
  'grid_buttons',
  'macro_button'
)

$allowedCommands = @(
  'keyboard_type',
  'macro_run',
  'media_next',
  'media_previous',
  'media_stop',
  'media_toggle',
  'mouse_click',
  'mouse_move',
  'power_shutdown',
  'power_sleep',
  'presentation_blackout',
  'presentation_next',
  'presentation_previous',
  'volume_set'
)

$errors = [System.Collections.Generic.List[string]]::new()

function Add-ValidationError {
  param([string]$Message)

  $null = $errors.Add($Message)
}

function ConvertTo-HashtableRecursive {
  param([object]$InputObject)

  if ($null -eq $InputObject) {
    return $null
  }

  if ($InputObject -is [string] -or $InputObject -is [ValueType]) {
    return $InputObject
  }

  if ($InputObject -is [System.Collections.IDictionary]) {
    $table = [ordered]@{}
    foreach ($key in $InputObject.Keys) {
      $table[$key] = ConvertTo-HashtableRecursive $InputObject[$key]
    }
    return $table
  }

  if ($InputObject -is [System.Collections.IEnumerable]) {
    $items = @()
    foreach ($item in $InputObject) {
      $items += ,(ConvertTo-HashtableRecursive $item)
    }
    return $items
  }

  $table = [ordered]@{}
  foreach ($property in $InputObject.PSObject.Properties) {
    $table[$property.Name] = ConvertTo-HashtableRecursive $property.Value
  }
  return $table
}

function Test-CommandName {
  param(
    [string]$CommandName,
    [string]$Context
  )

  if ([string]::IsNullOrWhiteSpace($CommandName)) {
    Add-ValidationError "$Context is missing a command name."
    return
  }

  if ($allowedCommands -notcontains $CommandName) {
    Add-ValidationError "$Context uses unsupported command '$CommandName'."
  }
}

function Test-MacroSteps {
  param(
    [System.Collections.IEnumerable]$Steps,
    [string]$Context
  )

  if ($null -eq $Steps) {
    Add-ValidationError "$Context is missing macro steps."
    return
  }

  $index = 0
  foreach ($step in $Steps) {
    $stepContext = "$Context step[$index]"
    if ($step -isnot [System.Collections.IDictionary]) {
      Add-ValidationError "$stepContext must be an object."
      $index++
      continue
    }

    $commandName = $null
    if ($step.Contains('name')) {
      $commandName = [string]$step['name']
    } elseif ($step.Contains('cmd')) {
      $commandName = [string]$step['cmd']
    } elseif ($step.Contains('type')) {
      $stepType = [string]$step['type']
      $stepAction = if ($step.Contains('action')) { [string]$step['action'] } else { '' }
      $commandName = if ([string]::IsNullOrWhiteSpace($stepAction)) { $stepType } else { "$stepType`_$stepAction" }
    }

    Test-CommandName -CommandName $commandName -Context $stepContext
    if ($commandName -eq 'macro_run') {
      Add-ValidationError "$stepContext cannot nest macro_run."
    }

    $index++
  }
}

function Test-DpadBinding {
  param(
    [object]$Binding,
    [string]$Context
  )

  if ($null -eq $Binding) {
    return
  }

  if ($Binding -isnot [System.Collections.IDictionary]) {
    Add-ValidationError "$Context must be an object."
    return
  }

  Test-CommandName -CommandName ([string]$Binding['command']) -Context $Context
  if ([string]$Binding['command'] -eq 'macro_run') {
    $props = if ($Binding.Contains('props')) { $Binding['props'] } else { $null }
    $steps = if ($props -is [System.Collections.IDictionary] -and $props.Contains('steps')) { $props['steps'] } else { $null }
    Test-MacroSteps -Steps $steps -Context $Context
  }
}

function Test-Control {
  param(
    [System.Collections.IDictionary]$Control,
    [string]$FileName,
    [int]$Index
  )

  $context = "$FileName control[$Index]"
  $type = [string]$Control['type']
  if ([string]::IsNullOrWhiteSpace($type)) {
    Add-ValidationError "$context is missing a type."
    return
  }

  if ($allowedTypes -notcontains $type) {
    Add-ValidationError "$context uses unsupported control type '$type'."
    return
  }

  switch ($type) {
    'dpad' {
      $props = $Control['props']
      if ($props -isnot [System.Collections.IDictionary]) {
        Add-ValidationError "$context requires props for dpad bindings."
        return
      }

      foreach ($direction in 'up', 'down', 'left', 'right', 'center') {
        Test-DpadBinding -Binding $props[$direction] -Context "$context.$direction"
      }
      return
    }
    'grid_buttons' {
      $props = $Control['props']
      if ($props -isnot [System.Collections.IDictionary]) {
        Add-ValidationError "$context requires props for grid button bindings."
        return
      }

      $buttons = $props['buttons']
      if ($buttons -isnot [System.Collections.IEnumerable]) {
        Add-ValidationError "$context requires a props.buttons array."
        return
      }

      $buttonIndex = 0
      foreach ($button in $buttons) {
        $buttonContext = "$context button[$buttonIndex]"
        if ($button -isnot [System.Collections.IDictionary]) {
          Add-ValidationError "$buttonContext must be an object."
          $buttonIndex++
          continue
        }

        $commandName = [string]$button['command']
        Test-CommandName -CommandName $commandName -Context $buttonContext
        if ($commandName -eq 'macro_run') {
          $buttonProps = if ($button.Contains('props')) { $button['props'] } else { $null }
          $steps = if ($buttonProps -is [System.Collections.IDictionary] -and $buttonProps.Contains('steps')) { $buttonProps['steps'] } else { $null }
          Test-MacroSteps -Steps $steps -Context $buttonContext
        }
        $buttonIndex++
      }
      return
    }
    default {
      $commandName = [string]$Control['command']
      Test-CommandName -CommandName $commandName -Context $context
      if ($commandName -eq 'macro_run') {
        $controlProps = if ($Control.Contains('props')) { $Control['props'] } else { $null }
        $steps = if ($controlProps -is [System.Collections.IDictionary] -and $controlProps.Contains('steps')) { $controlProps['steps'] } else { $null }
        Test-MacroSteps -Steps $steps -Context $context
      }
    }
  }
}

$repoFiles = @(Get-ChildItem $remoteDir -Filter *.json | Sort-Object Name)
$assetFiles = @(Get-ChildItem $assetDir -Filter *.json | Sort-Object Name)

$repoNames = $repoFiles.Name
$assetNames = $assetFiles.Name

foreach ($missing in ($repoNames | Where-Object { $assetNames -notcontains $_ })) {
  Add-ValidationError "android/assets/remotes is missing '$missing'."
}

foreach ($missing in ($assetNames | Where-Object { $repoNames -notcontains $_ })) {
  Add-ValidationError "remotes is missing '$missing'."
}

foreach ($repoFile in $repoFiles) {
  $assetPath = Join-Path $assetDir $repoFile.Name
  $repoJson = ConvertTo-HashtableRecursive (Get-Content $repoFile.FullName -Raw | ConvertFrom-Json)
  $assetJson = if (Test-Path $assetPath) {
    ConvertTo-HashtableRecursive (Get-Content $assetPath -Raw | ConvertFrom-Json)
  } else {
    $null
  }

  if ($null -eq $repoJson['layout']) {
    Add-ValidationError "$($repoFile.Name) is missing a layout array."
    continue
  }

  if ($null -ne $assetJson) {
    $repoNormalized = $repoJson | ConvertTo-Json -Depth 32 -Compress
    $assetNormalized = $assetJson | ConvertTo-Json -Depth 32 -Compress
    if ($repoNormalized -ne $assetNormalized) {
      Add-ValidationError "$($repoFile.Name) differs between remotes and android/assets/remotes."
    }
  }

  $index = 0
  foreach ($control in $repoJson['layout']) {
    if ($control -isnot [System.Collections.IDictionary]) {
      Add-ValidationError "$($repoFile.Name) control[$index] must be an object."
      $index++
      continue
    }

    Test-Control -Control $control -FileName $repoFile.Name -Index $index
    $index++
  }
}

if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Host "Remote catalog validation passed for $($repoFiles.Count) mirrored remotes."
