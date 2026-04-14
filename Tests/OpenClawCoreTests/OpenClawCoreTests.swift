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

@Test func openClawRequestEnvelopeUsesGatewayFrameShape() {
    let request = JSONRPCRequest(
        id: "req-1",
        method: "connect",
        params: ["role": .string("operator")]
    )

    let object = request.payload.objectValue ?? [:]

    #expect(object["type"] == .string("req"))
    #expect(object["id"] == .string("req-1"))
    #expect(object["method"] == .string("connect"))
    #expect(object["jsonrpc"] == nil)
}

@Test func deviceAuthPayloadV3MatchesGatewayFormat() {
    let payload = GatewayDeviceAuthPayload.buildV3(
        deviceId: "device-1",
        clientId: "client-1",
        clientMode: "ui",
        role: "operator",
        scopes: ["operator.read", "operator.write"],
        signedAtMs: 123,
        token: "token-1",
        nonce: "nonce-1",
        platform: "iOS",
        deviceFamily: "iPhone"
    )

    #expect(payload == "v3|device-1|client-1|ui|operator|operator.read,operator.write|123|token-1|nonce-1|ios|iphone")
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
