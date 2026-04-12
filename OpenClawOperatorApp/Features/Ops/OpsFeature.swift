import OpenClawCore
import SwiftUI

struct OpsFeature: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !model.canAccessOps {
                    ContentUnavailableView(
                        "当前连接没有 Ops 能力",
                        systemImage: "lock.slash",
                        description: Text("如果这是基础 scope 的 token，聊天仍可使用；需要更多 scopes 才会看到运维卡片。")
                    )
                } else if let snapshot = model.opsSnapshot {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(title: "Gateway", value: snapshot.gatewayHealth.rawValue.capitalized, tint: snapshot.gatewayHealth == .healthy ? .green : .orange)
                        MetricCard(title: "Nodes", value: "\(snapshot.nodeCount)", tint: .blue)
                        MetricCard(title: "Approvals", value: "\(snapshot.pendingApprovals)", tint: .orange)
                        MetricCard(title: "Tokens Today", value: "\(snapshot.usageSummary.tokensToday)", tint: .purple)
                    }

                    SectionBlock(title: "Active Models") {
                        ForEach(snapshot.modelStatus, id: \.self) { modelStatus in
                            Label(modelStatus, systemImage: "cpu.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    SectionBlock(title: "Online Nodes") {
                        ForEach(snapshot.onlineNodes) { node in
                            HStack {
                                Label(node.name, systemImage: "desktopcomputer")
                                Spacer()
                                Text(node.status)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    SectionBlock(title: "Pending Approvals") {
                        ForEach(snapshot.approvals) { approval in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(approval.title)
                                    .font(.subheadline.weight(.semibold))
                                Text("Risk: \(approval.risk)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "暂无运维快照",
                        systemImage: "waveform.path.ecg",
                        description: Text("连接网关后点右上角刷新，就会拉取健康状态、在线节点和 approvals。")
                    )
                }
            }
            .padding()
        }
        .background(Color(red: 0.98, green: 0.98, blue: 0.99))
        .navigationTitle("Ops")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refreshOps() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SectionBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
