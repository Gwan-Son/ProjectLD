import SwiftUI

struct MoodIconPicker: View {
    @Binding var selection: Mood

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Mood.allCases) { mood in
                MoodStatusOptionButton(
                    title: mood.rawValue,
                    iconName: mood.iconName,
                    isSelected: selection == mood
                ) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        selection = mood
                    }
                }
            }
        }
    }
}

struct StatusIconPicker: View {
    @Binding var selection: LongdyStatus

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(LongdyStatus.allCases) { status in
                MoodStatusOptionButton(
                    title: status.rawValue,
                    iconName: status.iconName,
                    isSelected: selection == status,
                    compact: true
                ) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        selection = status
                    }
                }
            }
        }
    }
}

private struct MoodStatusOptionButton: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if compact {
                HStack(spacing: 10) {
                    icon
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? MoodSharePalette.primary : MoodSharePalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(optionBackground)
            } else {
                VStack(spacing: 7) {
                    icon
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? MoodSharePalette.primary : MoodSharePalette.ink)
                }
                .frame(maxWidth: .infinity, minHeight: 104)
                .background(optionBackground)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var icon: some View {
        Image(iconName)
            .resizable()
            .scaledToFit()
            .padding(compact ? 5 : 7)
            .frame(width: compact ? 46 : 64, height: compact ? 46 : 64)
            .background(isSelected ? MoodSharePalette.selectedIcon : MoodSharePalette.iconBackground)
            .clipShape(Circle())
            .scaleEffect(isSelected ? 0.94 : 1)
    }

    private var optionBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isSelected ? MoodSharePalette.selectedBackground : MoodSharePalette.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? MoodSharePalette.primary : MoodSharePalette.line, lineWidth: isSelected ? 2 : 1)
            }
    }
}
