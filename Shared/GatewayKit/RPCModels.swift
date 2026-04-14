import Foundation

public enum GatewayMethod {
    public static let connectHello = "connect"
    public static let connectRefresh = "connect.refresh"
    public static let sessionsList = "sessions.list"
    public static let chatHistory = "chat.history"
    public static let chatSend = "chat.send"
    public static let healthSnapshot = "health"
    public static let approvalsList = "exec.approvals.get"
    public static let presenceList = "system-presence"
    public static let usageSummary = "usage.status"
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
            "type": .string("req"),
            "id": .string(id),
            "method": .string(method),
            "params": .object(params)
        ])
    }
}

public struct JSONRPCError: LocalizedError, Sendable, Hashable {
    public var code: Int
    public var message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    public var errorDescription: String? {
        code == -1 ? message : "[\(code)] \(message)"
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
