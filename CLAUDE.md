# CLAUDE.md

Guidance for working in this repository.

## What this app is

A SwiftUI iOS app (product name: "Hab' ich wirklich so viel Zeit gespart?").
While driving, it uses GPS to estimate:
- **Time saved** by driving faster than a configurable reference speed.
- **Extra energy consumption** vs. driving that same distance at the reference
  speed, from a physics model (aerodynamic drag, rolling resistance, gravity,
  kinetic-energy changes; regenerative braking for EVs).

The main screen shows a speed ring with an instantaneous-power band (red =
engine load, green = braking, bright green = recovered via regen), time saved,
extra-work percentage, travel time, distance, and average speed. Settings
configure the reference speed, unit (km/h or mph), and vehicle parameters.

## Layout

- `LohntSichDas.swift` — App entry point.
- `ContentView.swift` — Main screen.
- `SettingsView.swift` — Vehicle parameters, reference speed, unit picker.
- `HelpView.swift` — Explanatory text.
- `LocationManager.swift` — `@Observable` CoreLocation delegate; owns all state
  and the physics/energy model. Also runs a Kalman filter to smooth the
  instantaneous-power reading.
- `SystemNumberStyle.swift` — Shared number formatting (see rule below).

## Conventions

- SwiftUI + `@Observable` (Observation). Prefer async/await; avoid Combine.
- 4-space indentation; PascalCase types, camelCase members; avoid force-unwrap.
- **UI-facing strings are in German.** Keep new user-visible text German.
- Tests: Swift Testing framework; UI tests: XCUIAutomation.
- Build via Xcode.

## IMPORTANT: number formatting

All user-facing numbers must honor the user's **"Number Format"** setting
(iOS Settings → Language & Region), which is independent of Region and controls
the decimal and grouping separators.

- **Do** format via `Double.systemFormatted(fractionDigits:)` / `SystemNumberStyle`
  (both in `SystemNumberStyle.swift`). These are `NumberFormatter`-backed with
  `Locale.autoupdatingCurrent`, which reads that override.
- **Do not** use SwiftUI's `.number` `FormatStyle` or `String(format: "%f", …)`
  for user-facing values — the former reads separators from the locale
  *identifier* only and the latter is C-locale; both ignore the override.
- Exceptions currently left as-is: integer speed/threshold/kW labels (never reach
  a grouping separator) and the `Fahrzeit`/`Gesparte Zeit` durations (clock-style,
  not decimal numbers).

## Units

- Speeds stored internally in **km/h** (`currentSpeed`, `threshold`); physics uses
  SI (m/s, m, kg, J, W). Display converts to km/h or mph based on `useMiles`.
- Distances stored in meters; energy accumulators in Joules.
