//
//  ContentView.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import SwiftUI

struct ContentView: View {
    @State private var locationManager = LocationManager()
    @State private var showSettings = false
    @State private var showHelp = false

    // Power (W) at which the band reaches the 3 o'clock position.
    // Reference: 2000 kg car at 160 km/h, Cd=0.35, A=2.5 m² ≈ 57.5 kW
    private let powerBandScale: Double = 57500

    private var useMiles: Bool { locationManager.useMiles }
    private var speedUnit: String { useMiles ? "mph" : "km/h" }

    private var displaySpeed: Double {
        useMiles ? locationManager.currentSpeed / 1.60934 : locationManager.currentSpeed
    }

    private var displayThreshold: Double {
        useMiles ? locationManager.threshold / 1.60934 : locationManager.threshold
    }

    private var displayAverageSpeed: Double {
        useMiles ? locationManager.averageSpeed / 1.60934 : locationManager.averageSpeed
    }

    private var speedColor: Color {
        if locationManager.currentSpeed > locationManager.threshold {
            return .orange
        } else if locationManager.isDriving {
            return .primary
        } else {
            return .secondary
        }
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
                    Divider()
                    Button {
                        showSettings = true
                    } label: {
                        Label("Fahrzeuge verwalten…", systemImage: "slider.horizontal.3")
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

            // Speed display
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
                    .trim(from: 0.11, to: 0.89)
                    .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .foregroundStyle(speedColor.opacity(0.4))
                    .rotationEffect(.degrees(90))
                    .frame(width: 320, height: 320)
                    .offset(y: -30)

                // Power band: extends right (positive/engine) or left (negative/braking)
                let power = locationManager.instantaneousPower
                let fraction = min(abs(power) / powerBandScale * 0.25, 0.39)
                let bandStyle = StrokeStyle(lineWidth: 16, lineCap: .round)

                if power >= 0 {
                    // Positive power: red band (engine working)
                    Circle()
                        .trim(from: 0.5, to: 0.5 + fraction)
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
                        .trim(from: 0.5 - fraction, to: 0.5)
                        .stroke(style: bandStyle)
                        .foregroundStyle(Color.green.opacity(0.4))
                        .rotationEffect(.degrees(90))
                        .frame(width: 296, height: 296)
                        .offset(y: -30)
                        .animation(.easeInOut(duration: 1.0), value: power)

                    // Bright green: recovered portion (closest to 12 o'clock)
                    if regenFraction > 0 {
                        Circle()
                            .trim(from: 0.5 - regenFraction, to: 0.5)
                            .stroke(style: bandStyle)
                            .foregroundStyle(.green)
                            .rotationEffect(.degrees(90))
                            .frame(width: 296, height: 296)
                            .offset(y: -30)
                            .animation(.easeInOut(duration: 1.0), value: power)
                    }
                }

                // Scale tick near 4 o'clock on the ring (multiple of 10 kW)
                let tickPowerKW = round(130.0 / 90.0 * powerBandScale / 10000) * 10
                let tickAngleDeg = tickPowerKW * 1000 / powerBandScale * 0.25 * 360
                let tickAngleRad = tickAngleDeg * .pi / 180
                let labelR: Double = 190

                // Tick pointing inward from ring edge
                Rectangle()
                    .fill(speedColor.opacity(0.6))
                    .frame(width: 2, height: 14)
                    .offset(y: -151)
                    .rotationEffect(.degrees(tickAngleDeg))
                    .offset(y: -30)

                // "80 kW" label outside the ring
                Text("\(Int(tickPowerKW)) kW")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(speedColor.opacity(0.6))
                    .offset(
                        x: labelR * sin(tickAngleRad),
                        y: -30 - labelR * cos(tickAngleRad)
                    )

            }

            Spacer().frame(maxHeight: 20)

            // Time saved display
            VStack(spacing: 8) {
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

            // Extra work percentage
            Text(formattedExtraWork)
                .font(.title.bold())
                .foregroundStyle(.orange)
                .contentTransition(.numericText())
                .padding(.top, 8)

            // Show cumulative work values (actual / reference).
            Text("Arbeit: \((locationManager.cumulativeActualWork / 3_600_000).systemFormatted(fractionDigits: 2)) / \((locationManager.cumulativeBaselineWork / 3_600_000).systemFormatted(fractionDigits: 2)) kWh")
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer()

            // Travel time, distance, and average speed
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

            // Reset button
            Button {
                locationManager.reset()
            } label: {
                Text("Reset")
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.red, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            locationManager.start()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(locationManager: locationManager)
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
    }

    private var formattedPercentage: String {
        guard locationManager.travelTime > 0 else { return "\(0.0.systemFormatted(fractionDigits: 2)) %" }
        let pct = (locationManager.timeSaved / locationManager.travelTime) * 100
        return "\(pct.systemFormatted(fractionDigits: 2)) %"
    }

    private var formattedExtraWork: String {
        let pct = locationManager.extraWorkPercentage
        return "Mehrverbrauch ≥\(pct.systemFormatted(fractionDigits: 1)) %"
    }

    private var formattedDistance: String {
        let km = locationManager.totalDistance / 1000
        if useMiles {
            let miles = km / 1.60934
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






