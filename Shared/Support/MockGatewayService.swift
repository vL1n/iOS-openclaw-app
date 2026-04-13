import Foundation

public actor MockGatewayClient: GatewayClientProtocol {
    public nonisolated let connectionUpdates: AsyncStream<GatewayConnectionState>
    public nonisolated let serverEvents: AsyncStream<GatewayServerEvent>

    private var connectionContinuation: AsyncStream<GatewayConnectionState>.Continuation
    private var eventContinuation: AsyncStream<GatewayServerEvent>.Continuation
    private var messagesBySession: [String: [ChatMessageItem]]
    private var sessions: [ChatSessionSummary]

    public init() {
        self.sessions = Self.defaultSessions
        self.messagesBySession = Self.defaultMessages

        let connectionParts = AsyncStream.makeStream(of: GatewayConnectionState.self)
        self.connectionUpdates = connectionParts.stream
        self.connectionContinuation = connectionParts.continuation

        let eventParts = AsyncStream.makeStream(of: GatewayServerEvent.self)
        self.serverEvents = eventParts.stream
        self.eventContinuation = eventParts.continuation
    }

    public init(
        sessions: [ChatSessionSummary],
        messagesBySession: [String: [ChatMessageItem]]
    ) {
        self.sessions = sessions
        self.messagesBySession = messagesBySession

        let connectionParts = AsyncStream.makeStream(of: GatewayConnectionState.self)
        self.connectionUpdates = connectionParts.stream
        self.connectionContinuation = connectionParts.continuation

        let eventParts = AsyncStream.makeStream(of: GatewayServerEvent.self)
        self.serverEvents = eventParts.stream
        self.eventContinuation = eventParts.continuation
    }

    public func connect(profile: GatewayProfile, token: String, deviceID: String) async throws {
        _ = profile
        _ = token
        _ = deviceID
        connectionContinuation.yield(.init(phase: .connecting, capabilities: .basicChat))
        connectionContinuation.yield(.init(phase: .subscribed, capabilities: .all))
    }

    public func disconnect() async {
        connectionContinuation.yield(.init(phase: .offline, capabilities: .all))
    }

    public func refreshAuth() async throws {}

    public func invoke(method: String, params: [String : JSONValue]) async throws -> JSONValue {
        _ = method
        _ = params
        return .object([:])
    }

    public func listSessions() async throws -> [ChatSessionSummary] {
        sessions
    }

    public func loadMessages(sessionID: String) async throws -> [ChatMessageItem] {
        messagesBySession[sessionID] ?? []
    }

    public func sendMessage(sessionID: String, text: String) async throws {
        let user = ChatMessageItem(
            messageId: UUID().uuidString,
            role: .user,
            contentBlocks: [.init(value: text)],
            createdAt: .now
        )
        let assistant = ChatMessageItem(
            messageId: UUID().uuidString,
            role: .assistant,
            contentBlocks: [.init(value: "Mock reply for: \(text)")],
            createdAt: .now
        )
        messagesBySession[sessionID, default: []].append(contentsOf: [user, assistant])
        eventContinuation.yield(.init(method: "chat.message", params: [
            "sessionId": .string(sessionID),
            "text": .string(assistant.primaryText)
        ]))
    }

    public func fetchOpsSnapshot() async throws -> OpsSnapshot {
        OpsSnapshot(
            gatewayHealth: .healthy,
            nodeCount: 3,
            operatorCount: 1,
            pendingApprovals: 2,
            modelStatus: ["gpt-5.4", "claude-sonnet"],
            usageSummary: .init(costToday: 6.42, tokensToday: 184_000, activeModels: ["gpt-5.4", "claude-sonnet"]),
            onlineNodes: [
                .init(nodeId: "ios-01", name: "iPhone Runner", status: "online", lastSeenAt: .now),
                .init(nodeId: "mac-mini", name: "Mac mini", status: "busy", lastSeenAt: .now.addingTimeInterval(-180))
            ],
            approvals: [
                .init(approvalId: "approval-1", title: "Run shell command", risk: "medium", createdAt: .now.addingTimeInterval(-600)),
                .init(approvalId: "approval-2", title: "Delete temporary file", risk: "high", createdAt: .now.addingTimeInterval(-1200))
            ]
        )
    }

    public func registerPush(token: String, environment: String, bundleID: String, deviceID: String) async throws -> PushRegistration {
        _ = bundleID
        return PushRegistration(
            deviceId: deviceID,
            apnsToken: token,
            environment: environment,
            gatewayFingerprint: "mock-fingerprint"
        )
    }

    private static let defaultSessions: [ChatSessionSummary] = [
        .init(sessionId: "session-1", title: "Release Prep", model: "gpt-5.4", updatedAt: .now, unreadCount: 1, runState: .streaming),
        .init(sessionId: "session-2", title: "Ops Audit", model: "claude-sonnet", updatedAt: .now.addingTimeInterval(-3_600), unreadCount: 0, runState: .idle)
    ]

    private static let defaultMessages: [String: [ChatMessageItem]] = [
        "session-1": [
            .init(messageId: "msg-1", role: .system, contentBlocks: [.init(value: "You are connected to OpenClaw.")], createdAt: .now.addingTimeInterval(-400)),
            .init(messageId: "msg-2", role: .user, contentBlocks: [.init(value: "Summarize the latest deployment status.")], createdAt: .now.addingTimeInterval(-320)),
            .init(messageId: "msg-3", role: .assistant, contentBlocks: [.init(value: "All core services are healthy. One approval is still pending.")], createdAt: .now.addingTimeInterval(-300))
        ],
        "session-2": [
            .init(messageId: "msg-4", role: .user, contentBlocks: [.init(value: "How many nodes are online?")], createdAt: .now.addingTimeInterval(-6_000)),
            .init(messageId: "msg-5", role: .assistant, contentBlocks: [.init(value: "Two nodes are online and one is idle.")], createdAt: .now.addingTimeInterval(-5_900))
        ]
    ]
}
