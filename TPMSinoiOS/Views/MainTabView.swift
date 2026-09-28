import SwiftUI

public struct MainTabView: View {
    @ObservedObject var viewModel: TpmsViewModel

    public var body: some View {
        TabView {
            DashboardView(viewModel: viewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }

            if BleConstants.ENABLE_LOG_COLLECTION && viewModel.useEngineeringDashboard {
                AnalyticsView(viewModel: viewModel)
                    .tabItem {
                        Label("Logs", systemImage: "list.bullet.rectangle")
                    }
            }

            SensorView(viewModel: viewModel)
                .tabItem {
                    Label("Sensors", systemImage: "wave.3.right")
                }

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .alert("Connection Lost!", isPresented: $viewModel.showConnectionLostWarning) {
            Button("OK", role: .cancel) {
                viewModel.silenceAlarms()
            }
        } message: {
            Text("Bluetooth connection to TPMS Dispatcher was lost.")
        }
    }
}
