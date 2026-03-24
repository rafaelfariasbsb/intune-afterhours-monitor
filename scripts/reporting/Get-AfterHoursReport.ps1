<#
.SYNOPSIS
    Generates a formatted report from the local after-hours monitoring CSV log.

.DESCRIPTION
    Reads the CSV log file created by the AfterHoursMonitor scheduled task and produces
    a formatted summary report. This script is intended to be run locally on a device
    for quick analysis, or used as a building block for centralized reporting.

    The report includes:
    - Total nights logged and date range
    - Breakdown by session state (Active, Disconnected, NoSession)
    - User frequency ranking (who leaves their PC on most)
    - Average uptime at monitor time
    - Daily detail view

.PARAMETER LogPath
    Path to the CSV log file. Defaults to the standard location.

.PARAMETER Days
    Number of days to include in the report. Defaults to 30.

.PARAMETER OutputFormat
    Output format: "Text" (console), "CSV" (exportable), or "Object" (PowerShell objects).
    Defaults to "Text".

.EXAMPLE
    .\Get-AfterHoursReport.ps1
    Generates a text report for the last 30 days from the default log location.

.EXAMPLE
    .\Get-AfterHoursReport.ps1 -Days 7 -OutputFormat CSV
    Generates a CSV-formatted report for the last 7 days.

.EXAMPLE
    .\Get-AfterHoursReport.ps1 -LogPath "C:\Temp\after-hours-log.csv" -Days 14
    Reads from a custom log path and reports on the last 14 days.

.NOTES
    Author:  intune-afterhours-monitor contributors
    Version: 1.0.0
    Date:    2026-03-24
    Context: Local reporting script (run on individual devices)
    License: MIT
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "$env:ProgramData\AfterHoursMonitor\after-hours-log.csv",

    [Parameter(Mandatory = $false)]
    [int]$Days = 30,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Text", "CSV", "Object")]
    [string]$OutputFormat = "Text"
)

# ============================================================
# VALIDATION
# ============================================================

if (-not (Test-Path -Path $LogPath)) {
    Write-Error "Log file not found: $LogPath"
    Write-Error "The monitoring scheduled task may not have run yet. Check: Get-ScheduledTask -TaskName 'AfterHoursMonitor'"
    exit 1
}

# ============================================================
# READ AND FILTER DATA
# ============================================================

try {
    $allEntries = Import-Csv -Path $LogPath -Encoding UTF8
}
catch {
    Write-Error "Failed to read CSV file: $($_.Exception.Message)"
    exit 1
}

if ($allEntries.Count -eq 0) {
    Write-Warning "Log file exists but contains no entries."
    exit 0
}

# Filter to requested date range
$cutoffDate = (Get-Date).AddDays(-$Days)
$entries = $allEntries | Where-Object {
    try {
        $entryDate = [datetime]::ParseExact($_.Timestamp, 'yyyy-MM-dd HH:mm:ss', $null)
        return $entryDate -ge $cutoffDate
    }
    catch { return $false }
}

if ($entries.Count -eq 0) {
    Write-Warning "No entries found within the last $Days days."
    exit 0
}

# ============================================================
# CALCULATE STATISTICS
# ============================================================

$totalNights = $entries.Count
$firstEntry = ($entries | Select-Object -First 1).Timestamp
$lastEntry = ($entries | Select-Object -Last 1).Timestamp

$activeCount = ($entries | Where-Object { $_.SessionState -eq 'Active' }).Count
$disconnectedCount = ($entries | Where-Object { $_.SessionState -eq 'Disconnected' }).Count
$noSessionCount = ($entries | Where-Object { $_.SessionState -eq 'NoSession' }).Count
$queryFailedCount = ($entries | Where-Object { $_.SessionState -eq 'QueryFailed' }).Count

$avgUptime = [math]::Round(($entries | ForEach-Object { [double]$_.UptimeHours } | Measure-Object -Average).Average, 1)
$maxUptime = [math]::Round(($entries | ForEach-Object { [double]$_.UptimeHours } | Measure-Object -Maximum).Maximum, 1)

# User frequency ranking
$userStats = $entries | Where-Object { $_.LoggedUser -ne '' } |
    Group-Object -Property LoggedUser |
    Sort-Object -Property Count -Descending |
    Select-Object @{N = 'User'; E = { $_.Name } }, Count, @{N = 'Percentage'; E = { [math]::Round(($_.Count / $totalNights) * 100, 1) } }

# ============================================================
# OUTPUT
# ============================================================

switch ($OutputFormat) {
    "Object" {
        [PSCustomObject]@{
            Hostname         = $env:COMPUTERNAME
            ReportDays       = $Days
            TotalNights      = $totalNights
            FirstEntry       = $firstEntry
            LastEntry        = $lastEntry
            ActiveSessions   = $activeCount
            Disconnected     = $disconnectedCount
            NoSession        = $noSessionCount
            QueryFailed      = $queryFailedCount
            AvgUptimeHours   = $avgUptime
            MaxUptimeHours   = $maxUptime
            TopUsers         = $userStats
            Entries          = $entries
        }
    }

    "CSV" {
        $entries | ConvertTo-Csv -NoTypeInformation
    }

    "Text" {
        Write-Output ""
        Write-Output "============================================================"
        Write-Output "  AFTER-HOURS PC MONITORING REPORT"
        Write-Output "============================================================"
        Write-Output ""
        Write-Output "  Device:       $env:COMPUTERNAME"
        Write-Output "  Report range: Last $Days days ($firstEntry to $lastEntry)"
        Write-Output "  Generated:    $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Output ""
        Write-Output "------------------------------------------------------------"
        Write-Output "  SUMMARY"
        Write-Output "------------------------------------------------------------"
        Write-Output ""
        Write-Output "  Total nights logged:              $totalNights"
        Write-Output "  Nights with ACTIVE user session:  $activeCount ($([math]::Round(($activeCount/$totalNights)*100,1))%)"
        Write-Output "  Nights with DISCONNECTED session: $disconnectedCount ($([math]::Round(($disconnectedCount/$totalNights)*100,1))%)"
        Write-Output "  Nights with NO session:           $noSessionCount ($([math]::Round(($noSessionCount/$totalNights)*100,1))%)"
        Write-Output "  Nights with query failure:        $queryFailedCount"
        Write-Output ""
        Write-Output "  Average uptime at monitor time:   $avgUptime hours"
        Write-Output "  Maximum uptime at monitor time:   $maxUptime hours"
        Write-Output ""

        if ($userStats -and $userStats.Count -gt 0) {
            Write-Output "------------------------------------------------------------"
            Write-Output "  USER FREQUENCY (who leaves the PC on)"
            Write-Output "------------------------------------------------------------"
            Write-Output ""
            Write-Output "  {0,-25} {1,-10} {2,-10}" -f "User", "Nights", "% of Total"
            Write-Output "  {0,-25} {1,-10} {2,-10}" -f ("=" * 25), ("=" * 10), ("=" * 10)
            foreach ($user in $userStats) {
                Write-Output "  {0,-25} {1,-10} {2,-10}" -f $user.User, $user.Count, "$($user.Percentage)%"
            }
            Write-Output ""
        }

        Write-Output "------------------------------------------------------------"
        Write-Output "  DAILY LOG (last $Days days)"
        Write-Output "------------------------------------------------------------"
        Write-Output ""
        Write-Output "  {0,-22} {1,-18} {2,-12} {3,-15}" -f "Timestamp", "User", "Uptime (h)", "Session State"
        Write-Output "  {0,-22} {1,-18} {2,-12} {3,-15}" -f ("=" * 22), ("=" * 18), ("=" * 12), ("=" * 15)
        foreach ($entry in $entries) {
            $user = if ($entry.LoggedUser) { $entry.LoggedUser } else { "(none)" }
            Write-Output "  {0,-22} {1,-18} {2,-12} {3,-15}" -f $entry.Timestamp, $user, $entry.UptimeHours, $entry.SessionState
        }

        Write-Output ""
        Write-Output "============================================================"
        Write-Output "  Report generated by intune-afterhours-monitor"
        Write-Output "  https://github.com/your-org/intune-afterhours-monitor"
        Write-Output "============================================================"
        Write-Output ""
    }
}
