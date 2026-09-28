#Requires -Version 5.1
# Kortex Settings form — edits config\llama.env + regenerates scripts\run-server.bat
$ErrorActionPreference = 'Stop'

function Get-KortexInstallRoot {
  if ($PSScriptRoot) {
    $cand = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    if (Test-Path (Join-Path $cand 'scripts\run-server.bat')) { return $cand }
  }
  foreach ($p in @('C:\LlamaCppKortexio', 'C:\LlamaCppKortex', "${env:ProgramFiles}\LlamaCppKortexio")) {
    if (Test-Path (Join-Path $p 'scripts\run-server.bat')) { return $p }
  }
  return 'C:\LlamaCppKortex'
}

function Read-LlamaEnv([string]$path) {
  $cfg = [ordered]@{}
  if (-not (Test-Path $path)) { return $cfg }
  Get-Content $path | Where-Object { $_ -match '=' -and $_ -notmatch '^\s*#' } | ForEach-Object {
    $k, $v = $_ -split '=', 2
    $cfg[$k.Trim()] = $v.Trim()
  }
  return $cfg
}

function Write-LlamaEnv([string]$path, [hashtable]$cfg) {
  $lines = @(
    '# LlamaCppKortexio / Kortex stack',
    "ModelsDir=$($cfg.ModelsDir)",
    "Host=$($cfg.Host)",
    "Port=$($cfg.Port)",
    "DefaultModel=$($cfg.DefaultModel)",
    "GpuLayers=$($cfg.GpuLayers)",
    "CtxSize=$($cfg.CtxSize)",
    "Parallel=$($cfg.Parallel)",
    "FlashAttn=$($cfg.FlashAttn)",
    "ModelsMax=$($cfg.ModelsMax)",
    "Threads=$($cfg.Threads)",
    "CacheTypeK=$($cfg.CacheTypeK)",
    "CacheTypeV=$($cfg.CacheTypeV)",
    "Agent=$($cfg.Agent)",
    "Tools=$($cfg.Tools)",
    "Reasoning=$($cfg.Reasoning)",
    "ReasoningEffort=$($cfg.ReasoningEffort)",
    "ReasoningBudget=$($cfg.ReasoningBudget)",
    "ReasoningPreserve=$($cfg.ReasoningPreserve)",
    "WebUI=$($cfg.WebUI)",
    "MediaPath=$($cfg.MediaPath)"
  )
  $dir = Split-Path $path -Parent
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  Set-Content -Path $path -Value $lines -Encoding ASCII
}

function Write-RunServerBat([string]$batPath, [hashtable]$cfg) {
  $root = Split-Path (Split-Path $batPath -Parent) -Parent
  $preset = Join-Path $root 'config\models-preset.ini'
  $hostA = if ($cfg.Host) { $cfg.Host } else { '127.0.0.1' }
  $port = if ($cfg.Port) { $cfg.Port } else { '11434' }
  $ngl = if ($cfg.GpuLayers) { $cfg.GpuLayers } else { '99' }
  $ctx = if ($cfg.CtxSize) { $cfg.CtxSize } else { '65536' }
  $par = if ($cfg.Parallel) { $cfg.Parallel } else { '1' }
  $mmax = if ($cfg.ModelsMax) { $cfg.ModelsMax } else { '1' }
  $fa = if ($cfg.FlashAttn) { $cfg.FlashAttn } else { 'on' }
  $th = if ($cfg.Threads) { $cfg.Threads } else { '1' }
  $ctk = if ($cfg.CacheTypeK) { $cfg.CacheTypeK } else { 'q4_0' }
  $ctv = if ($cfg.CacheTypeV) { $cfg.CacheTypeV } else { 'q4_0' }
  $rea = if ($cfg.Reasoning) { $cfg.Reasoning } else { 'auto' }
  $eff = if ($cfg.ReasoningEffort) { $cfg.ReasoningEffort } else { 'medium' }
  $bud = if ($cfg.ReasoningBudget) { $cfg.ReasoningBudget } else { '-1' }
  $tools = if ($cfg.Tools) { $cfg.Tools } else { 'all' }
  $media = $cfg.MediaPath

  $args = @(
    "--models-preset `"$preset`"",
    "--host $hostA",
    "--port $port",
    "-ngl $ngl",
    "-c $ctx",
    "--parallel $par",
    "--models-max $mmax",
    "-fa $fa",
    "--threads $th",
    "-ctk $ctk",
    "-ctv $ctv",
    "--jinja",
    "--reasoning $rea",
    "--reasoning-effort $eff",
    "--reasoning-budget $bud"
  )
  if ($cfg.ReasoningPreserve -match '^(1|true|on|yes)$') { $args += '--reasoning-preserve' }
  if ($cfg.Agent -match '^(1|true|on|yes)$') { $args += '--agent' }
  if ($tools) { $args += "--tools $tools" }
  if ($media) { $args += "--media-path `"$media`"" }
  if ($cfg.WebUI -notmatch '^(0|false|off|no)$') { $args += '--webui' }

  $bat = @"
@echo off
setlocal
set ROOT=%~dp0..
set PATH=%ROOT%\bin;%PATH%
cd /d "%ROOT%\bin"
"%ROOT%\bin\llama-server.exe" $($args -join ' ')
"@
  New-Item -ItemType Directory -Path (Split-Path $batPath) -Force | Out-Null
  Set-Content -Path $batPath -Value $bat.TrimEnd() -Encoding ASCII
}

function Show-KortexSettingsForm {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $root = Get-KortexInstallRoot
  $envPath = Join-Path $root 'config\llama.env'
  $batPath = Join-Path $root 'scripts\run-server.bat'
  $cfg = Read-LlamaEnv $envPath

  # defaults
  $d = @{
    ModelsDir = 'D:\Models\gguf'; Host = '127.0.0.1'; Port = '11434'
    DefaultModel = 'bonsai-2-27b.gguf'; GpuLayers = '99'; CtxSize = '65536'
    Parallel = '1'; FlashAttn = 'on'; ModelsMax = '1'; Threads = '1'
    CacheTypeK = 'q4_0'; CacheTypeV = 'q4_0'; Agent = 'on'; Tools = 'all'
    Reasoning = 'auto'; ReasoningEffort = 'medium'; ReasoningBudget = '-1'
    ReasoningPreserve = 'on'; WebUI = 'on'; MediaPath = 'D:\'
  }
  foreach ($k in $d.Keys) { if (-not $cfg[$k]) { $cfg[$k] = $d[$k] } }

  $form = New-Object System.Windows.Forms.Form
  $form.Text = "Kortex Settings — $root"
  $form.Size = New-Object System.Drawing.Size 520, 520
  $form.StartPosition = 'CenterScreen'
  $form.FormBorderStyle = 'FixedDialog'
  $form.MaximizeBox = $false
  $form.Font = New-Object System.Drawing.Font 'Segoe UI', 9

  $y = 16
  function Add-LabeledText([string]$label, [string]$key, [int]$width = 320) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $label
    $lbl.Location = New-Object System.Drawing.Point 16, $script:y
    $lbl.Size = New-Object System.Drawing.Size 140, 22
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Text = [string]$cfg[$key]
    $tb.Location = New-Object System.Drawing.Point 160, ($script:y - 2)
    $tb.Size = New-Object System.Drawing.Size $width, 24
    $tb.Tag = $key
    $form.Controls.AddRange(@($lbl, $tb))
    $script:fields += $tb
    $script:y += 32
    return $tb
  }
  function Add-LabeledCombo([string]$label, [string]$key, [string[]]$items) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $label
    $lbl.Location = New-Object System.Drawing.Point 16, $script:y
    $lbl.Size = New-Object System.Drawing.Size 140, 22
    $cb = New-Object System.Windows.Forms.ComboBox
    $cb.DropDownStyle = 'DropDownList'
    $cb.Items.AddRange($items)
    $val = [string]$cfg[$key]
    if ($items -contains $val) { $cb.SelectedItem = $val } else { $cb.SelectedIndex = 0 }
    $cb.Location = New-Object System.Drawing.Point 160, ($script:y - 2)
    $cb.Size = New-Object System.Drawing.Size 200, 24
    $cb.Tag = $key
    $form.Controls.AddRange(@($lbl, $cb))
    $script:fields += $cb
    $script:y += 32
    return $cb
  }

  $script:y = $y
  $script:fields = @()

  Add-LabeledText 'ModelsDir' 'ModelsDir' | Out-Null
  Add-LabeledText 'Default model' 'DefaultModel' | Out-Null
  Add-LabeledText 'Context (-c)' 'CtxSize' 120 | Out-Null
  Add-LabeledText 'GPU layers' 'GpuLayers' 80 | Out-Null
  Add-LabeledText 'Parallel slots' 'Parallel' 80 | Out-Null
  Add-LabeledText 'Threads' 'Threads' 80 | Out-Null
  Add-LabeledCombo 'KV cache K' 'CacheTypeK' @('q4_0','q8_0','f16') | Out-Null
  Add-LabeledCombo 'KV cache V' 'CacheTypeV' @('q4_0','q8_0','f16') | Out-Null
  Add-LabeledCombo 'Flash Attn' 'FlashAttn' @('on','off','auto') | Out-Null
  Add-LabeledCombo 'Reasoning' 'Reasoning' @('auto','on','off') | Out-Null
  Add-LabeledCombo 'Effort (Bonsai)' 'ReasoningEffort' @('xhigh','medium','low') | Out-Null
  Add-LabeledText 'Reasoning budget' 'ReasoningBudget' 100 | Out-Null
  Add-LabeledCombo 'Agent' 'Agent' @('on','off') | Out-Null
  Add-LabeledText 'MediaPath' 'MediaPath' | Out-Null

  $hint = New-Object System.Windows.Forms.Label
  $hint.Text = "Estas opcoes exigem reiniciar o servico LlamaCppKortex.`r`nSampling (temp, top_p) continua na WebUI / API."
  $hint.Location = New-Object System.Drawing.Point 16, ($script:y + 4)
  $hint.Size = New-Object System.Drawing.Size 470, 36
  $hint.ForeColor = [System.Drawing.Color]::DimGray
  $form.Controls.Add($hint)

  $btnSave = New-Object System.Windows.Forms.Button
  $btnSave.Text = 'Guardar'
  $btnSave.Location = New-Object System.Drawing.Point 160, 440
  $btnSave.Size = New-Object System.Drawing.Size 100, 28

  $btnSaveRestart = New-Object System.Windows.Forms.Button
  $btnSaveRestart.Text = 'Guardar + Reiniciar'
  $btnSaveRestart.Location = New-Object System.Drawing.Point 270, 440
  $btnSaveRestart.Size = New-Object System.Drawing.Size 130, 28

  $btnCancel = New-Object System.Windows.Forms.Button
  $btnCancel.Text = 'Cancelar'
  $btnCancel.Location = New-Object System.Drawing.Point 410, 440
  $btnCancel.Size = New-Object System.Drawing.Size 80, 28
  $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

  function Collect-Config {
    $out = @{} + $cfg
    foreach ($c in $script:fields) {
      $key = [string]$c.Tag
      if ($c -is [System.Windows.Forms.ComboBox]) { $out[$key] = [string]$c.SelectedItem }
      else { $out[$key] = $c.Text.Trim() }
    }
    # keep preserve/webui/tools/host/port/modelsmax from previous if not on form
    if (-not $out.ReasoningPreserve) { $out.ReasoningPreserve = 'on' }
    if (-not $out.WebUI) { $out.WebUI = 'on' }
    if (-not $out.Tools) { $out.Tools = 'all' }
    if (-not $out.Host) { $out.Host = '127.0.0.1' }
    if (-not $out.Port) { $out.Port = '11434' }
    if (-not $out.ModelsMax) { $out.ModelsMax = '1' }
    return $out
  }

  $btnSave.add_Click({
    try {
      $newCfg = Collect-Config
      Write-LlamaEnv $envPath $newCfg
      Write-RunServerBat $batPath $newCfg
      [System.Windows.Forms.MessageBox]::Show("Guardado.`r`n$envPath`r`n$batPath", 'Kortex Settings') | Out-Null
    } catch {
      [System.Windows.Forms.MessageBox]::Show("Erro: $_", 'Kortex Settings') | Out-Null
    }
  })

  $btnSaveRestart.add_Click({
    try {
      $newCfg = Collect-Config
      Write-LlamaEnv $envPath $newCfg
      Write-RunServerBat $batPath $newCfg
      $tmp = Join-Path $env:TEMP ("kortex-settings-restart-" + [guid]::NewGuid().ToString('N') + ".ps1")
      @"
`$nssm = (Get-Command nssm.exe -EA SilentlyContinue).Source
if (-not `$nssm) { `$nssm = "`$env:LOCALAPPDATA\Microsoft\WinGet\Links\nssm.exe" }
& `$nssm restart LlamaCppKortex
"@ | Set-Content $tmp -Encoding UTF8
      Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',$tmp -Wait
      Start-Sleep 1
      Remove-Item $tmp -Force -EA SilentlyContinue
      [System.Windows.Forms.MessageBox]::Show('Guardado e servico reiniciado.', 'Kortex Settings') | Out-Null
      $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
      $form.Close()
    } catch {
      [System.Windows.Forms.MessageBox]::Show("Erro: $_", 'Kortex Settings') | Out-Null
    }
  })

  $form.Controls.AddRange(@($btnSave, $btnSaveRestart, $btnCancel))
  $form.AcceptButton = $btnSaveRestart
  $form.CancelButton = $btnCancel
  [void]$form.ShowDialog()
}

# Allow dot-sourcing or direct run
if ($MyInvocation.InvocationName -ne '.') {
  Show-KortexSettingsForm
}
