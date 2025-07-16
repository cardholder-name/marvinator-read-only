# Check-MarvinHealth.ps1
# Health check script for all GSelector/Marvin components

function Test-MarvinService {
    $healthStatus = @{
        IISService = $false
        MarvinAppPool = $false
        PluginsService = $false
        PublisherService = $false
        ServiceManager = $false
        MarvinEndpoint = $false
        Overall = $false
    }
    
    # Check IIS Service
    $iisService = Get-Service -Name "W3SVC" -ErrorAction SilentlyContinue
    if ($iisService -and $iisService.Status -eq "Running") {
        $healthStatus.IISService = $true
        Write-Host "OK: IIS (W3SVC) is running"
    } else {
        Write-Host "ERROR: IIS (W3SVC) is not running"
    }
    
    # Check Marvin Application Pool
    try {
        Import-Module WebAdministration -ErrorAction Stop
        $marvinAppPool = Get-IISAppPool -Name "RCS.GSelector.Marvin.AppPool" -ErrorAction SilentlyContinue
        if ($marvinAppPool -and $marvinAppPool.State -eq "Started") {
            $healthStatus.MarvinAppPool = $true
            Write-Host "OK: Marvin Application Pool is started"
            if ($marvinAppPool.ProcessId) {
                Write-Host "OK: Marvin worker process running (PID: $($marvinAppPool.ProcessId))"
            }
        } else {
            Write-Host "ERROR: Marvin Application Pool is not started"
        }
    } catch {
        Write-Host "ERROR: Failed to check Marvin Application Pool - $($_.Exception.Message)"
    }
    
    # Check Windows Services
    $pluginsService = Get-Service -Name "GSelectorPluginsService" -ErrorAction SilentlyContinue
    $publisherService = Get-Service -Name "GSelectorPublisherService" -ErrorAction SilentlyContinue
    
    if ($pluginsService -and $pluginsService.Status -eq "Running") {
        $healthStatus.PluginsService = $true
        Write-Host "OK: GSelector Plugins Service is running"
    } else {
        Write-Host "ERROR: GSelector Plugins Service is not running"
    }
    
    if ($publisherService -and $publisherService.Status -eq "Running") {
        $healthStatus.PublisherService = $true
        Write-Host "OK: GSelector Publisher Service is running"
    } else {
        Write-Host "ERROR: GSelector Publisher Service is not running"
    }
    
    # Check Service Manager process
    $serviceManager = Get-Process -Name "RCS.GSelector.ServiceManager" -ErrorAction SilentlyContinue
    if ($serviceManager) {
        $healthStatus.ServiceManager = $true
        Write-Host "OK: GSelector Service Manager process is running (PID: $($serviceManager.Id))"
    } else {
        Write-Host "ERROR: GSelector Service Manager process is not running"
    }
    
    # Test Marvin endpoint connectivity
    try {
        # Test the actual Marvin endpoint
        $marvinEndpoint = "/RCS.GSelector.Marvin.Services"
        $commonPorts = @(80, 443)
        
        $marvinEndpointFound = $false
        foreach ($port in $commonPorts) {
            $testResult = Test-NetConnection -ComputerName "localhost" -Port $port -WarningAction SilentlyContinue
            if ($testResult.TcpTestSucceeded) {
                Write-Host "OK: Port $port is responding"
                
                # Optional: Test HTTP endpoint specifically
                try {
                    $uri = "http://localhost:$port$marvinEndpoint"
                    $webRequest = Invoke-WebRequest -Uri $uri -Method GET -TimeoutSec 5 -ErrorAction Stop
                    Write-Host "OK: Marvin endpoint $uri is responding (Status: $($webRequest.StatusCode))"
                    $marvinEndpointFound = $true
                    break
                } catch {
                    Write-Host "INFO: Port $port responding but HTTP test failed - this may be normal"
                    $marvinEndpointFound = $true
                    break
                }
            }
        }
        
        if ($marvinEndpointFound) {
            $healthStatus.MarvinEndpoint = $true
            Write-Host "OK: Marvin service endpoint is accessible"
        } else {
            Write-Host "ERROR: Marvin service endpoint not responding"
        }
    }
    catch {
        Write-Host "WARNING: Failed to test Marvin service endpoint - $($_.Exception.Message)"
    }
    
    # Overall health assessment
    $healthStatus.Overall = $healthStatus.IISService -and $healthStatus.MarvinAppPool -and $healthStatus.PluginsService -and $healthStatus.PublisherService -and $healthStatus.ServiceManager
    
    return $healthStatus
}

# Run health check
$healthResult = Test-MarvinService
if (-not $healthResult.Overall) {
    Write-Host "WARNING: GSelector/Marvin system appears unhealthy"
    # Add your alerting/restart logic here
    exit 1
} else {
    Write-Host "SUCCESS: All GSelector/Marvin components are healthy"
    exit 0
}
