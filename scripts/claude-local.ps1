# Windows version of scripts/claude-local.sh: run Claude Code against the
# local Ollama model. Extra arguments are passed through to `claude`.
$ModelName = if ($env:MODEL_NAME) { $env:MODEL_NAME } else { 'qwen3.5-uncensored:9b' }
$OllamaUrl = if ($env:OLLAMA_HOST) { $env:OLLAMA_HOST } else { 'http://localhost:11434' }
if ($OllamaUrl -notmatch '^https?://') { $OllamaUrl = "http://$OllamaUrl" }

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  Write-Error 'claude not found. Install: irm https://claude.ai/install.ps1 | iex'; exit 1
}
try { Invoke-RestMethod "$OllamaUrl/api/version" | Out-Null }
catch { Write-Error "Ollama is not running at $OllamaUrl"; exit 1 }

$env:ANTHROPIC_BASE_URL = $OllamaUrl
$env:ANTHROPIC_AUTH_TOKEN = 'ollama'
$env:ANTHROPIC_API_KEY = ''
$env:ANTHROPIC_MODEL = $ModelName
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = $ModelName
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = $ModelName
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $ModelName
$env:ANTHROPIC_SMALL_FAST_MODEL = $ModelName
$env:CLAUDE_CODE_SUBAGENT_MODEL = $ModelName
$env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1'
if (-not $env:API_TIMEOUT_MS) { $env:API_TIMEOUT_MS = '600000' }

& claude --model $ModelName @args
exit $LASTEXITCODE
