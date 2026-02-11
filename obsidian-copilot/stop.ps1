# aiDAPTIV+ Obsidian Stopper
# Stops Obsidian application if it is running

param(
    [switch]$Verbose = $false
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Stopping Obsidian" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to find all Obsidian processes (multi-method detection)
function Get-ObsidianProcesses {
    $processes = @()
    
    # Method 1: Try exact name match
    $processes += Get-Process -Name "Obsidian" -ErrorAction SilentlyContinue
    
    # Method 2: Try case-insensitive wildcard match (in case of different naming)
    if ($processes.Count -eq 0) {
        $processes += Get-Process | Where-Object { $_.ProcessName -like "*obsidian*" }
    }
    
    # Method 3: Match by executable path (most reliable)
    if ($processes.Count -eq 0) {
        $processes += Get-Process | Where-Object { 
            try {
                $_.Path -and ($_.Path -like "*obsidian*")
            } catch {
                $false
            }
        }
    }
    
    return $processes
}

# Function to check if Obsidian is running
function Test-ObsidianRunning {
    $processes = Get-ObsidianProcesses
    return ($null -ne $processes -and $processes.Count -gt 0)
}

# Function to stop Obsidian processes
function Stop-ObsidianProcesses {
    $processes = Get-ObsidianProcesses
    if ($processes -and $processes.Count -gt 0) {
        $processCount = $processes.Count
        Write-Host "Found $processCount Obsidian process(es) running." -ForegroundColor Yellow
        
        foreach ($process in $processes) {
            if ($Verbose) {
                Write-Host "  Stopping process: $($process.Id) ($($process.ProcessName))" -ForegroundColor Gray
                if ($process.Path) {
                    Write-Host "    Path: $($process.Path)" -ForegroundColor Gray
                }
            }
            try {
                Stop-Process -Id $process.Id -Force -ErrorAction Stop
            } catch {
                Write-Host "  [WARN] Failed to stop process $($process.Id): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        # Wait a moment for processes to terminate
        Start-Sleep -Seconds 2
        
        # Verify all processes are stopped (using multi-method detection)
        $remainingProcesses = Get-ObsidianProcesses
        if ($remainingProcesses -and $remainingProcesses.Count -gt 0) {
            Write-Host "[WARN] Some Obsidian processes may still be running." -ForegroundColor Yellow
            return $false
        }
        
        Write-Host "All Obsidian processes stopped successfully." -ForegroundColor Green
        return $true
    }
    return $false
}

# Check if Obsidian is running
if (-not (Test-ObsidianRunning)) {
    Write-Host "[INFO] Obsidian is not running. Nothing to stop." -ForegroundColor Green
    exit 0
}

# Stop Obsidian processes
Write-Host "Stopping Obsidian..." -ForegroundColor Cyan
$stopped = Stop-ObsidianProcesses

if ($stopped) {
    Write-Host ""
    Write-Host "Obsidian stopped successfully." -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "[ERROR] Failed to stop all Obsidian processes." -ForegroundColor Red
    exit 1
}
