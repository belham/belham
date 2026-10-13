# Local Qwen3.5-9B Uncensored for Claude Code (via Ollama)

Runs [HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive](https://huggingface.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive)
locally in Ollama, configured to drive Claude Code through Ollama's
Anthropic-compatible API (`/v1/messages`).

## Requirements

- [Ollama](https://ollama.com/download) **0.17.5 or newer** (it needs the `qwen3.5` renderer/parser and the Anthropic API)
- [Claude Code](https://code.claude.com): `curl -fsSL https://claude.ai/install.sh | bash`
- About 10 GB of free RAM/VRAM for the default Q4_K_M build at 128K context (about 8 GB at 64K, see Tuning)

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
   - `num_ctx 131072`, room for Claude Code's prompt plus a 64K-token reply
   - Qwen 3.5's recommended coding settings (temp 0.6, top_p 0.95, top_k 20) and `repeat_penalty 1.1` against thinking loops
4. Sends two test requests to `/v1/messages`, a plain reply and a tool call, and fails if no `tool_use` block comes back

## Use with Claude Code

```bash
claude-local
```

`claude-local` pins the opus/sonnet/haiku/subagent tiers to the local model so nothing falls through to a model Ollama doesn't have, and raises Claude Code's reply cap from 32000 to 64000 tokens (`CLAUDE_CODE_MAX_OUTPUT_TOKENS`; set it yourself to override). Ollama's own launcher also works:

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
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000
export CLAUDE_CODE_SUBAGENT_MODEL=qwen3.5-uncensored:9b
claude --model qwen3.5-uncensored:9b
```

## Tuning

Set these as environment variables before `setup-qwen-ollama` (on Windows, pass `-ModelName`, `-NumCtx`, `-RepeatPenalty` instead):

| Env var | Default | Notes |
|---|---|---|
| `MODEL_NAME` | `qwen3.5-uncensored:9b` | Name of the Ollama model (used by both commands) |
| `NUM_CTX` | `131072` | Has to fit Claude Code's prompt (~25K) plus its reply (up to 64K). Low on memory: `65536`, and run `claude-local` with `CLAUDE_CODE_MAX_OUTPUT_TOKENS=32000` |
| `REPEAT_PENALTY` | `1.1` | Stops thinking loops; `1.0` is Qwen's stock value |
| `OLLAMA_HOST` | `http://localhost:11434` | Remote Ollama server |

## Troubleshooting

- **Tool calls printed as text / tool test fails:** update Ollama and re-run `setup-qwen-ollama`. Don't swap `RENDERER`/`PARSER` for a hand-written `TEMPLATE`.
- **"response exceeded the 32000 output token maximum":** use `claude-local` (raises the cap to 64000), or `export CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000` before `ollama launch claude`. If replies still hit the cap, the model is looping while thinking: re-run with `REPEAT_PENALTY=1.15 setup-qwen-ollama`.
- **Endless thinking loops:** re-run with a higher penalty, e.g. `REPEAT_PENALTY=1.15 setup-qwen-ollama` (Windows: `setup-qwen-ollama -RepeatPenalty 1.15`).
- **Slow or truncated replies:** a 9B model on Claude Code's large system prompt is slow on CPU. Use a GPU, or try Q4_K_M with `NUM_CTX=65536`.
- **Vision:** image input needs the repo's `mmproj` file; this setup is text and tools only.
