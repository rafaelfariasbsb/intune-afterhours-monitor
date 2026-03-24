# Pilot Kickoff — After-Hours PC Shutdown

> **Usage:** Send this to the pilot group (typically IT department) when starting Phase 3. Replace all `[PLACEHOLDER]` values.

---

**Subject:** IT Pilot Program: After-Hours PC Shutdown — Starting [DATE]

**To:** IT Department / Pilot Group

**From:** [YOUR_NAME], IT Department

---

Hi team,

We are starting a **pilot program for automatic after-hours PC shutdown** on our devices, and the IT department is the first group to test it. Here is what you need to know.

### What Is This?

As you know, we have been monitoring after-hours PC activity for the past [X] weeks. The data shows that [PERCENTAGE]% of our PCs are left on overnight, wasting approximately $[COST] per month in electricity.

Starting **[DATE]**, a scheduled task will be deployed to IT department PCs that will:
1. Show a **toast notification at [TIME minus 5 minutes]** warning that the PC will shut down.
2. **Shut down the PC at [TIME]** if it is still running.

### Why Us First?

Because we can troubleshoot our own issues, provide informed feedback, and help refine the solution before we roll it out to the rest of the organization. Your feedback is critical.

### What We Need From You

1. **Leave your PC on** on at least 2-3 nights this week so the shutdown triggers.
2. **Observe the experience:** Did you see the toast notification? Was 5 minutes enough time?
3. **Test the abort:** Try running `shutdown /a` in PowerShell to cancel the shutdown. Did it work?
4. **Report any issues** immediately via [Slack/Teams/email/ticket]:
   - Shutdown did not happen
   - No warning notification
   - Warning appeared too late
   - Data loss (if any)
   - Any other unexpected behavior

### How to Check

After the first night, you can verify the setup:

```powershell
# Check if the scheduled task exists
Get-ScheduledTask -TaskName "AfterHoursShutdown"

# Check the monitoring log
Get-Content "$env:ProgramData\AfterHoursMonitor\after-hours-log.csv" | Select-Object -Last 5
```

### Exception Testing

If you want to test the exception mechanism:

```powershell
# Create exception file (your PC will be skipped)
New-Item -Path "$env:ProgramData\YourCompany" -ItemType Directory -Force
Set-Content -Path "$env:ProgramData\YourCompany\shutdown-exception.txt" -Value "Test exception"

# Remove exception (re-enable shutdown)
Remove-Item "$env:ProgramData\YourCompany\shutdown-exception.txt"
```

### Timeline

| Date | Action |
|------|--------|
| [DATE] | Pilot deployment to IT devices |
| [DATE + 3 days] | First feedback check-in |
| [DATE + 7 days] | Mid-pilot review |
| [DATE + 14 days] | Pilot conclusion & go/no-go for rollout |

### Feedback Channel

Please report all feedback (positive and negative) to: **[CHANNEL/EMAIL]**

Use this format:
- **Device name:** [hostname]
- **What happened:** [description]
- **Expected behavior:** [what you expected]
- **Severity:** [cosmetic / annoying / blocking]

### FAQ

**Q: What if I am actively working at [TIME]?**
A: You will see a notification 5 minutes before. Run `shutdown /a` to cancel, or save your work and let it shut down.

**Q: What happens to my open documents?**
A: Applications will be force-closed. Save your work when you see the notification. Office auto-save helps, but do not rely on it.

**Q: Can I opt out of the pilot?**
A: Yes, create the exception file (see above). But please participate for at least 3 nights so we get useful data.

Thanks for helping us test this. Your feedback will directly shape how this rolls out to 500+ devices across the organization.

Best,
**[YOUR_NAME]**
