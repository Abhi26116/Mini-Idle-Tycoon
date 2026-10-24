import SwiftUI

@main
struct MiniIdleTycoonApp: App {
    @StateObject private var viewModel = GameEngineViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainGameView(viewModel: viewModel)
                // `initial: true` also covers the very first launch.
                .onChange(of: scenePhase, initial: true) { _, phase in
                    switch phase {
                    case .active:
                        viewModel.handleAppDidBecomeActive()
                    case .background:
                        viewModel.handleAppDidEnterBackground()
                    default:
                        break
                    }
                }
        }
    }
}
