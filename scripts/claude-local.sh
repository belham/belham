#!/usr/bin/env bash
# Run Claude Code against the local Ollama model instead of Anthropic's API.
# Extra arguments are passed through to `claude`.
#
# Equivalent to `ollama launch claude --model <model>`, but also pins every
# model tier (opus/sonnet/haiku/subagents) to the local model so no request
# leaks to a model Ollama doesn't have.
set -euo pipefail

MODEL_NAME="${MODEL_NAME:-qwen3.5-uncensored:9b}"
OLLAMA_URL="${OLLAMA_HOST:-http://localhost:11434}"
case "$OLLAMA_URL" in http://* | https://*) ;; *) OLLAMA_URL="http://$OLLAMA_URL" ;; esac

command -v claude >/dev/null || {
  echo "claude not found. Install: curl -fsSL https://claude.ai/install.sh | bash" >&2
  exit 1
}
curl -fsS "$OLLAMA_URL/api/version" >/dev/null 2>&1 || {
  echo "Ollama is not running at $OLLAMA_URL (start it with: ollama serve)" >&2
  exit 1
}

export ANTHROPIC_BASE_URL="$OLLAMA_URL"
export ANTHROPIC_AUTH_TOKEN="ollama"
export ANTHROPIC_API_KEY=""
export ANTHROPIC_MODEL="$MODEL_NAME"
export ANTHROPIC_DEFAULT_OPUS_MODEL="$MODEL_NAME"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$MODEL_NAME"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$MODEL_NAME"
export ANTHROPIC_SMALL_FAST_MODEL="$MODEL_NAME"
export CLAUDE_CODE_SUBAGENT_MODEL="$MODEL_NAME"
# No telemetry/update checks to Anthropic while running fully local.
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
# Local generation is slow; don't time out long turns.
export API_TIMEOUT_MS="${API_TIMEOUT_MS:-600000}"
# Claude Code caps each reply at 32000 tokens by default. Qwen's thinking can
# use a lot of that, so allow 64000. Prompt + output must fit in the model's
# num_ctx (131072 from setup-qwen-ollama); with NUM_CTX=65536 set this to 32000.
export CLAUDE_CODE_MAX_OUTPUT_TOKENS="${CLAUDE_CODE_MAX_OUTPUT_TOKENS:-64000}"

exec claude --model "$MODEL_NAME" "$@"
