import SwiftUI

@main
struct TPMSinoApp: App {
    @StateObject private var viewModel = TpmsViewModel()

    var body: some Scene {
        WindowGroup {
            MainTabView(viewModel: viewModel)
        }
    }
}
