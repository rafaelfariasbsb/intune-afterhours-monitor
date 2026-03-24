# Rollout Plan

A phased approach to deploying the After-Hours PC Monitor and Shutdown Policy.

## Overview

| Phase | Name | Duration | Risk Level |
|-------|------|----------|------------|
| 1 | Monitoring | Week 1-2 | None |
| 2 | Analysis & Communication | Week 3 | None |
| 3 | Pilot Enforcement | Week 4-5 | Low |
| 4 | Full Rollout | Week 6+ | Medium (mitigated) |

```
Week:  1    2    3    4    5    6    7    8+
       |----|----|----|----|----|----|----|--->

Phase 1: MONITOR
       [============]
       Deploy to all    Collect baseline data
       devices

Phase 2: ANALYZE
                    [====]
                    Generate reports
                    Present to management
                    Send employee notice

Phase 3: PILOT
                         [=========]
                         Enable shutdown
                         IT dept only
                         Validate & tune

Phase 4: ROLLOUT
                                   [=========>
                                   Enable shutdown
                                   All devices
                                   Monitor exceptions
```

---

## Phase 1: Monitoring (Week 1-2)

### Objective

Deploy the monitoring-only detection script to all managed devices. Collect a baseline of after-hours PC activity without making any changes.

### Actions

1. **Day 1:** Review and customize `Detect-AfterHoursPC.ps1`:
   - Set `$MonitorTime` to your business closing time.
   - Set `$DaysOfWeek` to your work week.
   - Test the script on 1-2 devices manually.

2. **Day 1:** Create the Proactive Remediation in Intune:
   - Name: `After-Hours PC Monitor`
   - Upload detection script only (no remediation).
   - Schedule: Daily.
   - Assign to: All devices (or all Windows devices group).

3. **Day 2-3:** Verify deployment:
   - Check Intune portal for device status.
   - Confirm scheduled tasks are being created on devices.
   - Verify CSV logs are being written.

4. **Day 4-14:** Collect data:
   - Let the monitoring run for at least 10 business days.
   - This gives you 2 full weeks of baseline data.

### Success Criteria

- [ ] Detection script deployed to 95%+ of target devices.
- [ ] CSV logs being written on pilot devices (spot-check 5-10 devices).
- [ ] Intune portal showing detection output for devices.
- [ ] No user-reported issues or performance impact.

### Rollback Plan

- Remove the Proactive Remediation assignment from Intune.
- The scheduled task on devices will remain but is harmless (only writes a CSV line).
- To clean up tasks: deploy a one-time script that runs `Unregister-ScheduledTask -TaskName "AfterHoursMonitor" -Confirm:$false`.

---

## Phase 2: Analysis & Communication (Week 3)

### Objective

Analyze the collected data, generate reports for management, and prepare employee communications.

### Actions

1. **Day 15-16:** Export and analyze data:
   - Use `Export-IntuneReport.ps1` to extract results from Intune.
   - Or manually review the Proactive Remediation results in the portal.
   - Calculate: What percentage of PCs are left on? How many nights? Which departments?

2. **Day 16-17:** Prepare management report:
   - Use [Executive Summary Template](templates/executive-summary-template.md).
   - Include: baseline data, estimated cost, proposed solution, timeline.
   - Calculate energy savings using the [Energy Savings Calculator](energy-savings-calculator.md).

3. **Day 17-18:** Present to management:
   - Get approval for enforcement.
   - Agree on exception policy (who can request exemptions and how).
   - Agree on communication plan.

4. **Day 18-19:** Communicate to employees:
   - Send [Employee Notification](templates/email-employee-notification.md) email.
   - Give at least 1 week notice before enforcement starts.
   - Include: why, when it starts, how to request exceptions, who to contact.

5. **Day 19-21:** Prepare enforcement scripts:
   - Customize `Detect-ShutdownPolicy.ps1` and `Remediate-ShutdownPolicy.ps1`.
   - Test on 1-2 IT devices manually.
   - Create the Intune Proactive Remediation (but do not assign yet).

### Success Criteria

- [ ] Management report delivered and approved.
- [ ] Employee notification sent at least 1 week before enforcement.
- [ ] Exception process defined and documented.
- [ ] Enforcement scripts tested on IT devices.

### Rollback Plan

Not applicable (no changes to devices in this phase).

---

## Phase 3: Pilot Enforcement (Week 4-5)

### Objective

Enable the shutdown policy on a small group (IT department) to validate the user experience, toast notification, exception mechanism, and overall reliability.

### Actions

1. **Day 22:** Deploy enforcement to IT pilot group:
   - Create Entra ID group: `intune-afterhours-pilot` with IT department devices.
   - Assign the `After-Hours Shutdown Policy` Proactive Remediation to this group.
   - Send [Pilot Kickoff Email](templates/email-pilot-kickoff.md) to IT staff.

2. **Day 22-23:** Validate initial deployment:
   - Confirm scheduled tasks are created on pilot devices.
   - Verify toast notification appears 5 minutes before shutdown.
   - Verify shutdown occurs at the configured time.
   - Test the exception file mechanism.

3. **Day 23-35:** Pilot monitoring:
   - Collect feedback from IT staff.
   - Monitor for issues: false shutdowns, missed warnings, timing problems.
   - Track: How many devices shut down? How many users reported issues?

4. **Day 33-35:** Pilot review:
   - Compile pilot results.
   - Address any issues found.
   - Decide: proceed to rollout, extend pilot, or adjust parameters.

### Success Criteria

- [ ] 100% of pilot devices have the shutdown task created.
- [ ] Toast notification confirmed working by 3+ pilot users.
- [ ] Shutdown occurs correctly at the configured time.
- [ ] Exception mechanism works (tested on at least 1 device).
- [ ] No data loss or unexpected shutdowns reported.
- [ ] IT staff comfortable with the solution.

### Rollback Plan

1. Remove the Proactive Remediation assignment from the pilot group.
2. Deploy a cleanup script to remove the scheduled task:
   ```powershell
   Unregister-ScheduledTask -TaskName "AfterHoursShutdown" -Confirm:$false -ErrorAction SilentlyContinue
   ```
3. Notify pilot users.

---

## Phase 4: Full Rollout (Week 6+)

### Objective

Deploy the shutdown policy to all managed devices, with exceptions configured for devices that need to stay on.

### Actions

1. **Day 36:** Configure exceptions:
   - Create an Entra ID group for exempt devices: `intune-afterhours-exceptions`.
   - Deploy the exception file to exempt devices via a separate Intune script.
   - Alternatively, add exempt devices to the exclusion group of the Proactive Remediation.

2. **Day 36:** Expand deployment:
   - Change the `After-Hours Shutdown Policy` assignment from pilot group to **All devices**.
   - Add `intune-afterhours-exceptions` to the exclusion list.
   - Consider a gradual rollout: department by department over 1-2 weeks.

3. **Day 36-37:** Monitor initial rollout:
   - Watch Intune portal for remediation status.
   - Be available for user questions.
   - Monitor helpdesk for related tickets.

4. **Day 37+:** Ongoing monitoring:
   - Review monitoring data weekly for the first month.
   - Track: What percentage of PCs are shutting down? Exception requests?
   - Send [Management Report](templates/email-management-report.md) monthly.

5. **Day 50+:** Optimization:
   - Review exception list — are any exemptions no longer needed?
   - Adjust shutdown time if needed.
   - Consider weekend enforcement (additional scheduled task).

### Success Criteria

- [ ] 90%+ of non-exempt devices shutting down by 22:30 on weeknights.
- [ ] Exception process working smoothly (< 5% of devices exempt).
- [ ] Helpdesk tickets related to shutdown < 2% of user base in first month.
- [ ] Energy savings measurable (compare electricity bills month-over-month).
- [ ] No data loss incidents.

### Rollback Plan

1. **Partial rollback:** Add affected devices to the exclusion group.
2. **Full rollback:**
   - Remove the Proactive Remediation assignment.
   - Deploy cleanup script to remove scheduled tasks.
   - Notify users that the policy is suspended.
3. **Timeline:** Full rollback can be executed in < 1 hour. Device-side cleanup takes up to 24 hours (next Intune sync cycle).

---

## Post-Rollout

### Monthly Activities

- Review monitoring data for trends.
- Update exception list.
- Send monthly savings report to management.
- Review and address any helpdesk tickets.

### Quarterly Activities

- Compare electricity bills with pre-deployment baseline.
- Review and optimize shutdown time.
- Assess user satisfaction.
- Update scripts if needed.

### Annual Activities

- Full review of energy savings vs. projection.
- Review exception policy.
- Consider expanding to weekends/holidays.
- Update documentation.

---

## Communication Timeline Summary

| When | What | Audience | Template |
|------|------|----------|----------|
| Week 3, Day 1 | Executive summary | Management | [Executive Summary](templates/executive-summary-template.md) |
| Week 3, Day 3 | Employee notification | All employees | [Employee Notification](templates/email-employee-notification.md) |
| Week 4, Day 1 | Pilot kickoff | IT department | [Pilot Kickoff](templates/email-pilot-kickoff.md) |
| Week 6, Day 1 | Rollout announcement | All employees | (update Employee Notification) |
| Monthly | Results report | Management | [Management Report](templates/email-management-report.md) |
