import SwiftUI
import UIKit

enum LongdyColors {
    static let primary = Color(red: 0.58, green: 0.28, blue: 0.26)
    static let ink = Color(red: 0.13, green: 0.18, blue: 0.24)
    static let muted = Color(red: 0.44, green: 0.43, blue: 0.40)
}

enum HomePalette {
    static let background = Color(red: 1.00, green: 0.96, blue: 0.97)
    static let surface = Color(red: 1.00, green: 0.98, blue: 0.98)
    static let primary = Color(red: 0.58, green: 0.28, blue: 0.26)
    static let hero = Color(red: 0.96, green: 0.59, blue: 0.56)
    static let heroInk = Color(red: 0.44, green: 0.18, blue: 0.16)
    static let secondary = Color(red: 0.49, green: 0.33, blue: 0.25)
    static let tertiary = Color(red: 0.80, green: 0.67, blue: 0.55)
    static let ink = Color(red: 0.16, green: 0.09, blue: 0.13)
    static let muted = Color(red: 0.33, green: 0.26, blue: 0.25)
}

enum CalendarPalette {
    static let background = Color(red: 1.00, green: 0.97, blue: 0.98)
    static let surface = Color(red: 1.00, green: 0.98, blue: 0.98)
    static let surfaceVariant = Color(red: 0.98, green: 0.85, blue: 0.91)
    static let primary = Color(red: 0.58, green: 0.28, blue: 0.26)
    static let hero = Color(red: 0.96, green: 0.59, blue: 0.56)
    static let heroInk = Color(red: 0.44, green: 0.18, blue: 0.16)
    static let secondary = Color(red: 0.49, green: 0.33, blue: 0.25)
    static let secondaryContainer = Color(red: 0.99, green: 0.78, blue: 0.68)
    static let tertiary = Color(red: 0.45, green: 0.35, blue: 0.25)
    static let tertiaryContainer = Color(red: 0.80, green: 0.67, blue: 0.55)
    static let ink = Color(red: 0.16, green: 0.09, blue: 0.13)
    static let muted = Color(red: 0.33, green: 0.26, blue: 0.25)

    static func eventColor(for type: EventType) -> Color {
        switch type {
        case .mine: primary
        case .partner: secondary
        case .meet: tertiary
        case .anniversary: Color(red: 0.70, green: 0.36, blue: 0.52)
        }
    }
}

enum CarePalette {
    static let background = Color(red: 1.00, green: 0.97, blue: 0.97)
    static let surface = Color.white
    static let surfaceContainer = Color(red: 1.00, green: 0.91, blue: 0.95)
    static let surfaceContainerLow = Color(red: 1.00, green: 0.94, blue: 0.96)
    static let surfaceHigh = Color(red: 1.00, green: 0.88, blue: 0.93)
    static let primary = Color(red: 0.58, green: 0.28, blue: 0.26)
    static let secondary = Color(red: 0.49, green: 0.33, blue: 0.25)
    static let tertiary = Color(red: 0.45, green: 0.35, blue: 0.25)
    static let primaryContainer = Color(red: 0.96, green: 0.59, blue: 0.56)
    static let onSurfaceVariant = Color(red: 0.33, green: 0.26, blue: 0.25)
    static let ink = Color(red: 0.16, green: 0.09, blue: 0.13)
    static let muted = Color(red: 0.33, green: 0.26, blue: 0.25)
    static let outline = Color(red: 0.53, green: 0.45, blue: 0.44)
    static let line = Color(red: 0.85, green: 0.76, blue: 0.75)
}

enum PhotoPalette {
    static let background = Color(red: 1.00, green: 0.97, blue: 0.97)
    static let surface = Color.white
    static let surfaceContainerLow = Color(red: 1.00, green: 0.94, blue: 0.96)
    static let primary = Color(red: 0.58, green: 0.28, blue: 0.26)
    static let secondary = Color(red: 0.49, green: 0.33, blue: 0.25)
    static let ink = Color(red: 0.16, green: 0.09, blue: 0.13)
    static let muted = Color(red: 0.33, green: 0.26, blue: 0.25)
    static let line = Color(red: 0.85, green: 0.76, blue: 0.75)
    static let error = Color(red: 0.73, green: 0.10, blue: 0.10)
}

enum WeatherPalette {
    static let background = Color(red: 1.00, green: 0.96, blue: 0.97)
    static let surface = Color(red: 1.00, green: 0.98, blue: 0.98)
    static let blush = Color(red: 1.00, green: 0.89, blue: 0.93)
    static let apricot = Color(red: 0.99, green: 0.78, blue: 0.68)
    static let mauve = Color(red: 0.89, green: 0.79, blue: 0.82)
    static let primary = Color(red: 0.58, green: 0.28, blue: 0.26)
    static let ink = Color(red: 0.16, green: 0.09, blue: 0.13)
    static let muted = Color(red: 0.33, green: 0.26, blue: 0.25)
}

enum LoginPalette {
    static let background = Color(red: 1.00, green: 0.97, blue: 0.97)
    static let surfaceContainer = Color(red: 1.00, green: 0.91, blue: 0.95)
    static let primary = Color(red: 0.58, green: 0.28, blue: 0.26)
    static let ink = Color(red: 0.16, green: 0.09, blue: 0.13)
    static let muted = Color(red: 0.33, green: 0.26, blue: 0.25)
    static let outline = Color(red: 0.53, green: 0.45, blue: 0.44)
    static let error = Color(red: 0.73, green: 0.10, blue: 0.10)
}

enum CoupleSetupPalette {
    static let background = Color(red: 1.00, green: 0.97, blue: 0.97)
    static let surfaceLow = Color(red: 1.00, green: 0.94, blue: 0.96)
    static let surfaceHigh = Color(red: 0.98, green: 0.85, blue: 0.91)
    static let primary = Color(red: 0.58, green: 0.28, blue: 0.26)
    static let primaryContainer = Color(red: 0.96, green: 0.59, blue: 0.56)
    static let secondary = Color(red: 0.49, green: 0.33, blue: 0.25)
    static let ink = Color(red: 0.16, green: 0.09, blue: 0.13)
    static let muted = Color(red: 0.33, green: 0.26, blue: 0.25)
    static let outline = Color(red: 0.53, green: 0.45, blue: 0.44)
    static let line = Color(red: 0.85, green: 0.76, blue: 0.75)
    static let error = Color(red: 0.73, green: 0.10, blue: 0.10)
}

enum MoodSharePalette {
    static let surface = Color.white.opacity(0.82)
    static let iconBackground = Color(red: 1.00, green: 0.91, blue: 0.94)
    static let selectedIcon = Color(red: 1.00, green: 0.82, blue: 0.84)
    static let selectedBackground = Color(red: 1.00, green: 0.91, blue: 0.93)
    static let primary = Color(red: 0.58, green: 0.28, blue: 0.26)
    static let ink = Color(red: 0.16, green: 0.09, blue: 0.13)
    static let line = Color(red: 0.88, green: 0.78, blue: 0.79)
}

struct BridgeAvatar: View {
    let user: LongdyUser?
    let fallback: String
    var size: CGFloat = 40
    var strokeColor = Color(red: 0.96, green: 0.59, blue: 0.56)

    var body: some View {
        ZStack {
            Color(red: 1.00, green: 0.98, blue: 0.98)
            if let image = profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(user?.friendlyName.first.map(String.init) ?? fallback)
                    .font(.system(size: max(14, size * 0.34), weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.58, green: 0.28, blue: 0.26))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(strokeColor, lineWidth: 2)
        }
    }

    private var profileImage: UIImage? {
        guard let urlText = user?.profilePhotoURL,
              let url = URL(string: urlText),
              url.isFileURL else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

struct BridgeScreenHeader: View {
    let currentUser: LongdyUser?
    let partner: LongdyUser?
    let eyebrow: String
    let title: String
    let summary: String?
    let primaryColor: Color
    let secondaryColor: Color
    let inkColor: Color

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                headerAvatar(for: currentUser, fallback: "나", stroke: primaryColor)
                Spacer()
                Text("Our Bridge")
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .foregroundStyle(primaryColor)
                Spacer()
                headerAvatar(for: partner, fallback: "?", stroke: secondaryColor)
            }

            VStack(spacing: 8) {
                Text(eyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryColor)
                Text(title)
                    .font(.system(size: 38, weight: .semibold, design: .serif))
                    .foregroundStyle(inkColor)
                    .multilineTextAlignment(.center)
                if let summary {
                    Text(summary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(secondaryColor.opacity(0.16))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func headerAvatar(for user: LongdyUser?, fallback: String, stroke: Color) -> some View {
        BridgeAvatar(user: user, fallback: fallback, strokeColor: stroke)
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
