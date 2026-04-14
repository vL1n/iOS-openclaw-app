import SwiftUI

enum OpenClawTheme {
    static let ink = Color(red: 0.03, green: 0.04, blue: 0.07)
    static let deep = Color(red: 0.05, green: 0.08, blue: 0.14)
    static let panel = Color.white.opacity(0.09)
    static let panelStrong = Color.white.opacity(0.14)
    static let line = Color.white.opacity(0.14)
    static let text = Color.white.opacity(0.94)
    static let secondaryText = Color.white.opacity(0.62)
    static let neon = Color(red: 0.14, green: 0.88, blue: 0.78)
    static let blue = Color(red: 0.22, green: 0.52, blue: 1.0)
    static let amber = Color(red: 1.0, green: 0.66, blue: 0.22)
    static let danger = Color(red: 1.0, green: 0.32, blue: 0.42)

    static var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.03, blue: 0.06),
                Color(red: 0.05, green: 0.10, blue: 0.18),
                Color(red: 0.02, green: 0.05, blue: 0.07)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var halo: RadialGradient {
        RadialGradient(
            colors: [
                neon.opacity(0.38),
                blue.opacity(0.16),
                .clear
            ],
            center: .topTrailing,
            startRadius: 40,
            endRadius: 420
        )
    }
}

struct ClawBackground: View {
    var body: some View {
        ZStack {
            OpenClawTheme.background
            OpenClawTheme.halo
            GeometryReader { proxy in
                Path { path in
                    let step: CGFloat = 34
                    var x: CGFloat = 0
                    while x < proxy.size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + proxy.size.height * 0.4, y: proxy.size.height))
                        x += step
                    }
                }
                .stroke(OpenClawTheme.line.opacity(0.25), lineWidth: 0.5)
            }
            .opacity(0.35)
        }
        .ignoresSafeArea()
    }
}

struct ClawCard<Content: View>: View {
    let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(OpenClawTheme.panel, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(OpenClawTheme.line, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 22, y: 14)
    }
}

struct ClawHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let actionSystemImage: String?
    let action: (() -> Void)?

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        actionSystemImage: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.actionSystemImage = actionSystemImage
        self.action = action
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow.uppercased())
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(2.4)
                    .foregroundStyle(OpenClawTheme.neon)
                Text(title)
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(OpenClawTheme.text)
                    .minimumScaleFactor(0.75)
                Text(subtitle)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(OpenClawTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
            if let actionSystemImage, let action {
                Button(action: action) {
                    Image(systemName: actionSystemImage)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(OpenClawTheme.ink)
                        .frame(width: 44, height: 44)
                        .background(OpenClawTheme.neon, in: Circle())
                        .shadow(color: OpenClawTheme.neon.opacity(0.4), radius: 14)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ClawEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ClawCard {
            VStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(OpenClawTheme.neon)
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(OpenClawTheme.text)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(OpenClawTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }
}
