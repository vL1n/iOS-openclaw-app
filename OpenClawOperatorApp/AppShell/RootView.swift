import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        return TabView(selection: $model.selectedTab) {
            NavigationStack {
                ChatFeature()
            }
            .tabItem {
                Label("Chat", systemImage: "bubble.left.and.text.bubble.right.fill")
            }
            .tag(AppTab.chat)

            NavigationStack {
                SessionsFeature()
            }
            .tabItem {
                Label("Sessions", systemImage: "rectangle.stack.person.crop.fill")
            }
            .tag(AppTab.sessions)

            NavigationStack {
                OpsFeature()
            }
            .tabItem {
                Label("Ops", systemImage: "waveform.path.ecg.rectangle.fill")
            }
            .tag(AppTab.ops)

            NavigationStack {
                SettingsFeature()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.2.fill")
            }
            .tag(AppTab.settings)
        }
        .tint(Color(red: 0.07, green: 0.45, blue: 0.69))
        .overlay(alignment: .top) {
            if let bannerMessage = model.bannerMessage {
                Text(bannerMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.72), in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
