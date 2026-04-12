import OpenClawCore
import SwiftUI

struct SettingsFeature: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        Form {
            Section("Gateway") {
                TextField("Display Name", text: $model.profileDraft.name)
                TextField("WebSocket URL", text: $model.profileDraft.endpoint)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                Picker("Transport", selection: $model.profileDraft.transportMode) {
                    ForEach(TransportMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                Toggle("Allow trusted local ws://", isOn: $model.profileDraft.allowInsecureLocal)
                TextField("Scopes", text: $model.profileDraft.requestedScopes)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Auth") {
                SecureField("Gateway Token", text: $model.authToken)
                TextField("Device ID", text: $model.deviceID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Connection") {
                LabeledContent("Status", value: model.connectionSummary)
                Button("Connect") {
                    Task { await model.connect() }
                }
                .disabled(model.authToken.isEmpty || model.isWorking)

                Button("Disconnect", role: .destructive) {
                    Task { await model.disconnect() }
                }

                Button("Refresh Everything") {
                    Task { await model.refreshAll() }
                }
            }

            Section("Notifications") {
                LabeledContent("Authorization", value: model.pushAuthorizationStatus)
                LabeledContent("Registration", value: model.pushRegistrationStatus)
                Button("Request APNs Permission") {
                    Task { await model.requestPushAuthorization() }
                }
            }

            Section("Diagnostics") {
                LabeledContent("Retry Count", value: "\(model.diagnostics.retryCount)")
                if let tlsNotes = model.diagnostics.tlsNotes {
                    Text(tlsNotes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let rpcError = model.diagnostics.lastRPCError {
                    Text("Last RPC Error: \(rpcError)")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                ForEach(Array(model.diagnostics.connectionTimeline.enumerated()), id: \.offset) { item in
                    HStack {
                        Text(item.element.phase.rawValue.capitalized)
                        Spacer()
                        Text(item.element.timestamp, style: .time)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
}
