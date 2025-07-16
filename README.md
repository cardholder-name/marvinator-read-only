# GSelector Marvin Service - Automated Monitoring & Recovery

Automated PowerShell solution to detect and resolve GSelector Marvin service deadlocks using scheduled monitoring and automated recovery procedures.

## 🚨 Problem Statement

GSelector Marvin service experiences cache write lock deadlocks (`GetWriteLock(6) Timeout`) causing service unresponsiveness and broadcast disruption, requiring manual intervention.

## ✅ Solution Overview

- **Automated monitoring** every 5 minutes via Task Scheduler
- **Pattern detection** of deadlock indicators in log files
- **Automated recovery** through IIS Application Pool restart
- **Event logging** for visibility and alerting integration
- **Escalation procedures** for manual intervention when needed

## 🏗️ Architecture

**Target System**: GSelector Marvin running as IIS Application Pool (`RCS.GSelector.Marvin.AppPool`)
**Dependencies**: GSelectorPluginsService, GSelectorPublisherService, IIS, MSSQL$GSELECTOR
**Management**: GSelector Service Manager (GUI only)
**Recovery Method**: IIS AppPool restart

## 📁 Repository Structure

```
gselector-marvin-monitoring/
├── scripts/
│   ├── Check-MarvinHealth.ps1              # Health check for all components
│   ├── Monitor-MarvinLogs-Production.ps1   # Real-time log monitoring
│   ├── Restart-MarvinService-Final.ps1     # Automated AppPool restart
│   ├── Setup-EventLogSource.ps1            # Event Log configuration
│   └── Setup-TaskScheduler.ps1             # Task Scheduler setup
├── documentation/
│   ├── GSelector_Marvin_Monitoring_Setup.md    # Complete technical guide
│   ├── GSelector_Marvin_Confluence_Documentation.md  # Condensed ops guide
│   ├── GSelector_Marvin_Issue_Analysis.md      # Problem analysis
│   └── GSelector_Marvin_Dev_Report.md          # Development findings
├── tests/
│   ├── Test-ServiceManagerCLI.ps1          # Service Manager CLI testing
│   ├── Test-TimestampFiltering.ps1         # Log filtering validation
│   └── Monitor-MarvinLogs-Fixed.ps1        # Alternative monitoring script
├── README.md
├── LICENSE
└── .gitignore
```

## 🚀 Quick Start

### Prerequisites
- Windows Server with IIS and GSelector
- PowerShell 5.1+ with RemoteSigned execution policy
- Administrator privileges

### Installation
1. **Clone repository**:
   ```powershell
   git clone https://github.com/yourusername/gselector-marvin-monitoring.git
   cd gselector-marvin-monitoring
   ```

2. **Create directories**:
   ```powershell
   New-Item -ItemType Directory -Path "C:\Scripts" -Force
   New-Item -ItemType Directory -Path "C:\Scripts\Logs" -Force
   ```

3. **Deploy scripts**:
   ```powershell
   Copy-Item -Path "scripts\*" -Destination "C:\Scripts\" -Force
   ```

4. **Configure monitoring**:
   ```powershell
   # Run as Administrator
   & "C:\Scripts\Setup-EventLogSource.ps1"
   & "C:\Scripts\Setup-TaskScheduler.ps1"
   ```

### Testing
```powershell
# Test health check
& "C:\Scripts\Check-MarvinHealth.ps1"

# Test log monitoring
& "C:\Scripts\Monitor-MarvinLogs-Production.ps1" -Verbose

# Verify scheduled task
Get-ScheduledTask -TaskName "Marvin Deadlock Monitor"
```

## 📊 Monitoring Thresholds

| Level | Condition | Action | Event ID |
|-------|-----------|--------|----------|
| **Warning** | 2-3 timeouts/5min | Log warning | 1001 |
| **Critical** | 3+ timeouts/5min | Auto-restart | 1002 |
| **Emergency** | Restart fails | Manual intervention | 2003 |

## 🔧 Configuration

### Default Settings
- **Time Window**: 5 minutes
- **Critical Threshold**: 3 timeouts
- **Warning Threshold**: 2 timeouts
- **Monitoring Pattern**: `GetWriteLock.*Timeout`

### Log Locations
- **Marvin Exceptions**: `C:\ProgramData\rcs\GSelector\logs\marvin-exception_*.log`
- **Monitoring Logs**: `C:\Scripts\Logs\marvin-monitor_*.log`

## 📋 Operations

### Daily Tasks
- Check Windows Event Viewer → Application Log → "GSelector Marvin Monitor"
- Verify Task Scheduler "Marvin Deadlock Monitor" is running
- Review restart frequency and patterns

### Emergency Procedures
If automated restart fails:
1. Check Event Log for error details
2. Manual AppPool restart: `Restart-WebAppPool -Name "RCS.GSelector.Marvin.AppPool"`
3. If still failing, use GSelector Service Manager GUI
4. Document incident and contact L2 support

## 🚨 Troubleshooting

### Common Issues

**Task Not Running**
```powershell
Get-ScheduledTask -TaskName "Marvin Deadlock Monitor"
Test-Path "C:\Scripts\Monitor-MarvinLogs-Production.ps1"
```

**False Positive Restarts**
```powershell
# Increase thresholds
& "C:\Scripts\Monitor-MarvinLogs-Production.ps1" -CriticalThreshold 5 -TimeWindowMinutes 10
```

**Restart Failure**
```powershell
Import-Module WebAdministration
Get-IISAppPool -Name "RCS.GSelector.Marvin.AppPool"
Restart-WebAppPool -Name "RCS.GSelector.Marvin.AppPool"
```

## 📖 Documentation

- **[Complete Setup Guide](documentation/GSelector_Marvin_Monitoring_Setup.md)** - Detailed technical documentation
- **[Confluence Documentation](documentation/GSelector_Marvin_Confluence_Documentation.md)** - Condensed operations guide
- **[Issue Analysis](documentation/GSelector_Marvin_Issue_Analysis.md)** - Problem analysis and findings
- **[Development Report](documentation/GSelector_Marvin_Dev_Report.md)** - Development process and decisions

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/improvement`
3. Test changes in development environment
4. Commit changes: `git commit -am 'Add improvement'`
5. Push to branch: `git push origin feature/improvement`
6. Create Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

| Level | Contact | When |
|-------|---------|------|
| **L1** | IT Operations | Automated restart fails |
| **L2** | Systems Admin | Multiple restart failures |
| **L3** | Senior IT Manager | Complete system failure |

---

*Created with AI assistance using GitHub Copilot | Reviewed and validated by IT Operations team*
