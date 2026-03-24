# Contributing to intune-afterhours-monitor

Thank you for your interest in contributing! This project aims to help organizations reduce energy waste by monitoring and managing PCs left on after business hours.

## How to Contribute

### Reporting Issues

- Use [GitHub Issues](../../issues) to report bugs or request features.
- Include your environment details: Windows version, PowerShell version, Intune license type.
- For bugs, provide steps to reproduce and the expected vs. actual behavior.

### Submitting Changes

1. **Fork** the repository.
2. Create a **feature branch** from `main`: `git checkout -b feature/my-improvement`
3. Make your changes following the code style guidelines below.
4. **Test** your scripts on a non-production device.
5. Commit with a descriptive message: `git commit -m "Add grace period option to shutdown policy"`
6. Push to your fork and open a **Pull Request** against `main`.

### What We Need Help With

- Translations of email templates and documentation
- Additional reporting formats (HTML, Excel)
- Integration with other MDM platforms (JAMF, Workspace ONE)
- Real-world energy savings data from deployments
- Improved toast notification UX
- macOS / Linux equivalents

## Code Style Guidelines

### PowerShell Best Practices

- Use **approved PowerShell verbs** (`Get-`, `Set-`, `New-`, `Remove-`, etc.).
- Include a complete **comment-based help block** (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.NOTES`).
- Place **configurable variables at the top** of the script with descriptive comments.
- Use `[CmdletBinding()]` where appropriate.
- Prefer `Write-Output` over `Write-Host` for Intune detection scripts (stdout is captured).
- Use `try/catch` for error handling — devices may be in unexpected states.
- Follow the **one-script-one-purpose** principle.
- Use **PascalCase** for function names and **camelCase** for local variables.
- Keep lines under **120 characters** where possible.

### Script Header Template

```powershell
<#
.SYNOPSIS
    Brief description of what the script does.

.DESCRIPTION
    Detailed description including context and use case.

.PARAMETER ParameterName
    Description of each parameter.

.EXAMPLE
    Example-Usage
    Description of what the example does.

.NOTES
    Author:  Your Name
    Version: 1.0.0
    Date:    YYYY-MM-DD
    Context: Intune Proactive Remediation / Standalone / GPO
#>
```

### Documentation

- Write documentation in **English**.
- Use Markdown for all docs.
- Include practical examples and real-world context.
- Keep the deployment guide up to date with any script changes.

## Testing Guidelines

### Before Submitting

1. **Syntax check**: Run `$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw .\script.ps1), [ref]$null)` to verify no syntax errors.
2. **Local test**: Run detection scripts on your own device and verify the output.
3. **Exit codes**: Ensure detection scripts return `0` (compliant) or `1` (non-compliant) correctly.
4. **No side effects**: Detection scripts must NOT modify the system. Only remediation scripts should make changes.
5. **Idempotency**: Remediation scripts must be safe to run multiple times without causing issues.

### Test Environment

- Windows 10 21H2+ or Windows 11
- PowerShell 5.1 (ships with Windows — Intune runs scripts with this version)
- Test with both admin and SYSTEM context

## Code of Conduct

- Be respectful and constructive in all interactions.
- Focus on the technical merits of contributions.
- Help newcomers get started.

## Questions?

Open a [Discussion](../../discussions) on GitHub if you have questions about contributing.

Thank you for helping organizations save energy and reduce costs!
