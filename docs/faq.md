# Frequently Asked Questions

## User Experience

### What if a user is still working at shutdown time?

The shutdown policy shows a **toast notification 5 minutes before shutdown**. The message reads: "This PC will shut down in 5 minutes. Please save your work." This gives users time to save documents and close applications.

If a user needs more time, they can postpone the shutdown by running `shutdown /a` in a command prompt or PowerShell window within the 5-minute warning period. However, the shutdown will be attempted again the next scheduled night.

For users who regularly work late, consider adding their device to the exception list or adjusting the shutdown time.

### Will I lose unsaved work?

The 5-minute warning gives you time to save. Additionally, `shutdown /s /f` forces applications to close, but many modern applications (Word, Excel, Chrome, etc.) have auto-save and session recovery features. That said, you should always save your work when you see the notification.

### Can I stop the shutdown once it starts?

Yes, during the warning period. Open a command prompt or PowerShell and run:

```cmd
shutdown /a
```

This aborts the pending shutdown. Note: this only stops the current shutdown. The scheduled task will trigger again the next night.

### Does the toast notification work if my screen is locked?

The notification is displayed on the lock screen if the session is locked. If no user is logged in at all, the shutdown proceeds silently (which is the correct behavior — no user session means no work to save).

## Device Management

### What about PCs that need to stay on (servers, monitoring stations, kiosks)?

Use the **exception mechanism**. Create a file at `C:\ProgramData\YourCompany\shutdown-exception.txt` on devices that should stay on. When this file exists, the enforcement detection script reports the device as compliant, and no shutdown task is created.

You can deploy the exception file via:
- A separate Intune PowerShell script targeted at an Entra ID group of exempt devices
- Manually on individual devices
- Via a helpdesk process where users request an exemption

### How do I exclude specific devices?

Three methods:

1. **Exception file:** Create `C:\ProgramData\YourCompany\shutdown-exception.txt` on the device.
2. **Intune exclusion group:** Add the device to an Entra ID group that is excluded from the Proactive Remediation assignment.
3. **Intune filter:** Use Intune assignment filters based on device properties (model, OS version, etc.).

### Does it work with laptops?

Yes. The scripts work on any Windows device enrolled in Intune. However:
- Laptops on **battery** will still shut down (which is usually desirable to preserve battery).
- Laptops with the **lid closed** are typically in sleep mode already and will not be affected.
- Docked laptops with external monitors behave like desktops.

### Does this affect Windows Update?

Windows Update can wake a PC from sleep to install updates, but it does not prevent a scheduled shutdown. If Windows Update is actively installing during the shutdown time:
- The `shutdown /f` flag forces the shutdown even during updates.
- Windows will resume the update on next boot.
- In rare cases, this could leave an update in a partially installed state. Windows is designed to handle this gracefully.

**Recommendation:** Schedule Windows Update maintenance windows *before* the shutdown time (e.g., 20:00) so updates complete before 22:00.

### What if Wake-on-LAN (WoL) is needed?

Wake-on-LAN can still wake a PC that was shut down by this policy. Shutdown does not disable the network adapter's WoL capability. WoL works with both sleep and shutdown states (as long as the BIOS and NIC are configured for it).

If you need PCs to wake up at a specific time (e.g., for morning patching), configure a BIOS wake timer or use WoL — both work after a clean shutdown.

## Licensing & Requirements

### What Intune license is required?

**Microsoft Intune Plan 1** or higher. This is included in:
- Microsoft 365 E3 / E5
- Microsoft 365 Business Premium
- Enterprise Mobility + Security (EMS) E3 / E5
- Standalone Intune Plan 1

**Proactive Remediations** (now called "Remediations") specifically requires:
- Intune Plan 1 (for basic remediations)
- One of the above licenses assigned to the user or device

### Does it work with co-managed devices (SCCM + Intune)?

Yes, as long as the **Client apps** workload is set to Intune (or Pilot Intune). Proactive Remediations require the Intune Management Extension, which is installed when certain workloads are managed by Intune.

### Does it work with Entra ID registered (BYOD) devices?

No. Proactive Remediations require devices to be **Entra ID joined** or **Hybrid Entra ID joined**. Entra ID registered (workplace joined) devices are not supported.

## Technical Questions

### How much disk space does the CSV log use?

Approximately **1-2 KB per month**. Each log entry is about 80 bytes, and the log retains 30 days by default. This is negligible.

### Does the detection script impact performance?

No. The detection script:
- Runs once daily during business hours (scheduled by Intune).
- Execution time is typically < 1 second.
- Only reads a small CSV file and outputs text.
- The scheduled task (AfterHoursMonitor) runs at 22:00 and completes in < 1 second.

### What happens if the device is offline at the scheduled time?

- **Intune detection script:** Will run at the next sync after the device comes online.
- **Scheduled task (monitoring):** If the PC is off at 22:00, the task does not run, and no log entry is created. This is correct — a PC that is off does not need monitoring.
- **Scheduled task (shutdown):** If the PC is off at 22:00, nothing happens. The task will run the next time the PC is on at the scheduled time.

### Can I change the shutdown time after deployment?

Yes. Update the `$ShutdownTime` variable in the remediation script and re-upload it to Intune. The next time the detection script runs and finds the task needs updating (or is missing), the remediation will recreate it with the new time.

Alternatively, update the `$ShutdownTime` in the detection script as well, so it recreates the task with the new time.

### What time zone does the scheduled task use?

The device's **local time zone**. If your organization spans multiple time zones, the shutdown will occur at 22:00 local time on each device, which is usually the desired behavior.

### How do I completely remove the solution?

1. Delete both Proactive Remediations from Intune.
2. Deploy a cleanup script:
   ```powershell
   Unregister-ScheduledTask -TaskName "AfterHoursMonitor" -Confirm:$false -ErrorAction SilentlyContinue
   Unregister-ScheduledTask -TaskName "AfterHoursShutdown" -Confirm:$false -ErrorAction SilentlyContinue
   Remove-Item "$env:ProgramData\AfterHoursMonitor" -Recurse -Force -ErrorAction SilentlyContinue
   ```
3. Delete exception files if any were created.

## Compliance & Policy

### Is this compliant with labor laws?

This solution shuts down PCs, not terminates work sessions prematurely. It is a facilities/energy management tool, not a time tracking tool. However:
- Always check with your HR and legal department before deploying.
- The 5-minute warning gives users time to save work.
- Users can abort the shutdown if needed.
- Consider your organization's overtime and flexible work policies.

### Does this count as employee monitoring?

The monitoring phase logs whether a PC is on and who is logged in. This is similar to a door access log showing who is in the building after hours. It does not track:
- What the user is doing
- What applications are open
- What websites are visited
- Keystrokes or screen content

Check your organization's privacy policy and applicable regulations (GDPR, etc.). In most jurisdictions, monitoring corporate-owned device power state is permissible without explicit consent, but consult your legal team.

### Can management see who is working late?

The monitoring data shows which PCs are on and which user account is logged in. Management can see this data in aggregate through the reports. If this is a concern:
- Communicate transparently about what data is collected and why.
- Focus reports on aggregate data (e.g., "40% of PCs in Building A are left on") rather than individual users.
- Consider anonymizing individual reports if your privacy policy requires it.
