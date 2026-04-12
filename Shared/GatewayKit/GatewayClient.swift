import Foundation

public protocol GatewayClientProtocol: Sendable {
    var connectionUpdates: AsyncStream<GatewayConnectionState> { get }
    var serverEvents: AsyncStream<GatewayServerEvent> { get }

    func connect(profile: GatewayProfile, token: String, deviceID: String) async throws
    func disconnect() async
    func refreshAuth() async throws
    func invoke(method: String, params: [String: JSONValue]) async throws -> JSONValue
    func listSessions() async throws -> [ChatSessionSummary]
    func loadMessages(sessionID: String) async throws -> [ChatMessageItem]
    func sendMessage(sessionID: String, text: String) async throws
    func fetchOpsSnapshot() async throws -> OpsSnapshot
    func registerPush(token: String, environment: String, bundleID: String, deviceID: String) async throws -> PushRegistration
}

public enum GatewayClientError: Error, Sendable {
    case invalidTransport(String)
    case unauthorized
    case malformedResponse(String)
}

public actor GatewayClient: GatewayClientProtocol {
    public nonisolated let connectionUpdates: AsyncStream<GatewayConnectionState>
    public nonisolated let serverEvents: AsyncStream<GatewayServerEvent>

    private let transport: GatewayTransport
    private let connectMethod: String
    private var stateMachine = GatewayConnectionStateMachine()
    private var requestCounter = 0
    private var receiveTask: Task<Void, Never>?
    private var pendingResponses: [String: CheckedContinuation<JSONValue, Error>] = [:]
    private var connectionContinuation: AsyncStream<GatewayConnectionState>.Continuation
    private var eventContinuation: AsyncStream<GatewayServerEvent>.Continuation

    public init(
        transport: GatewayTransport = URLSessionWebSocketTransport(),
        connectMethod: String = GatewayMethod.connectHello
    ) {
        self.transport = transport
        self.connectMethod = connectMethod

        let connectionParts = AsyncStream.makeStream(of: GatewayConnectionState.self)
        self.connectionUpdates = connectionParts.stream
        self.connectionContinuation = connectionParts.continuation

        let eventParts = AsyncStream.makeStream(of: GatewayServerEvent.self)
        self.serverEvents = eventParts.stream
        self.eventContinuation = eventParts.continuation
    }

    public func connect(profile: GatewayProfile, token: String, deviceID: String) async throws {
        try validate(profile: profile)

        await publishState(.startConnecting)

        try await transport.connect(url: profile.endpointURL, headers: [
            "Authorization": "Bearer \(token)",
            "X-OpenClaw-Role": "operator"
        ])

        startReceiveLoopIfNeeded()
        await publishState(.challengeReceived)

        let helloResponse = try await invoke(method: connectMethod, params: [
            "role": .string("operator"),
            "scopes": .array(profile.requestedScopes.map(JSONValue.string)),
            "deviceId": .string(deviceID)
        ])

        let capabilities = extractCapabilities(from: helloResponse)
        await publishState(.authenticated(capabilities))
        await publishState(.subscribed)
    }

    public func disconnect() async {
        receiveTask?.cancel()
        receiveTask = nil

        for continuation in pendingResponses.values {
            continuation.resume(throwing: GatewayTransportError.disconnected)
        }

        pendingResponses.removeAll()
        await transport.disconnect()
        await publishState(.disconnected(nil))
    }

    public func refreshAuth() async throws {
        _ = try await invoke(method: GatewayMethod.connectRefresh, params: [:])
    }

    public func invoke(method: String, params: [String: JSONValue]) async throws -> JSONValue {
        let id = nextRequestID()
        let request = JSONRPCRequest(id: id, method: method, params: params)

        return try await withCheckedThrowingContinuation { continuation in
            pendingResponses[id] = continuation

            Task {
                do {
                    try await transport.send(request.payload)
                } catch {
                    await self.failPending(id: id, error: error)
                }
            }
        }
    }

    public func listSessions() async throws -> [ChatSessionSummary] {
        let result = try await invoke(method: GatewayMethod.sessionsList, params: [:])
        return parseSessions(from: result)
    }

    public func loadMessages(sessionID: String) async throws -> [ChatMessageItem] {
        let result = try await invoke(method: GatewayMethod.chatHistory, params: ["sessionId": .string(sessionID)])
        return parseMessages(from: result)
    }

    public func sendMessage(sessionID: String, text: String) async throws {
        _ = try await invoke(method: GatewayMethod.chatSend, params: [
            "sessionId": .string(sessionID),
            "content": .string(text)
        ])
    }

    public func fetchOpsSnapshot() async throws -> OpsSnapshot {
        async let healthResponse = invoke(method: GatewayMethod.healthSnapshot, params: [:])
        async let presenceResponse = invoke(method: GatewayMethod.presenceList, params: [:])
        async let approvalsResponse = invoke(method: GatewayMethod.approvalsList, params: [:])
        async let usageResponse = invoke(method: GatewayMethod.usageSummary, params: [:])

        let health = try await healthResponse
        let presence = try await presenceResponse
        let approvals = try await approvalsResponse
        let usage = try await usageResponse

        return OpsSnapshot(
            gatewayHealth: parseHealth(from: health),
            nodeCount: parsePresenceItems(from: presence).count,
            operatorCount: extractOperatorCount(from: health),
            pendingApprovals: parseApprovals(from: approvals).count,
            modelStatus: extractModelStatus(from: health),
            usageSummary: parseUsage(from: usage),
            onlineNodes: parsePresenceItems(from: presence),
            approvals: parseApprovals(from: approvals)
        )
    }

    public func registerPush(token: String, environment: String, bundleID: String, deviceID: String) async throws -> PushRegistration {
        let response = try await invoke(method: GatewayMethod.pushRegister, params: [
            "apnsToken": .string(token),
            "environment": .string(environment),
            "bundleId": .string(bundleID),
            "deviceId": .string(deviceID)
        ])

        let object = response.objectValue ?? [:]
        let fingerprint = object["gatewayFingerprint"]?.stringValue ?? "unknown"

        return PushRegistration(
            deviceId: deviceID,
            apnsToken: token,
            environment: environment,
            gatewayFingerprint: fingerprint
        )
    }

    private func validate(profile: GatewayProfile) throws {
        switch profile.transportMode {
        case .secureWebSocket:
            guard profile.endpointURL.scheme?.lowercased() == "wss" else {
                throw GatewayClientError.invalidTransport("Secure mode requires a wss:// URL.")
            }
        case .localWebSocket:
            guard profile.allowInsecureLocal, profile.endpointURL.scheme?.lowercased() == "ws" else {
                throw GatewayClientError.invalidTransport("Local mode requires an allowed ws:// URL.")
            }
        }
    }

    private func nextRequestID() -> String {
        requestCounter += 1
        return "rpc-\(requestCounter)"
    }

    private func startReceiveLoopIfNeeded() {
        guard receiveTask == nil else { return }

        receiveTask = Task {
            while !Task.isCancelled {
                do {
                    let payload = try await self.transport.receive()
                    await self.handleInbound(payload)
                } catch {
                    await self.publishState(.degraded(error.localizedDescription))
                    await self.publishState(.reconnecting)
                    break
                }
            }
        }
    }

    private func handleInbound(_ payload: JSONValue) async {
        guard let object = payload.objectValue else { return }

        if let errorObject = object["error"]?.objectValue {
            let id = object["id"]?.stringValue ?? ""
            let error = JSONRPCError(
                code: errorObject["code"]?.intValue ?? -1,
                message: errorObject["message"]?.stringValue ?? "Unknown RPC error"
            )
            await failPending(id: id, error: error)
            return
        }

        if let id = object["id"]?.stringValue {
            let result = object["result"] ?? .null
            let continuation = pendingResponses.removeValue(forKey: id)
            continuation?.resume(returning: result)
            return
        }

        if let method = object["method"]?.stringValue {
            let params = object["params"]?.objectValue ?? [:]
            eventContinuation.yield(GatewayServerEvent(method: method, params: params))
        }
    }

    private func failPending(id: String, error: Error) {
        let continuation = pendingResponses.removeValue(forKey: id)
        continuation?.resume(throwing: error)
    }

    private func publishState(_ event: GatewayLifecycleEvent) async {
        let state = stateMachine.apply(event)
        connectionContinuation.yield(state)
    }
}

private extension GatewayClient {
    func extractCapabilities(from result: JSONValue) -> CapabilitySet {
        let object = result.objectValue ?? [:]
        if let methods = object["methods"]?.arrayValue?.compactMap(\.stringValue) {
            return CapabilitySet.from(methods: methods)
        }

        if let capabilities = object["capabilities"]?.objectValue {
            return CapabilitySet(
                chat: capabilities["chat"]?.boolValue ?? false,
                sessions: capabilities["sessions"]?.boolValue ?? false,
                approvals: capabilities["approvals"]?.boolValue ?? false,
                presence: capabilities["presence"]?.boolValue ?? false,
                health: capabilities["health"]?.boolValue ?? false,
                usage: capabilities["usage"]?.boolValue ?? false,
                logs: capabilities["logs"]?.boolValue ?? false,
                configRead: capabilities["configRead"]?.boolValue ?? false
            )
        }

        return .basicChat
    }

    func parseSessions(from result: JSONValue) -> [ChatSessionSummary] {
        let array = result.arrayValue ?? result.objectValue?["items"]?.arrayValue ?? []

        return array.compactMap { item in
            guard let object = item.objectValue else { return nil }
            return ChatSessionSummary(
                sessionId: object["sessionId"]?.stringValue ?? object["id"]?.stringValue ?? UUID().uuidString,
                title: object["title"]?.stringValue ?? "Untitled Session",
                model: object["model"]?.stringValue ?? "unknown",
                updatedAt: object["updatedAt"]?.dateValue ?? .now,
                unreadCount: object["unreadCount"]?.intValue ?? 0,
                runState: ChatRunState(rawValue: object["runState"]?.stringValue ?? "") ?? .idle
            )
        }
    }

    func parseMessages(from result: JSONValue) -> [ChatMessageItem] {
        let array = result.arrayValue ?? result.objectValue?["items"]?.arrayValue ?? []

        return array.compactMap { item in
            guard let object = item.objectValue else { return nil }

            let blocks = object["contentBlocks"]?.arrayValue?.compactMap { block in
                guard let blockObject = block.objectValue else { return nil }
                return ChatMessageItem.ContentBlock(
                    kind: ChatMessageItem.ContentBlock.Kind(rawValue: blockObject["kind"]?.stringValue ?? "") ?? .text,
                    value: blockObject["value"]?.stringValue ?? ""
                )
            } ?? [ChatMessageItem.ContentBlock(value: object["text"]?.stringValue ?? "")]

            return ChatMessageItem(
                messageId: object["messageId"]?.stringValue ?? object["id"]?.stringValue ?? UUID().uuidString,
                role: ChatMessageItem.Role(rawValue: object["role"]?.stringValue ?? "") ?? .assistant,
                contentBlocks: blocks,
                createdAt: object["createdAt"]?.dateValue ?? .now,
                streamState: ChatMessageItem.StreamState(rawValue: object["streamState"]?.stringValue ?? "") ?? .stable,
                errorState: ChatMessageItem.ErrorState(rawValue: object["errorState"]?.stringValue ?? "") ?? .none
            )
        }
    }

    func parseHealth(from result: JSONValue) -> OpsSnapshot.GatewayHealth {
        let value = result.objectValue?["status"]?.stringValue?.lowercased() ?? "healthy"
        return OpsSnapshot.GatewayHealth(rawValue: value) ?? .healthy
    }

    func extractOperatorCount(from result: JSONValue) -> Int {
        result.objectValue?["operatorCount"]?.intValue ?? 1
    }

    func extractModelStatus(from result: JSONValue) -> [String] {
        result.objectValue?["models"]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    func parsePresenceItems(from result: JSONValue) -> [NodePresenceItem] {
        let array = result.arrayValue ?? result.objectValue?["items"]?.arrayValue ?? []
        return array.compactMap { item in
            guard let object = item.objectValue else { return nil }
            return NodePresenceItem(
                nodeId: object["nodeId"]?.stringValue ?? object["id"]?.stringValue ?? UUID().uuidString,
                name: object["name"]?.stringValue ?? "Node",
                status: object["status"]?.stringValue ?? "unknown",
                lastSeenAt: object["lastSeenAt"]?.dateValue ?? .now
            )
        }
    }

    func parseApprovals(from result: JSONValue) -> [ApprovalItem] {
        let array = result.arrayValue ?? result.objectValue?["items"]?.arrayValue ?? []
        return array.compactMap { item in
            guard let object = item.objectValue else { return nil }
            return ApprovalItem(
                approvalId: object["approvalId"]?.stringValue ?? object["id"]?.stringValue ?? UUID().uuidString,
                title: object["title"]?.stringValue ?? "Approval Required",
                risk: object["risk"]?.stringValue ?? "medium",
                createdAt: object["createdAt"]?.dateValue ?? .now
            )
        }
    }

    func parseUsage(from result: JSONValue) -> UsageSummary {
        let object = result.objectValue ?? [:]
        return UsageSummary(
            costToday: object["costToday"]?.doubleValue ?? 0,
            tokensToday: object["tokensToday"]?.intValue ?? 0,
            activeModels: object["activeModels"]?.arrayValue?.compactMap(\.stringValue) ?? []
        )
    }
}
