import SwiftUI

struct BridgeProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppViewModel

    private var progress: DailyBridgeProgress {
        appState.dailyBridgeProgress
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    bridgeArtwork
                    progressSection
                    milestoneSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(HomePalette.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("닫기")
                }
            }
            .onAppear {
                appState.refreshCoupleData(force: true)
            }
        }
        .tint(HomePalette.primary)
    }

    private var header: some View {
        BridgeScreenHeader(
            currentUser: appState.currentProfile,
            partner: appState.partner,
            eyebrow: "오늘 함께 만든 거리",
            title: "연결된 다리",
            summary: progress.stageTitle,
            primaryColor: HomePalette.primary,
            secondaryColor: HomePalette.secondary,
            inkColor: HomePalette.ink
        )
    }

    private var bridgeArtwork: some View {
        Image(progress.assetName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .aspectRatio(1.5, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .id(progress.assetName)
            .accessibilityLabel(progress.stageTitle)
    }

    private var progressSection: some View {
        VStack(spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text("\(progress.points)")
                    .font(.system(size: 50, weight: .bold, design: .serif))
                    .foregroundStyle(HomePalette.primary)
                Text("/ \(progress.goalPoints)")
                    .font(.headline)
                    .foregroundStyle(HomePalette.muted)
                Spacer()
                Text(progress.stageTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HomePalette.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(HomePalette.hero.opacity(0.18))
                    Capsule()
                        .fill(HomePalette.hero)
                        .frame(width: proxy.size.width * progress.fraction)
                }
            }
            .frame(height: 12)
        }
        .padding(20)
        .background(HomePalette.surface.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var milestoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘의 발판")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(HomePalette.ink)

            ForEach(progress.milestones) { milestone in
                milestoneRow(milestone)
            }
        }
    }

    private func milestoneRow(_ milestone: BridgeMilestone) -> some View {
        HStack(spacing: 14) {
            Image(systemName: milestone.isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(milestone.isComplete ? HomePalette.hero : HomePalette.tertiary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HomePalette.ink)
                Text(milestone.detail)
                    .font(.caption)
                    .foregroundStyle(HomePalette.muted)
            }

            Spacer(minLength: 8)

            Text("\(milestone.earnedPoints)/\(milestone.goalPoints)")
                .font(.caption.weight(.bold))
                .foregroundStyle(HomePalette.primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(HomePalette.hero.opacity(0.14))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(HomePalette.surface.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
