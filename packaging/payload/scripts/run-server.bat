@echo off
setlocal
set ROOT=%~dp0..
set PATH=%ROOT%\bin;%PATH%
cd /d "%ROOT%\bin"
"%ROOT%\bin\llama-server.exe" --models-preset "%ROOT%\config\models-preset.ini" --host 127.0.0.1 --port 11434 -ngl 99 -c 65536 --parallel 1 --models-max 1 -fa on --threads 1 -ctk q4_0 -ctv q4_0 --jinja --reasoning auto --reasoning-effort medium --reasoning-budget -1 --reasoning-preserve --agent --tools all --webui
