# LlamaCppKortexio

**Local LLM stack for Windows:** CUDA `llama-server` (embedded WebUI) + system tray + one-click Inno Setup installer.

Repository: [Kortexio/LlamaCppKortexio](https://github.com/Kortexio/LlamaCppKortexio)  
This is a **standalone** Kortexio product tree (not a GitHub fork of `ggml-org/llama.cpp`).

## What you get

| Piece | Role |
|-------|------|
| **llama-server** | OpenAI-compatible API + **built-in WebUI** (`--webui`) |
| **Tray icon** | Health light, start/stop/restart service shortcuts |
| **Inno installer** | Single setup that drops all three under `Program Files` |

Default endpoint after install: `http://127.0.0.1:11434/`

## Windows installer

Download the latest **`LlamaCppKortexio-Setup-*.exe`** from [Releases](https://github.com/Kortexio/LlamaCppKortexio/releases).

Requirements:

- Windows 10/11 x64  
- NVIDIA GPU + current driver  
- [NSSM](https://nssm.cc/) for the Windows service (`winget install NSSM.NSSM` if prompted)

The installer can:

1. Copy `bin/` (CUDA build with embedded WebUI), config, scripts  
2. Install **LlamaCpp.Tray.exe**  
3. Register service **`LlamaCppKortex`** and open the WebUI  

Build the Setup.exe from source (developers):

```bat
:: from a machine that already has a Release CUDA build + tray binary staged
cd packaging
:: copy your build into packaging\payload\bin and LlamaCpp.Tray.exe into payload\
"%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" LlamaCppKortexio.iss
:: output: packaging\output\LlamaCppKortexio-Setup-1.0.0.exe
```

## Stack notes

The runtime is Kortexio’s CUDA build of the Prism **Bonsai** line (ternary `PTQ1_0` / `PQ2_0`) plus MoE expert-cache patches for offloaded experts. Flash Attention with **in-place q4_0/q8_0 KV** keeps long contexts practical on 12 GB cards.

Suggested server flags (also used by the bundled `run-server.bat`):

```text
-ngl 99 -c 65536 -fa on --threads 1 -ctk q4_0 -ctv q4_0 --webui
```

Point `config/llama.env` → `ModelsDir` and `config/models-preset.ini` at your GGUF folder, then restart the service.

## Performance (measured)

Hardware for the numbers below: **NVIDIA GeForce RTX 3060 12 GB**, Windows, Kortex build `b7bf75c89`, `llama-bench`, Flash Attention on, **KV cache q4_0/q4_0**, threads=1.

### Bonsai 2 27B — PTQ1_0 (recommended on this card)

File: `bonsai-2-27b.gguf` (~5.5 GiB). Empty-context decode and prefill, then the same tests with prompt depth filled:

| Depth | Prefill pp512 (t/s) | Decode tg128 (t/s) |
|------:|--------------------:|-------------------:|
| 0 | 573 | **43.7** |
| 16 384 | 478 | 33.5 |
| 32 768 | 408 | 27.0 |

**64k context window** fits in ~10 GB VRAM with q4 KV on this card. Expect decode roughly **~22–23 t/s** when the history is nearly full; short chats in the WebUI typically land around **37–39 t/s** (server + sampling overhead vs raw `llama-bench`).

### Bonsai 2 27B — PQ2_0

File: `bonsai-2-27b-pq2.gguf` (~6.7 GiB), same flags, depth 0:

| Test | t/s |
|------|----:|
| Prefill pp512 | ~575 |
| Decode tg128 | ~36 |

On Ampere (3060), **PTQ1_0 wins decode**; PQ2_0 remains useful if you prefer that pack or need to match other platforms.

### How to reproduce

```bat
llama-bench.exe -m bonsai-2-27b.gguf -ngl 99 -fa 1 -ctk q4_0 -ctv q4_0 -t 1 -p 512 -n 128 -d 0 -r 2
llama-bench.exe -m bonsai-2-27b.gguf -ngl 99 -fa 1 -ctk q4_0 -ctv q4_0 -t 1 -p 512 -n 128 -d 32768 -r 2
```

## Build from source

```bat
cmake -B build -G Ninja -DGGML_CUDA=ON -DGGML_CUDA_FA_ALL_QUANTS=ON -DCMAKE_BUILD_TYPE=Release -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_TESTS=OFF
cmake --build build --config Release
```

Stage `build\bin\*` into `packaging\payload\bin` before compiling the Inno script.

## License

Upstream llama.cpp / ggml components keep their original licenses (MIT). Kortexio packaging scripts in `packaging/` are provided for use with this distribution.

## Links

- Releases (installer): https://github.com/Kortexio/LlamaCppKortexio/releases  
- Issues: https://github.com/Kortexio/LlamaCppKortexio/issues  
- Prism Bonsai models: https://huggingface.co/collections/prism-ml/bonsai  
