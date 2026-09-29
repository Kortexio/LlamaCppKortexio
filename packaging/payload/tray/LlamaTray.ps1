#Requires -Version 5.1
# Llama.cpp Kortex — system tray monitor
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:HealthUrl = 'http://127.0.0.1:11434/health'
$script:WebUiUrl  = 'http://127.0.0.1:11434/'
$script:SvcLlama  = 'LlamaCppKortex'
$script:SvcTunnel = 'KortexioOllamaTunnel'
$script:InstallRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:LogDir    = Join-Path $script:InstallRoot 'logs'
$script:LastStatus = 'unknown'

# Single-instance mutex (avoid two tray icons)
$script:TrayMutex = New-Object System.Threading.Mutex($false, 'Global\LlamaCppKortexTray')
if (-not $script:TrayMutex.WaitOne(0, $false)) {
  [System.Windows.Forms.MessageBox]::Show('Kortex tray ja esta a correr.', 'Llama.cpp Kortex') | Out-Null
  exit 0
}

function Start-HiddenPowerShellFile([string]$file) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $psi.Arguments = "-NoProfile -NoLogo -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$file`""
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
  [void][System.Diagnostics.Process]::Start($psi)
}

function Show-Settings {
  $settings = Join-Path $PSScriptRoot 'KortexSettings.ps1'
  if (-not (Test-Path $settings)) {
    [System.Windows.Forms.MessageBox]::Show("KortexSettings.ps1 nao encontrado.`r`n$settings") | Out-Null
    return
  }
  # Separate process, no console window (CreateNoWindow)
  Start-HiddenPowerShellFile $settings
}

function New-StatusIcon([string]$colorName) {
  $bmp = New-Object System.Drawing.Bitmap 16,16
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.Clear([System.Drawing.Color]::Transparent)
  $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromName($colorName))
  $g.FillEllipse($brush, 1, 1, 13, 13)
  $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(220,0,0,0), 1)
  $g.DrawEllipse($pen, 1, 1, 13, 13)
  $g.Dispose(); $brush.Dispose(); $pen.Dispose()
  $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
  # clone to avoid handle lifetime issues
  $ms = New-Object System.IO.MemoryStream
  $icon.Save($ms)
  $ms.Position = 0
  $clone = New-Object System.Drawing.Icon $ms
  $ms.Dispose(); $icon.Dispose(); $bmp.Dispose()
  return $clone
}

function Get-LlamaHealth {
  try {
    $r = Invoke-RestMethod -Uri $script:HealthUrl -TimeoutSec 2
    if ($r.status -eq 'ok' -or $r -match 'ok') { return 'ok' }
    return 'degraded'
  } catch {
    return 'down'
  }
}

function Get-SvcStatus([string]$name) {
  try { (Get-Service -Name $name -EA Stop).Status.ToString() } catch { 'Missing' }
}

function Update-TrayStatus {
  $health = Get-LlamaHealth
  $llama  = Get-SvcStatus $script:SvcLlama
  $tunnel = Get-SvcStatus $script:SvcTunnel
  $script:LastStatus = $health

  switch ($health) {
    'ok' {
      $notify.Icon = $script:IconGreen
      $notify.Text = "Llama.cpp: OK`nServico: $llama`nTunel: $tunnel"
      $lblStatus.Text = "Estado: a correr (OK)"
      $lblStatus.ForeColor = [System.Drawing.Color]::ForestGreen
    }
    'degraded' {
      $notify.Icon = $script:IconYellow
      $notify.Text = "Llama.cpp: degradado`nServico: $llama`nTunel: $tunnel"
      $lblStatus.Text = "Estado: degradado"
      $lblStatus.ForeColor = [System.Drawing.Color]::DarkOrange
    }
    default {
      $notify.Icon = $script:IconRed
      $notify.Text = "Llama.cpp: PARADO`nServico: $llama`nTunel: $tunnel"
      $lblStatus.Text = "Estado: parado / sem resposta"
      $lblStatus.ForeColor = [System.Drawing.Color]::Firebrick
    }
  }
  $lblSvc.Text = "LlamaCppKortex: $llama | Tunel: $tunnel"
}

function Start-ElevatedNssm([string]$action) {
  # action: start|stop|restart  for LlamaCppKortex (+ restart tunnel optional)
  $tmp = Join-Path $env:TEMP ("llama-tray-" + [guid]::NewGuid().ToString('N') + ".ps1")
  @"
`$nssm = (Get-Command nssm.exe).Source
& `$nssm $action $($script:SvcLlama)
if ('$action' -eq 'restart' -or '$action' -eq 'start') {
  try { & `$nssm restart $($script:SvcTunnel) } catch {}
}
"@ | Set-Content -Path $tmp -Encoding ASCII
  # Hidden elevated via VBS (avoids Admin PowerShell flash)
  $vbs = Join-Path $env:TEMP ('llama-tray-' + [guid]::NewGuid().ToString('N') + '.vbs')
  $arg = "-NoProfile -NoLogo -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$tmp`""
  $vbsBody = "CreateObject(""Shell.Application"").ShellExecute ""powershell.exe"", ""$arg"", """", ""runas"", 0"
  [IO.File]::WriteAllText($vbs, $vbsBody)
  Start-Process wscript.exe -ArgumentList "//nologo","`"$vbs`"" -Wait
  Start-Sleep 2
  Remove-Item $tmp, $vbs -Force -EA SilentlyContinue
  Update-TrayStatus
}

# --- UI ---
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Llama.cpp Kortex'
$form.Size = New-Object System.Drawing.Size 360,210
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ShowInTaskbar = $false
$form.WindowState = 'Minimized'
$form.Hide()

$script:IconGreen  = New-StatusIcon 'LimeGreen'
$script:IconYellow = New-StatusIcon 'Gold'
$script:IconRed    = New-StatusIcon 'Red'

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = $script:IconRed
$notify.Visible = $true
$notify.Text = 'Llama.cpp Kortex'

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miOpen   = $menu.Items.Add('Abrir WebUI')
$miStatus = $menu.Items.Add('Mostrar estado')
$miSettings = $menu.Items.Add('Definicoes do servidor...')
$menu.Items.Add('-') | Out-Null
$miStart  = $menu.Items.Add('Iniciar servico')
$miStop   = $menu.Items.Add('Parar servico')
$miRest   = $menu.Items.Add('Reiniciar servico')
$menu.Items.Add('-') | Out-Null
$miLogs   = $menu.Items.Add('Abrir pasta de logs')
$miExit   = $menu.Items.Add('Sair do tray')
$notify.ContextMenuStrip = $menu

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.AutoSize = $false
$lblStatus.Location = New-Object System.Drawing.Point 16,16
$lblStatus.Size = New-Object System.Drawing.Size 320,28
$lblStatus.Font = New-Object System.Drawing.Font 'Segoe UI',11,[System.Drawing.FontStyle]::Bold

$lblSvc = New-Object System.Windows.Forms.Label
$lblSvc.AutoSize = $false
$lblSvc.Location = New-Object System.Drawing.Point 16,52
$lblSvc.Size = New-Object System.Drawing.Size 320,40
$lblSvc.Font = New-Object System.Drawing.Font 'Segoe UI',9

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.AutoSize = $false
$lblHint.Location = New-Object System.Drawing.Point 16,100
$lblHint.Size = New-Object System.Drawing.Size 320,50
$lblHint.Text = "Arranque automatico: servico Windows (Delayed Auto Start).`r`nEste tray tambem inicia com o Windows."
$lblHint.Font = New-Object System.Drawing.Font 'Segoe UI',8.5

$form.Controls.AddRange(@($lblStatus,$lblSvc,$lblHint))

$miOpen.add_Click({ Start-Process $script:WebUiUrl })
$miStatus.add_Click({
  Update-TrayStatus
  $form.Show()
  $form.WindowState = 'Normal'
  $form.ShowInTaskbar = $true
  $form.Activate()
})
$miSettings.add_Click({ Show-Settings })
$miStart.add_Click({ Start-ElevatedNssm 'start' })
$miStop.add_Click({ Start-ElevatedNssm 'stop' })
$miRest.add_Click({ Start-ElevatedNssm 'restart' })
$miLogs.add_Click({
  New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
  Start-Process explorer.exe $script:LogDir
})
$miExit.add_Click({
  $timer.Stop()
  $notify.Visible = $false
  $notify.Dispose()
  try { $script:TrayMutex.ReleaseMutex() } catch {}
  try { $script:TrayMutex.Dispose() } catch {}
  [System.Windows.Forms.Application]::Exit()
})
$notify.add_DoubleClick({ Start-Process $script:WebUiUrl })

$form.add_FormClosing({
  param($s,$e)
  if ($e.CloseReason -eq 'UserClosing') {
    $e.Cancel = $true
    $form.Hide()
    $form.ShowInTaskbar = $false
  }
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.add_Tick({ Update-TrayStatus })
$timer.Start()
Update-TrayStatus

# Balloon on first down->ok or ok->down
$script:Prev = $script:LastStatus
$timer2 = New-Object System.Windows.Forms.Timer
$timer2.Interval = 5000
$timer2.add_Tick({
  if ($script:LastStatus -ne $script:Prev) {
    if ($script:LastStatus -eq 'ok') {
      $notify.ShowBalloonTip(3000, 'Llama.cpp', 'Servidor a responder (OK).', [System.Windows.Forms.ToolTipIcon]::Info)
    } elseif ($script:LastStatus -eq 'down') {
      $notify.ShowBalloonTip(4000, 'Llama.cpp', 'Servidor parado ou sem resposta. Clique direito > Iniciar servico.', [System.Windows.Forms.ToolTipIcon]::Error)
    }
    $script:Prev = $script:LastStatus
  }
})
$timer2.Start()

[System.Windows.Forms.Application]::Run()