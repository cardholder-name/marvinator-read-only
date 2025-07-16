# Test-TimestampFiltering.ps1
# Test script to verify the monitoring script correctly filters by time window

param(
    [int]$TimeWindowMinutes = 5
)

$logDirectory = "C:\ProgramData\rcs\GSelector\logs"
$marvinExceptionLogs = "$logDirectory\marvin-exception_*.log"

Write-Host "=== Testing Timestamp Filtering ===" -ForegroundColor Cyan
Write-Host "Current time: $(Get-Date)"
Write-Host "Time window: $TimeWindowMinutes minutes"
Write-Host "Cutoff time: $((Get-Date).AddMinutes(-$TimeWindowMinutes))"
Write-Host ""

$cutoffTime = (Get-Date).AddMinutes(-$TimeWindowMinutes)
$pattern = "GetWriteLock.*Timeout"

$logFiles = Get-ChildItem $marvinExceptionLogs -ErrorAction SilentlyContinue
if (-not $logFiles) {
    Write-Host "No Marvin exception log files found at: $marvinExceptionLogs" -ForegroundColor Red
    return
}

foreach ($logFile in $logFiles) {
    Write-Host "Checking file: $($logFile.Name) (LastWriteTime: $($logFile.LastWriteTime))" -ForegroundColor Yellow
    
    $content = Get-Content $logFile.FullName -ErrorAction SilentlyContinue
    $totalMatches = 0
    $recentMatches = 0
    
    foreach ($line in $content) {
        if ($line -match $pattern) {
            $totalMatches++
            
            # Try to parse timestamp from log line
            $timestampMatch = $line -match "^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"
            if ($timestampMatch) {
                try {
                    $timestamp = [DateTime]::ParseExact($Matches[1], "yyyy-MM-dd HH:mm:ss", $null)
                    if ($timestamp -gt $cutoffTime) {
                        $recentMatches++
                        Write-Host "  RECENT: [$timestamp] $line" -ForegroundColor Green
                    } else {
                        Write-Host "  OLD: [$timestamp] $line" -ForegroundColor Gray
                    }
                } catch {
                    Write-Host "  PARSE ERROR: $line" -ForegroundColor Red
                }
            } else {
                Write-Host "  NO TIMESTAMP: $line" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host "  Total matches: $totalMatches"
    Write-Host "  Recent matches (within $TimeWindowMinutes minutes): $recentMatches"
    Write-Host ""
}

Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "If recent matches = 0, then your restart at 9am successfully resolved the deadlock issue!"
Write-Host "If recent matches > 0, then new deadlocks are occurring and need attention."
