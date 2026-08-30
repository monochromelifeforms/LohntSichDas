//
//  ContentView.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import SwiftUI

struct ContentView: View {
    @State private var locationManager: LocationManager

    init(locationManager: LocationManager = LocationManager()) {
        self._locationManager = State(initialValue: locationManager)
    }
    @State private var showSettings = false
    @State private var showHelp = false
    @State private var resetFlash = false
    @State private var showMehrverbrauchHelp = false
    @State private var showArbeitHelp = false

    // Ring geometry. The grey arc runs from `arcTrimStart` to `arcTrimEnd`; the
    // power band grows from the 12 o'clock centre (`bandTrimCenter`). A full band
    // reaches the end of the grey arc.
    private let arcTrimStart = 0.11
    private let arcTrimEnd = 0.89
    private let bandTrimCenter = 0.5
    private var maxBandFraction: Double { arcTrimEnd - bandTrimCenter }

    private let kmPerMile = 1.60934

    // Drivetrain efficiency mapping the engine's rated power to power at the wheels.
    private let drivetrainEfficiency = 0.85

    // Power (W) represented by the end of the grey arc: the active vehicle's
    // rated power delivered through the drivetrain.
    private var powerBandScale: Double {
        max(locationManager.selectedVehicle.power * 1000 * drivetrainEfficiency, 1)
    }

    private var useMiles: Bool { locationManager.useMiles }
    private var speedUnit: String { useMiles ? "mph" : "km/h" }

    /// Converts a speed from internal km/h to the user's display unit.
    private func displayValue(_ kmh: Double) -> Double {
        useMiles ? kmh / kmPerMile : kmh
    }

    private var displaySpeed: Double { displayValue(locationManager.currentSpeed) }
    private var displayThreshold: Double { displayValue(locationManager.threshold) }
    private var displayAverageSpeed: Double { displayValue(locationManager.averageSpeed) }

    private var speedColor: Color {
        if locationManager.currentSpeed > locationManager.threshold {
            return .orange
        } else if locationManager.isDriving {
            return .primary
        } else {
            return .secondary
        }
    }

    /// Color for the ring and its scale markings. Follows only the driving/idle
    /// state — it never turns orange, so exceeding the reference speed recolors
    /// the numbers but not the ring.
    private var ringColor: Color {
        locationManager.isDriving ? .primary : .secondary
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 10)
            HStack {
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.title2)
                }
                .padding(.leading, 24)
                .padding(.top, 8)
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title2)
                }
                .padding(.trailing, 24)
                .padding(.top, 8)
            }
            Spacer()

            ringGroup

            Spacer().frame(maxHeight: 20)

            timeSavedGroup

            Spacer()
            extraWorkGroup
            Spacer()
            statsGroup
            Spacer()

            // Staumodus and Stop buttons
            HStack(spacing: 12) {
                Button {
                    locationManager.trafficJamMode.toggle()
                } label: {
                    Label("Staumodus", systemImage: locationManager.trafficJamMode ? "car.fill" : "car")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(locationManager.trafficJamMode ? .orange : .gray.opacity(0.3),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(locationManager.trafficJamMode ? .white : .primary)
                }

                Button {
                    locationManager.stopDriving()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(locationManager.isDriving ? .blue : .gray.opacity(0.3),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(locationManager.isDriving ? .white : .primary)
                }
                .disabled(!locationManager.isDriving)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Reset button — requires a long press to avoid accidental activation
            Text("Reset (gedrückt halten)")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding()
                .background(.red, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
                .scaleEffect(resetFlash ? 0.92 : 1.0)
                .opacity(resetFlash ? 0.6 : 1.0)
                .animation(.easeOut(duration: 0.2), value: resetFlash)
                .onLongPressGesture(minimumDuration: 0.8) {
                    locationManager.reset()
                    resetFlash = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        resetFlash = false
                    }
                }
                .sensoryFeedback(.success, trigger: resetFlash)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            locationManager.start()
            UIApplication.shared.isIdleTimerDisabled = locationManager.isDriving
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: locationManager.isDriving) { _, driving in
            UIApplication.shared.isIdleTimerDisabled = driving
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(locationManager: locationManager)
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
    }

    // MARK: - Reusable groups (for future landscape layout)

    private var ringGroup: some View {
        VStack(spacing: 4) {
            Text("\(Int(displaySpeed))")
                .font(.system(size: 140, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(speedColor)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: speedColor)
            Text(speedUnit)
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Referenz: \(Int(displayThreshold)) \(speedUnit)")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .overlay {
            Circle()
                .trim(from: arcTrimStart, to: arcTrimEnd)
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .foregroundStyle(ringColor.opacity(0.4))
                .rotationEffect(.degrees(90))
                .frame(width: 320, height: 320)
                .offset(y: -30)

            if locationManager.showPowerBand {
                // Power band: extends right (positive/engine) or left (negative/braking).
                // A full band (max power at the wheels) reaches the end of the grey arc.
                let power = locationManager.instantaneousPower
                let fraction = min(abs(power) / powerBandScale, 1) * maxBandFraction
                let bandStyle = StrokeStyle(lineWidth: 16, lineCap: .round)

                if power >= 0 {
                    // Positive power: red band (engine working)
                    Circle()
                        .trim(from: bandTrimCenter, to: bandTrimCenter + fraction)
                        .stroke(style: bandStyle)
                        .foregroundStyle(.red)
                        .rotationEffect(.degrees(90))
                        .frame(width: 296, height: 296)
                        .offset(y: -30)
                        .animation(.easeInOut(duration: 1.0), value: power)
                } else {
                    // Negative power: dark green = energy lost to brakes,
                    // bright green (closer to 12 o'clock) = energy recovered via regen.
                    let regenFraction = locationManager.isElectric
                        ? fraction * locationManager.regenEfficiency
                        : 0

                    // Dark green: full braking band
                    Circle()
                        .trim(from: bandTrimCenter - fraction, to: bandTrimCenter)
                        .stroke(style: bandStyle)
                        .foregroundStyle(Color.green.opacity(0.8))
                        .rotationEffect(.degrees(90))
                        .frame(width: 296, height: 296)
                        .offset(y: -30)
                        .animation(.easeInOut(duration: 1.0), value: power)

                    // Bright green: recovered portion (closest to 12 o'clock)
                    if regenFraction > 0 {
                        Circle()
                            .trim(from: bandTrimCenter - regenFraction, to: bandTrimCenter)
                            .stroke(style: bandStyle)
                            .foregroundStyle(.green)
                            .rotationEffect(.degrees(90))
                            .frame(width: 296, height: 296)
                            .offset(y: -30)
                            .animation(.easeInOut(duration: 1.0), value: power)
                    }
                }

                // Adaptive scale ticks on both sides (engine = right, braking =
                // left). PowerScale chooses a 1-2-5 "nice" interval so there are
                // roughly 5–10 major ticks per side at any power range.
                let scale = PowerScale(powerBandScale: powerBandScale, maxBandFraction: maxBandFraction)
                let labelR: Double = 190

                // Centre tick at 12 o'clock (0 kW boundary)
                Rectangle()
                    .fill(ringColor.opacity(0.6))
                    .frame(width: 2, height: 18)
                    .offset(y: -179)

                ForEach(scale.ticks) { tick in
                    let tickH: Double = tick.isMajor ? 18 : 10
                    let tickY = -(158 - tickH / 2)

                    ForEach([tick.angleDegrees, -tick.angleDegrees], id: \.self) { angle in
                        Rectangle()
                            .fill(ringColor.opacity(0.6))
                            .frame(width: 2, height: tickH)
                            .offset(y: tickY)
                            .rotationEffect(.degrees(angle))
                            .offset(y: -30)
                    }

                    if tick.power == scale.labeledTickPower {
                        let rad = tick.angleDegrees * .pi / 180
                        Text(scale.labelText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(ringColor.opacity(0.6))
                            .offset(
                                x: labelR * sin(rad),
                                y: -30 - labelR * cos(rad)
                            )
                    }
                }
            }

            // Vehicle picker inside the ring (only when more than one car)
            if locationManager.vehicles.count > 1 {
                Menu {
                    ForEach(locationManager.vehicles) { vehicle in
                        Button {
                            locationManager.selectedVehicleID = vehicle.id
                        } label: {
                            if vehicle.id == locationManager.selectedVehicleID {
                                Label(vehicle.displayName, systemImage: "checkmark")
                            } else {
                                Text(vehicle.displayName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill")
                        Text(locationManager.selectedVehicle.displayName)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .font(.headline)
                }
                .offset(y: -135)
            }
        }
    }

    private var timeSavedGroup: some View {
        VStack(spacing: 2) {
            Text("Gesparte Zeit")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(formattedTimeSaved)
                .font(.system(size: 52, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(formattedPercentage)
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
    }

    private var extraWorkGroup: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Button { showMehrverbrauchHelp.toggle() } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.body)
                        .foregroundStyle(.orange.opacity(0.6))
                }
                .popover(isPresented: $showMehrverbrauchHelp) {
                    Text("Schätzt grob, wie viel mehr Kraftstoff bzw. Energie du durch das Überschreiten der Referenzgeschwindigkeit verbrauchst. Die Berechnung berücksichtigt Luftwiderstand, Rollwiderstand, Höhenunterschiede und Beschleunigung. Da reale Faktoren wie Gangwahl, Windverhältnisse, Motoreffizienz und Reifendruck nicht erfasst werden, dient der Wert nur als Anhaltspunkt.")
                        .font(.callout)
                        .padding()
                        .frame(width: 300)
                        .fixedSize(horizontal: false, vertical: true)
                        .presentationCompactAdaptation(.popover)
                }
                Text(formattedExtraWork)
                    .font(.title.bold())
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText())
            }
            HStack(spacing: 6) {
                Button { showArbeitHelp.toggle() } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.body)
                }
                .tint(.secondary)
                .popover(isPresented: $showArbeitHelp) {
                    Text("Mechanische Arbeit in kWh: tatsächlich geleistete Arbeit / Arbeit bei konstanter Referenzgeschwindigkeit. Der Quotient ergibt den Mehrverbrauch.")
                        .font(.callout)
                        .padding()
                        .frame(width: 300)
                        .fixedSize(horizontal: false, vertical: true)
                        .presentationCompactAdaptation(.popover)
                }
                Text("Arbeit: \((locationManager.cumulativeActualWork / 3_600_000).systemFormatted(fractionDigits: 2)) / \((locationManager.cumulativeBaselineWork / 3_600_000).systemFormatted(fractionDigits: 2)) kWh")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statsGroup: some View {
        HStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Fahrzeit")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(formattedTravelTime)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            VStack(spacing: 8) {
                Text("Strecke")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(formattedDistance)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            VStack(spacing: 8) {
                Text("Durchschnitt")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("\(displayAverageSpeed.systemFormatted(fractionDigits: 1)) \(speedUnit)")
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
    }

    // MARK: - Formatters

    private var formattedPercentage: String {
        guard locationManager.travelTime > 0 else { return "\(0.0.systemFormatted(fractionDigits: 2)) %" }
        let pct = (locationManager.timeSaved / locationManager.travelTime) * 100
        return "\(pct.systemFormatted(fractionDigits: 2)) %"
    }

    private var formattedExtraWork: String {
        let pct = locationManager.extraWorkPercentage
        return "Mehrverbrauch ≳\(pct.systemFormatted(fractionDigits: 1)) %"
    }

    private var formattedDistance: String {
        let km = locationManager.totalDistance / 1000
        if useMiles {
            let miles = km / kmPerMile
            return "\(miles.systemFormatted(fractionDigits: miles >= 100 ? 0 : 1)) mi"
        }
        return "\(km.systemFormatted(fractionDigits: km >= 100 ? 0 : 1)) km"
    }

    private var formattedTravelTime: String {
        let total = Int(locationManager.travelTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedTimeSaved: String {
        let total = locationManager.timeSaved
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        let seconds = Int(total) % 60
        let millis = Int((total.truncatingRemainder(dividingBy: 1)) * 1000)
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%03d", hours, minutes, seconds, millis)
        }
        return String(format: "%d:%02d.%03d", minutes, seconds, millis)
    }
}

#Preview {
    ContentView()
}

#Preview("Driving") {
    let lm = LocationManager()
    lm.currentSpeed = 155
    lm.instantaneousPower = 45_000
    return ContentView(locationManager: lm)
}



