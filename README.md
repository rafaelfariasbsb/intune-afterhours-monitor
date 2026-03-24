# intune-afterhours-monitor

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/powershell/)
[![Intune](https://img.shields.io/badge/Microsoft-Intune-0078D4.svg)](https://docs.microsoft.com/mem/intune/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**Monitor and automatically shut down PCs left on after business hours using Microsoft Intune Proactive Remediations.**

---

## The Problem

PCs left running overnight waste significant energy and money. In a typical organization:

- **40-60% of desktops** are left on after hours
- Each PC consumes **80-150W idle** (monitor off, PC on)
- Over a year, this adds up to **hundreds of thousands of dollars** in wasted electricity
- The environmental impact is equally significant: unnecessary CO2 emissions

Most employees simply forget to shut down. Others leave PCs on "just in case." Without visibility, IT and management have no data to act on.

## The Solution

A phased approach using **Microsoft Intune Proactive Remediations**:

```
Phase 1: MONITOR          Phase 2: ANALYZE          Phase 3: ENFORCE

+------------------+      +------------------+      +------------------+
| Deploy detection |      | Collect reports  |      | Deploy shutdown  |
| script to all    | ---> | Present data to  | ---> | scheduled task   |
| managed devices  |      | management       |      | with warning     |
+------------------+      +------------------+      +------------------+

  "How bad is it?"         "Here's the proof"        "Let's fix it"
```

### Architecture

```
+------------------------------------------------------------------+
|                     Microsoft Intune Portal                       |
|                  (Proactive Remediations)                         |
+------------------+-------------------+---------------------------+
                   |                   |
          Schedule |           Results |
          (daily)  |           (stdout)|
                   v                   |
+------------------------------------------------------------------+
|                      Managed Device                               |
|                                                                   |
|  +-------------------+     +------------------+                   |
|  | Detect-AfterHours |     | Scheduled Task   |                   |
|  | PC.ps1            |---->| (runs at 22:00)  |                   |
|  | (Intune agent)    |     | Logs to CSV      |                   |
|  +-------------------+     +------------------+                   |
|                                    |                              |
|                            +-------v--------+                     |
|                            | Local CSV Log  |                     |
|                            | (30-day retain)|                     |
|                            +----------------+                     |
|                                                                   |
|  +-------------------+     +------------------+                   |
|  | Detect-Shutdown   |     | Shutdown Task    |  (Phase 3 only)   |
|  | Policy.ps1        |---->| shutdown /s /f   |                   |
|  +-------------------+     | with 5-min toast |                   |
|                            +------------------+                   |
+------------------------------------------------------------------+
```

## Quick Start

### 1. Deploy Monitoring (5 minutes)

1. In the [Intune portal](https://intune.microsoft.com), go to **Devices > Remediations** (or **Reports > Endpoint analytics > Proactive remediations**).
2. Click **+ Create script package**, name it `After-Hours PC Monitor`.
3. Upload [`scripts/monitoring/Detect-AfterHoursPC.ps1`](scripts/monitoring/Detect-AfterHoursPC.ps1) as the detection script. Leave remediation script empty.
4. Set **Run this script using the logged-on credentials** to **No** (runs as SYSTEM).
5. Assign to **All devices** or a pilot group. Set schedule to **Daily**.

### 2. Collect Data (2 weeks)

Wait for data to accumulate. Check results in the Intune portal under the remediation package's **Device status** tab.

### 3. Take Action

Review the data, present to management using the [report templates](docs/templates/), and proceed to enforcement when ready.

See the full [Deployment Guide](docs/deployment-guide.md) for detailed instructions.

## Features

| Feature | Description |
|---------|-------------|
| **Zero-touch monitoring** | Detection script auto-creates a local scheduled task — no manual setup needed |
| **Local CSV logging** | Each device keeps a 30-day rolling log of after-hours activity |
| **Intune-native reporting** | Results flow through standard Proactive Remediation reporting |
| **Configurable schedule** | Shutdown time, days of week, and warning period are all variables at the top of each script |
| **User warning** | Toast notification 5 minutes before shutdown — users can save their work |
| **Exception mechanism** | Drop a file on the PC to permanently exclude it from shutdown |
| **GPO alternative** | Included scripts for organizations without Intune |
| **Graph API reporting** | Export consolidated data from Intune via Microsoft Graph |
| **Communication templates** | Ready-to-use email templates for management, employees, and pilots |

## Energy Savings Estimate

Assumptions: 80W idle consumption, 14 hours/night, 252 working days/year.

| PCs | Annual kWh Wasted | Annual Cost (USD) | CO2 Saved (kg) |
|-----|-------------------|--------------------|-----------------|
| 100 | 28,224 | $3,387 | 11,290 |
| 500 | 141,120 | $16,934 | 56,448 |
| 1,000 | 282,240 | $33,869 | 112,896 |
| 5,000 | 1,411,200 | $169,344 | 564,480 |

> Cost at $0.12/kWh (US average). CO2 at 0.4 kg/kWh. Your numbers will vary — see the [Energy Savings Calculator](docs/energy-savings-calculator.md) for a detailed methodology.

## Rollout Phases

| Phase | Duration | What Happens | Risk |
|-------|----------|-------------|------|
| **1. Monitor** | Week 1-2 | Deploy detection script, collect baseline data | None (read-only) |
| **2. Analyze** | Week 3 | Generate reports, present to stakeholders | None |
| **3. Pilot** | Week 4-5 | Enable shutdown on IT department only | Low (IT can self-troubleshoot) |
| **4. Rollout** | Week 6+ | Enable shutdown for all devices, configure exceptions | Medium (mitigated by warning + exceptions) |

See the full [Rollout Plan](docs/rollout-plan.md) for detailed steps, success criteria, and rollback procedures.

## Repository Structure

```
intune-afterhours-monitor/
├── README.md                       # This file
├── LICENSE                         # MIT License
├── CONTRIBUTING.md                 # How to contribute
├── .gitignore
├── docs/
│   ├── deployment-guide.md         # Step-by-step Intune deployment
│   ├── architecture.md             # Solution architecture and data flow
│   ├── energy-savings-calculator.md# ROI and savings methodology
│   ├── rollout-plan.md             # Phased rollout plan
│   ├── faq.md                      # Frequently asked questions
│   └── templates/                  # Communication templates
│       ├── email-management-report.md
│       ├── email-employee-notification.md
│       ├── email-pilot-kickoff.md
│       ├── executive-summary-template.md
│       └── change-request-template.md
└── scripts/
    ├── monitoring/                 # Phase 1: Detection only
    │   ├── Detect-AfterHoursPC.ps1
    │   └── README.md
    ├── enforcement/                # Phase 3: Shutdown policy
    │   ├── Detect-ShutdownPolicy.ps1
    │   ├── Remediate-ShutdownPolicy.ps1
    │   └── README.md
    ├── reporting/                  # Data extraction and reports
    │   ├── Get-AfterHoursReport.ps1
    │   ├── Export-IntuneReport.ps1
    │   └── README.md
    └── gpo-alternative/            # For orgs without Intune
        ├── Create-ShutdownGPO.ps1
        └── README.md
```

## Requirements

| Requirement | Details |
|------------|---------|
| **Intune License** | Microsoft Intune Plan 1 (included in Microsoft 365 E3/E5, Business Premium) |
| **Entra ID** | Devices must be Entra ID joined or Hybrid Entra ID joined |
| **Windows** | Windows 10 20H2+ or Windows 11 |
| **PowerShell** | 5.1 (ships with Windows — no additional install needed) |
| **Proactive Remediations** | Requires Intune license with Endpoint Analytics |
| **For Graph API reporting** | App Registration with `DeviceManagementConfiguration.Read.All` permission |

## Screenshots

> Screenshots will be added as the project matures. Contributions welcome!

<!--
![Intune Portal - Script Package](docs/images/intune-script-package.png)
![Detection Results](docs/images/detection-results.png)
![Energy Savings Dashboard](docs/images/energy-dashboard.png)
-->

## Related Projects

- [Microsoft Intune Remediations](https://learn.microsoft.com/mem/intune/fundamentals/remediations) — Official documentation
- [Intune Proactive Remediations Community](https://github.com/topics/intune-proactive-remediations) — Community scripts

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

*Saving energy, one PC at a time.*
