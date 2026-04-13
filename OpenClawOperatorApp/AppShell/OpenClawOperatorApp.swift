import Observation
import OpenClawCore
import SwiftData
import SwiftUI
import UIKit

@main
struct OpenClawOperatorApp: App {
    @UIApplicationDelegateAdaptor(OpenClawAppDelegate.self) private var appDelegate
    @State private var appModel: AppModel
    private let container: ModelContainer

    init() {
        let schema = Schema([
            GatewayProfileRecord.self,
            SessionRecord.self,
            MessageRecord.self,
            DiagnosticsRecord.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        self.container = container

        let persistence = PersistenceController(container: container)
        let keychain = KeychainStore(service: "ai.openclaw.operator")
        let pushManager = PushNotificationManager.shared
        let client = GatewayClient()
        let repository = GatewayOperatorRepository(client: client)

        _appModel = State(initialValue: AppModel(
            repository: repository,
            client: client,
            persistence: persistence,
            keychain: keychain,
            pushManager: pushManager
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .task {
                    await appModel.bootstrap()
                }
        }
        .modelContainer(container)
    }
}

final class OpenClawAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        _ = application
        PushNotificationManager.shared.updateDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        _ = application
        PushNotificationManager.shared.recordFailure(error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        _ = application
        PushNotificationManager.shared.route(from: userInfo)
        completionHandler(.newData)
    }
}
