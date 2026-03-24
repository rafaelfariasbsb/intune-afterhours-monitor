<#
.SYNOPSIS
    Exports after-hours monitoring data from Intune Proactive Remediations via Microsoft Graph API.

.DESCRIPTION
    Connects to Microsoft Graph API and extracts the detection output from the
    "After-Hours PC Monitor" Proactive Remediation package. Consolidates data from
    all devices into a single CSV report.

    Requires an App Registration in Entra ID with:
    - DeviceManagementConfiguration.Read.All (Application permission)
    - Admin consent granted

.PARAMETER TenantId
    Your Entra ID (Azure AD) tenant ID.

.PARAMETER ClientId
    The Application (client) ID of the App Registration.

.PARAMETER ClientSecret
    The client secret for the App Registration.

.PARAMETER ScriptPackageName
    Name of the Proactive Remediation package in Intune. Default: "After-Hours PC Monitor".

.PARAMETER OutputPath
    Path to save the CSV report. Default: current directory with timestamped filename.

.EXAMPLE
    .\Export-IntuneReport.ps1 -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -ClientId "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy" -ClientSecret "your-secret-here"

.EXAMPLE
    .\Export-IntuneReport.ps1 -TenantId $env:TENANT_ID -ClientId $env:CLIENT_ID -ClientSecret $env:CLIENT_SECRET -OutputPath "C:\Reports\after-hours.csv"

.NOTES
    Author:  intune-afterhours-monitor contributors
    Version: 1.0.0
    Date:    2026-03-24
    Context: Standalone reporting script (run from admin workstation)
    License: MIT

    Prerequisites:
    - App Registration with DeviceManagementConfiguration.Read.All permission
    - PowerShell 5.1+ (Windows PowerShell) or PowerShell 7+ (cross-platform)
    - Internet connectivity to https://graph.microsoft.com
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$ClientId,

    [Parameter(Mandatory = $true)]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false)]
    [string]$ScriptPackageName = "After-Hours PC Monitor",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ""
)

# ============================================================
# CONFIGURATION
# ============================================================

$GraphBaseUrl = "https://graph.microsoft.com/beta"
$TokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

# Default output path with timestamp
if (-not $OutputPath) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputPath = Join-Path -Path (Get-Location) -ChildPath "after-hours-report-$timestamp.csv"
}

# ============================================================
# FUNCTIONS
# ============================================================

function Get-GraphToken {
    <#
    .SYNOPSIS
        Obtains an OAuth2 access token for Microsoft Graph.
    #>
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret
    )

    $body = @{
        client_id     = $ClientId
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $ClientSecret
        grant_type    = "client_credentials"
    }

    try {
        $response = Invoke-RestMethod -Method Post -Uri $TokenUrl -Body $body -ContentType "application/x-www-form-urlencoded"
        return $response.access_token
    }
    catch {
        Write-Error "Failed to obtain access token: $($_.Exception.Message)"
        if ($_.ErrorDetails.Message) {
            Write-Error "Details: $($_.ErrorDetails.Message)"
        }
        exit 1
    }
}

function Invoke-GraphRequest {
    <#
    .SYNOPSIS
        Makes an authenticated request to the Microsoft Graph API with pagination support.
    #>
    param(
        [string]$Uri,
        [string]$Token
    )

    $headers = @{
        Authorization  = "Bearer $Token"
        'Content-Type' = 'application/json'
    }

    $allResults = @()

    try {
        do {
            $response = Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers
            if ($response.value) {
                $allResults += $response.value
            }
            $Uri = $response.'@odata.nextLink'
        } while ($Uri)

        return $allResults
    }
    catch {
        Write-Error "Graph API request failed: $($_.Exception.Message)"
        if ($_.ErrorDetails.Message) {
            Write-Error "Details: $($_.ErrorDetails.Message)"
        }
        return $null
    }
}

# ============================================================
# MAIN EXECUTION
# ============================================================

Write-Output "=================================================="
Write-Output "  Intune After-Hours Report Export"
Write-Output "=================================================="
Write-Output ""

# Step 1: Authenticate
Write-Output "[1/4] Authenticating to Microsoft Graph..."
$token = Get-GraphToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
Write-Output "  Authentication successful."

# Step 2: Find the Proactive Remediation script package
Write-Output "[2/4] Finding script package '$ScriptPackageName'..."
$scriptPackages = Invoke-GraphRequest -Uri "$GraphBaseUrl/deviceManagement/deviceHealthScripts" -Token $token

if (-not $scriptPackages) {
    Write-Error "No Proactive Remediation packages found. Check permissions (DeviceManagementConfiguration.Read.All)."
    exit 1
}

$targetPackage = $scriptPackages | Where-Object { $_.displayName -eq $ScriptPackageName }

if (-not $targetPackage) {
    Write-Warning "Script package '$ScriptPackageName' not found. Available packages:"
    $scriptPackages | ForEach-Object { Write-Warning "  - $($_.displayName) (ID: $($_.id))" }
    exit 1
}

$packageId = $targetPackage.id
Write-Output "  Found: $($targetPackage.displayName) (ID: $packageId)"

# Step 3: Get device run states
Write-Output "[3/4] Fetching device results (this may take a moment)..."
$deviceStates = Invoke-GraphRequest -Uri "$GraphBaseUrl/deviceManagement/deviceHealthScripts/$packageId/deviceRunStates?`$expand=managedDevice" -Token $token

if (-not $deviceStates) {
    Write-Warning "No device results found for this script package."
    exit 0
}

Write-Output "  Retrieved $($deviceStates.Count) device results."

# Step 4: Parse and export
Write-Output "[4/4] Processing results and exporting..."

$report = $deviceStates | ForEach-Object {
    $deviceName = $_.managedDevice.deviceName
    $lastSync = $_.lastStateUpdateDateTime
    $detectionState = $_.detectionState
    $preRemediationOutput = $_.preRemediationDetectionScriptOutput

    # Parse the detection output for key fields
    $hostname = ""
    $summary = ""
    $avgUptime = ""
    $users = ""
    $logEntries = ""

    if ($preRemediationOutput) {
        $lines = $preRemediationOutput -split "`n"
        foreach ($line in $lines) {
            if ($line -match '^HOSTNAME:\s*(.+)') { $hostname = $Matches[1].Trim() }
            if ($line -match '^SUMMARY:\s*(.+)') { $summary = $Matches[1].Trim() }
            if ($line -match '^AVG_UPTIME:\s*(.+)') { $avgUptime = $Matches[1].Trim() }
            if ($line -match '^USERS:\s*(.+)') { $users = $Matches[1].Trim() }
            if ($line -match '^LOG_ENTRIES:\s*(.+)') { $logEntries = $Matches[1].Trim() }
        }
    }

    [PSCustomObject]@{
        DeviceName        = $deviceName
        Hostname          = $hostname
        LastSync          = $lastSync
        DetectionState    = $detectionState
        Summary           = $summary
        AvgUptimeHours    = $avgUptime
        Users             = $users
        LogEntries        = $logEntries
        RawOutput         = ($preRemediationOutput -replace "`n", " | " -replace "`r", "")
    }
}

# Export to CSV
try {
    $report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Output ""
    Write-Output "  Report exported to: $OutputPath"
    Write-Output "  Total devices: $($report.Count)"

    # Quick summary
    $withData = ($report | Where-Object { $_.Summary -ne '' }).Count
    $noData = ($report | Where-Object { $_.Summary -eq '' }).Count
    Write-Output "  Devices with monitoring data: $withData"
    Write-Output "  Devices without data yet: $noData"
}
catch {
    Write-Error "Failed to export CSV: $($_.Exception.Message)"
    exit 1
}

Write-Output ""
Write-Output "=================================================="
Write-Output "  Export complete."
Write-Output "=================================================="
