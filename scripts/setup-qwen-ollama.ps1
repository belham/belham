# Windows version of scripts/setup-qwen-ollama.sh.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\setup-qwen-ollama.ps1 [-Quant Q4_K_M]
param(
  [ValidateSet('Q4_K_M', 'Q6_K', 'Q8_0', 'BF16')][string]$Quant = 'Q4_K_M',
  [string]$ModelName = 'qwen3.5-uncensored:9b',
  [int]$NumCtx = 65536
)
$ErrorActionPreference = 'Stop'

$OllamaUrl = if ($env:OLLAMA_HOST) { $env:OLLAMA_HOST } else { 'http://localhost:11434' }
if ($OllamaUrl -notmatch '^https?://') { $OllamaUrl = "http://$OllamaUrl" }
$Source = "hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:$Quant"
$Root = Split-Path -Parent $PSScriptRoot
$Template = Join-Path $Root 'ollama\Modelfile.template'
$Modelfile = Join-Path $Root 'ollama\Modelfile'

if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
  throw 'ollama not found. Install it from https://ollama.com/download'
}
$ver = [regex]::Match((ollama --version 2>&1 | Out-String), '\d+\.\d+\.\d+').Value
if ($ver -and ([version]$ver -lt [version]'0.17.5')) {
  throw "Ollama $ver is too old; need >= 0.17.5. Update Ollama and re-run."
}

try { Invoke-RestMethod "$OllamaUrl/api/version" | Out-Null }
catch { throw "Ollama is not running at $OllamaUrl. Start the Ollama app (or 'ollama serve') and re-run." }

Write-Host "==> Pulling $Source"
ollama pull $Source
if ($LASTEXITCODE) { throw 'pull failed' }

(Get-Content $Template -Raw).Replace('__FROM__', $Source).Replace('__NUM_CTX__', "$NumCtx") |
  Set-Content -NoNewline -Encoding ascii $Modelfile
Write-Host "==> Creating $ModelName"
ollama create $ModelName -f $Modelfile
if ($LASTEXITCODE) { throw 'create failed' }

Write-Host '==> Testing tool calling via the Anthropic API (what Claude Code uses)'
$body = @{
  model = $ModelName; max_tokens = 4096
  tools = @(@{ name = 'get_weather'; description = 'Get the current weather for a city'
      input_schema = @{ type = 'object'; properties = @{ city = @{ type = 'string' } }; required = @('city') } })
  messages = @(@{ role = 'user'; content = 'What is the weather in Paris? Use the tool.' })
} | ConvertTo-Json -Depth 10
$r = Invoke-RestMethod "$OllamaUrl/v1/messages" -Method Post -ContentType 'application/json' `
  -Headers @{ 'x-api-key' = 'ollama'; 'anthropic-version' = '2023-06-01' } -Body $body
if (-not ($r.content | Where-Object { $_.type -eq 'tool_use' })) {
  $r | ConvertTo-Json -Depth 10 | Write-Host
  throw 'No structured tool_use block returned; Claude Code needs working tool calls.'
}
Write-Host '    passed'
Write-Host ""
Write-Host "Done. Start Claude Code with:  ollama launch claude --model $ModelName"
