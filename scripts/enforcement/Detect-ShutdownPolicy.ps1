<#
.SYNOPSIS
    Detects whether the after-hours shutdown scheduled task exists and is active.

.DESCRIPTION
    This script is the DETECTION component of the After-Hours Shutdown Policy
    Intune Proactive Remediation.

    It checks for:
    1. An exception file — if present, the device is exempt and always reports compliant.
    2. The "AfterHoursShutdown" scheduled task — if it exists and is enabled, reports compliant.

    If the task does not exist or is disabled (and no exception file is present), the script
    exits with code 1 (non-compliant), which triggers the remediation script to create the task.

.EXAMPLE
    # Run manually to test:
    powershell.exe -ExecutionPolicy Bypass -File .\Detect-ShutdownPolicy.ps1

.NOTES
    Author:  intune-afterhours-monitor contributors
    Version: 1.0.0
    Date:    2026-03-24
    Context: Intune Proactive Remediation — Detection Script (Enforcement)
    License: MIT

    Exit Codes:
      0 = Compliant (task exists and is enabled, OR device is exempt)
      1 = Non-compliant (task missing or disabled — triggers remediation)
#>

# ============================================================
# CONFIGURATION — Must match the remediation script
# ============================================================

# Name of the shutdown scheduled task
$TaskName = "AfterHoursShutdown"

# Path to the exception file — if this file exists, the device is exempt
# Replace "YourCompany" with your organization name
$ExceptionFile = "$env:ProgramData\YourCompany\shutdown-exception.txt"

# ============================================================
# DETECTION LOGIC
# ============================================================

try {
    # Check 1: Is this device exempt?
    if (Test-Path -Path $ExceptionFile) {
        $exceptionContent = Get-Content -Path $ExceptionFile -Raw -ErrorAction SilentlyContinue
        Write-Output "EXEMPT: Device has an exception file. Reason: $($exceptionContent.Trim())"
        exit 0
    }

    # Check 2: Does the scheduled task exist?
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if ($null -eq $task) {
        Write-Output "NON_COMPLIANT: Scheduled task '$TaskName' does not exist."
        exit 1
    }

    # Check 3: Is the task enabled?
    if ($task.State -eq 'Disabled') {
        Write-Output "NON_COMPLIANT: Scheduled task '$TaskName' exists but is disabled."
        exit 1
    }

    # Task exists and is enabled
    $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
    $lastRun = if ($taskInfo.LastRunTime -and $taskInfo.LastRunTime -ne [datetime]::MinValue) {
        $taskInfo.LastRunTime.ToString('yyyy-MM-dd HH:mm:ss')
    } else {
        "Never"
    }

    Write-Output "COMPLIANT: Scheduled task '$TaskName' exists and is enabled. Last run: $lastRun"
    exit 0
}
catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    # On error, report non-compliant so remediation can attempt to fix
    exit 1
}
