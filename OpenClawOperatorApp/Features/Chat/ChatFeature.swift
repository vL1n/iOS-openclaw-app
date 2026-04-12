import OpenClawCore
import SwiftUI

struct ChatFeature: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
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
                        .padding()
                    }
                    .onChange(of: model.messages.count) { _, _ in
                        proxy.scrollTo(model.messages.last?.messageId, anchor: .bottom)
                    }
                }

                Divider()

                HStack(alignment: .bottom, spacing: 12) {
                    TextField("给 OpenClaw 发消息", text: $model.composeText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)

                    Button {
                        Task { await model.sendMessage() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.ultraThinMaterial)
                .overlay(alignment: .topLeading) {
                    Text("当前会话: \(selectedSessionID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 6)
                }
            } else {
                ContentUnavailableView(
                    "还没有选中的会话",
                    systemImage: "bubble.left.and.text.bubble.right",
                    description: Text("先在 Sessions 标签中选一个会话，或者连接后刷新列表。")
                )
            }
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refreshAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}

private struct ConnectionBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.connectionSummary)
                    .font(.subheadline.weight(.semibold))
                Text(model.profileDraft.endpoint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
    }

    private var color: Color {
        switch model.connectionState.phase {
        case .subscribed:
            return .green
        case .degraded, .offline:
            return .orange
        case .connecting, .challenged, .authenticated, .reconnecting:
            return .blue
        case .idle:
            return .gray
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(message.primaryText)
                .font(.body)
            if message.streamState != .stable || message.errorState != .none {
                HStack(spacing: 6) {
                    Label(message.streamState.rawValue, systemImage: "waveform")
                    if message.errorState != .none {
                        Label(message.errorState.rawValue, systemImage: "exclamationmark.triangle.fill")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
            return Color(red: 0.92, green: 0.96, blue: 0.99)
        case .user:
            return Color(red: 0.07, green: 0.45, blue: 0.69).opacity(0.15)
        case .system:
            return Color.gray.opacity(0.14)
        case .tool:
            return Color.orange.opacity(0.12)
        }
    }
}
