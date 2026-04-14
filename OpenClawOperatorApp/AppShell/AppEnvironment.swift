import Foundation
import Observation
import OpenClawCore

enum AppTab: Hashable {
    case chat
    case sessions
    case ops
    case settings
}

struct GatewayProfileDraft: Sendable {
    var name = "My OpenClaw"
    var endpoint = "ws://10.84.1.2:18789"
    var transportMode: TransportMode = .localWebSocket
    var allowInsecureLocal = true
    var requestedScopes = "operator.read,operator.write,operator.approvals"

    init() {}

    init(profile: GatewayProfile) {
        name = profile.name
        endpoint = profile.endpointURL.absoluteString
        transportMode = profile.transportMode
        allowInsecureLocal = profile.allowInsecureLocal
        requestedScopes = profile.requestedScopes.joined(separator: ",")
    }

    func buildProfile(lastConnectedAt: Date? = nil) throws -> GatewayProfile {
        guard let url = URL(string: endpoint) else {
            throw DraftError.invalidURL
        }

        return GatewayProfile(
            name: name.isEmpty ? "My OpenClaw" : name,
            endpointURL: url,
            transportMode: transportMode,
            allowInsecureLocal: allowInsecureLocal,
            requestedScopes: requestedScopes
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            lastConnectedAt: lastConnectedAt
        )
    }

    enum DraftError: LocalizedError {
        case invalidURL

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "请输入有效的 Gateway WebSocket 地址。"
            }
        }
    }
}

@MainActor
@Observable
final class AppModel {
    var selectedTab: AppTab = .chat
    var profileDraft = GatewayProfileDraft()
    var authToken = ""
    var deviceID = UUID().uuidString

    var connectionState = GatewayConnectionState()
    var diagnostics = DiagnosticsBundle(connectionTimeline: [], lastRPCError: nil, retryCount: 0, tlsNotes: nil, pushStatus: "未配置")
    var sessions: [ChatSessionSummary] = []
    var selectedSessionID: String?
    var messages: [ChatMessageItem] = []
    var opsSnapshot: OpsSnapshot?
    var composeText = ""

    var bannerMessage: String?
    var isBootstrapping = false
    var isWorking = false
    var pushAuthorizationStatus = "未请求"
    var pushRegistrationStatus = "未注册"
    var latestPushToken: String?

    private let repository: OperatorRepositoryProtocol
    private let client: GatewayClientProtocol
    private let persistence: PersistenceController
    private let keychain: KeychainStoring
    private let pushManager: PushNotificationManaging

    private var connectionTask: Task<Void, Never>?
    private var routeTask: Task<Void, Never>?

    init(
        repository: OperatorRepositoryProtocol,
        client: GatewayClientProtocol,
        persistence: PersistenceController,
        keychain: KeychainStoring,
        pushManager: PushNotificationManaging
    ) {
        self.repository = repository
        self.client = client
        self.persistence = persistence
        self.keychain = keychain
        self.pushManager = pushManager
    }

    func shutdown() {
        connectionTask?.cancel()
        connectionTask = nil
        routeTask?.cancel()
        routeTask = nil
    }

    func bootstrap() async {
        guard !isBootstrapping else { return }
        isBootstrapping = true
        defer { isBootstrapping = false }

        if let profile = persistence.loadProfile() {
            profileDraft = GatewayProfileDraft(profile: profile)
            deviceID = keychain.string(for: "device-id") ?? deviceID
        }

        authToken = keychain.string(for: "gateway-token") ?? ""
        sessions = persistence.loadSessions()
        diagnostics = persistence.loadDiagnostics() ?? diagnostics

        if selectedSessionID == nil {
            selectedSessionID = sessions.first?.sessionId
        }

        if let selectedSessionID {
            messages = persistence.loadMessages(sessionID: selectedSessionID)
        }

        observeConnectionUpdates()
        observeNotificationRoutes()
    }

    var canAccessOps: Bool {
        connectionState.capabilities.health || connectionState.capabilities.approvals || connectionState.capabilities.presence
    }

    var connectionSummary: String {
        switch connectionState.phase {
        case .idle:
            return "未连接"
        case .connecting:
            return "连接中"
        case .challenged:
            return "鉴权挑战中"
        case .authenticated:
            return "已认证"
        case .subscribed:
            return "已订阅"
        case .degraded:
            return "连接退化"
        case .reconnecting:
            return "重连中"
        case .offline:
            return "离线"
        }
    }

    func connect() async {
        isWorking = true
        defer { isWorking = false }

        do {
            let profile = try profileDraft.buildProfile(lastConnectedAt: .now)
            try keychain.set(authToken, for: "gateway-token")
            try keychain.set(deviceID, for: "device-id")
            persistence.save(profile: profile)

            try await client.connect(profile: profile, token: authToken, deviceID: deviceID)
            bannerMessage = "已连接到 \(profile.name)"
            await refreshAll()

            if let latestPushToken {
                await registerPushIfPossible(token: latestPushToken)
            }
        } catch {
            bannerMessage = error.localizedDescription
        }
    }

    func disconnect() async {
        await client.disconnect()
        bannerMessage = "连接已关闭"
    }

    func refreshAll() async {
        await refreshSessions()

        if let selectedSessionID {
            await loadMessages(for: selectedSessionID)
        }

        await refreshOps()
        diagnostics = await repository.diagnostics(pushStatus: pushRegistrationStatus)
        persistence.save(diagnostics: diagnostics)
    }

    func refreshSessions() async {
        do {
            let fetched = try await repository.refreshSessions()
            sessions = fetched
            persistence.save(sessions: fetched)

            if selectedSessionID == nil {
                selectedSessionID = fetched.first?.sessionId
            }
        } catch {
            bannerMessage = error.localizedDescription
        }
    }

    func refreshOps() async {
        guard canAccessOps || connectionState.phase == .subscribed else { return }

        do {
            opsSnapshot = try await repository.refreshOps()
        } catch {
            bannerMessage = error.localizedDescription
        }
    }

    func loadMessages(for sessionID: String) async {
        selectedSessionID = sessionID
        do {
            let fetched = try await repository.messages(for: sessionID)
            messages = fetched
            persistence.save(messages: fetched, sessionID: sessionID)
        } catch {
            bannerMessage = error.localizedDescription
        }
    }

    func sendMessage() async {
        let outgoing = composeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outgoing.isEmpty, let sessionID = selectedSessionID else { return }

        composeText = ""
        messages = optimisticMessagesAppending(outgoing, to: messages)
        persistence.save(messages: messages, sessionID: sessionID)

        do {
            let refreshed = try await repository.sendMessage(outgoing, to: sessionID)
            messages = refreshed
            persistence.save(messages: refreshed, sessionID: sessionID)
            await refreshSessions()
        } catch {
            bannerMessage = error.localizedDescription
        }
    }

    func requestPushAuthorization() async {
        let granted = await pushManager.requestAuthorization()
        pushAuthorizationStatus = granted ? "已授权" : "被拒绝"
        latestPushToken = pushManager.latestDeviceToken

        if let latestPushToken {
            await registerPushIfPossible(token: latestPushToken)
        }
    }

    func openSession(_ sessionID: String) async {
        selectedSessionID = sessionID
        selectedTab = .chat
        await loadMessages(for: sessionID)
    }

    private func registerPushIfPossible(token: String) async {
        guard connectionState.phase == .subscribed else {
            pushRegistrationStatus = "等待连接后注册"
            return
        }

        do {
            let registration = try await repository.registerPush(
                token: token,
                environment: "development",
                bundleID: "ai.openclaw.operator",
                deviceID: deviceID
            )
            pushRegistrationStatus = "已注册 \(registration.environment)"
            diagnostics = await repository.diagnostics(pushStatus: pushRegistrationStatus)
            persistence.save(diagnostics: diagnostics)
        } catch {
            pushRegistrationStatus = "注册失败"
            bannerMessage = error.localizedDescription
        }
    }

    private func observeConnectionUpdates() {
        guard connectionTask == nil else { return }

        connectionTask = Task { [weak self] in
            guard let self else { return }
            for await update in client.connectionUpdates {
                await repository.recordConnection(update)
                let diagnostics = await repository.diagnostics(pushStatus: pushRegistrationStatus)
                await MainActor.run {
                    self.connectionState = update
                    self.diagnostics = diagnostics
                    self.persistence.save(diagnostics: diagnostics)
                    if let error = update.lastErrorDescription, !error.isEmpty {
                        self.bannerMessage = error
                    }
                }
            }
        }
    }

    private func observeNotificationRoutes() {
        guard routeTask == nil else { return }

        routeTask = Task { [weak self] in
            guard let self else { return }
            for await sessionID in pushManager.routes {
                await self.openSession(sessionID)
            }
        }
    }

    private func optimisticMessagesAppending(_ text: String, to existing: [ChatMessageItem]) -> [ChatMessageItem] {
        var updated = existing
        updated.append(.init(
            messageId: UUID().uuidString,
            role: .user,
            contentBlocks: [.init(value: text)],
            createdAt: .now,
            streamState: .streaming
        ))
        return updated
    }
}
