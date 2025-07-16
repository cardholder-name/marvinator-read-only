# Monitor-MarvinLogs-Fixed.ps1
# Fixed version with proper timestamp parsing

param(
    [int]$TimeWindowMinutes = 5,
    [int]$CriticalThreshold = 3,
    [switch]$SendAlerts = $false,
    [switch]$Verbose = $false
)

# Configuration
$logDirectory = "C:\ProgramData\rcs\GSelector\logs"
$marvinExceptionLogs = "$logDirectory\marvin-exception_*.log"
$mainExceptionLogs = "$logDirectory\main-exception_*.log"

# Alert patterns
$alertPatterns = @{
    "CacheWriteLock" = @{
        Pattern = "GetWriteLock.*Timeout"
        Threshold = $CriticalThreshold
        Priority = "Critical"
        LogPath = $marvinExceptionLogs
    }
    "WCFSerialization" = @{
        Pattern = "InvalidDataContractException.*SettingsValueObject.*cannot be serialized"
        Threshold = 5
        Priority = "High"
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
        Write-Warning "Log path not found: $LogPath"
        return @{ Count = 0; Matches = @() }
    }
    
    $cutoffTime = (Get-Date).AddMinutes(-$timeWindow)
    $logMatches = @()
    
    if ($Verbose) {
        Write-Host "    Cutoff time: $cutoffTime"
    }
    
    try {
        $logFiles = Get-ChildItem $LogPath -ErrorAction SilentlyContinue
        foreach ($logFile in $logFiles) {
            if ($Verbose) {
                Write-Host "    Checking file: $($logFile.Name) (LastWriteTime: $($logFile.LastWriteTime))"
            }
            
            $content = Get-Content $logFile.FullName -ErrorAction SilentlyContinue
            foreach ($line in $content) {
                if ($line -match $Pattern) {
                    # Try to parse timestamp from log line
                    $timestampMatch = $line -match "^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"
                    if ($timestampMatch) {
                        try {
                            $timestamp = [DateTime]::ParseExact($Matches[1], "yyyy-MM-dd HH:mm:ss", $null)
                            if ($timestamp -gt $cutoffTime) {
                                $logMatches += @{
                                    Timestamp = $timestamp
                                    Line = $line
                                    File = $logFile.Name
                                }
                                if ($Verbose) {
                                    Write-Host "      MATCH: [$timestamp] $line" -ForegroundColor Green
                                }
                            } else {
                                if ($Verbose) {
                                    Write-Host "      OLD: [$timestamp] $line" -ForegroundColor Gray
                                }
                            }
                        } catch {
                            if ($Verbose) {
                                Write-Host "      PARSE ERROR: $line" -ForegroundColor Red
                            }
                        }
                    } else {
                        # If we can't parse timestamp from line, check file modification time
                        if ($logFile.LastWriteTime -gt $cutoffTime) {
                            $logMatches += @{
                                Timestamp = $logFile.LastWriteTime
                                Line = $line
                                File = $logFile.Name
                            }
                            if ($Verbose) {
                                Write-Host "      MATCH (file time): [$($logFile.LastWriteTime)] $line" -ForegroundColor Yellow
                            }
                        }
                    }
                }
            }
        }
    } catch {
        Write-Warning "Error reading logs: $($_.Exception.Message)"
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
    
    Write-Host $message -ForegroundColor Red
    
    # Log to Windows Event Log
    try {
        # Check if event source exists, create if not
        if (-not [System.Diagnostics.EventLog]::SourceExists("GSelector Marvin Monitor")) {
            Write-Host "Creating Event Log source 'GSelector Marvin Monitor'..."
            New-EventLog -LogName "Application" -Source "GSelector Marvin Monitor"
        }
        Write-EventLog -LogName "Application" -Source "GSelector Marvin Monitor" -EventId 3001 -EntryType Error -Message $message
    } catch {
        Write-Warning "Failed to write to Event Log: $($_.Exception.Message)"
    }
    
    if ($SendAlerts) {
        # Add your alerting mechanism here (email, SMS, etc.)
        # Example: Send-MailMessage -To "admin@company.com" -Subject "Marvin Alert: $AlertType" -Body $message
    }
}

# Main monitoring logic
Write-Host "Starting Marvin log monitoring..."
Write-Host "Log directory: $logDirectory"
Write-Host "Time window: $TimeWindowMinutes minutes"
Write-Host "Current time: $(Get-Date)"
Write-Host "Cutoff time: $((Get-Date).AddMinutes(-$TimeWindowMinutes))"
Write-Host "Checking patterns..."

$alertTriggered = $false

foreach ($alertName in $alertPatterns.Keys) {
    $alert = $alertPatterns[$alertName]
    
    Write-Host "Checking $alertName pattern..."
    $result = Test-LogPattern -LogPath $alert.LogPath -Pattern $alert.Pattern -Threshold $alert.Threshold -TimeWindow $TimeWindowMinutes
    
    Write-Host "  Found $($result.Count) matches (threshold: $($alert.Threshold))"
    
    if ($result.Count -ge $alert.Threshold) {
        Send-Alert -AlertType $alertName -Priority $alert.Priority -Count $result.Count -LogMatches $result.Matches
        $alertTriggered = $true
    }
}

if (-not $alertTriggered) {
    Write-Host "SUCCESS: No critical patterns detected in logs within the last $TimeWindowMinutes minutes" -ForegroundColor Green
}

return -not $alertTriggered
