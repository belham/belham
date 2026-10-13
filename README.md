# Local Qwen3.5-9B Uncensored for Claude Code (via Ollama)

Runs [HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive](https://huggingface.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive)
locally in Ollama, configured to drive Claude Code through Ollama's
Anthropic-compatible API (`/v1/messages`).

## Requirements

- [Ollama](https://ollama.com/download) **0.17.5 or newer** (it needs the `qwen3.5` renderer/parser and the Anthropic API)
- [Claude Code](https://code.claude.com): `curl -fsSL https://claude.ai/install.sh | bash`
- About 8 GB of free RAM/VRAM for the default Q4_K_M build at 64K context

## Install (once)

Puts two commands on your PATH so you can run them from any directory:

| Command | What it does |
|---|---|
| `setup-qwen-ollama [QUANT]` | Downloads the model into Ollama, configures it for Claude Code, and tests it |
| `claude-local [claude args]` | Starts Claude Code on the local model |

macOS / Linux (installs to `~/.local/bin` and adds it to PATH if needed):

```bash
git clone -b agent/fervent-feynman-82rxyc https://github.com/belham/belham
belham/scripts/install.sh
# open a new terminal, then from anywhere:
setup-qwen-ollama           # Q4_K_M (5.3 GB); or Q6_K, Q8_0, BF16
```

Windows (installs to `%LOCALAPPDATA%\Programs\qwen-ollama` and adds it to your user PATH):

```powershell
git clone -b agent/fervent-feynman-82rxyc https://github.com/belham/belham
powershell -ExecutionPolicy Bypass -File belham\scripts\install.ps1
# open a new terminal, then from anywhere:
setup-qwen-ollama -Quant Q4_K_M
```

The commands are standalone copies, so you can delete the cloned repo afterwards.
Re-run `install.sh` / `install.ps1` after pulling updates.

## What `setup-qwen-ollama` does

1. Checks the Ollama version and starts the server if needed
2. Pulls the GGUF straight from Hugging Face (`ollama pull hf.co/HauhauCS/...:Q4_K_M`)
3. Writes a Modelfile to `~/.config/qwen-ollama/Modelfile` (Windows: `%LOCALAPPDATA%\qwen-ollama\Modelfile`) and builds `qwen3.5-uncensored:9b` from it. The Modelfile sets:
   - `RENDERER qwen3.5` / `PARSER qwen3.5`, so tool calls and thinking come back as structured `tool_use` / `thinking` blocks (without these, tool calls show up as plain text and Claude Code can't run them)
   - `num_ctx 65536` (Claude Code needs at least 64K)
   - Qwen 3.5's recommended coding settings (temp 0.6, top_p 0.95, top_k 20)
4. Sends two test requests to `/v1/messages`, a plain reply and a tool call, and fails if no `tool_use` block comes back

## Use with Claude Code

```bash
claude-local
```

`claude-local` pins the opus/sonnet/haiku/subagent tiers to the local model so nothing falls through to a model Ollama doesn't have. Ollama's own launcher also works:

```bash
ollama launch claude --model qwen3.5-uncensored:9b
```

Manual equivalent:

```bash
export ANTHROPIC_BASE_URL=http://localhost:11434
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_API_KEY=""
export ANTHROPIC_DEFAULT_OPUS_MODEL=qwen3.5-uncensored:9b
export ANTHROPIC_DEFAULT_SONNET_MODEL=qwen3.5-uncensored:9b
export ANTHROPIC_DEFAULT_HAIKU_MODEL=qwen3.5-uncensored:9b
export CLAUDE_CODE_SUBAGENT_MODEL=qwen3.5-uncensored:9b
claude --model qwen3.5-uncensored:9b
```

## Tuning

Set these as environment variables before `setup-qwen-ollama` (on Windows, pass `-ModelName`, `-NumCtx`, `-RepeatPenalty` instead):

| Env var | Default | Notes |
|---|---|---|
| `MODEL_NAME` | `qwen3.5-uncensored:9b` | Name of the Ollama model (used by both commands) |
| `NUM_CTX` | `65536` | Use `131072` if you have the memory; don't go below 64K |
| `REPEAT_PENALTY` | `1.0` | Try `1.1` if the model loops while thinking |
| `OLLAMA_HOST` | `http://localhost:11434` | Remote Ollama server |

## Troubleshooting

- **Tool calls printed as text / tool test fails:** update Ollama and re-run `setup-qwen-ollama`. Don't swap `RENDERER`/`PARSER` for a hand-written `TEMPLATE`.
- **Endless thinking loops:** re-run with `REPEAT_PENALTY=1.1 setup-qwen-ollama` (Windows: `setup-qwen-ollama -RepeatPenalty 1.1`).
- **Slow or truncated replies:** a 9B model on Claude Code's large system prompt is slow on CPU. Use a GPU, or try Q4_K_M with `NUM_CTX=65536`.
- **Vision:** image input needs the repo's `mmproj` file; this setup is text and tools only.
