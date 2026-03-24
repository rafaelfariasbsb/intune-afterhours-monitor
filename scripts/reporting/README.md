# Reporting Scripts

## Overview

This folder contains scripts for extracting and analyzing after-hours monitoring data, both locally on individual devices and centrally via the Microsoft Graph API.

## Scripts

### Get-AfterHoursReport.ps1

**Purpose:** Generates a formatted report from the local CSV log on a device.

**Use case:** Run on individual devices for quick analysis, or as part of a remote management session.

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-LogPath` | No | `$env:ProgramData\AfterHoursMonitor\after-hours-log.csv` | Path to the CSV log |
| `-Days` | No | `30` | Number of days to include |
| `-OutputFormat` | No | `Text` | `Text` (console), `CSV`, or `Object` (PowerShell objects) |

**Examples:**

```powershell
# Generate a text report for the last 30 days
.\Get-AfterHoursReport.ps1

# Generate a CSV export for the last 7 days
.\Get-AfterHoursReport.ps1 -Days 7 -OutputFormat CSV > report.csv

# Get PowerShell objects for further processing
$data = .\Get-AfterHoursReport.ps1 -OutputFormat Object
$data.TopUsers | Format-Table
```

**Sample text output:**

```
============================================================
  AFTER-HOURS PC MONITORING REPORT
============================================================

  Device:       PC-SALES-042
  Report range: Last 30 days (2026-02-22 22:00:01 to 2026-03-23 22:00:01)
  Generated:    2026-03-24 09:15:30

------------------------------------------------------------
  SUMMARY
------------------------------------------------------------

  Total nights logged:              22
  Nights with ACTIVE user session:  8 (36.4%)
  Nights with DISCONNECTED session: 3 (13.6%)
  Nights with NO session:           11 (50.0%)
  Nights with query failure:        0

  Average uptime at monitor time:   16.3 hours
  Maximum uptime at monitor time:   48.2 hours

------------------------------------------------------------
  USER FREQUENCY (who leaves the PC on)
------------------------------------------------------------

  User                      Nights     % of Total
  =========================  ==========  ==========
  jsmith                    6          27.3%
  mjones                    3          13.6%
  admin                     2          9.1%
```

---

### Export-IntuneReport.ps1

**Purpose:** Extracts after-hours monitoring data from Intune via the Microsoft Graph API and exports a consolidated CSV report across all devices.

**Use case:** Central reporting for management. Run from an admin workstation with internet access.

**Prerequisites:**

1. **App Registration in Entra ID:**
   - Go to [Entra ID portal](https://entra.microsoft.com) > **App registrations > + New registration**.
   - Name: `intune-afterhours-report` (or any name).
   - Supported account types: Single tenant.
   - No redirect URI needed.

2. **API Permissions:**
   - Add: **Microsoft Graph > Application permissions > DeviceManagementConfiguration.Read.All**
   - Grant admin consent.

3. **Client Secret:**
   - Go to **Certificates & secrets > + New client secret**.
   - Copy the secret value (shown only once).

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-TenantId` | Yes | — | Your Entra ID tenant ID |
| `-ClientId` | Yes | — | App Registration client ID |
| `-ClientSecret` | Yes | — | Client secret value |
| `-ScriptPackageName` | No | `"After-Hours PC Monitor"` | Name of the Proactive Remediation in Intune |
| `-OutputPath` | No | `./after-hours-report-{timestamp}.csv` | Output CSV file path |

**Examples:**

```powershell
# Basic export
.\Export-IntuneReport.ps1 `
    -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -ClientId "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy" `
    -ClientSecret "your-secret-here"

# Using environment variables (recommended)
$env:TENANT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$env:CLIENT_ID = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
$env:CLIENT_SECRET = "your-secret-here"

.\Export-IntuneReport.ps1 `
    -TenantId $env:TENANT_ID `
    -ClientId $env:CLIENT_ID `
    -ClientSecret $env:CLIENT_SECRET `
    -OutputPath "C:\Reports\monthly-report.csv"
```

**Output CSV columns:**

| Column | Description |
|--------|-------------|
| `DeviceName` | Intune device name |
| `Hostname` | Hostname from detection output |
| `LastSync` | Last time the script ran |
| `DetectionState` | Intune detection result |
| `Summary` | Parsed summary line |
| `AvgUptimeHours` | Average uptime from log |
| `Users` | Users found logged in after hours |
| `LogEntries` | Number of log entries |
| `RawOutput` | Full detection script output |

**Security note:** Store the client secret securely. Use environment variables or Azure Key Vault, never hardcode in scripts. The `.gitignore` in this repository excludes `.env` files.

## Troubleshooting

### Export-IntuneReport: "No Proactive Remediation packages found"
- Verify the App Registration has `DeviceManagementConfiguration.Read.All` permission with admin consent.
- Check that the tenant ID, client ID, and client secret are correct.

### Export-IntuneReport: Script package not found
- The `-ScriptPackageName` must exactly match the name in the Intune portal (case-sensitive).
- The script lists all available packages if the specified one is not found.

### Get-AfterHoursReport: "Log file not found"
- The monitoring scheduled task has not run yet. Check: `Get-ScheduledTask -TaskName "AfterHoursMonitor"`
- The detection script must run at least once to create the task, and then the task must trigger at the monitor time.
