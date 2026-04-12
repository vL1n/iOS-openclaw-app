import Foundation

public struct BootstrapPayload: Sendable, Hashable {
    public var sessions: [ChatSessionSummary]
    public var diagnostics: DiagnosticsBundle

    public init(sessions: [ChatSessionSummary], diagnostics: DiagnosticsBundle) {
        self.sessions = sessions
        self.diagnostics = diagnostics
    }
}

public protocol OperatorRepositoryProtocol: Sendable {
    func bootstrap() async throws -> BootstrapPayload
    func refreshSessions() async throws -> [ChatSessionSummary]
    func messages(for sessionID: String) async throws -> [ChatMessageItem]
    func sendMessage(_ text: String, to sessionID: String) async throws -> [ChatMessageItem]
    func refreshOps() async throws -> OpsSnapshot
    func registerPush(token: String, environment: String, bundleID: String, deviceID: String) async throws -> PushRegistration
    func recordConnection(_ state: GatewayConnectionState) async
    func diagnostics(pushStatus: String) async -> DiagnosticsBundle
}

public actor GatewayOperatorRepository: OperatorRepositoryProtocol {
    private let client: GatewayClientProtocol
    private var sessionsCache: [ChatSessionSummary] = []
    private var messageCache: [String: [ChatMessageItem]] = [:]
    private var timeline: [DiagnosticsBundle.ConnectionTimelineEntry] = [
        .init(phase: .idle, note: "Repository initialized")
    ]
    private var lastRPCError: String?

    public init(client: GatewayClientProtocol) {
        self.client = client
    }

    public func bootstrap() async throws -> BootstrapPayload {
        let sessions = try await refreshSessions()
        let diagnostics = await diagnostics(pushStatus: "Not registered")
        return BootstrapPayload(sessions: sessions, diagnostics: diagnostics)
    }

    public func refreshSessions() async throws -> [ChatSessionSummary] {
        do {
            sessionsCache = try await client.listSessions().sorted(by: { $0.updatedAt > $1.updatedAt })
            return sessionsCache
        } catch {
            lastRPCError = error.localizedDescription
            if sessionsCache.isEmpty {
                throw error
            }

            return sessionsCache
        }
    }

    public func messages(for sessionID: String) async throws -> [ChatMessageItem] {
        do {
            let messages = try await client.loadMessages(sessionID: sessionID).sorted(by: { $0.createdAt < $1.createdAt })
            messageCache[sessionID] = messages
            return messages
        } catch {
            lastRPCError = error.localizedDescription
            if let cached = messageCache[sessionID] {
                return cached
            }

            throw error
        }
    }

    public func sendMessage(_ text: String, to sessionID: String) async throws -> [ChatMessageItem] {
        let optimisticMessage = ChatMessageItem(
            messageId: UUID().uuidString,
            role: .user,
            contentBlocks: [.init(value: text)],
            createdAt: .now,
            streamState: .streaming
        )

        var existing = messageCache[sessionID] ?? []
        existing.append(optimisticMessage)
        messageCache[sessionID] = existing

        do {
            try await client.sendMessage(sessionID: sessionID, text: text)
            let refreshed = try await messages(for: sessionID)
            messageCache[sessionID] = refreshed
            return refreshed
        } catch {
            lastRPCError = error.localizedDescription
            existing[existing.count - 1].streamState = .interrupted
            existing[existing.count - 1].errorState = .sendFailed
            messageCache[sessionID] = existing
            return existing
        }
    }

    public func refreshOps() async throws -> OpsSnapshot {
        do {
            return try await client.fetchOpsSnapshot()
        } catch {
            lastRPCError = error.localizedDescription
            throw error
        }
    }

    public func registerPush(token: String, environment: String, bundleID: String, deviceID: String) async throws -> PushRegistration {
        do {
            return try await client.registerPush(
                token: token,
                environment: environment,
                bundleID: bundleID,
                deviceID: deviceID
            )
        } catch {
            lastRPCError = error.localizedDescription
            throw error
        }
    }

    public func recordConnection(_ state: GatewayConnectionState) async {
        timeline.append(.init(
            phase: state.phase,
            timestamp: state.lastTransitionAt,
            note: state.lastErrorDescription
        ))
    }

    public func diagnostics(pushStatus: String) async -> DiagnosticsBundle {
        DiagnosticsBundle(
            connectionTimeline: timeline,
            lastRPCError: lastRPCError,
            retryCount: timeline.filter { $0.phase == .reconnecting }.count,
            tlsNotes: "Use wss:// for remote or Tailscale connections. ws:// is only intended for trusted local use.",
            pushStatus: pushStatus
        )
    }
}
