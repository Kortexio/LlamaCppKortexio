LlamaCppKortexio
================

Installed components
- bin\llama-server.exe  (CUDA build with embedded WebUI)
- LlamaCpp.Tray.exe     (system tray)
- scripts\run-server.bat
- config\llama.env + models-preset.ini

Service: LlamaCppKortex (NSSM)
WebUI:   http://127.0.0.1:11434/

Edit ModelsDir / models-preset.ini, then:
  nssm restart LlamaCppKortex

Source: https://github.com/Kortexio/LlamaCppKortexio
