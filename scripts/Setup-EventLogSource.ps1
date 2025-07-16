# Setup-EventLogSource.ps1
# Creates Windows Event Log source for GSelector Marvin monitoring

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

$eventSources = @(
    "GSelector Marvin",
    "GSelector Marvin Monitor"
)

foreach ($source in $eventSources) {
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
            Write-Host "Creating Event Log source: $source" -ForegroundColor Yellow
            New-EventLog -LogName "Application" -Source $source
            Write-Host "✓ Event Log source '$source' created successfully" -ForegroundColor Green
        } else {
            Write-Host "✓ Event Log source '$source' already exists" -ForegroundColor Green
        }
    } catch {
        Write-Host "✗ Failed to create Event Log source '$source': $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test writing to each source
Write-Host "`nTesting Event Log sources..." -ForegroundColor Cyan

foreach ($source in $eventSources) {
    try {
        $testMessage = "Test message from $source - $(Get-Date)"
        Write-EventLog -LogName "Application" -Source $source -EventId 1000 -EntryType Information -Message $testMessage
        Write-Host "✓ Successfully wrote test event to '$source'" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to write test event to '$source': $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nEvent Log source setup completed!" -ForegroundColor Cyan
Write-Host "You can now view events in Windows Event Viewer under Applications and Services Logs > Application" -ForegroundColor Gray
