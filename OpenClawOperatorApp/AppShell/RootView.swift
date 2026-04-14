import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        return ZStack {
            ClawBackground()

            TabView(selection: $model.selectedTab) {
                NavigationStack {
                    ChatFeature()
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.text.bubble.right.fill")
                }
                .tag(AppTab.chat)

                NavigationStack {
                    SessionsFeature()
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .tabItem {
                    Label("Sessions", systemImage: "rectangle.stack.person.crop.fill")
                }
                .tag(AppTab.sessions)

                NavigationStack {
                    OpsFeature()
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .tabItem {
                    Label("Ops", systemImage: "waveform.path.ecg.rectangle.fill")
                }
                .tag(AppTab.ops)

                NavigationStack {
                    SettingsFeature()
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .tag(AppTab.settings)
            }
            .tint(OpenClawTheme.neon)
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            if let bannerMessage = model.bannerMessage {
                Text(bannerMessage)
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    .foregroundStyle(OpenClawTheme.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(OpenClawTheme.panelStrong, in: Capsule())
                    .overlay(Capsule().stroke(OpenClawTheme.neon.opacity(0.55), lineWidth: 1))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
