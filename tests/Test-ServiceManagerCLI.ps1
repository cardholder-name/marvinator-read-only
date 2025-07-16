# Test-ServiceManagerCLI.ps1
# Comprehensive testing of Service Manager command line options

param(
    [switch]$TestAll = $false,
    [switch]$TestHelp = $false,
    [switch]$TestRestart = $false,
    [switch]$Verbose = $false
)

$serviceManagerPath = "C:\Program Files\RCS\GSelector\ServiceManager\RCS.GSelector.ServiceManager.exe"
$logPath = "C:\Scripts\Logs\ServiceManager-Test.log"

# Ensure log directory exists
$logDir = Split-Path $logPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force
}

function Write-TestLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    if ($Verbose) { Write-Host $logEntry }
    Add-Content -Path $logPath -Value $logEntry
}

function Test-ServiceManagerCommand {
    param(
        [string]$Arguments,
        [string]$Description,
        [int]$TimeoutSeconds = 10
    )
    
    Write-TestLog "Testing: $Description" "TEST"
    Write-TestLog "Command: `"$serviceManagerPath`" $Arguments" "INFO"
    
    try {
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $serviceManagerPath
        $processInfo.Arguments = $Arguments
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        
        $stdout = New-Object System.Text.StringBuilder
        $stderr = New-Object System.Text.StringBuilder
        
        $process.OutputDataReceived += {
            if ($null -ne $_.Data) {
                [void]$stdout.AppendLine($_.Data)
            }
        }
        
        $process.ErrorDataReceived += {
            if ($null -ne $_.Data) {
                [void]$stderr.AppendLine($_.Data)
            }
        }
        
        $process.Start()
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
        
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        
        if (-not $completed) {
            $process.Kill()
            Write-TestLog "Command timed out after $TimeoutSeconds seconds" "WARNING"
            return @{
                Success = $false
                ExitCode = -1
                Output = "TIMEOUT"
                Error = "Command timed out"
            }
        }
        
        $exitCode = $process.ExitCode
        $outputText = $stdout.ToString().Trim()
        $errorText = $stderr.ToString().Trim()
        
        Write-TestLog "Exit Code: $exitCode" "INFO"
        if ($outputText) { Write-TestLog "Output: $outputText" "INFO" }
        if ($errorText) { Write-TestLog "Error: $errorText" "ERROR" }
        
        return @{
            Success = ($exitCode -eq 0)
            ExitCode = $exitCode
            Output = $outputText
            Error = $errorText
        }
        
    } catch {
        Write-TestLog "Exception: $($_.Exception.Message)" "ERROR"
        return @{
            Success = $false
            ExitCode = -999
            Output = ""
            Error = $_.Exception.Message
        }
    }
}

# Clear previous log
if (Test-Path $logPath) {
    Remove-Item $logPath -Force
}

Write-TestLog "Starting Service Manager CLI testing" "INFO"
Write-TestLog "Service Manager Path: $serviceManagerPath" "INFO"

if (-not (Test-Path $serviceManagerPath)) {
    Write-TestLog "ERROR: Service Manager not found at $serviceManagerPath" "ERROR"
    exit 1
}

$testResults = @()

# Test help options
if ($TestHelp -or $TestAll) {
    Write-TestLog "=== TESTING HELP OPTIONS ===" "INFO"
    
    $helpCommands = @(
        @{ Args = "/?"; Desc = "Standard Windows help" },
        @{ Args = "/help"; Desc = "Help command" },
        @{ Args = "-help"; Desc = "Help command (dash)" },
        @{ Args = "--help"; Desc = "Help command (double dash)" },
        @{ Args = "/h"; Desc = "Short help" },
        @{ Args = "-h"; Desc = "Short help (dash)" }
    )
    
    foreach ($cmd in $helpCommands) {
        $result = Test-ServiceManagerCommand -Arguments $cmd.Args -Description $cmd.Desc
        $testResults += @{
            Command = $cmd.Args
            Description = $cmd.Desc
            Result = $result
        }
    }
}

# Test restart options
if ($TestRestart -or $TestAll) {
    Write-TestLog "=== TESTING RESTART OPTIONS ===" "INFO"
    
    $restartCommands = @(
        @{ Args = "/restart-component:RCS.GSelector.Marvin.Services"; Desc = "Restart Marvin component by full name" },
        @{ Args = "/restart-component:Marvin"; Desc = "Restart Marvin component by display name" },
        @{ Args = "/restart-appool:RCS.GSelector.Marvin.Services"; Desc = "Restart Marvin as AppPool" },
        @{ Args = "/restart-group:GSELECTOR"; Desc = "Restart GSELECTOR group" },
        @{ Args = "/restart-marvin"; Desc = "Restart Marvin directly" },
        @{ Args = "/restart"; Desc = "General restart command" },
        @{ Args = "-restart-component RCS.GSelector.Marvin.Services"; Desc = "Restart Marvin component (dash syntax)" },
        @{ Args = "-restart-marvin"; Desc = "Restart Marvin (dash syntax)" },
        @{ Args = "/start-component:RCS.GSelector.Marvin.Services"; Desc = "Start Marvin component" },
        @{ Args = "/stop-component:RCS.GSelector.Marvin.Services"; Desc = "Stop Marvin component" },
        @{ Args = "/status"; Desc = "Show component status" },
        @{ Args = "/list-components"; Desc = "List all components" }
    )
    
    foreach ($cmd in $restartCommands) {
        $result = Test-ServiceManagerCommand -Arguments $cmd.Args -Description $cmd.Desc
        $testResults += @{
            Command = $cmd.Args
            Description = $cmd.Desc
            Result = $result
        }
    }
}

# Generate summary report
Write-TestLog "=== TEST SUMMARY ===" "INFO"

$successfulCommands = @()
$failedCommands = @()

foreach ($test in $testResults) {
    if ($test.Result.Success) {
        $successfulCommands += $test
        Write-TestLog "✓ SUCCESS: $($test.Command) - $($test.Description)" "INFO"
    } else {
        $failedCommands += $test
        Write-TestLog "✗ FAILED: $($test.Command) - $($test.Description) (Exit: $($test.Result.ExitCode))" "WARNING"
    }
}

Write-TestLog "Total tests: $($testResults.Count)" "INFO"
Write-TestLog "Successful: $($successfulCommands.Count)" "INFO"
Write-TestLog "Failed: $($failedCommands.Count)" "INFO"

# Output results to console
Write-Host "`n=== SERVICE MANAGER CLI TEST RESULTS ===" -ForegroundColor Cyan
Write-Host "Service Manager Path: $serviceManagerPath"
Write-Host "Log File: $logPath"
Write-Host ""

if ($successfulCommands.Count -gt 0) {
    Write-Host "✓ SUCCESSFUL COMMANDS:" -ForegroundColor Green
    foreach ($cmd in $successfulCommands) {
        Write-Host "  $($cmd.Command) - $($cmd.Description)" -ForegroundColor Green
        if ($cmd.Result.Output) {
            Write-Host "    Output: $($cmd.Result.Output)" -ForegroundColor Gray
        }
    }
    Write-Host ""
}

if ($failedCommands.Count -gt 0) {
    Write-Host "✗ FAILED COMMANDS:" -ForegroundColor Red
    foreach ($cmd in $failedCommands) {
        Write-Host "  $($cmd.Command) - $($cmd.Description) (Exit: $($cmd.Result.ExitCode))" -ForegroundColor Red
        if ($cmd.Result.Error -and $cmd.Result.Error -ne "TIMEOUT") {
            Write-Host "    Error: $($cmd.Result.Error)" -ForegroundColor Gray
        }
    }
}

Write-Host "`n=== RECOMMENDATIONS ===" -ForegroundColor Yellow
if ($successfulCommands.Count -eq 0) {
    Write-Host "• Service Manager appears to be GUI-only (no CLI support detected)"
    Write-Host "• Continue using direct IIS AppPool restart method"
    Write-Host "• Consider Service Manager GUI automation via COM/UI automation"
} else {
    Write-Host "• Service Manager supports CLI operations!"
    Write-Host "• Update restart scripts to use successful commands"
    Write-Host "• Test successful commands in production environment"
}

Write-Host "`nFull test log saved to: $logPath" -ForegroundColor Cyan
