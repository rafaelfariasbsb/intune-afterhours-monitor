<#
.SYNOPSIS
    Creates a scheduled task to shut down the PC after business hours with a user warning.

.DESCRIPTION
    This script is the REMEDIATION component of the After-Hours Shutdown Policy
    Intune Proactive Remediation.

    It creates a Windows Scheduled Task ("AfterHoursShutdown") that:
    1. Runs at the configured time (default 22:00) on weekdays.
    2. Displays a toast notification warning the user that the PC will shut down.
    3. Waits for the configured warning period (default 5 minutes).
    4. Executes a forced shutdown (shutdown /s /f /t 0).

    The script also checks for an exception file — if present, it does NOT create the task
    and exits with code 0 (success, device is exempt).

    The task runs as SYSTEM and persists across reboots.

.EXAMPLE
    # Run manually to test (as Administrator):
    powershell.exe -ExecutionPolicy Bypass -File .\Remediate-ShutdownPolicy.ps1

.NOTES
    Author:  intune-afterhours-monitor contributors
    Version: 1.0.0
    Date:    2026-03-24
    Context: Intune Proactive Remediation — Remediation Script (Enforcement)
    License: MIT

    Exit Codes:
      0 = Success (task created, or device is exempt)
      1 = Failure (could not create the task)
#>

# ============================================================
# CONFIGURATION — Adjust these values for your organization
# ============================================================

# Time to shut down the PC (24-hour format, device local time)
$ShutdownTime = "22:00"

# Minutes of warning before shutdown (toast notification is shown this many minutes early)
$WarningMinutes = 5

# Days of the week the shutdown task runs
$DaysOfWeek = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")

# Name of the scheduled task
$TaskName = "AfterHoursShutdown"

# Path to the exception file — if this file exists, skip creating the shutdown task
# Replace "YourCompany" with your organization name
$ExceptionFile = "$env:ProgramData\YourCompany\shutdown-exception.txt"

# Description for the scheduled task
$TaskDescription = "Shuts down this PC after business hours with a 5-minute user warning. Part of the After-Hours Shutdown Policy."

# Warning message shown to the user
$WarningTitle = "Automatic Shutdown"
$WarningMessage = "This PC will shut down in $WarningMinutes minutes. Please save your work.`n`nTo cancel: open PowerShell and run 'shutdown /a'"

# ============================================================
# MAIN LOGIC
# ============================================================

try {
    # Check for exception file
    if (Test-Path -Path $ExceptionFile) {
        $exceptionContent = Get-Content -Path $ExceptionFile -Raw -ErrorAction SilentlyContinue
        Write-Output "EXEMPT: Device has an exception file. Skipping task creation. Reason: $($exceptionContent.Trim())"
        exit 0
    }

    # Remove existing task if present (to ensure clean configuration)
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -ne $existingTask) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    }

    # Parse the shutdown time
    $timeParts = $ShutdownTime.Split(':')
    $hour = [int]$timeParts[0]
    $minute = [int]$timeParts[1]

    # Calculate the warning time (shutdown time minus warning minutes)
    $shutdownDateTime = [datetime]::Today.AddHours($hour).AddMinutes($minute)
    $warningDateTime = $shutdownDateTime.AddMinutes(-$WarningMinutes)
    $warningTimeStr = $warningDateTime.ToString("HH:mm")

    # Build the PowerShell script that the scheduled task will execute
    # This script shows a toast notification, waits, then shuts down
    $shutdownScript = @"
# After-Hours Shutdown Script
# Shows a toast notification, waits, then shuts down the PC

`$WarningMinutes = $WarningMinutes
`$WarningTitle = '$($WarningTitle -replace "'", "''")'
`$WarningMessage = '$($WarningMessage -replace "'", "''")'

# Check for exception file before proceeding
if (Test-Path '$ExceptionFile') {
    exit 0
}

# Show toast notification to the active user (if any)
try {
    # Method 1: Use msg.exe to send a message to all sessions
    `$sessions = query user 2>&1
    if (`$LASTEXITCODE -eq 0 -and `$sessions) {
        # There are user sessions — show the warning
        msg * /TIME:$($WarningMinutes * 60) "`$WarningMessage"
    }
}
catch {
    # If msg.exe fails, try BurntToast or fall back to shutdown timer
    # The shutdown /t flag below also provides a system-level warning
}

# Also initiate shutdown with timer (provides a system-level countdown)
# This gives users the full warning period to save work and run 'shutdown /a' to abort
shutdown /s /f /t $($WarningMinutes * 60) /c "`$WarningMessage" /d p:0:0
"@

    $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($shutdownScript))

    # Create the trigger — run at the warning time (warning period before actual shutdown)
    # The script itself handles the countdown via shutdown /t
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DaysOfWeek -At $warningDateTime

    # Create the action — run the PowerShell shutdown script
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand $encodedCommand"

    # Create the principal — run as SYSTEM with highest privileges
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    # Create task settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 15) `
        -WakeToRun

    # Register the task
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Description $TaskDescription `
        -Trigger $trigger `
        -Action $action `
        -Principal $principal `
        -Settings $settings `
        -Force | Out-Null

    # Verify the task was created
    $verifyTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if ($null -ne $verifyTask) {
        Write-Output "SUCCESS: Scheduled task '$TaskName' created. Warning at $warningTimeStr, shutdown at $ShutdownTime ($($DaysOfWeek -join ', '))."
        exit 0
    }
    else {
        Write-Output "FAILED: Scheduled task '$TaskName' was not created. Unknown error."
        exit 1
    }
}
catch {
    Write-Output "ERROR: Failed to create scheduled task: $($_.Exception.Message)"
    exit 1
}
