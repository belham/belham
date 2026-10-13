# Install the commands onto your PATH so they run from any folder:
#   setup-qwen-ollama   download the model into Ollama and test it
#   claude-local        start Claude Code on the local model
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts\install.ps1
$ErrorActionPreference = 'Stop'
$BinDir = Join-Path $env:LOCALAPPDATA 'Programs\qwen-ollama'
# The .ps1 files go in a lib\ subfolder so only the .cmd shims are on PATH;
# otherwise PowerShell picks the .ps1 and fails under the default policy.
$LibDir = Join-Path $BinDir 'lib'
New-Item -ItemType Directory -Force $LibDir | Out-Null

foreach ($name in 'setup-qwen-ollama', 'claude-local') {
  Copy-Item (Join-Path $PSScriptRoot "$name.ps1") (Join-Path $LibDir "$name.ps1") -Force
  # .cmd shim: works from cmd.exe and PowerShell without changing execution policy.
  "@powershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0lib\$name.ps1`" %*" |
    Set-Content -Encoding ascii (Join-Path $BinDir "$name.cmd")
}
Write-Host "Installed setup-qwen-ollama and claude-local to $BinDir"

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $BinDir) {
  [Environment]::SetEnvironmentVariable('Path', ($(if ($userPath) { "$userPath;" }) + $BinDir), 'User')
  Write-Host "Added $BinDir to your user PATH. Open a new terminal to use the commands."
}
