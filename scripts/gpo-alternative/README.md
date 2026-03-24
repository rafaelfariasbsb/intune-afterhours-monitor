# GPO Alternative

## Overview

This folder contains a script for organizations that do not have Microsoft Intune but want to deploy the after-hours PC shutdown policy via **Active Directory Group Policy Objects (GPO)**.

## Scripts

### Create-ShutdownGPO.ps1

**Purpose:** Creates a GPO that deploys a Windows Scheduled Task to shut down PCs after business hours.

**How it works:**
1. Creates a new GPO with the specified name.
2. Links the GPO to the target Organizational Unit (OU).
3. Configures a GPP (Group Policy Preferences) Scheduled Task that:
   - Triggers at the warning time (shutdown time minus warning minutes).
   - Runs `shutdown.exe /s /f /t 300 /c "message"` to warn and then shut down.
   - Runs as SYSTEM.
   - Triggers on configured weekdays.

**Prerequisites:**
- Active Directory domain
- RSAT installed (GroupPolicy and ActiveDirectory PowerShell modules)
- Domain Admin or Group Policy Creator Owners membership
- Run from a domain-joined workstation or server

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-GPOName` | No | `"After-Hours PC Shutdown"` | Name of the GPO |
| `-ShutdownTime` | No | `"22:00"` | Shutdown time (24h format) |
| `-WarningMinutes` | No | `5` | Minutes of warning |
| `-TargetOU` | **Yes** | — | DN of the target OU |
| `-TaskName` | No | `"AfterHoursShutdown"` | Name of the scheduled task |
| `-DaysOfWeek` | No | `Mon-Fri` | Days the task runs |
| `-WhatIf` | No | — | Preview mode (no changes) |

**Examples:**

```powershell
# Preview what the script will do
.\Create-ShutdownGPO.ps1 -TargetOU "OU=Workstations,DC=contoso,DC=com" -WhatIf

# Create the GPO with default settings (22:00, Mon-Fri, 5 min warning)
.\Create-ShutdownGPO.ps1 -TargetOU "OU=Workstations,DC=contoso,DC=com"

# Custom settings
.\Create-ShutdownGPO.ps1 `
    -GPOName "Corporate Shutdown Policy" `
    -ShutdownTime "21:00" `
    -WarningMinutes 10 `
    -TargetOU "OU=Computers,OU=Corp,DC=contoso,DC=com"
```

## Intune vs. GPO Comparison

| Feature | Intune | GPO |
|---------|--------|-----|
| **Requires** | Intune license + Entra ID join | AD domain + RSAT |
| **Monitoring** | Built-in via Proactive Remediations | Manual (no centralized reporting) |
| **Exception mechanism** | Exception file + Intune exclusion groups | Move device to a different OU |
| **Reporting** | Intune portal + Graph API export | Event Viewer / manual checks |
| **Remote devices** | Works over internet (Intune agent) | Only on-network (domain reachability) |
| **Rollback** | Remove Intune assignment | Remove GPO + gpupdate |
| **Hybrid devices** | Works (if Intune-managed) | Works |
| **Cloud-only devices** | Works | Does not apply |

## Rollback

To remove the shutdown GPO:

```powershell
# Remove the GPO (also removes the link)
Remove-GPO -Name "After-Hours PC Shutdown"

# Force policy update on affected machines (or wait for next GP refresh)
# Run on each machine, or use Invoke-GPUpdate remotely:
Invoke-GPUpdate -Computer "PC-NAME" -Force
```

The scheduled task will be removed from devices on the next Group Policy refresh (default: every 90 minutes, or immediately with `gpupdate /force`).

## Limitations

- **No centralized reporting.** Unlike Intune, GPO does not provide a dashboard showing which devices are compliant. You would need to collect data manually or via a separate monitoring solution.
- **Network-dependent.** The GPO only applies when the device can reach a domain controller. Devices off-network (e.g., remote workers) will not receive updates.
- **OU-based targeting.** Exceptions require moving devices to a different OU, which is less flexible than Intune's group-based assignments.
