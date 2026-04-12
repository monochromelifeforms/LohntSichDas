//
//  ContentView.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import SwiftUI

struct ContentView: View {
    @State private var locationManager = LocationManager()
    @State private var showSettings = false
    @State private var showHelp = false

    private var speedColor: Color {
        let speed = locationManager.currentSpeed
        if speed > locationManager.threshold { return .green }
        if locationManager.isDriving { return .cyan }
        return .white
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.leading, 24)
                .padding(.top, 8)
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.trailing, 24)
                .padding(.top, 8)
            }
            Spacer()

            // Speed display
            VStack(spacing: 4) {
                Text("\(Int(locationManager.currentSpeed))")
                    .font(.system(size: 140, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(speedColor)
                    .contentTransition(.numericText())
                    .shadow(color: speedColor.opacity(0.6), radius: 12)
                Text("km/h")
                    .font(.title.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Referenz: \(Int(locationManager.threshold)) km/h")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .overlay {
                Circle()
                    .trim(from: 0.1, to: 0.9)
                    .stroke(
                        AngularGradient(
                            colors: [speedColor.opacity(0.0), speedColor.opacity(0.5), speedColor.opacity(0.0)],
                            center: .center,
                            startAngle: .degrees(126),
                            endAngle: .degrees(414)
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: 280, height: 280)
                    .offset(y: -30)
            }

            Spacer()

            // Time saved display
            VStack(spacing: 8) {
                Text("Gesparte Zeit")
                    .font(.subheadline.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.5))
                Text(formattedTimeSaved)
                    .font(.system(size: 52, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
                    .shadow(color: .green.opacity(0.4), radius: 8)
                Text(formattedPercentage)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.green.opacity(0.7))
                    .contentTransition(.numericText())
            }

            Spacer()

            // Travel time, distance, and average speed
            HStack(spacing: 0) {
                statItem(label: "Fahrzeit", value: formattedTravelTime)
                divider
                statItem(label: "Strecke", value: formattedDistance)
                divider
                statItem(label: "Durchschnitt", value: "\(Int(locationManager.averageSpeed)) km/h")
            }
            .padding(.horizontal, 16)

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
                        .background(
                            locationManager.trafficJamMode
                                ? AnyShapeStyle(.orange.gradient)
                                : AnyShapeStyle(.white.opacity(0.08)),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(locationManager.trafficJamMode ? 0 : 0.1))
                        )
                        .foregroundStyle(locationManager.trafficJamMode ? .white : .white.opacity(0.8))
                }

                Button {
                    locationManager.stopDriving()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            locationManager.isDriving
                                ? AnyShapeStyle(.blue.gradient)
                                : AnyShapeStyle(.white.opacity(0.08)),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(locationManager.isDriving ? 0 : 0.1))
                        )
                        .foregroundStyle(locationManager.isDriving ? .white : .white.opacity(0.4))
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
                    .background(.red.gradient, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear {
            locationManager.start()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(threshold: $locationManager.threshold)
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.9))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.15))
            .frame(width: 1, height: 36)
    }

    private var formattedPercentage: String {
        guard locationManager.travelTime > 0 else { return "0.00 %" }
        let pct = (locationManager.timeSaved / locationManager.travelTime) * 100
        return String(format: "%.2f %%", pct)
    }

    private var formattedDistance: String {
        let km = locationManager.totalDistance / 1000
        if km >= 100 {
            return String(format: "%.0f km", km)
        }
        return String(format: "%.1f km", km)
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
