import SwiftUI

@main
struct MiniIdleTycoonApp: App {
    private let adsManager: GoogleAdsManager
    @StateObject private var viewModel: GameEngineViewModel
    @Environment(\.scenePhase) private var scenePhase

    /// `true` when the app is only hosting unit tests: no ads or consent forms.
    private static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    init() {
        let adsManager = GoogleAdsManager()
        self.adsManager = adsManager
        _viewModel = StateObject(wrappedValue: GameEngineViewModel(adsManager: adsManager))
    }

    var body: some Scene {
        WindowGroup {
            MainGameView(viewModel: viewModel)
                // `initial: true` also covers the very first launch.
                .onChange(of: scenePhase, initial: true) { _, phase in
                    switch phase {
                    case .active:
                        viewModel.handleAppDidBecomeActive()
                        if !Self.isRunningTests {
                            adsManager.start()
                        }
                    case .background:
                        viewModel.handleAppDidEnterBackground()
                    default:
                        break
                    }
                }
        }
    }
}
