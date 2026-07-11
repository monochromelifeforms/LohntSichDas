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
configure the reference speed, unit (km/h or mph), and one or more vehicles. The
active vehicle is picked from a menu on the car name in the home-screen top bar.

## Layout

- `LohntSichDas.swift` — App entry point.
- `ContentView.swift` — Main screen.
- `SettingsView.swift` — Vehicle parameters, reference speed, unit picker.
- `HelpView.swift` — Explanatory text.
- `LocationManager.swift` — `@Observable` CoreLocation delegate; owns all state
  and the physics/energy model. Also runs a Kalman filter to smooth the
  instantaneous-power reading.
- `SystemNumberStyle.swift` — Shared number formatting (see rule below).
- `Vehicle.swift` — `Codable` value type: a vehicle's name + physics parameters.

## Conventions

- SwiftUI + `@Observable` (Observation). Prefer async/await; avoid Combine.
- 4-space indentation; PascalCase types, camelCase members; avoid force-unwrap.
- **UI-facing strings are in German.** Keep new user-visible text German.
- Tests: Swift Testing framework; UI tests: XCUIAutomation.
- Build via Xcode.
- **Avoid code duplication.** Reuse the existing model, formatting, and view
  building blocks rather than copying them. This matters especially when adding
  an alternate presentation of the same data — e.g. a future CarPlay screen or a
  landscape layout: share the one `LocationManager` instance, reuse the value
  formatting (`SystemNumberStyle` / `Double.systemFormatted`) and the physics/
  vehicle logic, and factor common UI (the speed ring, stat rows, buttons) into
  reusable subviews used by every layout. If a piece of the current screen needs
  to be shared, extract it into its own view rather than re-implementing it.

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

## IMPORTANT: settings persistence

All user-configurable **settings** must persist across app launches. In
`LocationManager` (an `@Observable` class, so `@AppStorage` is unavailable) each
setting is a computed property backed by `UserDefaults`, wrapped in
`access(keyPath:)` / `withMutation(keyPath:)` so `@Observable` keeps tracking it.
This saves on every change and restores on launch — no explicit load/save step.

- **When adding a new setting**, copy the existing template in `LocationManager`:
  a `UserDefaults`-backed computed property with its default value inline in the
  getter. That single property is the only change required — do not reintroduce a
  plain stored `var` for a setting.
- Transient runtime state (current speed, drive timers, energy accumulators,
  `isDriving`, `trafficJamMode`) stays as plain stored properties and is **not**
  persisted; keep it under the "Transient runtime state" mark.

## Vehicles

- Reference speed (`threshold`) and `useMiles` are **global** scalar settings.
  The per-vehicle physics parameters (mass, frontal area, Cd, Cr, `isElectric`,
  regen) live on `Vehicle` values.
- `LocationManager` owns the `[Vehicle]` list and the active `selectedVehicleID`
  (both persisted as JSON in `UserDefaults`; a legacy single-car config is
  migrated into "Auto #1" on first launch). `carMass`, `frontalArea`, … are
  facades onto the active vehicle, so the energy model and settings fields use
  them unchanged. To add a per-vehicle parameter, add it to `Vehicle` and add a
  matching facade — do not add a global `UserDefaults` setting for it.
- Unnamed vehicles display as "Auto #<n>" via `Vehicle.displayName`; keep new
  user-visible vehicle text German.
- `Vehicle.power` is stored in **kW**; the entry unit (kW/HP/PS) is the global
  `powerUnit` setting (`PowerUnit`). A new vehicle defaults to 100 HP.
- The home-screen speed ring scales its power band to the active vehicle:
  `powerBandScale = power(kW)·1000·drivetrainEfficiency (0.85)` is the power at
  the **end of the grey arc**; the labelled kW tick is derived from it. When
  adding a `Vehicle` field that Settings persists, extend `Vehicle`'s custom
  `init(from:)` with `decodeIfPresent` so older saved vehicles still load.
