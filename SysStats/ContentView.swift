import SwiftUI

struct ContentView: View {
    @ObservedObject private var statsManager = StatsManager.shared
    @ObservedObject private var prefs = PreferencesManager.shared
    @State private var showingPreferences = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showingPreferences {
                preferencesView
            } else {
                statsView
            }
        }
        .frame(width: 280)
    }

    // MARK: - Stats View

    private var statsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("System Stats")
                    .font(.headline)
                Spacer()
                Button(action: { showingPreferences = true }) {
                    Image(systemName: "gear")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                if prefs.showCPU {
                    StatRow(
                        icon: "cpu",
                        label: "CPU",
                        value: "\(statsManager.currentMetrics.cpuUsage)%",
                        percentage: Double(statsManager.currentMetrics.cpuUsage) / 100.0
                    )
                }

                if prefs.showGPU {
                    StatRow(
                        icon: "gpu",
                        label: "GPU",
                        value: "\(statsManager.currentMetrics.gpuUsage)%",
                        percentage: Double(statsManager.currentMetrics.gpuUsage) / 100.0
                    )
                }

                if prefs.showRAM {
                    StatRow(
                        icon: "memorychip",
                        label: "RAM",
                        value: "\(statsManager.currentMetrics.ramUsage)%",
                        percentage: Double(statsManager.currentMetrics.ramUsage) / 100.0
                    )
                }

                if prefs.showTemperature {
                    let temp = statsManager.currentMetrics.temperature
                    let displayTemp = prefs.temperatureUnit == .fahrenheit ? temp * 9/5 + 32 : temp
                    let tempString = temp > 0 ? String(format: "%.0f%@", displayTemp, prefs.temperatureUnit.label) : "—"

                    HStack {
                        Image(systemName: "thermometer.medium")
                            .frame(width: 20)
                            .foregroundColor(.orange)
                        Text("Temp")
                            .frame(width: 40, alignment: .leading)
                        Spacer()
                        Text(tempString)
                            .monospacedDigit()
                            .foregroundColor(tempColor(temp))
                    }
                }
            }

            Divider()

            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)

                Spacer()

                Text("Updated every \(prefs.updateInterval.label)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private func tempColor(_ temp: Double) -> Color {
        if temp <= 0 { return .secondary }
        if temp < 50 { return .green }
        if temp < 70 { return .orange }
        return .red
    }

    // MARK: - Preferences View

    private var preferencesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { showingPreferences = false }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Text("Preferences")
                    .font(.headline)

                Spacer()
            }

            Divider()

            // Update Interval
            VStack(alignment: .leading, spacing: 6) {
                Text("Update Interval")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $prefs.updateInterval) {
                    ForEach(UpdateInterval.allCases, id: \.self) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider()

            // Stats to Show
            VStack(alignment: .leading, spacing: 6) {
                Text("Show in Menu Bar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Toggle("CPU Usage", isOn: $prefs.showCPU)
                    .toggleStyle(.checkbox)
                Toggle("GPU Usage", isOn: $prefs.showGPU)
                    .toggleStyle(.checkbox)
                Toggle("RAM Usage", isOn: $prefs.showRAM)
                    .toggleStyle(.checkbox)
                Toggle("Temperature", isOn: $prefs.showTemperature)
                    .toggleStyle(.checkbox)
            }

            Divider()

            // Temperature Unit
            VStack(alignment: .leading, spacing: 6) {
                Text("Temperature Unit")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $prefs.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider()

            // Launch at Login
            Toggle("Launch at Login", isOn: $prefs.launchAtLogin)
                .toggleStyle(.checkbox)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Stat Row Component

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let percentage: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.accentColor)

            Text(label)
                .frame(width: 40, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geometry.size.width * min(max(percentage, 0), 1), height: 8)
                }
            }
            .frame(height: 8)

            Text(value)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var barColor: Color {
        if percentage < 0.5 { return .green }
        if percentage < 0.8 { return .orange }
        return .red
    }
}

#Preview {
    ContentView()
}
