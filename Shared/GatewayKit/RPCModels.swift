import Foundation

public enum GatewayMethod {
    public static let connectHello = "connect.hello"
    public static let connectRefresh = "connect.refresh"
    public static let sessionsList = "sessions.list"
    public static let chatHistory = "chat.history"
    public static let chatSend = "chat.send"
    public static let healthSnapshot = "health.snapshot"
    public static let approvalsList = "approvals.list"
    public static let presenceList = "presence.list"
    public static let usageSummary = "usage.summary"
    public static let pushRegister = "push.register"
}

public struct JSONRPCRequest: Sendable, Hashable {
    public var id: String
    public var method: String
    public var params: [String: JSONValue]

    public init(id: String, method: String, params: [String: JSONValue]) {
        self.id = id
        self.method = method
        self.params = params
    }

    public var payload: JSONValue {
        .object([
            "jsonrpc": .string("2.0"),
            "id": .string(id),
            "method": .string(method),
            "params": .object(params)
        ])
    }
}

public struct JSONRPCError: Error, Sendable, Hashable {
    public var code: Int
    public var message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
}

public struct GatewayServerEvent: Sendable, Hashable {
    public var method: String
    public var params: [String: JSONValue]

    public init(method: String, params: [String: JSONValue]) {
        self.method = method
        self.params = params
    }
}
