import OpenClawCore
import SwiftUI

struct SettingsFeature: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        ZStack {
            ClawBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ClawHeader(
                        eyebrow: "Control Rig",
                        title: "Settings",
                        subtitle: "Tune the local operator link"
                    )

                    SettingsPanel(title: "Gateway", systemImage: "antenna.radiowaves.left.and.right") {
                        FieldRow(title: "Display Name") {
                            TextField("Display Name", text: $model.profileDraft.name)
                        }
                        FieldRow(title: "WebSocket URL") {
                            TextField("WebSocket URL", text: $model.profileDraft.endpoint)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transport")
                                .font(.system(.caption2, design: .monospaced).weight(.bold))
                                .foregroundStyle(OpenClawTheme.neon)
                            Picker("Transport", selection: $model.profileDraft.transportMode) {
                                ForEach(TransportMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        Toggle("Allow trusted local ws://", isOn: $model.profileDraft.allowInsecureLocal)
                            .tint(OpenClawTheme.neon)
                            .foregroundStyle(OpenClawTheme.text)
                        FieldRow(title: "Scopes") {
                            TextField("Scopes", text: $model.profileDraft.requestedScopes)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }

                    SettingsPanel(title: "Auth", systemImage: "key.horizontal.fill") {
                        FieldRow(title: "Gateway Token") {
                            SecureField("Gateway Token", text: $model.authToken)
                        }
                        FieldRow(title: "Device ID") {
                            TextField("Device ID", text: $model.deviceID)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }

                    SettingsPanel(title: "Connection", systemImage: "bolt.horizontal.circle.fill") {
                        StatusLine(title: "Status", value: model.connectionSummary)
                        HStack(spacing: 10) {
                            ActionButton(title: "Connect", systemImage: "link") {
                                Task { await model.connect() }
                            }
                            .disabled(model.isWorking)
                            .opacity(model.isWorking ? 0.45 : 1)

                            ActionButton(title: "Refresh", systemImage: "arrow.clockwise") {
                                Task { await model.refreshAll() }
                            }
                        }

                        Button {
                            Task { await model.disconnect() }
                        } label: {
                            Label("Disconnect", systemImage: "xmark.circle")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(OpenClawTheme.danger)
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsPanel(title: "Notifications", systemImage: "bell.badge.fill") {
                        StatusLine(title: "Authorization", value: model.pushAuthorizationStatus)
                        StatusLine(title: "Registration", value: model.pushRegistrationStatus)
                        ActionButton(title: "Request APNs Permission", systemImage: "bell.and.waves.left.and.right") {
                            Task { await model.requestPushAuthorization() }
                        }
                    }

                    SettingsPanel(title: "Diagnostics", systemImage: "waveform.path.ecg") {
                        StatusLine(title: "Retry Count", value: "\(model.diagnostics.retryCount)")
                        if let tlsNotes = model.diagnostics.tlsNotes {
                            Text(tlsNotes)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(OpenClawTheme.secondaryText)
                        }
                        if let rpcError = model.diagnostics.lastRPCError {
                            Text("Last RPC Error: \(rpcError)")
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(OpenClawTheme.amber)
                        }

                        ForEach(Array(model.diagnostics.connectionTimeline.enumerated()), id: \.offset) { item in
                            StatusLine(title: item.element.phase.rawValue.capitalized, value: item.element.timestamp.formatted(date: .omitted, time: .shortened))
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
}

private struct SettingsPanel<Content: View>: View {
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
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: systemImage)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(OpenClawTheme.text)
                content
            }
        }
    }
}

private struct FieldRow<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(OpenClawTheme.neon)
            content
                .font(.system(.body, design: .rounded))
                .foregroundStyle(OpenClawTheme.text)
                .tint(OpenClawTheme.neon)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(OpenClawTheme.panelStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct StatusLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(OpenClawTheme.text)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(OpenClawTheme.secondaryText)
                .lineLimit(1)
        }
    }
}

private struct ActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(OpenClawTheme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(OpenClawTheme.neon, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
