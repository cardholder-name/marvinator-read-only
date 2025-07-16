# Restart-MarvinService-Final.ps1
# FINAL PRODUCTION VERSION - IIS AppPool restart method confirmed
# Service Manager CLI testing completed - NOT SUPPORTED

param(
    [string]$Reason = "Automated restart due to deadlock detection",
    [switch]$FullSystem = $false,
    [switch]$TestMode = $false
)

# Configuration
$marvinAppPoolName = "RCS.GSelector.Marvin.AppPool"
$logPath = "C:\Scripts\Logs\marvin-restart.log"
$eventSource = "GSelector Marvin Monitor"

# Ensure log directory exists
$logDir = Split-Path $logPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force
}

function Write-RestartLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $logPath -Value $logEntry
}

function Test-MarvinHealth {
    Write-RestartLog "Checking Marvin health before restart..."
    
    try {
        Import-Module WebAdministration -ErrorAction Stop
        $marvinAppPool = Get-IISAppPool -Name $marvinAppPoolName -ErrorAction SilentlyContinue
        
        if ($marvinAppPool) {
            Write-RestartLog "Marvin AppPool found - State: $($marvinAppPool.State)"
            return @{
                Exists = $true
                State = $marvinAppPool.State
                ProcessId = $marvinAppPool.ProcessId
            }
        } else {
            Write-RestartLog "ERROR: Marvin AppPool not found" "ERROR"
            return @{
                Exists = $false
                State = "NotFound"
                ProcessId = $null
            }
        }
    } catch {
        Write-RestartLog "ERROR: Failed to check Marvin health - $($_.Exception.Message)" "ERROR"
        return @{
            Exists = $false
            State = "Error"
            ProcessId = $null
        }
    }
}

function Restart-MarvinAppPool {
    param([string]$RestartReason)
    
    Write-RestartLog "=== MARVIN APPLICATION POOL RESTART ===" "INFO"
    Write-RestartLog "Reason: $RestartReason" "INFO"
    
    if ($TestMode) {
        Write-RestartLog "TEST MODE: Would restart Marvin AppPool" "INFO"
        return $true
    }
    
    try {
        # Log the restart event
        try {
            if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) {
                New-EventLog -LogName "Application" -Source $eventSource
            }
            Write-EventLog -LogName "Application" -Source $eventSource -EventId 3001 -EntryType Information -Message "Marvin AppPool restart initiated: $RestartReason"
        } catch {
            Write-RestartLog "WARNING: Failed to write to Event Log: $($_.Exception.Message)" "WARNING"
        }
        
        # Get current state
        $healthBefore = Test-MarvinHealth
        Write-RestartLog "Pre-restart state: $($healthBefore.State)" "INFO"
        
        # Restart the Application Pool
        Write-RestartLog "Restarting Marvin Application Pool..." "INFO"
        Import-Module WebAdministration -ErrorAction Stop
        
        Restart-WebAppPool -Name $marvinAppPoolName
        Write-RestartLog "Restart command executed" "INFO"
        
        # Wait for restart to complete
        Write-RestartLog "Waiting 30 seconds for restart to complete..." "INFO"
        Start-Sleep -Seconds 30
        
        # Verify restart success
        $healthAfter = Test-MarvinHealth
        Write-RestartLog "Post-restart state: $($healthAfter.State)" "INFO"
        
        if ($healthAfter.State -eq "Started") {
            Write-RestartLog "SUCCESS: Marvin Application Pool restarted successfully" "INFO"
            
            # Log successful restart
            try {
                $successMessage = "Marvin AppPool restart completed successfully. Previous state: $($healthBefore.State), Current state: $($healthAfter.State)"
                Write-EventLog -LogName "Application" -Source $eventSource -EventId 3002 -EntryType Information -Message $successMessage
            } catch {
                Write-RestartLog "WARNING: Failed to log success to Event Log" "WARNING"
            }
            
            return $true
        } else {
            Write-RestartLog "ERROR: Marvin Application Pool failed to start properly - State: $($healthAfter.State)" "ERROR"
            
            # Log failure
            try {
                $failureMessage = "Marvin AppPool restart failed. State after restart: $($healthAfter.State)"
                Write-EventLog -LogName "Application" -Source $eventSource -EventId 3003 -EntryType Error -Message $failureMessage
            } catch {
                Write-RestartLog "WARNING: Failed to log failure to Event Log" "WARNING"
            }
            
            return $false
        }
        
    } catch {
        Write-RestartLog "ERROR: Failed to restart Marvin AppPool - $($_.Exception.Message)" "ERROR"
        
        # Log exception
        try {
            $exceptionMessage = "Marvin AppPool restart failed with exception: $($_.Exception.Message)"
            Write-EventLog -LogName "Application" -Source $eventSource -EventId 3004 -EntryType Error -Message $exceptionMessage
        } catch {
            Write-RestartLog "WARNING: Failed to log exception to Event Log" "WARNING"
        }
        
        return $false
    }
}

function Restart-FullGSelectorSystem {
    param([string]$RestartReason)
    
    Write-RestartLog "=== FULL GSELECTOR SYSTEM RESTART ===" "WARNING"
    Write-RestartLog "Reason: $RestartReason" "WARNING"
    
    if ($TestMode) {
        Write-RestartLog "TEST MODE: Would restart full GSelector system" "INFO"
        return $true
    }
    
    # This is a more complex operation - typically done via Service Manager GUI
    Write-RestartLog "MANUAL INTERVENTION REQUIRED: Use Service Manager GUI for full system restart" "WARNING"
    Write-RestartLog "Service Manager Path: C:\Program Files\RCS\GSelector\ServiceManager\RCS.GSelector.ServiceManager.exe" "INFO"
    
    return $false
}

# Main execution
Write-RestartLog "Starting Marvin restart script..." "INFO"
Write-RestartLog "Parameters: FullSystem=$FullSystem, TestMode=$TestMode" "INFO"

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-RestartLog "ERROR: This script must be run as Administrator" "ERROR"
    exit 1
}

# Initial health check
$initialHealth = Test-MarvinHealth
if (-not $initialHealth.Exists) {
    Write-RestartLog "ERROR: Marvin AppPool not found - cannot proceed" "ERROR"
    exit 1
}

Write-RestartLog "Initial Marvin state: $($initialHealth.State)" "INFO"

# Execute restart based on parameters
if ($FullSystem) {
    $result = Restart-FullGSelectorSystem -RestartReason $Reason
} else {
    $result = Restart-MarvinAppPool -RestartReason $Reason
}

# Final status
if ($result) {
    Write-RestartLog "=== RESTART OPERATION COMPLETED SUCCESSFULLY ===" "INFO"
    exit 0
} else {
    Write-RestartLog "=== RESTART OPERATION FAILED ===" "ERROR"
    exit 1
}
