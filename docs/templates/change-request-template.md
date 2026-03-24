# Change Request — After-Hours PC Shutdown Policy

> **Usage:** Fill out this template to submit a formal change request (GMUD/RFC) for deploying the shutdown policy. Adapt the format to your organization's change management process.

---

## Change Request Details

| Field | Value |
|-------|-------|
| **CR Number** | [AUTO-GENERATED] |
| **Title** | Deploy After-Hours PC Automatic Shutdown Policy via Intune |
| **Requester** | [YOUR_NAME], IT Department |
| **Date Submitted** | [DATE] |
| **Priority** | Medium |
| **Category** | Endpoint Management / Energy Management |
| **Environment** | Production — All Intune-managed Windows devices |

---

## 1. Description of Change

Deploy a Microsoft Intune Proactive Remediation package that creates a Windows Scheduled Task on all managed devices to automatically shut down PCs at [TIME] on weekdays (Monday through Friday).

The solution consists of two components:
1. **Monitoring** (already deployed): Detection script that logs after-hours PC activity to a local CSV file.
2. **Enforcement** (this change): Detection + Remediation scripts that create a scheduled task to shut down PCs after a 5-minute user warning.

## 2. Justification / Business Reason

- Monitoring data shows **[PERCENTAGE]% of PCs** ([NUM] devices) are left on after hours nightly.
- Estimated annual electricity waste: **$[COST]**.
- Solution uses existing Intune infrastructure at **zero additional software cost**.
- Management approval obtained on [DATE] (reference: [meeting minutes / email / ticket]).

## 3. Scope of Change

### In Scope
- All Intune-managed Windows devices (desktops and laptops)
- Entra ID joined and Hybrid Entra ID joined devices
- Windows 10 20H2+ and Windows 11

### Out of Scope
- Servers (not managed by Intune)
- macOS devices
- BYOD / Entra ID registered devices
- Devices in the exception group `intune-afterhours-exceptions`

### Affected Systems
- Microsoft Intune (new Proactive Remediation package)
- Target devices (new scheduled task created)
- No network, server, or infrastructure changes

## 4. Implementation Plan

| Step | Action | Time | Responsible |
|------|--------|------|-------------|
| 1 | Create Proactive Remediation in Intune portal | 15 min | [NAME] |
| 2 | Upload detection and remediation scripts | 10 min | [NAME] |
| 3 | Assign to pilot group (`intune-afterhours-pilot`) | 5 min | [NAME] |
| 4 | Validate on 3-5 pilot devices | 24 hours | [NAME] |
| 5 | Monitor pilot for 1 week | 1 week | [NAME] |
| 6 | Expand to all devices (excluding exceptions) | 10 min | [NAME] |
| 7 | Monitor for 1 week post-rollout | 1 week | [NAME] |

**Implementation Window:** [DATE] [TIME] to [DATE] [TIME]
**Estimated Downtime:** None (no service interruption)

## 5. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| User loses unsaved work due to forced shutdown | Low | Medium | 5-minute toast warning; users can abort with `shutdown /a` |
| Critical PC shut down unexpectedly | Low | High | Exception file mechanism; Intune exclusion group for critical devices |
| Scheduled task conflicts with existing GPO | Low | Low | Test on pilot group first; check `gpresult` on pilot devices |
| Users unable to abort shutdown | Very Low | Medium | `shutdown /a` is a standard Windows command; documented in employee notification |
| Mass helpdesk tickets | Medium | Low | Phased rollout; employee notification sent 1 week prior |

**Overall Risk Level:** LOW

## 6. Rollback Plan

Rollback can be executed in **under 5 minutes**. Device-side cleanup takes up to 24 hours (next Intune sync).

| Step | Action | Time |
|------|--------|------|
| 1 | Remove group assignment from Proactive Remediation in Intune | 2 min |
| 2 | (Optional) Deploy cleanup script to remove scheduled tasks | 5 min |
| 3 | Notify affected users | 10 min |

Cleanup script:
```powershell
Unregister-ScheduledTask -TaskName "AfterHoursShutdown" -Confirm:$false -ErrorAction SilentlyContinue
```

**Rollback trigger criteria:**
- More than 5% of users report data loss
- Shutdown occurs outside the configured time window
- Scheduled task causes system instability

## 7. Testing Plan

### Pre-Implementation Testing
- [x] Scripts tested on developer workstation
- [x] Scripts tested running as SYSTEM context (via `psexec -s`)
- [x] Toast notification verified on Windows 10 and Windows 11
- [x] Exception file mechanism tested
- [x] Abort (`shutdown /a`) verified

### Post-Implementation Testing
- [ ] Verify scheduled task created on 3+ pilot devices
- [ ] Verify toast notification appears at [TIME minus 5 min]
- [ ] Verify shutdown occurs at [TIME]
- [ ] Verify exception file prevents shutdown
- [ ] Verify Intune portal shows correct compliance status
- [ ] Monitor helpdesk for related tickets (first 48 hours)

## 8. Communication Plan

| When | What | Audience | Method |
|------|------|----------|--------|
| [DATE - 7 days] | Employee notification | All employees | Email |
| [DATE] | Pilot kickoff | IT department | Email + Teams |
| [DATE + 14 days] | Rollout announcement | All employees | Email |
| Weekly | Status update | IT management | Email |

## 9. Approvals

| Role | Name | Decision | Date |
|------|------|----------|------|
| Change Requester | [NAME] | Requested | [DATE] |
| IT Manager | [NAME] | [ ] Approved / [ ] Rejected | _____ |
| Change Advisory Board | [NAME] | [ ] Approved / [ ] Rejected | _____ |
| Security | [NAME] | [ ] Approved / [ ] Rejected | _____ |

**Notes / Conditions:**

_____________________________________________________________

_____________________________________________________________

---

*Template from [intune-afterhours-monitor](https://github.com/your-org/intune-afterhours-monitor).*
