# Architecture

## Solution Overview

The After-Hours PC Monitor uses Microsoft Intune Proactive Remediations as a delivery and reporting mechanism. The actual monitoring and enforcement happen via Windows Scheduled Tasks on each device.

```
+====================================================================+
|                    MICROSOFT INTUNE (Cloud)                         |
|                                                                    |
|  +-----------------------------+  +-----------------------------+  |
|  | Proactive Remediation #1    |  | Proactive Remediation #2    |  |
|  | "After-Hours PC Monitor"    |  | "After-Hours Shutdown"      |  |
|  |                             |  |                             |  |
|  | Detection:                  |  | Detection:                  |  |
|  |   Detect-AfterHoursPC.ps1   |  |   Detect-ShutdownPolicy.ps1 |  |
|  |                             |  |                             |  |
|  | Remediation: (none)         |  | Remediation:                |  |
|  |                             |  |   Remediate-ShutdownPolicy  |  |
|  +-----------------------------+  +-----------------------------+  |
|         |           ^                    |            ^             |
|    Push | script    | stdout        Push | scripts    | stdout     |
|         v           |                    v            |             |
+====================================================================+
          |           |                    |            |
          v           |                    v            |
+====================================================================+
|                    MANAGED DEVICE (Windows)                         |
|                                                                    |
|  +-----------------------------+  +-----------------------------+  |
|  | Intune Mgmt Extension       |  | Intune Mgmt Extension       |  |
|  | runs detection daily        |  | runs detection daily        |  |
|  +-----------------------------+  +-----------------------------+  |
|         |           ^                    |            ^             |
|         v           |                    v            |             |
|  +-----------------------------+  +-----------------------------+  |
|  | Scheduled Task:             |  | Scheduled Task:             |  |
|  | "AfterHoursMonitor"         |  | "AfterHoursShutdown"        |  |
|  |  Runs at 22:00 Mon-Fri     |  |  Runs at 22:00 Mon-Fri     |  |
|  |  Logs hostname, user,      |  |  Shows toast notification   |  |
|  |  session state to CSV      |  |  Waits 5 minutes            |  |
|  +-----------------------------+  |  Executes shutdown /s /f    |  |
|         |                         +-----------------------------+  |
|         v                                                          |
|  +-----------------------------+                                   |
|  | CSV Log File                |                                   |
|  | ProgramData\AfterHours...   |                                   |
|  | 30-day rolling retention    |                                   |
|  +-----------------------------+                                   |
|                                                                    |
|  +-----------------------------+                                   |
|  | Exception File (optional)   |                                   |
|  | ProgramData\YourCompany\    |                                   |
|  | shutdown-exception.txt      |                                   |
|  +-----------------------------+                                   |
+====================================================================+
```

## Component Descriptions

### 1. Intune Proactive Remediation — Monitoring

- **Purpose:** Delivers the monitoring script and collects results.
- **Detection script:** `Detect-AfterHoursPC.ps1`
  - On first run: creates a Windows Scheduled Task (`AfterHoursMonitor`) that runs at the configured time (default 22:00) on weekdays.
  - On subsequent runs: reads the CSV log, outputs a summary to stdout (captured by Intune), and prunes old entries.
  - **Always returns exit code 0** (compliant) because this is monitoring only.
- **Remediation script:** None. This package is read-only.
- **Schedule:** Daily (configured in Intune). Runs during business hours to report on the *previous night's* data.

### 2. Intune Proactive Remediation — Enforcement

- **Purpose:** Ensures a shutdown scheduled task exists on each device.
- **Detection script:** `Detect-ShutdownPolicy.ps1`
  - Checks if the `AfterHoursShutdown` scheduled task exists and is enabled.
  - Returns exit code 0 (compliant) if the task exists, 1 (non-compliant) if missing.
  - Also checks for the exception file — if present, always returns 0 (exempt device).
- **Remediation script:** `Remediate-ShutdownPolicy.ps1`
  - Creates the `AfterHoursShutdown` scheduled task.
  - The task shows a toast notification 5 minutes before shutdown.
  - After the warning period, executes `shutdown /s /f /t 0`.

### 3. Windows Scheduled Tasks

Two tasks are created on each device:

| Task Name | Created By | Trigger | Action |
|-----------|-----------|---------|--------|
| `AfterHoursMonitor` | Detection script (monitoring) | Daily at 22:00, Mon-Fri | Logs hostname, user, session state to CSV |
| `AfterHoursShutdown` | Remediation script (enforcement) | Daily at 22:00, Mon-Fri | Toast warning, then `shutdown /s /f` |

Both tasks run as `SYSTEM` and persist across reboots.

### 4. Local CSV Log

- **Location:** `C:\ProgramData\AfterHoursMonitor\after-hours-log.csv`
- **Format:** `Timestamp,Hostname,LoggedUser,UptimeHours,SessionState`
- **Retention:** 30 days (configurable). Pruned on each detection script run.
- **Size:** Approximately 1 KB per month per device.

### 5. Exception File

- **Location:** `C:\ProgramData\YourCompany\shutdown-exception.txt`
- **Purpose:** If this file exists, the enforcement detection script reports compliant (0) and no shutdown task is created or maintained.
- **Contents:** Free-form text (recommended: reason and approver).

## Data Flow

### Monitoring Flow

```
1. Intune pushes detection script to device (daily, business hours)
2. Script checks if "AfterHoursMonitor" scheduled task exists
   ├── No:  Creates the task (first run only)
   └── Yes: Continues
3. Script reads CSV log from previous night
4. Script outputs summary to stdout
5. Script prunes entries older than 30 days
6. Intune agent captures stdout and reports to cloud
7. Admin views results in Intune portal
```

### Enforcement Flow

```
1. Intune pushes detection script to device (daily)
2. Script checks for exception file
   ├── Exists: Exit 0 (exempt, no action needed)
   └── Missing: Continue
3. Script checks if "AfterHoursShutdown" task exists and is enabled
   ├── Yes: Exit 0 (compliant)
   └── No:  Exit 1 (non-compliant, triggers remediation)
4. Intune runs remediation script
5. Script creates "AfterHoursShutdown" scheduled task
6. At 22:00, the task runs:
   a. Shows toast notification: "PC will shut down in 5 minutes"
   b. Waits 5 minutes
   c. Executes: shutdown /s /f /t 0
```

## Security Considerations

### Execution Context

- All scripts run as **SYSTEM** via the Intune Management Extension.
- SYSTEM has full local admin rights but no network identity.
- The scheduled tasks also run as SYSTEM.

### Data Privacy

- **No data leaves the device** except the stdout summary captured by Intune.
- The CSV log stays local on the device.
- Logged data: hostname, username, session state. No keylogging, no screen capture, no browsing history.
- The monitoring script does not access any user files or data.

### Attack Surface

- The scheduled task is created with a specific name and a `shutdown` command. There is no arbitrary code execution.
- The exception file path is hardcoded — it cannot be used to bypass other policies.
- The scripts do not download or execute any external content.
- No credentials are stored on the device.

### Audit Trail

- The CSV log provides a local audit trail of after-hours activity.
- Intune portal provides a cloud audit trail of script execution results.
- Scheduled task creation/modification is logged in the Windows Event Log (Task Scheduler operational log).

## Network Requirements

- No additional network ports or firewall rules needed.
- The solution uses the existing Intune Management Extension communication channel (HTTPS to `*.manage.microsoft.com`).
- No direct cloud connectivity is required at shutdown time — the scheduled task runs locally.

## Scalability

- Each device operates independently. There is no central server or database.
- The Intune Proactive Remediation engine handles distribution to thousands of devices.
- CSV logs are small (~1 KB/month) and self-pruning.
- The scripts are lightweight (< 1 second execution time).
