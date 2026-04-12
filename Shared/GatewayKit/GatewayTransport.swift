import Foundation

public protocol GatewayTransport: Sendable {
    func connect(url: URL, headers: [String: String]) async throws
    func disconnect() async
    func send(_ value: JSONValue) async throws
    func receive() async throws -> JSONValue
}

public enum GatewayTransportError: Error, Sendable {
    case invalidURL
    case disconnected
    case unsupportedMessage
}

public actor URLSessionWebSocketTransport: GatewayTransport {
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?

    public init() {}

    public func connect(url: URL, headers: [String: String]) async throws {
        var request = URLRequest(url: url)
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let session = URLSession(configuration: .ephemeral)
        let task = session.webSocketTask(with: request)
        task.resume()

        self.session = session
        self.task = task
    }

    public func disconnect() async {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    public func send(_ value: JSONValue) async throws {
        guard let task else {
            throw GatewayTransportError.disconnected
        }

        let data = try JSONEncoder().encode(value)
        try await task.send(.data(data))
    }

    public func receive() async throws -> JSONValue {
        guard let task else {
            throw GatewayTransportError.disconnected
        }

        let message = try await task.receive()
        let data: Data

        switch message {
        case .data(let payload):
            data = payload
        case .string(let payload):
            data = Data(payload.utf8)
        @unknown default:
            throw GatewayTransportError.unsupportedMessage
        }

        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}

public actor InMemoryGatewayTransport: GatewayTransport {
    public private(set) var sentValues: [JSONValue] = []
    private var inbox: [JSONValue]
    private var isConnected = false

    public init(inbox: [JSONValue] = []) {
        self.inbox = inbox
    }

    public func connect(url: URL, headers: [String: String]) async throws {
        _ = headers
        guard !url.absoluteString.isEmpty else {
            throw GatewayTransportError.invalidURL
        }

        isConnected = true
    }

    public func disconnect() async {
        isConnected = false
    }

    public func send(_ value: JSONValue) async throws {
        guard isConnected else {
            throw GatewayTransportError.disconnected
        }

        sentValues.append(value)
    }

    public func receive() async throws -> JSONValue {
        guard isConnected else {
            throw GatewayTransportError.disconnected
        }

        guard !inbox.isEmpty else {
            throw GatewayTransportError.disconnected
        }

        return inbox.removeFirst()
    }

    public func enqueue(_ value: JSONValue) {
        inbox.append(value)
    }
}
