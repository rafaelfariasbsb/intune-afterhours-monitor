<#
.SYNOPSIS
    Detects whether a PC is left on after business hours and creates a monitoring scheduled task.

.DESCRIPTION
    This script is designed to run as an Intune Proactive Remediation (detection only).

    On first run, it creates a Windows Scheduled Task ("AfterHoursMonitor") that runs at
    the configured time (default 22:00) on weekdays. The task logs the PC's state (hostname,
    logged-in user, uptime, session state) to a local CSV file.

    On subsequent runs (triggered daily by Intune during business hours), the script:
    1. Ensures the scheduled task exists (recreates if missing).
    2. Reads the CSV log from the previous night.
    3. Outputs a summary to stdout (captured by Intune for reporting).
    4. Prunes log entries older than the retention period.

    This is a MONITORING-ONLY script. It always exits with code 0 (compliant) and makes
    no changes to the system beyond the scheduled task and CSV log.

.EXAMPLE
    # Run manually to test (as Administrator or SYSTEM):
    powershell.exe -ExecutionPolicy Bypass -File .\Detect-AfterHoursPC.ps1

.NOTES
    Author:  intune-afterhours-monitor contributors
    Version: 1.0.0
    Date:    2026-03-24
    Context: Intune Proactive Remediation — Detection Script
    License: MIT

    Exit Codes:
      0 = Always (compliant) — this is monitoring only

    Requirements:
      - Windows 10 20H2+ or Windows 11
      - PowerShell 5.1
      - Runs as SYSTEM (Intune default for Proactive Remediations)
#>

# ============================================================
# CONFIGURATION — Adjust these values for your organization
# ============================================================

# Time to check if the PC is on (24-hour format, device local time)
$MonitorTime = "22:00"

# Name of the scheduled task created on each device
$TaskName = "AfterHoursMonitor"

# Folder for the CSV log file
$LogFolder = "$env:ProgramData\AfterHoursMonitor"

# CSV log file name
$LogFile = "after-hours-log.csv"

# Number of days to retain log entries (older entries are pruned)
$LogRetentionDays = 30

# Days of the week to monitor (scheduled task trigger days)
$DaysOfWeek = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")

# Description for the scheduled task
$TaskDescription = "Logs whether this PC is on after business hours. Part of the After-Hours PC Monitor solution."

# ============================================================
# FUNCTIONS
# ============================================================

function Ensure-LogFolder {
    <#
    .SYNOPSIS
        Creates the log folder if it does not exist.
    #>
    if (-not (Test-Path -Path $LogFolder)) {
        try {
            New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
        }
        catch {
            Write-Output "ERROR: Failed to create log folder: $($_.Exception.Message)"
        }
    }
}

function Ensure-ScheduledTask {
    <#
    .SYNOPSIS
        Creates the monitoring scheduled task if it does not exist or is misconfigured.
    #>
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if ($null -eq $existingTask) {
        try {
            # Build the PowerShell command that the scheduled task will execute
            $logPath = Join-Path -Path $LogFolder -ChildPath $LogFile
            $scriptBlock = @"
`$logPath = '$logPath'
`$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
`$hostname = `$env:COMPUTERNAME
`$loggedUser = ''
`$sessionState = 'NoSession'

# Get active user sessions using query user
try {
    `$queryResult = query user 2>&1
    if (`$queryResult -match 'Active') {
        `$lines = `$queryResult | Where-Object { `$_ -match 'Active' }
        if (`$lines) {
            `$parts = (`$lines[0] -replace '\s{2,}', ',').Split(',')
            `$loggedUser = `$parts[0].Trim().TrimStart('>')
            `$sessionState = 'Active'
        }
    }
    elseif (`$queryResult -match 'Disc') {
        `$lines = `$queryResult | Where-Object { `$_ -match 'Disc' }
        if (`$lines) {
            `$parts = (`$lines[0] -replace '\s{2,}', ',').Split(',')
            `$loggedUser = `$parts[0].Trim().TrimStart('>')
            `$sessionState = 'Disconnected'
        }
    }
}
catch {
    `$sessionState = 'QueryFailed'
}

# Calculate uptime
`$uptime = (New-TimeSpan -Start (Get-CimInstance Win32_OperatingSystem).LastBootUpTime -End (Get-Date)).TotalHours
`$uptimeRounded = [math]::Round(`$uptime, 1)

# Ensure CSV has a header
if (-not (Test-Path `$logPath)) {
    'Timestamp,Hostname,LoggedUser,UptimeHours,SessionState' | Out-File -FilePath `$logPath -Encoding UTF8
}

# Append the log entry
"`$timestamp,`$hostname,`$loggedUser,`$uptimeRounded,`$sessionState" | Out-File -FilePath `$logPath -Append -Encoding UTF8
"@

            $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($scriptBlock))

            # Parse the monitor time
            $timeParts = $MonitorTime.Split(':')
            $hour = [int]$timeParts[0]
            $minute = [int]$timeParts[1]

            # Create the trigger
            $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DaysOfWeek -At ([datetime]::Today.AddHours($hour).AddMinutes($minute))

            # Create the action — run the PowerShell command
            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encodedCommand"

            # Create the principal — run as SYSTEM
            $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

            # Create task settings
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

            # Register the task
            Register-ScheduledTask -TaskName $TaskName -Description $TaskDescription -Trigger $trigger -Action $action -Principal $principal -Settings $settings -Force | Out-Null

            Write-Output "TASK_CREATED: Scheduled task '$TaskName' created successfully (trigger: $MonitorTime, $($DaysOfWeek -join ', '))."
        }
        catch {
            Write-Output "ERROR: Failed to create scheduled task: $($_.Exception.Message)"
        }
    }
    else {
        # Task exists — verify it is enabled
        if ($existingTask.State -eq 'Disabled') {
            try {
                Enable-ScheduledTask -TaskName $TaskName | Out-Null
                Write-Output "TASK_ENABLED: Scheduled task '$TaskName' was disabled and has been re-enabled."
            }
            catch {
                Write-Output "WARNING: Could not re-enable scheduled task: $($_.Exception.Message)"
            }
        }
    }
}

function Prune-OldEntries {
    <#
    .SYNOPSIS
        Removes CSV log entries older than the configured retention period.
    #>
    $logPath = Join-Path -Path $LogFolder -ChildPath $LogFile

    if (-not (Test-Path -Path $logPath)) {
        return
    }

    try {
        $cutoffDate = (Get-Date).AddDays(-$LogRetentionDays)
        $allLines = Get-Content -Path $logPath -Encoding UTF8

        if ($allLines.Count -le 1) {
            return  # Only header or empty
        }

        $header = $allLines[0]
        $dataLines = $allLines | Select-Object -Skip 1 | Where-Object {
            if ($_ -match '^\d{4}-\d{2}-\d{2}') {
                $entryDate = [datetime]::ParseExact($_.Substring(0, 19), 'yyyy-MM-dd HH:mm:ss', $null)
                return $entryDate -ge $cutoffDate
            }
            return $false
        }

        $prunedCount = ($allLines.Count - 1) - ($dataLines | Measure-Object).Count

        if ($prunedCount -gt 0) {
            $header | Out-File -FilePath $logPath -Encoding UTF8
            if ($dataLines) {
                $dataLines | Out-File -FilePath $logPath -Append -Encoding UTF8
            }
        }
    }
    catch {
        # Pruning failure is non-critical — log grows slightly larger but still works
        Write-Output "WARNING: Failed to prune old entries: $($_.Exception.Message)"
    }
}

function Get-LogSummary {
    <#
    .SYNOPSIS
        Reads the CSV log and outputs a summary for Intune to capture.
    #>
    $logPath = Join-Path -Path $LogFolder -ChildPath $LogFile

    if (-not (Test-Path -Path $logPath)) {
        Write-Output "STATUS: No log file found. The monitoring task has not run yet (runs at $MonitorTime)."
        Write-Output "HOSTNAME: $env:COMPUTERNAME"
        return
    }

    try {
        $entries = Import-Csv -Path $logPath -Encoding UTF8

        if ($entries.Count -eq 0) {
            Write-Output "STATUS: Log file exists but has no entries. Waiting for first scheduled run at $MonitorTime."
            Write-Output "HOSTNAME: $env:COMPUTERNAME"
            return
        }

        # Calculate statistics
        $totalNights = $entries.Count
        $withActiveUser = ($entries | Where-Object { $_.SessionState -eq 'Active' }).Count
        $disconnected = ($entries | Where-Object { $_.SessionState -eq 'Disconnected' }).Count
        $noSession = ($entries | Where-Object { $_.SessionState -eq 'NoSession' }).Count
        $queryFailed = ($entries | Where-Object { $_.SessionState -eq 'QueryFailed' }).Count

        # Get unique users
        $uniqueUsers = ($entries | Where-Object { $_.LoggedUser -ne '' } | Select-Object -ExpandProperty LoggedUser -Unique) -join ', '
        if (-not $uniqueUsers) { $uniqueUsers = "(none)" }

        # Average uptime
        $avgUptime = [math]::Round(($entries | ForEach-Object { [double]$_.UptimeHours } | Measure-Object -Average).Average, 1)

        # Output summary (captured by Intune)
        Write-Output "HOSTNAME: $env:COMPUTERNAME"
        Write-Output "SUMMARY: $totalNights nights logged | Active: $withActiveUser | Disconnected: $disconnected | NoSession: $noSession | QueryFailed: $queryFailed"
        Write-Output "AVG_UPTIME: $avgUptime hours"
        Write-Output "USERS: $uniqueUsers"
        Write-Output "MONITOR_TIME: $MonitorTime"
        Write-Output "LOG_ENTRIES: $totalNights"

        # Output last 7 entries for quick review
        Write-Output "--- LAST 7 ENTRIES ---"
        $entries | Select-Object -Last 7 | ForEach-Object {
            Write-Output "$($_.Timestamp) | User: $($_.LoggedUser) | Uptime: $($_.UptimeHours)h | State: $($_.SessionState)"
        }
    }
    catch {
        Write-Output "ERROR: Failed to read log file: $($_.Exception.Message)"
        Write-Output "HOSTNAME: $env:COMPUTERNAME"
    }
}

# ============================================================
# MAIN EXECUTION
# ============================================================

try {
    # Step 1: Ensure the log folder exists
    Ensure-LogFolder

    # Step 2: Ensure the scheduled task exists
    Ensure-ScheduledTask

    # Step 3: Prune old log entries
    Prune-OldEntries

    # Step 4: Output summary for Intune
    Get-LogSummary
}
catch {
    Write-Output "CRITICAL_ERROR: $($_.Exception.Message)"
}

# Always exit 0 (compliant) — this is monitoring only
exit 0
