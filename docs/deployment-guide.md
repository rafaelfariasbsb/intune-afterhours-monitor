# Deployment Guide

Step-by-step instructions for deploying the After-Hours PC Monitor via Microsoft Intune.

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Create Proactive Remediation — Monitoring](#2-create-proactive-remediation--monitoring)
3. [Upload Detection Script](#3-upload-detection-script)
4. [Configure Schedule](#4-configure-schedule)
5. [Assign to Pilot Group](#5-assign-to-pilot-group)
6. [Validate Deployment](#6-validate-deployment)
7. [Read Results](#7-read-results)
8. [Expand to All Devices](#8-expand-to-all-devices)
9. [Deploy Enforcement (Shutdown Policy)](#9-deploy-enforcement-shutdown-policy)
10. [Configure Exceptions](#10-configure-exceptions)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Prerequisites

Before deploying, verify:

- [ ] **Intune license** — Microsoft Intune Plan 1 or higher (included in M365 E3/E5/Business Premium)
- [ ] **Proactive Remediations enabled** — Go to **Reports > Endpoint analytics** and verify the feature is available
- [ ] **Devices enrolled** — Target devices must be enrolled in Intune and Entra ID joined (or Hybrid joined)
- [ ] **Windows 10 20H2+** or **Windows 11** on target devices
- [ ] **Admin access** — You need Intune Administrator or Endpoint Analytics Administrator role
- [ ] **Entra ID group** for pilot (recommended: IT department, 10-20 devices)

### Create a Pilot Group

1. Go to [Entra ID portal](https://entra.microsoft.com) > **Groups > All groups**.
2. Click **+ New group**.
3. Type: **Security**, Name: `intune-afterhours-pilot`.
4. Add 10-20 devices from the IT department.
5. Click **Create**.

> **Tip:** Use a dynamic device group with a query like `(device.department -eq "IT")` for automatic membership.

---

## 2. Create Proactive Remediation — Monitoring

1. Open the [Intune portal](https://intune.microsoft.com).
2. Navigate to **Devices > Remediations** (previously under Reports > Endpoint analytics > Proactive remediations).
3. Click **+ Create script package**.
4. Fill in the basics:
   - **Name:** `After-Hours PC Monitor`
   - **Description:** `Monitors whether PCs are left on after business hours (22:00). Creates a local scheduled task that logs activity to CSV. Detection only — no changes to the device.`
   - **Publisher:** Your organization name

<!-- ![Create Script Package](images/create-script-package.png) -->

5. Click **Next**.

---

## 3. Upload Detection Script

1. On the **Settings** page:
   - **Detection script file:** Upload `scripts/monitoring/Detect-AfterHoursPC.ps1`
   - **Remediation script file:** Leave empty (this is monitoring only)
   - **Run this script using the logged-on credentials:** **No** (runs as SYSTEM)
   - **Enforce script signature check:** **No** (unless you sign your scripts)
   - **Run script in 64-bit PowerShell:** **Yes**

<!-- ![Script Settings](images/script-settings.png) -->

2. Click **Next**.

### Before Uploading: Configure Variables

Open `Detect-AfterHoursPC.ps1` and review the configuration section at the top:

```powershell
# ============================================================
# CONFIGURATION — Adjust these values for your organization
# ============================================================
$MonitorTime      = "22:00"          # Time to check if PC is on (24h format)
$TaskName         = "AfterHoursMonitor"
$LogFolder        = "$env:ProgramData\AfterHoursMonitor"
$LogFile          = "after-hours-log.csv"
$LogRetentionDays = 30               # Days to keep log entries
$DaysOfWeek       = @("Monday","Tuesday","Wednesday","Thursday","Friday")
```

Adjust `$MonitorTime` to match your organization's closing time. The default is 22:00 (10 PM).

---

## 4. Configure Schedule

1. On the **Assignments** page (after scope tags), configure the schedule:
   - **Frequency:** Daily
   - **Recurrence:** Every 1 day
   - **Time:** Pick a time during business hours (e.g., 09:00 AM) — this is when Intune *runs the detection script*, not when the monitoring happens. The detection script checks the CSV that was written at 22:00 the night before.

> **Important:** The Intune schedule is for running the detection script that *reads* the log. The actual monitoring happens via a scheduled task created by the script that runs at the configured `$MonitorTime`.

2. Click **Next**.

---

## 5. Assign to Pilot Group

1. On the **Assignments** page:
   - **Included groups:** Click **+ Add groups** and select `intune-afterhours-pilot`.
   - **Excluded groups:** Leave empty for now.

<!-- ![Assign to Group](images/assign-group.png) -->

2. Click **Next**, review the summary, and click **Create**.

---

## 6. Validate Deployment

After 24-48 hours, verify the solution is working:

### Check in Intune Portal

1. Go to **Devices > Remediations**.
2. Click on `After-Hours PC Monitor`.
3. Go to the **Device status** tab.
4. You should see devices reporting with:
   - **Detection status:** `With issues` or `Without issues`
   - **Pre-remediation output:** Text showing the monitoring results

### Check on a Device (Optional)

RDP or walk up to a pilot device and verify:

1. **Scheduled Task exists:**
   ```powershell
   Get-ScheduledTask -TaskName "AfterHoursMonitor" | Format-List TaskName, State, LastRunTime
   ```

2. **CSV log is being written:**
   ```powershell
   Get-Content "$env:ProgramData\AfterHoursMonitor\after-hours-log.csv" | Select-Object -Last 5
   ```

3. **Log folder exists:**
   ```powershell
   Test-Path "$env:ProgramData\AfterHoursMonitor"
   ```

---

## 7. Read Results

### In the Intune Portal

The detection script outputs a summary to stdout, which Intune captures. To view:

1. Go to **Devices > Remediations > After-Hours PC Monitor > Device status**.
2. Click on any device to see its **Pre-remediation detection output**.
3. The output includes:
   - Number of nights logged
   - Number of nights the PC was on with a user logged in
   - Number of nights the PC was on with no active session
   - Last 7 entries from the log

### Export Data

For a consolidated report across all devices, use the Graph API export script:

```powershell
.\scripts\reporting\Export-IntuneReport.ps1 -TenantId "your-tenant-id" -ClientId "your-app-id" -ClientSecret "your-secret"
```

See [scripts/reporting/README.md](../scripts/reporting/README.md) for details.

---

## 8. Expand to All Devices

Once you have validated the pilot (typically after 2 weeks):

1. Go to **Devices > Remediations > After-Hours PC Monitor**.
2. Click **Properties > Assignments > Edit**.
3. Change **Included groups** from the pilot group to **All devices** (or a broader group).
4. Add any exclusion groups (servers, kiosks, conference room PCs).
5. Click **Review + save**.

---

## 9. Deploy Enforcement (Shutdown Policy)

> **Only proceed after you have monitoring data and management approval.**

### Create a Second Proactive Remediation

1. Go to **Devices > Remediations > + Create script package**.
2. Fill in:
   - **Name:** `After-Hours Shutdown Policy`
   - **Description:** `Ensures a scheduled task exists to shut down PCs at 22:00 on weekdays. Shows a 5-minute warning toast notification before shutdown.`
3. Upload scripts:
   - **Detection script:** `scripts/enforcement/Detect-ShutdownPolicy.ps1`
   - **Remediation script:** `scripts/enforcement/Remediate-ShutdownPolicy.ps1`
   - **Run this script using the logged-on credentials:** **No**
   - **Run script in 64-bit PowerShell:** **Yes**
4. Schedule: **Daily**, once per day.
5. Assign to `intune-afterhours-pilot` first.
6. After 1-2 weeks of successful pilot, expand to all devices.

### Before Uploading: Configure Variables

Review both enforcement scripts and adjust:

```powershell
$ShutdownTime    = "22:00"    # When to shut down (24h format)
$WarningMinutes  = 5          # Minutes of warning before shutdown
$DaysOfWeek      = @("Monday","Tuesday","Wednesday","Thursday","Friday")
$ExceptionFile   = "$env:ProgramData\YourCompany\shutdown-exception.txt"
```

---

## 10. Configure Exceptions

Some PCs need to stay on (monitoring stations, build servers, etc.). The enforcement script checks for an exception file.

### To Exempt a Device

Create the exception file on the device:

```powershell
# Run as Administrator on the device to exempt
$exceptionPath = "$env:ProgramData\YourCompany"
New-Item -Path $exceptionPath -ItemType Directory -Force
Set-Content -Path "$exceptionPath\shutdown-exception.txt" -Value "Exempted: Monitoring station. Approved by: John Doe, 2026-01-15"
```

Or deploy via Intune as a PowerShell script targeted at a group of exempt devices.

### To Remove an Exemption

```powershell
Remove-Item "$env:ProgramData\YourCompany\shutdown-exception.txt" -Force
```

---

## 11. Troubleshooting

### Scheduled Task Not Created

**Symptom:** The CSV log file does not exist after 24 hours.

**Cause:** The detection script may not have run yet, or it failed to create the task.

**Fix:**
1. Check the Intune Management Extension log:
   ```
   C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AgentExecutor.log
   ```
2. Look for errors related to `AfterHoursMonitor`.
3. Try running the detection script manually as SYSTEM (use `psexec -s powershell`).

### Detection Script Shows No Data

**Symptom:** Intune shows the script ran, but the output says "No log entries found."

**Cause:** The scheduled task has not yet run (it runs at 22:00).

**Fix:** Wait until after the configured monitor time. The first data point will appear the next morning.

### Shutdown Not Working

**Symptom:** The remediation script deployed, but PCs are not shutting down.

**Causes and fixes:**
- **Task disabled:** Check `Get-ScheduledTask -TaskName "AfterHoursShutdown"` — verify State is `Ready`.
- **Exception file present:** Check `Test-Path "$env:ProgramData\YourCompany\shutdown-exception.txt"`.
- **Time zone issue:** The scheduled task uses the device's local time zone. Verify it is correct.
- **Group Policy conflict:** A GPO may be overriding the scheduled task. Check `gpresult /r`.

### User Did Not See Warning Toast

**Symptom:** PC shut down without the 5-minute warning.

**Cause:** The toast notification requires an active user session. If no user is logged in, the shutdown proceeds silently (which is the desired behavior — no user means no work to save).

### Script Execution Policy

**Symptom:** Script fails with "execution policy" error.

**Fix:** Intune Proactive Remediations bypass the local execution policy by design. If running manually, use:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### High CPU or Disk Usage

**Symptom:** The monitoring script causes performance issues.

**Fix:** The scripts are lightweight and should not cause performance issues. If they do:
1. Check the CSV file size — it should be small (30 days of daily entries).
2. Verify `$LogRetentionDays` is set (default: 30). Old entries are pruned on each run.

---

## Next Steps

- Read the [Rollout Plan](rollout-plan.md) for a complete phased approach
- Use the [Email Templates](templates/) to communicate with stakeholders
- Check the [FAQ](faq.md) for common questions
- Review the [Architecture](architecture.md) for technical details
