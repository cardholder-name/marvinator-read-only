# Monitor-MarvinLogs-Production.ps1
# Production monitoring script with enhanced logging and error handling

param(
    [int]$TimeWindowMinutes = 5,
    [int]$CriticalThreshold = 3,
    [switch]$SendAlerts = $false,
    [switch]$AutoRestart = $false
)

# Configuration
$logDirectory = "C:\ProgramData\rcs\GSelector\logs"
$marvinExceptionLogs = "$logDirectory\marvin-exception_*.log"
$mainExceptionLogs = "$logDirectory\main-exception_*.log"
$monitoringLogPath = "C:\Scripts\Logs\marvin-monitoring.log"

# Ensure monitoring log directory exists
$monitoringLogDir = Split-Path $monitoringLogPath -Parent
if (-not (Test-Path $monitoringLogDir)) {
    New-Item -ItemType Directory -Path $monitoringLogDir -Force
}

# Logging function
function Write-MonitoringLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $monitoringLogPath -Value $logEntry
}

# Alert patterns
$alertPatterns = @{
    "CacheWriteLock" = @{
        Pattern = "GetWriteLock.*Timeout"
        Threshold = $CriticalThreshold
        Priority = "Critical"
        LogPath = $marvinExceptionLogs
    }
    "DatabaseTimeout" = @{
        Pattern = "SqlException.*Execution Timeout Expired"
        Threshold = 3
        Priority = "Medium"
        LogPath = $mainExceptionLogs
    }
}

function Test-LogPattern {
    param(
        [string]$LogPath,
        [string]$Pattern,
        [int]$Threshold,
        [int]$TimeWindow
    )
    
    if (-not (Test-Path $LogPath)) {
        Write-MonitoringLog "Log path not found: $LogPath" "WARNING"
        return @{ Count = 0; Matches = @() }
    }
    
    $cutoffTime = (Get-Date).AddMinutes(-$timeWindow)
    $logMatches = @()
    
    try {
        $logFiles = Get-ChildItem $LogPath -ErrorAction SilentlyContinue
        foreach ($logFile in $logFiles) {
            # For files modified within our time window, check content
            if ($logFile.LastWriteTime -gt $cutoffTime) {
                $content = Get-Content $logFile.FullName -ErrorAction SilentlyContinue
                foreach ($line in $content) {
                    if ($line -match $Pattern) {
                        $logMatches += @{
                            Timestamp = $logFile.LastWriteTime
                            Line = $line.Trim()
                            File = $logFile.Name
                        }
                    }
                }
            }
        }
    } catch {
        Write-MonitoringLog "Error reading logs: $($_.Exception.Message)" "ERROR"
    }
    
    return @{
        Count = $logMatches.Count
        Matches = $logMatches
    }
}

function Send-Alert {
    param(
        [string]$AlertType,
        [string]$Priority,
        [int]$Count,
        [array]$LogMatches
    )
    
    $message = "ALERT: $AlertType - $Priority Priority`n"
    $message += "Count: $Count occurrences in last $TimeWindowMinutes minutes`n"
    $message += "Recent matches:`n"
    
    foreach ($match in $LogMatches | Select-Object -First 3) {
        $message += "[$($match.Timestamp)] $($match.File): $($match.Line)`n"
    }
    
    Write-MonitoringLog $message "ALERT"
    
    # Log to Windows Event Log
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists("GSelector Marvin Monitor")) {
            New-EventLog -LogName "Application" -Source "GSelector Marvin Monitor"
        }
        Write-EventLog -LogName "Application" -Source "GSelector Marvin Monitor" -EventId 3001 -EntryType Error -Message $message
    } catch {
        Write-MonitoringLog "Failed to write to Event Log: $($_.Exception.Message)" "ERROR"
    }
    
    # Auto-restart logic for critical cache write lock issues
    if ($AlertType -eq "CacheWriteLock" -and $AutoRestart) {
        Write-MonitoringLog "Initiating automatic restart due to critical cache write lock timeouts" "INFO"
        try {
            Import-Module WebAdministration -ErrorAction Stop
            Restart-WebAppPool -Name "RCS.GSelector.Marvin.AppPool"
            Write-MonitoringLog "Marvin Application Pool recycled successfully" "INFO"
            
            # Log successful restart to Event Log
            $restartMessage = "Marvin Application Pool automatically recycled due to cache write lock timeouts"
            Write-EventLog -LogName "Application" -Source "GSelector Marvin Monitor" -EventId 3002 -EntryType Information -Message $restartMessage
        } catch {
            Write-MonitoringLog "Failed to restart Marvin Application Pool: $($_.Exception.Message)" "ERROR"
        }
    }
}

# Main monitoring logic
Write-MonitoringLog "Starting Marvin log monitoring (TimeWindow: $TimeWindowMinutes minutes)"

$alertTriggered = $false

foreach ($alertName in $alertPatterns.Keys) {
    $alert = $alertPatterns[$alertName]
    
    Write-MonitoringLog "Checking $alertName pattern..."
    $result = Test-LogPattern -LogPath $alert.LogPath -Pattern $alert.Pattern -Threshold $alert.Threshold -TimeWindow $TimeWindowMinutes
    
    Write-MonitoringLog "Found $($result.Count) matches (threshold: $($alert.Threshold))"
    
    if ($result.Count -ge $alert.Threshold) {
        Send-Alert -AlertType $alertName -Priority $alert.Priority -Count $result.Count -Matches $result.Matches
        $alertTriggered = $true
    }
}

if (-not $alertTriggered) {
    Write-MonitoringLog "SUCCESS: No critical patterns detected in logs" "INFO"
}

Write-MonitoringLog "Monitoring cycle completed"

# Return exit code for Task Scheduler
if ($alertTriggered) {
    exit 1
} else {
    exit 0
}
