#!/usr/bin/env bash
# Install HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive into Ollama and
# check that it works with Claude Code through Ollama's Anthropic API.
#
# Usage: scripts/setup-qwen-ollama.sh [QUANT]
#   QUANT    Q4_K_M (default, 5.3 GB) | Q6_K (6.9 GB) | Q8_0 (8.9 GB) | BF16 (17 GB)
#
# Env overrides:
#   MODEL_NAME   name of the Ollama model to create (default: qwen3.5-uncensored:9b)
#   NUM_CTX      context window (default: 65536; Claude Code needs >= 64K)
#   OLLAMA_HOST  Ollama server (default: http://localhost:11434)
set -euo pipefail

QUANT="${1:-Q4_K_M}"
MODEL_NAME="${MODEL_NAME:-qwen3.5-uncensored:9b}"
NUM_CTX="${NUM_CTX:-65536}"
OLLAMA_URL="${OLLAMA_HOST:-http://localhost:11434}"
case "$OLLAMA_URL" in http://* | https://*) ;; *) OLLAMA_URL="http://$OLLAMA_URL" ;; esac

HF_REPO="hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive"
SOURCE="$HF_REPO:$QUANT"
MIN_OLLAMA="0.17.5"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT/ollama/Modelfile.template"
MODELFILE="$ROOT/ollama/Modelfile"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

# --- 1. Ollama installed and recent enough --------------------------------
command -v ollama >/dev/null || die "ollama not found. Install it from https://ollama.com/download"
command -v curl >/dev/null || die "curl not found"

OLLAMA_VERSION="$(ollama --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | tail -n1 || true)"
if [ -n "$OLLAMA_VERSION" ] && ! version_ge "$OLLAMA_VERSION" "$MIN_OLLAMA"; then
  die "Ollama $OLLAMA_VERSION is too old; need >= $MIN_OLLAMA for the qwen3.5 renderer/parser and Claude Code support. Update Ollama and re-run."
fi
say "Ollama ${OLLAMA_VERSION:-unknown version}"

# --- 2. Server running ----------------------------------------------------
if ! curl -fsS "$OLLAMA_URL/api/version" >/dev/null 2>&1; then
  say "Starting ollama serve in the background (log: /tmp/ollama-serve.log)"
  nohup ollama serve >/tmp/ollama-serve.log 2>&1 &
  for _ in $(seq 1 30); do
    curl -fsS "$OLLAMA_URL/api/version" >/dev/null 2>&1 && break
    sleep 1
  done
  curl -fsS "$OLLAMA_URL/api/version" >/dev/null 2>&1 || die "Ollama server did not start at $OLLAMA_URL"
fi

# --- 3. Pull the GGUF straight from Hugging Face --------------------------
say "Pulling $SOURCE"
ollama pull "$SOURCE"

# --- 4. Build the Claude Code-ready model ---------------------------------
sed -e "s|__FROM__|$SOURCE|" -e "s|__NUM_CTX__|$NUM_CTX|" "$TEMPLATE" >"$MODELFILE"
say "Creating $MODEL_NAME from $MODELFILE"
ollama create "$MODEL_NAME" -f "$MODELFILE"

# --- 5. Smoke tests -------------------------------------------------------
TOOL_DEF='{"name":"get_weather","description":"Get the current weather for a city","input_schema":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}'

say "Test 1/2: Anthropic /v1/messages text reply"
REPLY="$(curl -fsS "$OLLAMA_URL/v1/messages" \
  -H 'content-type: application/json' -H 'x-api-key: ollama' -H 'anthropic-version: 2023-06-01' \
  -d "{\"model\":\"$MODEL_NAME\",\"max_tokens\":2048,\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: OK\"}]}")" \
  || die "Anthropic-compatible endpoint failed. Is Ollama >= $MIN_OLLAMA?"
echo "$REPLY" | grep -Eq '"type":"(text|thinking)"' || die "Unexpected reply: $REPLY"
say "  passed"

say "Test 2/2: Anthropic /v1/messages tool calling (what Claude Code uses)"
REPLY="$(curl -fsS "$OLLAMA_URL/v1/messages" \
  -H 'content-type: application/json' -H 'x-api-key: ollama' -H 'anthropic-version: 2023-06-01' \
  -d "{\"model\":\"$MODEL_NAME\",\"max_tokens\":4096,\"tools\":[$TOOL_DEF],\"messages\":[{\"role\":\"user\",\"content\":\"What is the weather in Paris? Use the tool.\"}]}")"
if echo "$REPLY" | grep -q '"type":"tool_use"'; then
  say "  passed"
else
  warn "model answered without a structured tool_use block:"
  echo "$REPLY" >&2
  warn "Claude Code needs working tool calls. Update Ollama, and make sure the Modelfile keeps RENDERER/PARSER qwen3.5."
  exit 1
fi

cat <<EOF

Done. Model '$MODEL_NAME' is ready for Claude Code.

Start Claude Code on it with either:
  ollama launch claude --model $MODEL_NAME
or
  scripts/claude-local.sh
EOF
