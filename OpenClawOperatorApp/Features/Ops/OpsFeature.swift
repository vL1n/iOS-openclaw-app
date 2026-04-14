import OpenClawCore
import SwiftUI

struct OpsFeature: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            ClawBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ClawHeader(
                        eyebrow: "Ops Matrix",
                        title: "Gateway",
                        subtitle: model.connectionSummary,
                        actionSystemImage: "arrow.clockwise"
                    ) {
                        Task { await model.refreshOps() }
                    }

                    if !model.canAccessOps {
                        ClawEmptyState(
                            title: "当前连接没有 Ops 能力",
                            message: "如果这是基础 scope 的 token，聊天仍可使用；需要更多 scopes 才会看到运维卡片。",
                            systemImage: "lock.slash"
                        )
                    } else if let snapshot = model.opsSnapshot {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MetricCard(title: "Gateway", value: snapshot.gatewayHealth.rawValue.capitalized, systemImage: "antenna.radiowaves.left.and.right", tint: snapshot.gatewayHealth == .healthy ? OpenClawTheme.neon : OpenClawTheme.amber)
                            MetricCard(title: "Nodes", value: "\(snapshot.nodeCount)", systemImage: "point.3.connected.trianglepath.dotted", tint: OpenClawTheme.blue)
                            MetricCard(title: "Approvals", value: "\(snapshot.pendingApprovals)", systemImage: "checkmark.seal", tint: OpenClawTheme.amber)
                            MetricCard(title: "Tokens", value: "\(snapshot.usageSummary.tokensToday)", systemImage: "bolt.horizontal.circle", tint: Color(red: 0.82, green: 0.56, blue: 1.0))
                        }

                        SectionBlock(title: "Active Models", systemImage: "cpu.fill") {
                            ForEach(snapshot.modelStatus, id: \.self) { modelStatus in
                                MatrixRow(title: modelStatus, detail: "ready", systemImage: "circle.hexagongrid.fill", tint: OpenClawTheme.neon)
                            }
                        }

                        SectionBlock(title: "Online Nodes", systemImage: "network") {
                            ForEach(snapshot.onlineNodes) { node in
                                MatrixRow(title: node.name, detail: node.status, systemImage: "desktopcomputer", tint: node.status == "online" ? OpenClawTheme.neon : OpenClawTheme.amber)
                            }
                        }

                        SectionBlock(title: "Pending Approvals", systemImage: "exclamationmark.shield") {
                            ForEach(snapshot.approvals) { approval in
                                MatrixRow(title: approval.title, detail: "risk \(approval.risk)", systemImage: "shield.lefthalf.filled", tint: OpenClawTheme.amber)
                            }
                        }
                    } else {
                        ClawEmptyState(
                            title: "暂无运维快照",
                            message: "连接网关后点右上角刷新，就会拉取健康状态、在线节点和 approvals。",
                            systemImage: "waveform.path.ecg"
                        )
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
}

private struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        ClawCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(tint)
                    Spacer()
                    Circle()
                        .fill(tint)
                        .frame(width: 7, height: 7)
                }
                Text(value)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(OpenClawTheme.text)
                    .minimumScaleFactor(0.7)
                Text(title.uppercased())
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(OpenClawTheme.secondaryText)
            }
        }
    }
}

private struct SectionBlock<Content: View>: View {
    let title: String
    let systemImage: String
    private let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        ClawCard {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(OpenClawTheme.text)
                Spacer()
            }
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
    }
}

private struct MatrixRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: Circle())
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(OpenClawTheme.text)
                .lineLimit(1)
            Spacer()
            Text(detail.uppercased())
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(OpenClawTheme.secondaryText)
        }
        .padding(.vertical, 6)
    }
}
