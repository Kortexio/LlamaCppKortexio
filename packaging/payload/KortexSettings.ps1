#Requires -Version 5.1
# Kortex Settings - polished WinForms UI (ASCII-safe, no scroll)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:Bg       = [System.Drawing.Color]::FromArgb(24, 24, 28)
$script:BgPanel  = [System.Drawing.Color]::FromArgb(32, 32, 38)
$script:BgInput  = [System.Drawing.Color]::FromArgb(40, 40, 48)
$script:Fg       = [System.Drawing.Color]::FromArgb(236, 236, 240)
$script:FgMuted  = [System.Drawing.Color]::FromArgb(150, 150, 160)
$script:Accent   = [System.Drawing.Color]::FromArgb(46, 160, 140)
$script:AccentDk = [System.Drawing.Color]::FromArgb(36, 128, 112)
$script:FontUi   = New-Object System.Drawing.Font 'Segoe UI', 9
$script:FontTitle = New-Object System.Drawing.Font 'Segoe UI Semibold', 13
$script:FontSec  = New-Object System.Drawing.Font 'Segoe UI Semibold', 9

function Get-KortexInstallRoot {
  if ($PSScriptRoot) {
    $cand = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    if (Test-Path (Join-Path $cand 'scripts\run-server.bat')) { return $cand }
    if (Test-Path (Join-Path $PSScriptRoot 'scripts\run-server.bat')) { return $PSScriptRoot }
  }
  foreach ($p in @('C:\LlamaCppKortex', 'C:\LlamaCppKortexio', "${env:ProgramFiles}\LlamaCppKortexio")) {
    if (Test-Path (Join-Path $p 'scripts\run-server.bat')) { return $p }
  }
  return 'C:\LlamaCppKortex'
}

function Read-LlamaEnv([string]$path) {
  $cfg = @{}
  if (-not (Test-Path $path)) { return $cfg }
  Get-Content $path | Where-Object { $_ -match '=' -and $_ -notmatch '^\s*#' } | ForEach-Object {
    $k, $v = $_ -split '=', 2
    $cfg[$k.Trim()] = $v.Trim()
  }
  return $cfg
}

function Write-LlamaEnv([string]$path, $cfg) {
  $keys = @(
    'ModelsDir','Host','Port','DefaultModel','GpuLayers','CtxSize','Parallel','FlashAttn',
    'ModelsMax','Threads','CacheTypeK','CacheTypeV','Agent','Tools','Reasoning','ReasoningEffort',
    'ReasoningBudget','ReasoningPreserve','WebUI','MediaPath'
  )
  $lines = New-Object System.Collections.Generic.List[string]
  [void]$lines.Add('# LlamaCppKortexio / Kortex stack')
  foreach ($k in $keys) { [void]$lines.Add("$k=$($cfg[$k])") }
  New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
  [IO.File]::WriteAllLines($path, $lines.ToArray(), [Text.Encoding]::ASCII)
}

function Write-RunServerBat([string]$batPath, $cfg) {
  $root = Split-Path (Split-Path $batPath -Parent) -Parent
  $preset = Join-Path $root 'config\models-preset.ini'
  $hostA = $cfg['Host']; if (-not $hostA) { $hostA = '127.0.0.1' }
  $port = $cfg['Port']; if (-not $port) { $port = '11434' }
  $ngl = $cfg['GpuLayers']; if (-not $ngl) { $ngl = '99' }
  $ctx = $cfg['CtxSize']; if (-not $ctx) { $ctx = '65536' }
  $par = $cfg['Parallel']; if (-not $par) { $par = '1' }
  $mmax = $cfg['ModelsMax']; if (-not $mmax) { $mmax = '1' }
  $fa = $cfg['FlashAttn']; if (-not $fa) { $fa = 'on' }
  $th = $cfg['Threads']; if (-not $th) { $th = '1' }
  $ctk = $cfg['CacheTypeK']; if (-not $ctk) { $ctk = 'q4_0' }
  $ctv = $cfg['CacheTypeV']; if (-not $ctv) { $ctv = 'q4_0' }
  $rea = $cfg['Reasoning']; if (-not $rea) { $rea = 'auto' }
  $eff = $cfg['ReasoningEffort']; if (-not $eff) { $eff = 'medium' }
  $bud = $cfg['ReasoningBudget']; if (-not $bud) { $bud = '-1' }
  $tools = $cfg['Tools']; if (-not $tools) { $tools = 'all' }

  $a = New-Object System.Collections.Generic.List[string]
  [void]$a.Add("--models-preset `"$preset`"")
  [void]$a.Add("--host $hostA"); [void]$a.Add("--port $port")
  [void]$a.Add("-ngl $ngl"); [void]$a.Add("-c $ctx")
  [void]$a.Add("--parallel $par"); [void]$a.Add("--models-max $mmax")
  [void]$a.Add("-fa $fa"); [void]$a.Add("--threads $th")
  [void]$a.Add("-ctk $ctk"); [void]$a.Add("-ctv $ctv")
  [void]$a.Add('--jinja')
  [void]$a.Add("--reasoning $rea")
  [void]$a.Add("--reasoning-effort $eff")
  [void]$a.Add("--reasoning-budget $bud")
  if ($cfg['ReasoningPreserve'] -match '^(1|true|on|yes)$') { [void]$a.Add('--reasoning-preserve') }
  if ($cfg['Agent'] -match '^(1|true|on|yes)$') { [void]$a.Add('--agent') }
  if ($tools) { [void]$a.Add("--tools $tools") }
  if ($cfg['MediaPath']) { [void]$a.Add("--media-path `"$($cfg['MediaPath'])`"") }
  if ($cfg['WebUI'] -notmatch '^(0|false|off|no)$') { [void]$a.Add('--webui') }

  $joined = [string]::Join(' ', $a.ToArray())
  $bat = "@echo off`r`nsetlocal`r`nset ROOT=%~dp0..`r`nset PATH=%ROOT%\bin;%PATH%`r`ncd /d `"%ROOT%\bin`"`r`n`"%ROOT%\bin\llama-server.exe`" $joined`r`n"
  New-Item -ItemType Directory -Path (Split-Path $batPath) -Force | Out-Null
  [IO.File]::WriteAllText($batPath, $bat, [Text.Encoding]::ASCII)
}

function New-FlatButton([string]$text, [Drawing.Color]$bg, [Drawing.Color]$fg, [bool]$primary=$false) {
  $b = New-Object System.Windows.Forms.Button
  $b.Text = $text
  $b.FlatStyle = 'Flat'
  $b.FlatAppearance.BorderSize = 0
  $b.BackColor = $bg
  $b.ForeColor = $fg
  $b.Cursor = [System.Windows.Forms.Cursors]::Hand
  $b.Font = if ($primary) { New-Object System.Drawing.Font 'Segoe UI Semibold', 9 } else { $script:FontUi }
  $b.Height = 32
  return $b
}

function New-Section([string]$title, [int]$x, [int]$y, [int]$w, [int]$h) {
  $p = New-Object System.Windows.Forms.Panel
  $p.Location = New-Object System.Drawing.Point $x, $y
  $p.Size = New-Object System.Drawing.Size $w, $h
  $p.BackColor = $script:BgPanel
  $hdr = New-Object System.Windows.Forms.Label
  $hdr.Text = $title
  $hdr.Font = $script:FontSec
  $hdr.ForeColor = $script:Accent
  $hdr.Location = New-Object System.Drawing.Point 14, 10
  $hdr.AutoSize = $true
  $p.Controls.Add($hdr)
  return $p
}

function Add-Field([System.Windows.Forms.Control]$parent, [string]$label, [string]$key, [int]$x, [int]$y, [int]$w, [string[]]$combo=$null) {
  $lbl = New-Object System.Windows.Forms.Label
  $lbl.Text = $label
  $lbl.ForeColor = $script:FgMuted
  $lbl.Font = $script:FontUi
  $lbl.Location = New-Object System.Drawing.Point $x, $y
  $lbl.Size = New-Object System.Drawing.Size $w, 16
  $parent.Controls.Add($lbl)

  if ($combo) {
    $c = New-Object System.Windows.Forms.ComboBox
    $c.DropDownStyle = 'DropDownList'
    $c.FlatStyle = 'Flat'
    foreach ($it in $combo) { [void]$c.Items.Add($it) }
    $val = [string]$script:cfg[$key]
    if ($combo -contains $val) { $c.SelectedItem = $val } else { $c.SelectedIndex = 0 }
  } else {
    $c = New-Object System.Windows.Forms.TextBox
    $c.BorderStyle = 'FixedSingle'
    $c.Text = [string]$script:cfg[$key]
  }
  $c.BackColor = $script:BgInput
  $c.ForeColor = $script:Fg
  $c.Font = $script:FontUi
  $c.Location = New-Object System.Drawing.Point $x, ($y + 18)
  $c.Size = New-Object System.Drawing.Size $w, 26
  $c.Tag = $key
  $parent.Controls.Add($c)
  [void]$script:fields.Add($c)
  return $c
}

$root = Get-KortexInstallRoot
$envPath = Join-Path $root 'config\llama.env'
$batPath = Join-Path $root 'scripts\run-server.bat'
$script:cfg = Read-LlamaEnv $envPath
$script:defaults = @{
  ModelsDir='D:\Models\gguf'; Host='127.0.0.1'; Port='11434'; DefaultModel='bonsai-2-27b.gguf'
  GpuLayers='99'; CtxSize='65536'; Parallel='1'; FlashAttn='on'; ModelsMax='1'; Threads='1'
  CacheTypeK='q4_0'; CacheTypeV='q4_0'; Agent='on'; Tools='all'; Reasoning='auto'
  ReasoningEffort='medium'; ReasoningBudget='-1'; ReasoningPreserve='on'; WebUI='on'; MediaPath='D:\'
}
foreach ($k in $script:defaults.Keys) {
  if (-not $script:cfg.ContainsKey($k) -or [string]::IsNullOrWhiteSpace([string]$script:cfg[$k])) {
    $script:cfg[$k] = $script:defaults[$k]
  }
}

$script:fields = New-Object System.Collections.ArrayList

# Fixed geometry - everything visible, no scroll
$cw = 640
$ch = 720
$pad = 16
$secW = $cw - (2 * $pad)
$gap = 12
$col = [int](($secW - 28 - $gap) / 2)
$xL = 14
$xR = $xL + $col + $gap

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Kortexio - Server Settings'
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
$form.AutoScroll = $false
$form.ClientSize = New-Object System.Drawing.Size $cw, $ch
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.BackColor = $script:Bg
$form.Font = $script:FontUi
$form.ShowInTaskbar = $true
try {
  $ico = Join-Path $root 'llamacpp.ico'
  if (Test-Path $ico) { $form.Icon = New-Object System.Drawing.Icon $ico }
} catch {}

# Header
$hdr = New-Object System.Windows.Forms.Panel
$hdr.Location = New-Object System.Drawing.Point 0, 0
$hdr.Size = New-Object System.Drawing.Size $cw, 56
$hdr.BackColor = $script:BgPanel
$t = New-Object System.Windows.Forms.Label
$t.Text = 'Server Settings'
$t.Font = $script:FontTitle
$t.ForeColor = $script:Fg
$t.Location = New-Object System.Drawing.Point 18, 8
$t.AutoSize = $true
$s = New-Object System.Windows.Forms.Label
$s.Text = $root
$s.ForeColor = $script:FgMuted
$s.Location = New-Object System.Drawing.Point 20, 32
$s.AutoSize = $true
$hdr.Controls.Add($t)
$hdr.Controls.Add($s)
$form.Controls.Add($hdr)

# PATHS
$pPaths = New-Section 'PATHS' $pad 68 $secW 148
Add-Field $pPaths 'Models folder' 'ModelsDir' $xL 32 ($secW - 28) | Out-Null
Add-Field $pPaths 'Default model' 'DefaultModel' $xL 80 $col | Out-Null
Add-Field $pPaths 'Media path' 'MediaPath' $xR 80 $col | Out-Null
$form.Controls.Add($pPaths)

# GPU / CONTEXT
$pGpu = New-Section 'GPU  /  CONTEXT' $pad 228 $secW 236
Add-Field $pGpu 'Context size' 'CtxSize' $xL 32 $col | Out-Null
Add-Field $pGpu 'GPU layers' 'GpuLayers' $xR 32 $col | Out-Null
Add-Field $pGpu 'Threads' 'Threads' $xL 80 $col | Out-Null
Add-Field $pGpu 'Parallel slots' 'Parallel' $xR 80 $col | Out-Null
Add-Field $pGpu 'KV cache K' 'CacheTypeK' $xL 128 $col @('q4_0','q8_0','f16') | Out-Null
Add-Field $pGpu 'KV cache V' 'CacheTypeV' $xR 128 $col @('q4_0','q8_0','f16') | Out-Null
Add-Field $pGpu 'Flash Attn' 'FlashAttn' $xL 176 $col @('on','off','auto') | Out-Null
$form.Controls.Add($pGpu)

# REASONING / AGENT
$pReason = New-Section 'REASONING  /  AGENT' $pad 476 $secW 120
Add-Field $pReason 'Reasoning' 'Reasoning' $xL 32 $col @('auto','on','off') | Out-Null
Add-Field $pReason 'Effort (Bonsai)' 'ReasoningEffort' $xR 32 $col @('xhigh','medium','low') | Out-Null
Add-Field $pReason 'Reasoning budget' 'ReasoningBudget' $xL 80 $col | Out-Null
Add-Field $pReason 'Agent mode' 'Agent' $xR 80 $col @('on','off') | Out-Null
$form.Controls.Add($pReason)

$note = New-Object System.Windows.Forms.Label
$note.Text = 'Changing these options restarts the LlamaCppKortex service. Sampling (temp, top_p) stays in the WebUI / API.'
$note.ForeColor = $script:FgMuted
$note.Location = New-Object System.Drawing.Point $pad, 608
$note.Size = New-Object System.Drawing.Size $secW, 32
$form.Controls.Add($note)

$btnCancel = New-FlatButton 'Cancel' $script:BgInput $script:Fg
$btnCancel.Location = New-Object System.Drawing.Point ($cw - 360), 652
$btnCancel.Width = 100
$btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

$btnSave = New-FlatButton 'Save' $script:BgInput $script:Fg
$btnSave.Location = New-Object System.Drawing.Point ($cw - 250), 652
$btnSave.Width = 100

$btnApply = New-FlatButton 'Save and Restart' $script:Accent ([System.Drawing.Color]::White) $true
$btnApply.Location = New-Object System.Drawing.Point ($cw - 140), 652
$btnApply.Width = 124
$btnApply.FlatAppearance.MouseOverBackColor = $script:AccentDk

$form.Controls.Add($btnCancel)
$form.Controls.Add($btnSave)
$form.Controls.Add($btnApply)
$form.CancelButton = $btnCancel

function Collect-Config {
  $out = @{}
  foreach ($k in $script:cfg.Keys) { $out[$k] = $script:cfg[$k] }
  foreach ($c in $script:fields) {
    $key = [string]$c.Tag
    if ($c -is [System.Windows.Forms.ComboBox]) { $out[$key] = [string]$c.SelectedItem }
    else { $out[$key] = $c.Text.Trim() }
  }
  foreach ($k in @('ReasoningPreserve','WebUI','Tools','Host','Port','ModelsMax')) {
    if (-not $out[$k]) { $out[$k] = $script:defaults[$k] }
  }
  return $out
}

$btnSave.Add_Click({
  try {
    $newCfg = Collect-Config
    Write-LlamaEnv $envPath $newCfg
    Write-RunServerBat $batPath $newCfg
    $script:cfg = $newCfg
    [System.Windows.Forms.MessageBox]::Show('Settings saved. Restart the service to apply.', 'Kortexio', 'OK', 'Information') | Out-Null
  } catch {
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Kortexio', 'OK', 'Error') | Out-Null
  }
})

$btnApply.Add_Click({
  try {
    $newCfg = Collect-Config
    Write-LlamaEnv $envPath $newCfg
    Write-RunServerBat $batPath $newCfg
    $tmp = Join-Path $env:TEMP ('kortex-restart-' + [guid]::NewGuid().ToString('N') + '.ps1')
    $ps = @(
      '$ErrorActionPreference = "Stop"'
      '$nssm = (Get-Command nssm.exe -EA SilentlyContinue).Source'
      'if (-not $nssm) { $nssm = "$env:LOCALAPPDATA\Microsoft\WinGet\Links\nssm.exe" }'
      '& $nssm restart LlamaCppKortex'
    ) -join "`r`n"
    [IO.File]::WriteAllText($tmp, $ps)
    $vbs = Join-Path $env:TEMP ('kortex-restart-' + [guid]::NewGuid().ToString('N') + '.vbs')
    $vbsBody = "CreateObject(`"Shell.Application`").ShellExecute `"powershell.exe`", `"-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"`"$tmp`"`"`", `"`", `"runas`", 0"
    [IO.File]::WriteAllText($vbs, $vbsBody)
    Start-Process wscript.exe -ArgumentList $vbs -Wait
    Start-Sleep 2
    Remove-Item $tmp, $vbs -Force -EA SilentlyContinue
    [System.Windows.Forms.MessageBox]::Show('Saved and service restart requested.', 'Kortexio', 'OK', 'Information') | Out-Null
    $form.Close()
  } catch {
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Kortexio', 'OK', 'Error') | Out-Null
  }
})

[void]$form.ShowDialog()
