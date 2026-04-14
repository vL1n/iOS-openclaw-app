import OpenClawCore
import SwiftUI

struct SessionsFeature: View {
    @Environment(AppModel.self) private var model
    @State private var searchText = ""

    var body: some View {
        ZStack {
            ClawBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ClawHeader(
                        eyebrow: "Memory Index",
                        title: "Sessions",
                        subtitle: "\(filteredSessions.count) active timelines",
                        actionSystemImage: "arrow.clockwise"
                    ) {
                        Task { await model.refreshSessions() }
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(OpenClawTheme.neon)
                        TextField("搜索会话", text: $searchText)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(OpenClawTheme.text)
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(OpenClawTheme.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(OpenClawTheme.line, lineWidth: 1)
                    }

                    if filteredSessions.isEmpty {
                        ClawEmptyState(
                            title: "暂无会话",
                            message: "连接 Gateway 后刷新，这里会显示最近的 OpenClaw 会话。",
                            systemImage: "rectangle.stack.badge.person.crop"
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredSessions) { session in
                                SessionCard(session: session, isSelected: model.selectedSessionID == session.sessionId) {
                                    Task { await model.openSession(session.sessionId) }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var filteredSessions: [ChatSessionSummary] {
        guard !searchText.isEmpty else { return model.sessions }
        return model.sessions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.model.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private struct SessionCard: View {
    let session: ChatSessionSummary
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ClawCard(padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(session.title)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(OpenClawTheme.text)
                            Text(session.sessionId)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(OpenClawTheme.secondaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(session.updatedAt, style: .relative)
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .foregroundStyle(isSelected ? OpenClawTheme.ink : OpenClawTheme.neon)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? OpenClawTheme.neon : OpenClawTheme.neon.opacity(0.14), in: Capsule())
                    }

                    HStack(spacing: 10) {
                        Tag(text: session.model, systemImage: "cpu")
                        Tag(text: session.runState.rawValue.capitalized, systemImage: "waveform.path")
                        if session.unreadCount > 0 {
                            Tag(text: "\(session.unreadCount) unread", systemImage: "bell.badge")
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct Tag: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.system(.caption2, design: .monospaced).weight(.semibold))
            .foregroundStyle(OpenClawTheme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(OpenClawTheme.panelStrong, in: Capsule())
    }
}
