import SwiftUI

public struct DashboardView: View {
    @ObservedObject var viewModel: TpmsViewModel

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Connection Header
                ConnectionHeaderCard(
                    connectionState: viewModel.connectionState,
                    isSimulationMode: viewModel.isSimulationMode
                )

                if viewModel.useEngineeringDashboard {
                    EngineeringDashboardView(viewModel: viewModel)
                } else {
                    VehicleTyreGrid(viewModel: viewModel)
                }

                if viewModel.isSimulationMode && !viewModel.useEngineeringDashboard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Simulation Control: RL Pressure")
                            .font(.headline)
                        Slider(value: $viewModel.simulationRlPressurePsi, in: 0...100)
                        Text("Value: \(Int(viewModel.simulationRlPressurePsi)) \(viewModel.usePsi ? "PSI" : "Bar")")
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                }
            }
            .padding()
        }
    }
}

struct ConnectionHeaderCard: View {
    let connectionState: BleConnectionState
    let isSimulationMode: Bool

    var body: some View {
        HStack {
            Image(systemName: isSimulationMode ? "flask.fill" : "antenna.radiowaves.left.and.right")
                .font(.system(size: 28))
                .foregroundColor(isSimulationMode ? .purple : .blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(isSimulationMode ? "Simulation Active" : "Connected to TPMS")
                    .font(.headline)
                    .bold()
                Text(isSimulationMode ? "Simulated Telemetry Mode" : "BLE TPMS Live Diagnostics")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
    }
}

struct VehicleTyreGrid: View {
    @ObservedObject var viewModel: TpmsViewModel

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(TireKey.allCases) { key in
                TireCard(key: key, viewModel: viewModel)
            }
        }
    }
}

struct TireCard: View {
    let key: TireKey
    @ObservedObject var viewModel: TpmsViewModel

    var body: some View {
        let data = viewModel.tyreStatuses[key] ?? TpmsData()
        let isNoData = !data.isValid || data.timestamp == 0
        let ab = viewModel.getAbnormalities(for: key, data: data)
        let isAlert = ab != 0

        let displayP = viewModel.usePsi ? "\(Int(data.pressurePsi)) PSI" : String(format: "%.1f Bar", data.pressurePsi * 0.0689476)
        let displayT = viewModel.useCelsius ? "\(Int(data.temperatureCelsius)) °C" : "\(Int(data.temperatureCelsius * 1.8 + 32)) °F"

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(key.rawValue)
                    .font(.title2)
                    .bold()
                Spacer()
                if isAlert {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                } else if data.isValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            if isNoData {
                Text("No Data")
                    .font(.title3)
                    .foregroundColor(.secondary)
            } else {
                Text(displayP)
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(isAlert ? .red : .primary)
                Text(displayT)
                    .font(.title3)
                    .bold()
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(isAlert ? Color.red.opacity(0.15) : Color(.secondarySystemBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isAlert ? Color.red : Color.gray.opacity(0.3), lineWidth: isAlert ? 3 : 1)
        )
    }
}

struct EngineeringDashboardView: View {
    @ObservedObject var viewModel: TpmsViewModel

    var body: some View {
        VStack(spacing: 8) {
            // Header Row
            HStack {
                Text("Tire").frame(maxWidth: .infinity)
                Text("Pressure").frame(maxWidth: .infinity)
                Text("Temp").frame(maxWidth: .infinity)
                Text("Battery").frame(maxWidth: .infinity)
                Text("Sec").frame(maxWidth: .infinity)
                Text("RSSI").frame(maxWidth: .infinity)
                Text("Sensor ID").frame(maxWidth: .infinity)
            }
            .font(.caption)
            .bold()
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)

            // 4 Tire Rows
            ForEach(TireKey.allCases) { key in
                let data = viewModel.tyreStatuses[key] ?? TpmsData()
                let isNoData = !data.isValid || data.timestamp == 0
                let pStr = isNoData ? "-" : (viewModel.usePsi ? "\(Int(data.pressurePsi))" : String(format: "%.1f", data.pressurePsi * 0.0689476))
                let tStr = isNoData ? "-" : (viewModel.useCelsius ? "\(Int(data.temperatureCelsius))" : "\(Int(data.temperatureCelsius * 1.8 + 32))")
                let battStr = isNoData ? "-" : (data.isBatteryGood ? "Good" : "Bad")
                let elapsed = isNoData ? "-" : "\(max(0, Int((Int64(Date().timeIntervalSince1970 * 1000) - data.timestamp) / 1000)))s"
                let rssiStr = isNoData ? "-" : "\(data.rssiDbm)"
                let idStr = data.sensorId ?? "-"

                HStack {
                    // Enlarged 18pt ExtraBold numbers in Engineering view!
                    Text(key.rawValue).font(.system(size: 18, weight: .bold)).frame(maxWidth: .infinity)
                    Text(pStr).font(.system(size: 18, weight: .bold)).frame(maxWidth: .infinity)
                    Text(tStr).font(.system(size: 18, weight: .bold)).frame(maxWidth: .infinity)
                    Text(battStr).font(.system(size: 18, weight: .bold)).frame(maxWidth: .infinity)
                    Text(elapsed).font(.system(size: 18, weight: .bold)).frame(maxWidth: .infinity)
                    Text(rssiStr).font(.system(size: 18, weight: .bold)).frame(maxWidth: .infinity)
                    Text(idStr).font(.system(size: 18, weight: .bold)).frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }
}
