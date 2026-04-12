import Foundation
import OpenClawCore
import SwiftData

@Model
final class GatewayProfileRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var endpointURL: String
    var transportMode: String
    var allowInsecureLocal: Bool
    var requestedScopes: String
    var lastConnectedAt: Date?

    init(profile: GatewayProfile) {
        id = profile.id
        name = profile.name
        endpointURL = profile.endpointURL.absoluteString
        transportMode = profile.transportMode.rawValue
        allowInsecureLocal = profile.allowInsecureLocal
        requestedScopes = profile.requestedScopes.joined(separator: ",")
        lastConnectedAt = profile.lastConnectedAt
    }

    var profileValue: GatewayProfile? {
        guard
            let url = URL(string: endpointURL),
            let transport = TransportMode(rawValue: transportMode)
        else {
            return nil
        }

        return GatewayProfile(
            id: id,
            name: name,
            endpointURL: url,
            transportMode: transport,
            allowInsecureLocal: allowInsecureLocal,
            requestedScopes: requestedScopes
                .split(separator: ",")
                .map { String($0) },
            lastConnectedAt: lastConnectedAt
        )
    }
}

@Model
final class SessionRecord {
    @Attribute(.unique) var sessionId: String
    var title: String
    var model: String
    var updatedAt: Date
    var unreadCount: Int
    var runState: String

    init(summary: ChatSessionSummary) {
        sessionId = summary.sessionId
        title = summary.title
        model = summary.model
        updatedAt = summary.updatedAt
        unreadCount = summary.unreadCount
        runState = summary.runState.rawValue
    }

    var summaryValue: ChatSessionSummary {
        ChatSessionSummary(
            sessionId: sessionId,
            title: title,
            model: model,
            updatedAt: updatedAt,
            unreadCount: unreadCount,
            runState: ChatRunState(rawValue: runState) ?? .idle
        )
    }
}

@Model
final class MessageRecord {
    @Attribute(.unique) var messageId: String
    var sessionId: String
    var role: String
    var text: String
    var createdAt: Date
    var streamState: String
    var errorState: String

    init(sessionID: String, message: ChatMessageItem) {
        messageId = message.messageId
        sessionId = sessionID
        role = message.role.rawValue
        text = message.primaryText
        createdAt = message.createdAt
        streamState = message.streamState.rawValue
        errorState = message.errorState.rawValue
    }

    var messageValue: ChatMessageItem {
        ChatMessageItem(
            messageId: messageId,
            role: ChatMessageItem.Role(rawValue: role) ?? .assistant,
            contentBlocks: [.init(value: text)],
            createdAt: createdAt,
            streamState: ChatMessageItem.StreamState(rawValue: streamState) ?? .stable,
            errorState: ChatMessageItem.ErrorState(rawValue: errorState) ?? .none
        )
    }
}

@Model
final class DiagnosticsRecord {
    @Attribute(.unique) var id: String
    var payload: Data

    init(bundle: DiagnosticsBundle) {
        id = "latest"
        payload = (try? JSONEncoder().encode(bundle)) ?? Data()
    }
}

@MainActor
final class PersistenceController {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func loadProfile() -> GatewayProfile? {
        let descriptor = FetchDescriptor<GatewayProfileRecord>()
        return (try? container.mainContext.fetch(descriptor).first)?.profileValue
    }

    func save(profile: GatewayProfile) {
        let descriptor = FetchDescriptor<GatewayProfileRecord>()
        let existing = (try? container.mainContext.fetch(descriptor).first)
        if let existing {
            existing.name = profile.name
            existing.endpointURL = profile.endpointURL.absoluteString
            existing.transportMode = profile.transportMode.rawValue
            existing.allowInsecureLocal = profile.allowInsecureLocal
            existing.requestedScopes = profile.requestedScopes.joined(separator: ",")
            existing.lastConnectedAt = profile.lastConnectedAt
        } else {
            container.mainContext.insert(GatewayProfileRecord(profile: profile))
        }

        try? container.mainContext.save()
    }

    func loadSessions() -> [ChatSessionSummary] {
        let descriptor = FetchDescriptor<SessionRecord>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return (try? container.mainContext.fetch(descriptor))?.map(\.summaryValue) ?? []
    }

    func save(sessions: [ChatSessionSummary]) {
        let descriptor = FetchDescriptor<SessionRecord>()
        let existing = (try? container.mainContext.fetch(descriptor)) ?? []
        existing.forEach(container.mainContext.delete)
        sessions.map(SessionRecord.init).forEach(container.mainContext.insert)
        try? container.mainContext.save()
    }

    func loadMessages(sessionID: String) -> [ChatMessageItem] {
        let predicate = #Predicate<MessageRecord> { $0.sessionId == sessionID }
        let descriptor = FetchDescriptor<MessageRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? container.mainContext.fetch(descriptor))?.map(\.messageValue) ?? []
    }

    func save(messages: [ChatMessageItem], sessionID: String) {
        let predicate = #Predicate<MessageRecord> { $0.sessionId == sessionID }
        let descriptor = FetchDescriptor<MessageRecord>(predicate: predicate)
        let existing = (try? container.mainContext.fetch(descriptor)) ?? []
        existing.forEach(container.mainContext.delete)
        messages.map { MessageRecord(sessionID: sessionID, message: $0) }.forEach(container.mainContext.insert)
        try? container.mainContext.save()
    }

    func loadDiagnostics() -> DiagnosticsBundle? {
        let descriptor = FetchDescriptor<DiagnosticsRecord>()
        guard
            let record = try? container.mainContext.fetch(descriptor).first,
            let value = try? JSONDecoder().decode(DiagnosticsBundle.self, from: record.payload)
        else {
            return nil
        }

        return value
    }

    func save(diagnostics: DiagnosticsBundle) {
        let descriptor = FetchDescriptor<DiagnosticsRecord>()
        if let existing = try? container.mainContext.fetch(descriptor).first {
            existing.payload = (try? JSONEncoder().encode(diagnostics)) ?? Data()
        } else {
            container.mainContext.insert(DiagnosticsRecord(bundle: diagnostics))
        }

        try? container.mainContext.save()
    }
}
