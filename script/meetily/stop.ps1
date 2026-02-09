$ErrorActionPreference = 'Stop'

$exePath = Join-Path $PSScriptRoot 'meetily\meetily.exe'

# Stop meetily.exe by exact executable path
$stopped = Get-CimInstance Win32_Process |
  Where-Object { $_.ExecutablePath -ieq $exePath } |
  ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    $_
  }

# Fallback: stop any remaining meetily process by name
Stop-Process -Name 'meetily' -Force -ErrorAction SilentlyContinue

Write-Host ("Stopped processes: meetily.exe={0}" -f @($stopped).Count)
