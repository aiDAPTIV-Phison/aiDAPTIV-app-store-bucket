$ErrorActionPreference = 'Stop'

$exePath = Join-Path $PSScriptRoot 'meetily\meetily.exe'

# Start meetily
$stdoutLog = Join-Path $PSScriptRoot 'meetily.log'
$stderrLog = Join-Path $PSScriptRoot 'meetily.err.log'

if (Test-Path $exePath) {
  $processParams = @{
    FilePath               = $exePath
    WorkingDirectory       = $PSScriptRoot
    RedirectStandardOutput = $stdoutLog
    RedirectStandardError  = $stderrLog
  }
  Start-Process @processParams
} else {
  Write-Error "meetily.exe not found at: $exePath"
  exit 1
}

