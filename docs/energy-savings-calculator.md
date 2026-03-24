# Energy Savings Calculator

This document provides a methodology for calculating the energy and cost savings from shutting down PCs after business hours.

## The Formula

```
Annual Savings = PCs × Watts × Hours_per_night × Working_days × kWh_price ÷ 1000
```

Where:
- **PCs** — Number of PCs that are currently left on after hours
- **Watts** — Average idle power consumption per PC (typically 60-150W)
- **Hours_per_night** — Hours the PC is on unnecessarily (e.g., 22:00 to 08:00 = 10 hours, or 22:00 to next 08:00 = 10 hours)
- **Working_days** — Number of working days per year (typically 250-260)
- **kWh_price** — Cost per kilowatt-hour in your region

## Reference Values

### Power Consumption by Device Type

| Device Type | Idle Power (W) | Sleep Power (W) | Off Power (W) |
|------------|----------------|-----------------|----------------|
| Desktop (standard) | 60-80 W | 2-5 W | 0.5-2 W |
| Desktop (high-perf) | 100-150 W | 3-8 W | 1-3 W |
| Desktop + Monitor | 100-150 W | 3-8 W | 1-3 W |
| Mini PC / SFF | 20-40 W | 1-3 W | 0.5-1 W |
| Laptop (plugged in, lid open) | 15-30 W | 1-3 W | 0.3-1 W |
| All-in-one | 40-70 W | 2-5 W | 0.5-2 W |

> **Recommendation:** Use **80W** as a conservative average for a mixed fleet of desktops and monitors. Measure your actual devices for accurate numbers (see below).

### Electricity Prices by Region

| Region | Avg. Price (USD/kWh) |
|--------|---------------------|
| United States (average) | $0.12 |
| United States (California) | $0.22 |
| Canada | $0.10 |
| United Kingdom | $0.28 |
| Germany | $0.35 |
| Australia | $0.25 |
| Brazil | $0.13 |
| India | $0.08 |

> Check your electricity bill for the actual rate. Use the **total cost per kWh** including taxes, distribution, and demand charges.

## Savings Examples

Using: 80W idle, 10 hours/night (22:00 to 08:00), 252 working days/year.

### At $0.12/kWh (US average)

| PCs Left On | Annual kWh | Annual Cost | Monthly Cost |
|-------------|-----------|-------------|--------------|
| 50 | 10,080 | $1,210 | $101 |
| 100 | 20,160 | $2,419 | $202 |
| 250 | 50,400 | $6,048 | $504 |
| 500 | 100,800 | $12,096 | $1,008 |
| 1,000 | 201,600 | $24,192 | $2,016 |
| 5,000 | 1,008,000 | $120,960 | $10,080 |

### At $0.28/kWh (UK average)

| PCs Left On | Annual kWh | Annual Cost | Monthly Cost |
|-------------|-----------|-------------|--------------|
| 50 | 10,080 | $2,822 | $235 |
| 100 | 20,160 | $5,645 | $470 |
| 250 | 50,400 | $14,112 | $1,176 |
| 500 | 100,800 | $28,224 | $2,352 |
| 1,000 | 201,600 | $56,448 | $4,704 |

## How to Measure Your Real Consumption

### Option 1: Kill-A-Watt Meter (Most Accurate)

1. Purchase a plug-in power meter (e.g., Kill-A-Watt, ~$20-30).
2. Plug the PC and monitor into the meter.
3. Measure idle consumption with the PC on but no user activity (screen on, then screen off).
4. Measure for at least 30 minutes to get a stable reading.
5. Repeat for 3-5 representative devices.

### Option 2: Windows Power Estimation

Run on a sample of devices:

```powershell
# Get estimated power consumption via WMI (rough estimate)
$battery = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
if ($battery) {
    Write-Output "Battery present - laptop. Idle draw ~20-30W plugged in."
} else {
    Write-Output "No battery - desktop. Idle draw ~60-100W estimated."
}

# Check power plan
powercfg /getactivescheme
```

### Option 3: Manufacturer Specifications

Check the power supply rating on the PC:
- The **rated wattage** (e.g., 300W PSU) is the *maximum*, not typical idle draw.
- Typical idle is **20-40% of PSU rating** for desktops.
- Look for Energy Star or 80 Plus certifications for efficiency data.

## ROI Calculation

### Simple ROI

```
Total project cost:
  - IT staff time: ~20 hours × hourly rate
  - No software cost (uses existing Intune license)
  - No hardware cost

Annual savings: (from table above)

ROI = (Annual savings - Project cost) ÷ Project cost × 100
Payback period = Project cost ÷ Monthly savings
```

### Example ROI

For an organization with **500 PCs** at $0.12/kWh:

| Item | Value |
|------|-------|
| IT staff time (20h × $50/h) | $1,000 |
| Software cost | $0 (Intune already licensed) |
| **Total project cost** | **$1,000** |
| Annual energy savings | $12,096 |
| **ROI** | **1,110%** |
| **Payback period** | **~3 weeks** |

## Environmental Impact

### CO2 Emissions Reduction

The carbon footprint of electricity varies by region and energy source:

| Energy Source | CO2 per kWh |
|--------------|-------------|
| US average (grid mix) | 0.40 kg |
| EU average | 0.30 kg |
| Coal-heavy grid | 0.90 kg |
| Natural gas grid | 0.45 kg |
| Renewable-heavy grid | 0.05-0.15 kg |

### Example: 500 PCs at US average

```
Annual kWh saved:   100,800 kWh
CO2 per kWh:        0.40 kg
Annual CO2 saved:   40,320 kg (40.3 metric tons)

Equivalent to:
  - 9 passenger cars driven for 1 year
  - 100,000 miles of driving
  - 1,600 tree seedlings grown for 10 years
```

> Source: [EPA Greenhouse Gas Equivalencies Calculator](https://www.epa.gov/energy/greenhouse-gas-equivalencies-calculator)

## Including Weekends and Holidays

The calculations above assume PCs are only left on during **weeknights**. If PCs are also left on over weekends:

```
Weekend hours = 48 hours (Friday 22:00 to Monday 08:00 = 58h, minus the 10h already counted)
Weekend days per year = ~52 weekends

Additional savings = PCs × Watts × 48 × 52 ÷ 1000 × kWh_price
```

This can add **30-40% more savings** on top of the weeknight calculation.

## Presenting to Management

Use the [Executive Summary Template](templates/executive-summary-template.md) and include:

1. **Current state:** "X% of our PCs are left on after hours" (from monitoring data).
2. **Cost:** "This costs us approximately $X per year in electricity."
3. **Solution:** "Automated shutdown via existing tools at zero additional cost."
4. **Timeline:** "4-6 weeks to full deployment."
5. **Risk:** "Minimal — includes user warning and exception mechanism."
