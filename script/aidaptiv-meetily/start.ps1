$ErrorActionPreference = 'Stop'

$exePath = Join-Path $PSScriptRoot 'aidaptiv-meetily\aidaptiv-meetily.exe'

# Start meetily
$stdoutLog = Join-Path $PSScriptRoot 'aidaptiv-meetily.log'
$stderrLog = Join-Path $PSScriptRoot 'aidaptiv-meetily.err.log'

if (Test-Path $exePath) {
  $processParams = @{
    FilePath               = $exePath
    WorkingDirectory       = $PSScriptRoot
    RedirectStandardOutput = $stdoutLog
    RedirectStandardError  = $stderrLog
  }
  Start-Process @processParams
} else {
  Write-Error "aidaptiv-meetily.exe not found at: $exePath"
  exit 1
}

