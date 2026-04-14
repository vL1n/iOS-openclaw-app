import OpenClawCore
import SwiftUI

struct ChatFeature: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        ZStack {
            ClawBackground()

            VStack(spacing: 16) {
                ClawHeader(
                    eyebrow: "Operator Link",
                    title: "Chat",
                    subtitle: "Live control channel to \(model.profileDraft.endpoint)",
                    actionSystemImage: "arrow.clockwise"
                ) {
                    Task { await model.refreshAll() }
                }

                ConnectionBanner()

                if let selectedSessionID = model.selectedSessionID {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(model.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.messageId)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: model.messages.count) { _, _ in
                            proxy.scrollTo(model.messages.last?.messageId, anchor: .bottom)
                        }
                    }

                    ClawCard(padding: 12) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SESSION \(selectedSessionID)")
                                .font(.system(.caption2, design: .monospaced).weight(.bold))
                                .tracking(1.6)
                                .foregroundStyle(OpenClawTheme.neon)

                            HStack(alignment: .bottom, spacing: 12) {
                                TextField("给 OpenClaw 发消息", text: $model.composeText, axis: .vertical)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(OpenClawTheme.text)
                                    .tint(OpenClawTheme.neon)
                                    .lineLimit(1...4)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(OpenClawTheme.panelStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                                Button {
                                    Task { await model.sendMessage() }
                                } label: {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 18, weight: .black))
                                        .foregroundStyle(OpenClawTheme.ink)
                                        .frame(width: 44, height: 44)
                                        .background(OpenClawTheme.neon, in: Circle())
                                        .shadow(color: OpenClawTheme.neon.opacity(0.45), radius: 14)
                                }
                                .buttonStyle(.plain)
                                .disabled(model.composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .opacity(model.composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                            }
                        }
                    }
                } else {
                    Spacer(minLength: 20)
                    ClawEmptyState(
                        title: "还没有选中的会话",
                        message: "先在 Sessions 标签中选一个会话，或者连接后刷新列表。",
                        systemImage: "bubble.left.and.text.bubble.right"
                    )
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 10)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct ConnectionBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ClawCard(padding: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.24))
                        .frame(width: 34, height: 34)
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.connectionSummary)
                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                        .foregroundStyle(OpenClawTheme.text)
                    Text(model.profileDraft.endpoint)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(OpenClawTheme.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Text(model.connectionState.phase.rawValue.uppercased())
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.14), in: Capsule())
            }
        }
    }

    private var color: Color {
        switch model.connectionState.phase {
        case .subscribed:
            return OpenClawTheme.neon
        case .degraded, .offline:
            return OpenClawTheme.amber
        case .connecting, .challenged, .authenticated, .reconnecting:
            return OpenClawTheme.blue
        case .idle:
            return OpenClawTheme.secondaryText
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessageItem

    var body: some View {
        HStack {
            if message.role == .assistant || message.role == .system {
                bubble
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                bubble
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(1.2)
                .foregroundStyle(accent)
            Text(message.primaryText)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(OpenClawTheme.text)
            if message.streamState != .stable || message.errorState != .none {
                HStack(spacing: 6) {
                    Label(message.streamState.rawValue, systemImage: "waveform")
                    if message.errorState != .none {
                        Label(message.errorState.rawValue, systemImage: "exclamationmark.triangle.fill")
                    }
                }
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(OpenClawTheme.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: 330, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        }
    }

    private var label: String {
        switch message.role {
        case .assistant:
            return "Assistant"
        case .user:
            return "You"
        case .system:
            return "System"
        case .tool:
            return "Tool"
        }
    }

    private var background: Color {
        switch message.role {
        case .assistant:
            return OpenClawTheme.panelStrong
        case .user:
            return OpenClawTheme.blue.opacity(0.22)
        case .system:
            return OpenClawTheme.panel
        case .tool:
            return OpenClawTheme.amber.opacity(0.16)
        }
    }

    private var accent: Color {
        switch message.role {
        case .assistant:
            return OpenClawTheme.neon
        case .user:
            return OpenClawTheme.blue
        case .system:
            return OpenClawTheme.secondaryText
        case .tool:
            return OpenClawTheme.amber
        }
    }
}
