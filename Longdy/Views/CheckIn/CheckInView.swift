import SwiftUI

struct CheckInView: View {
    @EnvironmentObject private var appState: AppViewModel
    @StateObject private var viewModel = CheckInViewModel()
    @State private var isSavingCheckIn = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    moodCard
                    statusCard
                    temperatureCard

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .background(MoodSharePalette.background.ignoresSafeArea())
            .navigationTitle("기분 공유")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.load(from: appState.myLatestCheckIn)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(viewModel.mood.iconName)
                .resizable()
                .scaledToFit()
                .padding(8)
                .frame(width: 72, height: 72)
                .background(MoodSharePalette.selectedBackground)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("지금의 나를 알려주세요")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(MoodSharePalette.ink)
                Text("말보다 가볍게, 오늘의 마음과 리듬을 나눠요.")
                    .font(.callout)
                    .foregroundStyle(MoodSharePalette.muted)
            }
        }
    }

    private var moodCard: some View {
        checkInCard(title: "지금 마음", iconName: viewModel.mood.iconName) {
            MoodIconPicker(selection: $viewModel.mood)
        }
    }

    private var statusCard: some View {
        checkInCard(title: "현재 상태", iconName: viewModel.status.iconName) {
            StatusIconPicker(selection: $viewModel.status)
        }
    }

    private var temperatureCard: some View {
        checkInCard(title: "공유 시간", systemImage: "clock") {
            Picker("유지 시간", selection: $viewModel.duration) {
                ForEach(MoodShareDuration.allCases) { duration in
                    Text(duration.title).tag(duration)
                }
            }
            .tint(MoodSharePalette.primary)

            Button(action: saveCheckIn) {
                saveLabel(isSaving: isSavingCheckIn, title: "기분 공유 저장")
            }
            .buttonStyle(MoodSharePrimaryButtonStyle())
            .disabled(isSavingCheckIn)
        }
    }

    private func checkInCard<Content: View>(
        title: String,
        iconName: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                if let iconName {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MoodSharePalette.primary)
                        .frame(width: 34, height: 34)
                }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(MoodSharePalette.ink)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoodSharePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MoodSharePalette.line.opacity(0.65), lineWidth: 1)
        }
    }

    private func saveLabel(isSaving: Bool, title: String) -> some View {
        HStack(spacing: 8) {
            if isSaving { ProgressView().tint(.white) }
            Text(isSaving ? "저장 중" : title)
        }
    }

    private func saveCheckIn() {
        isSavingCheckIn = true
        Task {
            if let checkIn = await viewModel.saveCheckIn(userId: appState.userId, coupleId: appState.coupleId) {
                appState.applySavedCheckIn(checkIn)
            }
            isSavingCheckIn = false
        }
    }

}

struct SliderRow: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MoodSharePalette.ink)
                Spacer()
                Text("\(Int(value))/5")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MoodSharePalette.primary)
            }
            Slider(value: $value, in: 1...5, step: 1)
                .tint(MoodSharePalette.primary)
        }
    }
}

private struct MoodSharePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(MoodSharePalette.primary.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MoodShareSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(MoodSharePalette.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(MoodSharePalette.selectedBackground.opacity(configuration.isPressed ? 0.65 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
