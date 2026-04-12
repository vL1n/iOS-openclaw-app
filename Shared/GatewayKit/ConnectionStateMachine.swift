import Foundation

public enum GatewayLifecycleEvent: Sendable {
    case startConnecting
    case challengeReceived
    case authenticated(CapabilitySet)
    case subscribed
    case degraded(String)
    case reconnecting
    case disconnected(String?)
    case reset
}

public struct GatewayConnectionStateMachine: Sendable {
    public private(set) var state: GatewayConnectionState

    public init(state: GatewayConnectionState = GatewayConnectionState()) {
        self.state = state
    }

    @discardableResult
    public mutating func apply(_ event: GatewayLifecycleEvent, now: Date = .now) -> GatewayConnectionState {
        switch event {
        case .startConnecting:
            state.phase = .connecting
            state.lastErrorDescription = nil
        case .challengeReceived:
            state.phase = .challenged
        case .authenticated(let capabilities):
            state.phase = .authenticated
            state.capabilities = capabilities
            state.lastErrorDescription = nil
        case .subscribed:
            state.phase = .subscribed
        case .degraded(let error):
            state.phase = .degraded
            state.lastErrorDescription = error
        case .reconnecting:
            state.phase = .reconnecting
            state.retryCount += 1
        case .disconnected(let error):
            state.phase = .offline
            state.lastErrorDescription = error
        case .reset:
            state = GatewayConnectionState()
        }

        state.lastTransitionAt = now
        return state
    }
}
