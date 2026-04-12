import Foundation
import Testing
@testable import OpenClawCore

@Test func jsonValueRoundTrip() throws {
    let value: JSONValue = .object([
        "message": .string("hello"),
        "count": .number(3),
        "flags": .array([.bool(true), .bool(false)]),
        "nested": .object(["ok": .bool(true)])
    ])

    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

    #expect(decoded == value)
}

@Test func connectionStateMachineTransitionsInOrder() {
    var machine = GatewayConnectionStateMachine()
    let now = Date(timeIntervalSince1970: 100)

    let connecting = machine.apply(.startConnecting, now: now)
    #expect(connecting.phase == .connecting)

    let challenged = machine.apply(.challengeReceived, now: now.addingTimeInterval(1))
    #expect(challenged.phase == .challenged)

    let authenticated = machine.apply(.authenticated(.basicChat), now: now.addingTimeInterval(2))
    #expect(authenticated.phase == .authenticated)
    #expect(authenticated.capabilities.chat)

    let subscribed = machine.apply(.subscribed, now: now.addingTimeInterval(3))
    #expect(subscribed.phase == .subscribed)

    let reconnecting = machine.apply(.reconnecting, now: now.addingTimeInterval(4))
    #expect(reconnecting.phase == .reconnecting)
    #expect(reconnecting.retryCount == 1)
}

@Test func repositoryFallsBackToCachedMessagesAfterSendFailure() async throws {
    let client = MockGatewayClient()
    let repository = GatewayOperatorRepository(client: client)

    let initial = try await repository.messages(for: "session-1")
    #expect(!initial.isEmpty)

    let updated = try await repository.sendMessage("Ship the beta", to: "session-1")
    #expect(updated.last?.primaryText.contains("Ship the beta") == true || updated.last?.primaryText.contains("Mock reply") == true)

    let diagnostics = await repository.diagnostics(pushStatus: "Pending")
    #expect(diagnostics.connectionTimeline.first?.phase == .idle)
}
