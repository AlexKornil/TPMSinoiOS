import SwiftUI

public struct AnalyticsView: View {
    @ObservedObject var viewModel: TpmsViewModel

    public var body: some View {
        NavigationView {
            List(viewModel.logsHistory) { packet in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sensor: \(packet.sensorId ?? "-")")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(packet.pressurePsi)) PSI")
                            .bold()
                            .foregroundColor(.blue)
                    }
                    HStack {
                        Text("Temp: \(Int(packet.temperatureCelsius)) °C")
                            .font(.subheadline)
                        Spacer()
                        Text("RSSI: \(packet.rssiDbm) dBm")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Telemetry History")
        }
    }
}
