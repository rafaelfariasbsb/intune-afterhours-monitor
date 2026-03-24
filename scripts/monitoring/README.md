# Monitoring Scripts

## Overview

This folder contains the **Phase 1 (monitoring-only)** detection script. It collects data about PCs left on after business hours without making any changes to the shutdown behavior.

## Scripts

### Detect-AfterHoursPC.ps1

**Purpose:** Monitors whether PCs are left on after business hours.

**How it works:**
1. On first run, creates a Windows Scheduled Task (`AfterHoursMonitor`) that fires at the configured time (default 22:00) on weekdays.
2. The scheduled task logs the device state to a local CSV file: timestamp, hostname, logged-in user, uptime, and session state.
3. On each Intune detection run (daily, during business hours), the script reads the CSV and outputs a summary to stdout, which Intune captures.
4. Old log entries are automatically pruned based on the retention period.

**Configuration variables** (at the top of the script):

| Variable | Default | Description |
|----------|---------|-------------|
| `$MonitorTime` | `"22:00"` | Time to check if the PC is on (24h format, local time) |
| `$TaskName` | `"AfterHoursMonitor"` | Name of the scheduled task |
| `$LogFolder` | `$env:ProgramData\AfterHoursMonitor` | Folder for the CSV log |
| `$LogFile` | `"after-hours-log.csv"` | CSV file name |
| `$LogRetentionDays` | `30` | Days to keep log entries |
| `$DaysOfWeek` | `Mon-Fri` | Days the task runs |

**Intune configuration:**
- **Script type:** Detection only (no remediation script)
- **Run as:** SYSTEM (set "Run this script using the logged-on credentials" to **No**)
- **64-bit PowerShell:** Yes
- **Schedule:** Daily

**Exit codes:**
- `0` — Always (this is monitoring only; always reports compliant)

**Sample output** (captured by Intune):
```
HOSTNAME: PC-SALES-042
SUMMARY: 12 nights logged | Active: 3 | Disconnected: 2 | NoSession: 7 | QueryFailed: 0
AVG_UPTIME: 18.3 hours
USERS: jsmith, mjones
MONITOR_TIME: 22:00
LOG_ENTRIES: 12
--- LAST 7 ENTRIES ---
2026-03-17 22:00:01 | User: jsmith | Uptime: 14.2h | State: Active
2026-03-18 22:00:01 | User:  | Uptime: 22.1h | State: NoSession
2026-03-19 22:00:01 | User: jsmith | Uptime: 8.5h | State: Disconnected
...
```

**CSV log format:**
```csv
Timestamp,Hostname,LoggedUser,UptimeHours,SessionState
2026-03-17 22:00:01,PC-SALES-042,jsmith,14.2,Active
2026-03-18 22:00:01,PC-SALES-042,,22.1,NoSession
```

**Session states:**
- `Active` — User is logged in and the session is active (or screen locked)
- `Disconnected` — User session exists but is disconnected (e.g., RDP disconnected)
- `NoSession` — No user is logged in
- `QueryFailed` — Could not query user sessions (non-critical error)

## Troubleshooting

### Scheduled task not created
- Verify the script runs as SYSTEM (not as the logged-on user).
- Check the Intune Management Extension log: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AgentExecutor.log`

### No data in CSV
- The CSV is written by the scheduled task at the configured time (default 22:00). Wait until after that time.
- Verify the task exists: `Get-ScheduledTask -TaskName "AfterHoursMonitor"`
- Check the task's last run result: `(Get-ScheduledTaskInfo -TaskName "AfterHoursMonitor").LastTaskResult`

### Script reports "No log file found"
- This is normal on the first day. The detection script creates the task, which will run that night and create the log.
