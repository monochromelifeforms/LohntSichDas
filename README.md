# Hab' ich wirklich so viel Zeit gespart?

> **Disclaimer:** This entire codebase — every line of Swift, SwiftUI, and this README — was written by Claude (Anthropic's AI assistant) via agentic coding. The physics formulas and energy model were audited and validated by the human author.

## What is this?

A simple iOS app that answers the age-old question every speeder secretly wonders: *"Am I actually saving any time by driving this fast?"*

The app tracks your driving speed via GPS and calculates in real time how much time you save (or don't) by exceeding a reference speed — defaulting to 130 km/h on the Autobahn or 60 mph.

Spoiler: it's usually less than you think.

## Features

- **Live speedometer** — large, glanceable speed display with a ring indicator
- **Instantaneous power band** — a colored arc inside the speed ring shows current engine power output. Red (clockwise) = engine working, green (counterclockwise) = braking/coasting. For EVs, bright green indicates energy recovered via regenerative braking, while dark green shows energy lost to heat. Scale ticks every 10 kW with a labeled reference mark. Smoothed with a Kalman filter for stable readings.
- **Peak power tracking** — displays the highest observed power (estimated at the crank) during the current session
- **Time saved counter** — running tally of seconds saved versus the reference speed, with percentage
- **Extra fuel consumption estimate** ("Mehrverbrauch") — physics-based estimate of additional energy consumed by exceeding the reference speed, accounting for aerodynamic drag, rolling resistance, altitude changes (GPS), and kinetic energy changes. Uses the ISA barometric formula for altitude-dependent air density.
- **Cumulative work display** — shows actual vs. baseline mechanical work in kWh for sanity-checking
- **Multiple vehicles** — configure and switch between cars with individual physics parameters (mass, frontal area, drag coefficient, rolling resistance, engine power, EV toggle with regen efficiency)
- **Power unit flexibility** — enter engine power in kW, HP, or PS
- **Travel stats** — travel time, distance driven, and average speed
- **Traffic jam mode** ("Staumodus") — prevents the trip timer from auto-stopping in slow traffic
- **Background tracking** — keeps running when you switch apps
- **mph / km/h toggle** — for both sides of the Atlantic
- **Locale-aware number formatting** — honors the system's decimal separator setting

## Physics model

The energy model uses Newton's second law / the work-energy theorem:

```
W_engine = ΔKE + W_drag + W_roll + W_gravity
```

where:
- **W_drag** = ½ · ρ(h) · Cd · A · v² · dx — aerodynamic drag (air density from ISA model)
- **W_roll** = Cr · m · g · dx — rolling resistance
- **W_gravity** = m · g · Δh — altitude change (from GPS)
- **ΔKE** = ½ · m · (v₂² − v₁²) — kinetic energy change

When W_engine > 0, fuel is consumed. When W_engine ≤ 0: ICE vehicles consume no fuel (coasting/braking), EVs partially recover energy via regenerative braking.

The baseline comparison assumes driving the same distance at the reference speed (constant speed, so ΔKE = 0). The extra consumption percentage is:

```
Mehrverbrauch = (W_actual − W_baseline) / W_baseline × 100%
```

## How it works

Whenever your speed exceeds the reference threshold, the app accumulates the time difference: how long the distance you just covered would have taken at the reference speed versus how long it actually took. Time spent below the threshold is not subtracted — it only counts the gains.

## Requirements

- iOS 17+
- Location permission (always, for background tracking)

## Built with

- Swift & SwiftUI
- CoreLocation
- Observation framework
- Claude (Anthropic) — agentic coding
