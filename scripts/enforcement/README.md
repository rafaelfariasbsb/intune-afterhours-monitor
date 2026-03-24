# Enforcement Scripts

## Overview

This folder contains the **Phase 3 (enforcement)** scripts. These create a scheduled task that shuts down PCs after business hours, with a user warning before shutdown.

> **Deploy these only after completing Phase 1 (monitoring) and Phase 2 (analysis).** See the [Rollout Plan](../../docs/rollout-plan.md).

## Scripts

### Detect-ShutdownPolicy.ps1

**Purpose:** Checks whether the shutdown scheduled task exists and is enabled.

**Logic:**
1. Checks for an exception file. If present, reports compliant (exempt device).
2. Checks if the `AfterHoursShutdown` scheduled task exists.
3. Checks if the task is enabled.

**Exit codes:**
- `0` (compliant) — Task exists and is enabled, OR device is exempt
- `1` (non-compliant) — Task missing or disabled, triggers remediation

### Remediate-ShutdownPolicy.ps1

**Purpose:** Creates the shutdown scheduled task.

**What it does:**
1. Checks for the exception file. If present, exits without creating the task.
2. Removes any existing task with the same name (clean slate).
3. Creates a new scheduled task that:
   - Triggers at the warning time (shutdown time minus warning minutes).
   - Shows a message to all user sessions via `msg.exe`.
   - Initiates `shutdown /s /f /t 300` with a user-visible countdown.
   - Users can abort with `shutdown /a` during the countdown.

**Configuration variables** (at the top of the script):

| Variable | Default | Description |
|----------|---------|-------------|
| `$ShutdownTime` | `"22:00"` | When to shut down the PC (24h format) |
| `$WarningMinutes` | `5` | Minutes of warning before shutdown |
| `$DaysOfWeek` | `Mon-Fri` | Days the task runs |
| `$TaskName` | `"AfterHoursShutdown"` | Scheduled task name |
| `$ExceptionFile` | `$env:ProgramData\YourCompany\shutdown-exception.txt` | Path to exception file |
| `$WarningMessage` | (see script) | Message shown to users |

**Exit codes:**
- `0` — Task created successfully, OR device is exempt
- `1` — Failed to create the task

### Intune Configuration

| Setting | Value |
|---------|-------|
| Detection script | `Detect-ShutdownPolicy.ps1` |
| Remediation script | `Remediate-ShutdownPolicy.ps1` |
| Run as logged-on user | **No** (runs as SYSTEM) |
| 64-bit PowerShell | **Yes** |
| Schedule | Daily |
| Assignment | Start with pilot group, then expand |

## User Experience

When the shutdown task triggers:

1. **At shutdown time minus 5 minutes:** A message box appears: "This PC will shut down in 5 minutes. Please save your work."
2. **Windows also shows:** A system-level shutdown countdown in the notification area.
3. **User can abort:** Open PowerShell or cmd and run `shutdown /a`.
4. **At shutdown time:** If not aborted, the PC shuts down with forced application close.

If no user is logged in, the shutdown proceeds silently (correct behavior).

## Exception Mechanism

To exempt a device from shutdown, create the exception file:

```powershell
# Create exception
$path = "$env:ProgramData\YourCompany"
New-Item -Path $path -ItemType Directory -Force
Set-Content -Path "$path\shutdown-exception.txt" -Value "Monitoring station. Approved by: Jane Doe, 2026-01-15"

# Remove exception
Remove-Item "$env:ProgramData\YourCompany\shutdown-exception.txt" -Force
```

When the exception file exists:
- The detection script reports **compliant** (no remediation triggered).
- The shutdown task's own script also checks for the file before shutting down.

## Troubleshooting

### Task created but shutdown does not happen
- Verify the task is in `Ready` state: `Get-ScheduledTask -TaskName "AfterHoursShutdown"`
- Check the task's last run result: `(Get-ScheduledTaskInfo -TaskName "AfterHoursShutdown").LastTaskResult`
- Verify the PC is on at the scheduled time.

### User did not see the warning
- The `msg.exe` command requires active user sessions. If the screen is locked, the message appears on the lock screen.
- The `shutdown /t 300 /c` command also provides a system-level notification.

### Shutdown aborted repeatedly
- If a user keeps running `shutdown /a`, the task will fire again the next night.
- For persistent cases, discuss with the user or their manager about the policy.

### How to completely remove the shutdown policy
```powershell
Unregister-ScheduledTask -TaskName "AfterHoursShutdown" -Confirm:$false
```
