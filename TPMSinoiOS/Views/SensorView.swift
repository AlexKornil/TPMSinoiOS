import SwiftUI

public struct SensorView: View {
    @ObservedObject var viewModel: TpmsViewModel
    @State private var selectedTire: TireKey? = nil

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Sensor Pairing")
                    .font(.title2)
                    .bold()

                Text("Make the sensor transmit using the activator, then tap a tire position to assign.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let latest = viewModel.tpmsData, latest.isValid {
                    VStack {
                        Text("RECEIVED SENSOR DATA")
                            .font(.caption)
                            .bold()
                        Text("Sensor ID: \(latest.sensorId ?? "-")")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.blue)
                        Text("\(Int(latest.pressurePsi)) PSI | \(Int(latest.temperatureCelsius)) °C | \(latest.rssiDbm) dBm")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(TireKey.allCases) { key in
                        Button(action: {
                            if let sensorId = viewModel.tpmsData?.sensorId {
                                viewModel.assignSensorToTire(key, sensorId: sensorId)
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text(key.rawValue)
                                    .font(.title)
                                    .bold()
                                Text(viewModel.sensorPairs[key] ?? "Unassigned")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(16)
                        }
                    }
                }
            }
            .padding()
        }
    }
}
