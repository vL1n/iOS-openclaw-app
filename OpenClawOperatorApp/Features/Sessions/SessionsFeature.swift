import OpenClawCore
import SwiftUI

struct SessionsFeature: View {
    @Environment(AppModel.self) private var model
    @State private var searchText = ""

    var body: some View {
        List(filteredSessions) { session in
            Button {
                Task { await model.openSession(session.sessionId) }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(session.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(session.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        Label(session.model, systemImage: "cpu")
                        Label(session.runState.rawValue.capitalized, systemImage: "waveform.path")
                        if session.unreadCount > 0 {
                            Label("\(session.unreadCount)", systemImage: "bell.badge")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .listRowBackground(model.selectedSessionID == session.sessionId ? Color(red: 0.94, green: 0.97, blue: 0.99) : Color.clear)
        }
        .searchable(text: $searchText, prompt: "搜索会话")
        .navigationTitle("Sessions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refreshSessions() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    private var filteredSessions: [ChatSessionSummary] {
        guard !searchText.isEmpty else { return model.sessions }
        return model.sessions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.model.localizedCaseInsensitiveContains(searchText)
        }
    }
}
