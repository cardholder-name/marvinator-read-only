# GSelector Marvin Service - Automated Monitoring & Recovery

## 📋 Overview

Automated solution to detect and resolve GSelector Marvin service deadlocks using PowerShell scripts, scheduled monitoring, and automated recovery procedures.

**Problem**: Marvin service experiences cache write lock deadlocks (`GetWriteLock(6) Timeout`) causing service unresponsiveness and broadcast disruption.

**Solution**: Automated monitoring every 5 minutes with threshold-based restart triggering to prevent manual intervention and service outages.

## 🏗️ System Architecture

**Marvin Service**: IIS Application Pool (`RCS.GSelector.Marvin.AppPool`)  
**Dependencies**: GSelectorPluginsService, GSelectorPublisherService, IIS, MSSQL$GSELECTOR  
**Management**: GSelector Service Manager (GUI only)  
**Recovery Method**: IIS AppPool restart

| Component | Type | Monitoring |
|-----------|------|------------|
| Marvin Service | IIS App Pool | ✅ Automated |
| Service Manager | GUI Application | ✅ Process check |
| Plugins Service | Windows Service | ✅ Service status |
| Publisher Service | Windows Service | ✅ Service status |

## 🔧 Solution Components

### Scripts
- **`Check-MarvinHealth.ps1`**: Health check for all GSelector components
- **`Monitor-MarvinLogs-Production.ps1`**: Real-time log monitoring with pattern matching
- **`Restart-MarvinService-Final.ps1`**: Automated AppPool restart with verification
- **`Setup-EventLogSource.ps1`**: Creates Windows Event Log sources
- **`Setup-TaskScheduler.ps1`**: Configures scheduled monitoring

### Monitoring Pattern
Primary detection: `GetWriteLock.*Timeout` in marvin-exception logs

### Task Scheduler
- **Frequency**: Every 5 minutes
- **Account**: SYSTEM
- **Action**: Execute log monitoring script

### Event Log Integration
**Source**: "GSelector Marvin Monitor"  
**Event IDs**: 1000 (success), 1001 (warning), 1002 (error), 2001-2003 (restart events)

## 📊 Alert Thresholds

| Level | Condition | Action | Notification |
|-------|-----------|--------|-------------|
| **Warning** | 2-3 timeouts/5min | Log warning | Email (optional) |
| **Critical** | 3+ timeouts/5min | Auto-restart | SMS + Email |
| **Emergency** | Restart fails | Manual intervention | Phone call |

## 🚀 Quick Deployment

### Prerequisites
- Windows Server with IIS and GSelector
- PowerShell 5.1+ with RemoteSigned execution policy
- Administrator privileges

### Steps
1. **Setup directories**:
   ```powershell
   New-Item -ItemType Directory -Path "C:\Scripts" -Force
   New-Item -ItemType Directory -Path "C:\Scripts\Logs" -Force
   ```

2. **Deploy scripts** to `C:\Scripts\`:
   - `Check-MarvinHealth.ps1`
   - `Monitor-MarvinLogs-Production.ps1` 
   - `Restart-MarvinService-Final.ps1`
   - `Setup-EventLogSource.ps1`
   - `Setup-TaskScheduler.ps1`

3. **Configure monitoring**:
   ```powershell
   # Run as Administrator
   & "C:\Scripts\Setup-EventLogSource.ps1"
   & "C:\Scripts\Setup-TaskScheduler.ps1"
   ```

4. **Test deployment**:
   ```powershell
   & "C:\Scripts\Check-MarvinHealth.ps1"
   & "C:\Scripts\Monitor-MarvinLogs-Production.ps1" -Verbose
   ```

## 🔧 Configuration

### Default Settings
| Parameter | Value | Description |
|-----------|-------|-------------|
| `TimeWindowMinutes` | 5 | Log analysis window |
| `CriticalThreshold` | 3 | Timeout count for restart |
| `WarningThreshold` | 2 | Timeout count for warning |

### Log Locations
| Type | Path |
|------|------|
| Marvin Exceptions | `C:\ProgramData\rcs\GSelector\logs\marvin-exception_*.log` |
| Monitoring Logs | `C:\Scripts\Logs\marvin-monitor_*.log` |

### Custom Thresholds
```powershell
# Higher threshold example
& "C:\Scripts\Monitor-MarvinLogs-Production.ps1" -CriticalThreshold 5 -TimeWindowMinutes 10
```

## 📋 Operations

### Daily Tasks
- Check Windows Event Viewer → Application Log → "GSelector Marvin Monitor"
- Verify Task Scheduler "Marvin Deadlock Monitor" is running
- Review restart frequency and patterns

### Weekly Tasks
- Clean up old monitoring logs
- Review alert thresholds effectiveness
- Check system performance impact

## 🚨 Troubleshooting

### Task Not Running
**Issue**: No Event Log entries, monitoring inactive
**Fix**: 
```powershell
Get-ScheduledTask -TaskName "Marvin Deadlock Monitor"
Test-Path "C:\Scripts\Monitor-MarvinLogs-Production.ps1"
& "C:\Scripts\Monitor-MarvinLogs-Production.ps1" -Verbose
```

### False Positive Restarts
**Issue**: Frequent unnecessary restarts
**Fix**: Increase thresholds
```powershell
& "C:\Scripts\Monitor-MarvinLogs-Production.ps1" -CriticalThreshold 5 -TimeWindowMinutes 10
```

### Restart Failure (Event ID 2003)
**Issue**: AppPool restart failed
**Fix**: Manual intervention required
```powershell
Import-Module WebAdministration
Get-IISAppPool -Name "RCS.GSelector.Marvin.AppPool"
Restart-WebAppPool -Name "RCS.GSelector.Marvin.AppPool"
```

### Complete System Failure
1. Open GSelector Service Manager (GUI)
2. Perform manual restart of all components
3. Check Windows Event Log for errors
4. Document incident and restart monitoring

## � Support & Escalation

| Level | Contact | When |
|-------|---------|------|
| **L1** | IT Operations | Automated restart fails |
| **L2** | Systems Admin | Multiple restart failures |
| **L3** | Senior IT Manager | Complete system failure |

---

## � Quick Reference

### Key Files
- **Health Check**: `C:\Scripts\Check-MarvinHealth.ps1`
- **Log Monitor**: `C:\Scripts\Monitor-MarvinLogs-Production.ps1`
- **Restart Script**: `C:\Scripts\Restart-MarvinService-Final.ps1`
- **Event Log**: Windows Application Log → "GSelector Marvin Monitor"

### Key Commands
```powershell
# Manual health check
& "C:\Scripts\Check-MarvinHealth.ps1"

# Check task status
Get-ScheduledTask -TaskName "Marvin Deadlock Monitor"

# Manual AppPool restart
Restart-WebAppPool -Name "RCS.GSelector.Marvin.AppPool"
```

### Monitoring Pattern
Watch for `GetWriteLock.*Timeout` in `C:\ProgramData\rcs\GSelector\logs\marvin-exception_*.log`

---

*Document Version 1.0 | Created: July 16, 2025 | Contact: IT Operations Team*
