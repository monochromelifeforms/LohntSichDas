//
//  HelpView.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 4) {
                        Text("Lohnt sich das?")
                            .font(.largeTitle.bold())
                        Text("–oder–")
                        Text("Hab' ich wirklich so viel Zeit gespart?")
                            .font(.title2)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                    section(
                        icon: "speedometer",
                        title: "Geschwindigkeit",
                        text: "Die App zeigt deine aktuelle Geschwindigkeit per GPS an – wahlweise in km/h oder mph."
                    )

                    section(
                        icon: "bolt.fill",
                        title: "Momentanleistung",
                        text: "Der farbige Bogen innerhalb des Geschwindigkeitsrings zeigt die aktuelle Motorleistung an. Rot (nach rechts) bedeutet, der Motor arbeitet – je weiter der Bogen reicht, desto mehr Leistung wird abgerufen. Grün (nach links) zeigt Bremsen bzw. Rekuperation bei Elektrofahrzeugen."
                    )

                    section(
                        icon: "clock.arrow.circlepath",
                        title: "Gesparte Zeit",
                        text: "Immer wenn du schneller als die eingestellte Referenzgeschwindigkeit fährst, berechnet die App, wie viel Zeit du im Vergleich zur Referenzgeschwindigkeit sparst. Zeit unterhalb der Referenz wird nicht abgezogen."
                    )

                    section(
                        icon: "fuelpump",
                        title: "Mehrverbrauch",
                        text: "Schätzt grob, wie viel mehr Kraftstoff bzw. Energie du durch das Überschreiten der Referenzgeschwindigkeit verbrauchst. Die Berechnung berücksichtigt Luftwiderstand, Rollwiderstand, Höhenunterschiede und Beschleunigung. Da reale Faktoren wie Gangwahl, Windverhältnisse, Motoreffizienz und Reifendruck nicht erfasst werden, dient der Wert nur als Anhaltspunkt. Die Fahrzeugparameter (Masse, Stirnfläche, Cw-Wert usw.) können in den Einstellungen angepasst werden."
                    )

                    section(
                        icon: "timer",
                        title: "Fahrzeit",
                        text: "Die Fahrzeit läuft, sobald du schneller als 10 km/h fährst. Sie stoppt automatisch, wenn du länger als eine Minute unter 6 km/h bleibst. Im Staumodus wird die Fahrzeit nie automatisch gestoppt."
                    )

                    section(
                        icon: "road.lanes",
                        title: "Strecke",
                        text: "Zeigt die gesamte gefahrene Strecke seit dem letzten Reset an – in Kilometern oder Meilen, je nach Einstellung."
                    )

                    section(
                        icon: "gauge.with.dots.needle.50percent",
                        title: "Durchschnittsgeschwindigkeit",
                        text: "Die Durchschnittsgeschwindigkeit wird aus der gefahrenen Strecke und der Fahrzeit berechnet."
                    )

                    section(
                        icon: "car.fill",
                        title: "Staumodus",
                        text: "Aktiviere den Staumodus, wenn du im Stau stehst. Die Fahrzeit läuft dann weiter, auch wenn du lange stehst oder nur langsam fährst."
                    )

                    section(
                        icon: "stop.fill",
                        title: "Stop",
                        text: "Stoppt die Fahrzeit sofort manuell, z.\u{00A0}B. wenn du an deinem Ziel angekommen bist."
                    )

                    section(
                        icon: "gearshape",
                        title: "Einstellungen",
                        text: "Über das Zahnrad oben rechts kannst du die Referenzgeschwindigkeit anpassen (Standard: 130 km/h bzw. 60 mph) und zwischen km/h und mph umschalten."
                    )

                    section(
                        icon: "location.fill",
                        title: "Hintergrund",
                        text: "Die App läuft im Hintergrund weiter und erfasst auch dann Geschwindigkeit und gesparte Zeit, wenn du eine andere App nutzt."
                    )
                }
                .padding(24)
            }
            .navigationTitle("Hilfe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func section(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
