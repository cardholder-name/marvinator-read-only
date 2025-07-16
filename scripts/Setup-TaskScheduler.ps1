# Setup-TaskScheduler.ps1
# Creates a scheduled task to run Marvin monitoring every 5 minutes

param(
    [string]$ScriptPath = "C:\Scripts\Monitor-MarvinLogs-Production.ps1",
    [string]$TaskName = "Marvin Deadlock Monitor",
    [string]$TaskDescription = "Monitors Marvin logs for cache write lock deadlocks and alerts on critical issues"
)

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# Verify the monitoring script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Error "Monitoring script not found at: $ScriptPath"
    exit 1
}

try {
    # Create the scheduled task
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 365) -At (Get-Date) -Once
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false
    $principal = New-ScheduledTaskPrincipal -UserID "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    $task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description $TaskDescription
    
    # Register the task
    Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force
    
    Write-Host "SUCCESS: Scheduled task '$TaskName' created successfully" -ForegroundColor Green
    Write-Host "Task will run every 5 minutes using SYSTEM account" -ForegroundColor Green
    Write-Host "Script path: $ScriptPath" -ForegroundColor Green
    
    # Start the task immediately to test
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Task started for immediate test run" -ForegroundColor Yellow
    
    # Wait a moment and check task history
    Start-Sleep -Seconds 10
    $taskInfo = Get-ScheduledTask -TaskName $TaskName
    Write-Host "Task State: $($taskInfo.State)" -ForegroundColor Cyan
    
} catch {
    Write-Error "Failed to create scheduled task: $($_.Exception.Message)"
    exit 1
}
