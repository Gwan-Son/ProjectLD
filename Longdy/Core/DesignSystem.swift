import SwiftUI

enum LongdyColors {
    static let background = Color(red: 0.98, green: 0.95, blue: 0.90)
    static let surface = Color(red: 1.00, green: 0.99, blue: 0.96)
    static let primary = Color(red: 0.58, green: 0.28, blue: 0.26)
    static let peach = Color(red: 0.96, green: 0.63, blue: 0.49)
    static let mint = Color(red: 0.70, green: 0.82, blue: 0.73)
    static let ink = Color(red: 0.13, green: 0.18, blue: 0.24)
    static let muted = Color(red: 0.44, green: 0.43, blue: 0.40)
    static let line = Color(red: 0.88, green: 0.82, blue: 0.74)
}

struct LongdyCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LongdyColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(LongdyColors.line.opacity(0.55), lineWidth: 1)
            )
    }
}

struct SectionTitle: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(LongdyColors.ink)
    }
}

struct BridgeAvatar: View {
    let user: LongdyUser?
    let fallback: String

    var body: some View {
        Text(user?.friendlyName.first.map(String.init) ?? fallback)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.58, green: 0.28, blue: 0.26))
            .frame(width: 40, height: 40)
            .background(Color(red: 1.00, green: 0.98, blue: 0.98))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color(red: 0.96, green: 0.59, blue: 0.56), lineWidth: 2)
            )
    }
}

struct LoadingView: View {
    let message: String

    var body: some View {
        ZStack {
            Color(red: 1.00, green: 0.96, blue: 0.97)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(Color(red: 0.58, green: 0.28, blue: 0.26))

                Text(message)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Color(red: 0.33, green: 0.26, blue: 0.25))
            }
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image("empty-state")
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 96)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(LongdyColors.ink)
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(LongdyColors.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(LongdyColors.peach.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension View {
    func longdyScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(LongdyColors.background.ignoresSafeArea())
    }
}
