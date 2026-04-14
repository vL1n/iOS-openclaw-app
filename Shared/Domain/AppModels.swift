import Foundation

public enum TransportMode: String, Codable, CaseIterable, Sendable {
    case secureWebSocket = "wss"
    case localWebSocket = "ws"

    public var displayName: String {
        switch self {
        case .secureWebSocket:
            return "Secure WebSocket"
        case .localWebSocket:
            return "Trusted Local WebSocket"
        }
    }
}

public struct GatewayProfile: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var endpointURL: URL
    public var transportMode: TransportMode
    public var allowInsecureLocal: Bool
    public var requestedScopes: [String]
    public var lastConnectedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        endpointURL: URL,
        transportMode: TransportMode,
        allowInsecureLocal: Bool = false,
        requestedScopes: [String] = ["operator.read", "operator.write", "operator.approvals"],
        lastConnectedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.endpointURL = endpointURL
        self.transportMode = transportMode
        self.allowInsecureLocal = allowInsecureLocal
        self.requestedScopes = requestedScopes
        self.lastConnectedAt = lastConnectedAt
    }
}

public struct CapabilitySet: Codable, Hashable, Sendable {
    public var chat: Bool
    public var sessions: Bool
    public var approvals: Bool
    public var presence: Bool
    public var health: Bool
    public var usage: Bool
    public var logs: Bool
    public var configRead: Bool

    public init(
        chat: Bool = false,
        sessions: Bool = false,
        approvals: Bool = false,
        presence: Bool = false,
        health: Bool = false,
        usage: Bool = false,
        logs: Bool = false,
        configRead: Bool = false
    ) {
        self.chat = chat
        self.sessions = sessions
        self.approvals = approvals
        self.presence = presence
        self.health = health
        self.usage = usage
        self.logs = logs
        self.configRead = configRead
    }

    public static let all = CapabilitySet(
        chat: true,
        sessions: true,
        approvals: true,
        presence: true,
        health: true,
        usage: true,
        logs: true,
        configRead: true
    )

    public static let basicChat = CapabilitySet(
        chat: true,
        sessions: true,
        presence: true,
        health: true
    )

    public var asMethodMap: [String: Bool] {
        [
            "chat": chat,
            "sessions": sessions,
            "approvals": approvals,
            "presence": presence,
            "health": health,
            "usage": usage,
            "logs": logs,
            "configRead": configRead
        ]
    }

    public static func from(methods: [String]) -> CapabilitySet {
        var set = CapabilitySet()
        let joined = methods.joined(separator: ",").lowercased()
        set.chat = joined.contains("chat")
        set.sessions = joined.contains("session")
        set.approvals = joined.contains("approval")
        set.presence = joined.contains("presence") || joined.contains("node")
        set.health = joined.contains("health")
        set.usage = joined.contains("usage")
        set.logs = joined.contains("log")
        set.configRead = joined.contains("config")
        return set
    }
}

public enum ConnectionPhase: String, Codable, Sendable {
    case idle
    case connecting
    case challenged
    case authenticated
    case subscribed
    case degraded
    case reconnecting
    case offline
}

public struct GatewayConnectionState: Codable, Hashable, Sendable {
    public var phase: ConnectionPhase
    public var retryCount: Int
    public var lastErrorDescription: String?
    public var capabilities: CapabilitySet
    public var lastTransitionAt: Date

    public init(
        phase: ConnectionPhase = .idle,
        retryCount: Int = 0,
        lastErrorDescription: String? = nil,
        capabilities: CapabilitySet = CapabilitySet(),
        lastTransitionAt: Date = .now
    ) {
        self.phase = phase
        self.retryCount = retryCount
        self.lastErrorDescription = lastErrorDescription
        self.capabilities = capabilities
        self.lastTransitionAt = lastTransitionAt
    }
}

public enum ChatRunState: String, Codable, CaseIterable, Sendable {
    case idle
    case streaming
    case waiting
    case failed
}

public struct ChatSessionSummary: Identifiable, Codable, Hashable, Sendable {
    public var id: String { sessionId }
    public var sessionId: String
    public var title: String
    public var model: String
    public var updatedAt: Date
    public var unreadCount: Int
    public var runState: ChatRunState

    public init(
        sessionId: String,
        title: String,
        model: String,
        updatedAt: Date,
        unreadCount: Int = 0,
        runState: ChatRunState = .idle
    ) {
        self.sessionId = sessionId
        self.title = title
        self.model = model
        self.updatedAt = updatedAt
        self.unreadCount = unreadCount
        self.runState = runState
    }
}

public struct ChatMessageItem: Identifiable, Codable, Hashable, Sendable {
    public enum Role: String, Codable, CaseIterable, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    public struct ContentBlock: Codable, Hashable, Sendable {
        public enum Kind: String, Codable, Sendable {
            case text
            case status
            case tool
        }

        public var kind: Kind
        public var value: String

        public init(kind: Kind = .text, value: String) {
            self.kind = kind
            self.value = value
        }
    }

    public enum StreamState: String, Codable, Sendable {
        case stable
        case streaming
        case interrupted
    }

    public enum ErrorState: String, Codable, Sendable {
        case none
        case sendFailed
        case receiveFailed
        case unauthorized
    }

    public var id: String { messageId }
    public var messageId: String
    public var role: Role
    public var contentBlocks: [ContentBlock]
    public var createdAt: Date
    public var streamState: StreamState
    public var errorState: ErrorState

    public init(
        messageId: String,
        role: Role,
        contentBlocks: [ContentBlock],
        createdAt: Date = .now,
        streamState: StreamState = .stable,
        errorState: ErrorState = .none
    ) {
        self.messageId = messageId
        self.role = role
        self.contentBlocks = contentBlocks
        self.createdAt = createdAt
        self.streamState = streamState
        self.errorState = errorState
    }

    public var primaryText: String {
        contentBlocks.map(\.value).joined(separator: "\n")
    }
}

public struct NodePresenceItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String { nodeId }
    public var nodeId: String
    public var name: String
    public var status: String
    public var lastSeenAt: Date

    public init(nodeId: String, name: String, status: String, lastSeenAt: Date) {
        self.nodeId = nodeId
        self.name = name
        self.status = status
        self.lastSeenAt = lastSeenAt
    }
}

public struct ApprovalItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String { approvalId }
    public var approvalId: String
    public var title: String
    public var risk: String
    public var createdAt: Date

    public init(approvalId: String, title: String, risk: String, createdAt: Date) {
        self.approvalId = approvalId
        self.title = title
        self.risk = risk
        self.createdAt = createdAt
    }
}

public struct UsageSummary: Codable, Hashable, Sendable {
    public var costToday: Double
    public var tokensToday: Int
    public var activeModels: [String]

    public init(costToday: Double = 0, tokensToday: Int = 0, activeModels: [String] = []) {
        self.costToday = costToday
        self.tokensToday = tokensToday
        self.activeModels = activeModels
    }
}

public struct OpsSnapshot: Codable, Hashable, Sendable {
    public enum GatewayHealth: String, Codable, Sendable {
        case healthy
        case degraded
        case offline
    }

    public var gatewayHealth: GatewayHealth
    public var nodeCount: Int
    public var operatorCount: Int
    public var pendingApprovals: Int
    public var modelStatus: [String]
    public var usageSummary: UsageSummary
    public var onlineNodes: [NodePresenceItem]
    public var approvals: [ApprovalItem]

    public init(
        gatewayHealth: GatewayHealth,
        nodeCount: Int,
        operatorCount: Int,
        pendingApprovals: Int,
        modelStatus: [String],
        usageSummary: UsageSummary,
        onlineNodes: [NodePresenceItem],
        approvals: [ApprovalItem]
    ) {
        self.gatewayHealth = gatewayHealth
        self.nodeCount = nodeCount
        self.operatorCount = operatorCount
        self.pendingApprovals = pendingApprovals
        self.modelStatus = modelStatus
        self.usageSummary = usageSummary
        self.onlineNodes = onlineNodes
        self.approvals = approvals
    }
}

public struct PushRegistration: Codable, Hashable, Sendable {
    public var deviceId: String
    public var apnsToken: String
    public var environment: String
    public var gatewayFingerprint: String
    public var registeredAt: Date

    public init(
        deviceId: String,
        apnsToken: String,
        environment: String,
        gatewayFingerprint: String,
        registeredAt: Date = .now
    ) {
        self.deviceId = deviceId
        self.apnsToken = apnsToken
        self.environment = environment
        self.gatewayFingerprint = gatewayFingerprint
        self.registeredAt = registeredAt
    }
}

public struct DiagnosticsBundle: Codable, Hashable, Sendable {
    public struct ConnectionTimelineEntry: Codable, Hashable, Sendable {
        public var phase: ConnectionPhase
        public var timestamp: Date
        public var note: String?

        public init(phase: ConnectionPhase, timestamp: Date = .now, note: String? = nil) {
            self.phase = phase
            self.timestamp = timestamp
            self.note = note
        }
    }

    public var connectionTimeline: [ConnectionTimelineEntry]
    public var lastRPCError: String?
    public var retryCount: Int
    public var tlsNotes: String?
    public var pushStatus: String

    public init(
        connectionTimeline: [ConnectionTimelineEntry],
        lastRPCError: String?,
        retryCount: Int,
        tlsNotes: String?,
        pushStatus: String
    ) {
        self.connectionTimeline = connectionTimeline
        self.lastRPCError = lastRPCError
        self.retryCount = retryCount
        self.tlsNotes = tlsNotes
        self.pushStatus = pushStatus
    }
}
