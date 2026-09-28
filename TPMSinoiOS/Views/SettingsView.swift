import SwiftUI

public struct SettingsView: View {
    @ObservedObject var viewModel: TpmsViewModel
    @State private var showEraseAlert = false

    public var body: some View {
        Form {
            Section(header: Text("Sensor List")) {
                Button("Erase Sensor List", role: .destructive) {
                    showEraseAlert = true
                }
            }

            Section(header: Text("Dashboard Mode")) {
                Toggle("Engineering Mode", isOn: $viewModel.useEngineeringDashboard)
            }

            Section(header: Text("Alarm Options")) {
                Toggle("Vibrate on Alarm", isOn: $viewModel.vibrateOnAlarm)
                Toggle("Enable Disconnection Alarm", isOn: $viewModel.enableDisconnectionAlarm)
                Toggle("Loud Disconnection Alarm", isOn: $viewModel.loudDisconnectionAlarm)
            }

            Section(header: Text("Display Units")) {
                Toggle("Use PSI (Pressure)", isOn: $viewModel.usePsi)
                Toggle("Use Celsius (Temperature)", isOn: $viewModel.useCelsius)
            }

            Section(header: Text("Front Tires Boundaries")) {
                Stepper("Min Pressure: \(Int(viewModel.minPressureFront)) PSI", value: $viewModel.minPressureFront, in: 20...80)
                Stepper("Nominal Pressure: \(Int(viewModel.nominalPressureFront)) PSI", value: $viewModel.nominalPressureFront, in: 20...80)
                Stepper("Max Pressure: \(Int(viewModel.maxPressureFront)) PSI", value: $viewModel.maxPressureFront, in: 20...80)
                Stepper("Max Temp: \(Int(viewModel.maxTempFront)) °C", value: $viewModel.maxTempFront, in: 40...90)
            }

            Section(header: Text("Rear Tires Boundaries")) {
                Stepper("Min Pressure: \(Int(viewModel.minPressureRear)) PSI", value: $viewModel.minPressureRear, in: 20...80)
                Stepper("Nominal Pressure: \(Int(viewModel.nominalPressureRear)) PSI", value: $viewModel.nominalPressureRear, in: 20...80)
                Stepper("Max Pressure: \(Int(viewModel.maxPressureRear)) PSI", value: $viewModel.maxPressureRear, in: 20...80)
                Stepper("Max Temp: \(Int(viewModel.maxTempRear)) °C", value: $viewModel.maxTempRear, in: 40...90)
            }

            Section(header: Text("Simulation Mode")) {
                Toggle("Simulation Mode", isOn: Binding(
                    get: { viewModel.isSimulationMode },
                    set: { viewModel.setSimulationMode($0) }
                ))
            }
        }
        .alert("Erase Sensor List?", isPresented: $showEraseAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Erase", role: .destructive) {
                viewModel.eraseSensorList()
            }
        } message: {
            Text("This will erase all pairings of the sensors with the tires. Continue?")
        }
        .onDisappear {
            viewModel.saveSettings()
        }
    }
}
