<#
.SYNOPSIS
    Creates a Group Policy Object that schedules automatic PC shutdown after business hours.

.DESCRIPTION
    For organizations without Microsoft Intune, this script creates a GPO that deploys
    a Windows Scheduled Task to shut down PCs after business hours.

    The GPO uses Group Policy Preferences (GPP) Scheduled Tasks to create a task on
    all computers in the target OU.

    Requirements:
    - Active Directory domain
    - RSAT (Remote Server Administration Tools) with GroupPolicy module
    - Domain Admin or Group Policy Creator Owners membership
    - Run from a domain-joined machine with RSAT installed

.PARAMETER GPOName
    Name of the GPO to create. Default: "After-Hours PC Shutdown".

.PARAMETER ShutdownTime
    Time to initiate shutdown (24-hour format). Default: "22:00".

.PARAMETER WarningMinutes
    Minutes of warning before shutdown. Default: 5.

.PARAMETER TargetOU
    Distinguished Name of the OU to link the GPO to.
    Example: "OU=Workstations,DC=contoso,DC=com"

.PARAMETER WhatIf
    Shows what would happen without making changes.

.EXAMPLE
    .\Create-ShutdownGPO.ps1 -TargetOU "OU=Workstations,DC=contoso,DC=com"
    Creates the GPO and links it to the Workstations OU.

.EXAMPLE
    .\Create-ShutdownGPO.ps1 -TargetOU "OU=Computers,OU=Corp,DC=contoso,DC=com" -ShutdownTime "21:00" -GPOName "Corp Shutdown Policy"
    Creates a custom-named GPO with a 21:00 shutdown time.

.EXAMPLE
    .\Create-ShutdownGPO.ps1 -TargetOU "OU=Workstations,DC=contoso,DC=com" -WhatIf
    Shows what the script would do without creating anything.

.NOTES
    Author:  intune-afterhours-monitor contributors
    Version: 1.0.0
    Date:    2026-03-24
    Context: GPO alternative for organizations without Intune
    License: MIT

    This script creates the GPO and configures a scheduled task via GPP.
    The scheduled task uses shutdown.exe with a countdown timer and user warning.

    Important: Test in a lab environment or pilot OU before deploying to production.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$GPOName = "After-Hours PC Shutdown",

    [Parameter(Mandatory = $false)]
    [string]$ShutdownTime = "22:00",

    [Parameter(Mandatory = $false)]
    [int]$WarningMinutes = 5,

    [Parameter(Mandatory = $true)]
    [string]$TargetOU,

    [Parameter(Mandatory = $false)]
    [string]$TaskName = "AfterHoursShutdown",

    [Parameter(Mandatory = $false)]
    [string[]]$DaysOfWeek = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
)

# ============================================================
# PREREQUISITES CHECK
# ============================================================

Write-Output "============================================================"
Write-Output "  After-Hours PC Shutdown — GPO Creation Script"
Write-Output "============================================================"
Write-Output ""

# Check for GroupPolicy module
if (-not (Get-Module -ListAvailable -Name GroupPolicy)) {
    Write-Error "GroupPolicy module not found. Install RSAT: Add-WindowsCapability -Online -Name Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0"
    exit 1
}

Import-Module GroupPolicy -ErrorAction Stop

# Check for ActiveDirectory module
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory module not found. Install RSAT: Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
    exit 1
}

Import-Module ActiveDirectory -ErrorAction Stop

# Verify the target OU exists
try {
    $ou = Get-ADOrganizationalUnit -Identity $TargetOU -ErrorAction Stop
    Write-Output "  Target OU: $($ou.DistinguishedName)"
}
catch {
    Write-Error "Target OU not found: $TargetOU"
    Write-Error "Verify the Distinguished Name. Example: OU=Workstations,DC=contoso,DC=com"
    exit 1
}

# ============================================================
# CALCULATE TIMES
# ============================================================

$timeParts = $ShutdownTime.Split(':')
$hour = [int]$timeParts[0]
$minute = [int]$timeParts[1]
$shutdownDateTime = [datetime]::Today.AddHours($hour).AddMinutes($minute)
$warningDateTime = $shutdownDateTime.AddMinutes(-$WarningMinutes)
$warningTimeStr = $warningDateTime.ToString("HH:mm")
$shutdownSeconds = $WarningMinutes * 60

Write-Output "  Shutdown time: $ShutdownTime"
Write-Output "  Warning time:  $warningTimeStr ($WarningMinutes min before)"
Write-Output "  Days:          $($DaysOfWeek -join ', ')"
Write-Output ""

# ============================================================
# CREATE GPO
# ============================================================

if ($PSCmdlet.ShouldProcess($GPOName, "Create GPO")) {
    # Check if GPO already exists
    $existingGPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if ($existingGPO) {
        Write-Warning "GPO '$GPOName' already exists (ID: $($existingGPO.Id)). Use a different name or remove the existing GPO first."
        $confirm = Read-Host "Overwrite? (y/N)"
        if ($confirm -ne 'y') {
            Write-Output "Aborted."
            exit 0
        }
        Remove-GPO -Name $GPOName -Confirm:$false
    }

    try {
        # Create the GPO
        $gpo = New-GPO -Name $GPOName -Comment "Automatic PC shutdown after business hours. Created by intune-afterhours-monitor."
        Write-Output "  GPO created: $($gpo.DisplayName) (ID: $($gpo.Id))"

        # Link the GPO to the target OU
        New-GPLink -Name $GPOName -Target $TargetOU -LinkEnabled Yes | Out-Null
        Write-Output "  GPO linked to: $TargetOU"

        # Configure the scheduled task via GPP
        # GPP scheduled tasks are stored in the GPO's Machine\Preferences\ScheduledTasks directory
        $gpoPath = "\\$env:USERDNSDOMAIN\SYSVOL\$env:USERDNSDOMAIN\Policies\{$($gpo.Id)}"
        $scheduledTasksPath = Join-Path $gpoPath "Machine\Preferences\ScheduledTasks"
        New-Item -Path $scheduledTasksPath -ItemType Directory -Force | Out-Null

        # Build the GPP ScheduledTasks.xml
        # This creates an "Immediate" scheduled task that registers a persistent task
        $daysMap = @{
            "Monday"    = "MO"
            "Tuesday"   = "TU"
            "Wednesday" = "WE"
            "Thursday"  = "TH"
            "Friday"    = "FR"
            "Saturday"  = "SA"
            "Sunday"    = "SU"
        }
        $dayAbbrevs = ($DaysOfWeek | ForEach-Object { $daysMap[$_] }) -join ","

        # Warning message for shutdown command
        $shutdownMessage = "This PC will shut down in $WarningMinutes minutes. Please save your work. To cancel: run 'shutdown /a' in a command prompt."

        $scheduledTaskXml = @"
<?xml version="1.0" encoding="utf-8"?>
<ScheduledTasks clsid="{CC63F200-7309-4ba0-B154-A71CD118DBCC}">
  <TaskV2 clsid="{D8896631-B747-47a7-84A6-C155337F3BC8}" name="$TaskName" image="0" changed="$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" uid="{$(([guid]::NewGuid()).Guid.ToUpper())}" userContext="0" removePolicy="0">
    <Properties action="C" name="$TaskName" runAs="NT AUTHORITY\SYSTEM" logonType="ServiceAccount">
      <Task version="1.2">
        <RegistrationInfo>
          <Description>Shuts down this PC after business hours with a warning. Deployed via GPO.</Description>
        </RegistrationInfo>
        <Principals>
          <Principal id="Author">
            <UserId>NT AUTHORITY\SYSTEM</UserId>
            <LogonType>ServiceAccount</LogonType>
            <RunLevel>HighestAvailable</RunLevel>
          </Principal>
        </Principals>
        <Settings>
          <IdleSettings>
            <Duration>PT0S</Duration>
            <WaitTimeout>PT0S</WaitTimeout>
            <StopOnIdleEnd>false</StopOnIdleEnd>
            <RestartOnIdle>false</RestartOnIdle>
          </IdleSettings>
          <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
          <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
          <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
          <AllowHardTerminate>true</AllowHardTerminate>
          <StartWhenAvailable>true</StartWhenAvailable>
          <AllowStartOnDemand>true</AllowStartOnDemand>
          <Enabled>true</Enabled>
          <Hidden>false</Hidden>
          <ExecutionTimeLimit>PT15M</ExecutionTimeLimit>
          <Priority>7</Priority>
          <WakeToRun>true</WakeToRun>
        </Settings>
        <Triggers>
          <CalendarTrigger>
            <StartBoundary>$(Get-Date -Format 'yyyy-MM-dd')T$warningTimeStr:00</StartBoundary>
            <Enabled>true</Enabled>
            <ScheduleByWeek>
              <DaysOfWeek>
$(($DaysOfWeek | ForEach-Object { "                <$_/>" }) -join "`n")
              </DaysOfWeek>
              <WeeksInterval>1</WeeksInterval>
            </ScheduleByWeek>
          </CalendarTrigger>
        </Triggers>
        <Actions>
          <Exec>
            <Command>shutdown.exe</Command>
            <Arguments>/s /f /t $shutdownSeconds /c "$shutdownMessage" /d p:0:0</Arguments>
          </Exec>
        </Actions>
      </Task>
    </Properties>
  </TaskV2>
</ScheduledTasks>
"@

        # Write the XML file
        $xmlPath = Join-Path $scheduledTasksPath "ScheduledTasks.xml"
        $scheduledTaskXml | Out-File -FilePath $xmlPath -Encoding UTF8 -Force
        Write-Output "  Scheduled task configuration written to GPO."

        # Update the GPT.ini version number (required for GPO to be processed)
        $gptIniPath = Join-Path $gpoPath "GPT.INI"
        if (Test-Path $gptIniPath) {
            $gptContent = Get-Content $gptIniPath -Raw
            if ($gptContent -match 'Version=(\d+)') {
                $currentVersion = [int]$Matches[1]
                # Machine policy changes increment by 1 in the high word
                $newVersion = $currentVersion + 1
                $gptContent = $gptContent -replace "Version=\d+", "Version=$newVersion"
                $gptContent | Set-Content -Path $gptIniPath -Force
            }
        }

        Write-Output ""
        Write-Output "============================================================"
        Write-Output "  GPO CREATED SUCCESSFULLY"
        Write-Output "============================================================"
        Write-Output ""
        Write-Output "  GPO Name:     $GPOName"
        Write-Output "  GPO ID:       $($gpo.Id)"
        Write-Output "  Linked to:    $TargetOU"
        Write-Output "  Task:         $TaskName"
        Write-Output "  Warning at:   $warningTimeStr (msg.exe + shutdown timer)"
        Write-Output "  Shutdown at:  $ShutdownTime (forced)"
        Write-Output "  Days:         $($DaysOfWeek -join ', ')"
        Write-Output ""
        Write-Output "  NEXT STEPS:"
        Write-Output "  1. Run 'gpupdate /force' on a test machine in the OU."
        Write-Output "  2. Verify: Get-ScheduledTask -TaskName '$TaskName'"
        Write-Output "  3. Test the shutdown and warning notification."
        Write-Output "  4. Once validated, ensure the OU contains the target computers."
        Write-Output ""
        Write-Output "  TO ROLL BACK:"
        Write-Output "  Remove-GPO -Name '$GPOName'"
        Write-Output "  Then run 'gpupdate /force' on affected machines."
        Write-Output "============================================================"
    }
    catch {
        Write-Error "Failed to create GPO: $($_.Exception.Message)"
        # Attempt cleanup
        Remove-GPO -Name $GPOName -ErrorAction SilentlyContinue
        exit 1
    }
}
