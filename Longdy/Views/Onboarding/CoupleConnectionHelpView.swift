import SwiftUI

struct CoupleConnectionHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    VStack(spacing: 18) {
                        helpStep(
                            number: 1,
                            icon: "key.fill",
                            title: "한 사람이 초대 코드를 만들어요",
                            description: "초대 코드 만들기를 누르면 6자리 코드가 생성돼요."
                        )
                        helpStep(
                            number: 2,
                            icon: "square.and.arrow.up",
                            title: "상대방에게 코드를 보내요",
                            description: "복사 또는 공유하기로 생성된 코드를 전달해 주세요."
                        )
                        helpStep(
                            number: 3,
                            icon: "link",
                            title: "상대방이 코드를 입력해요",
                            description: "상대방이 받은 코드를 입력하고 연결하기를 누르면 두 사람의 공간이 열려요."
                        )
                    }

                    tips
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(CoupleSetupPalette.background.ignoresSafeArea())
            .navigationTitle("연결 방법")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("확인") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(CoupleSetupPalette.primary)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("둘 중 한 명만 초대 코드를 만들면 돼요")
                .font(.title3.weight(.bold))
                .foregroundStyle(CoupleSetupPalette.ink)
            Text("같은 코드를 사용해 두 계정을 하나의 커플 공간으로 연결해요.")
                .font(.subheadline)
                .foregroundStyle(CoupleSetupPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func helpStep(
        number: Int,
        icon: String,
        title: String,
        description: String
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(CoupleSetupPalette.surfaceHigh)
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(CoupleSetupPalette.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("STEP \(number)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(CoupleSetupPalette.primary)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(CoupleSetupPalette.ink)
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(CoupleSetupPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("연결 전 확인", systemImage: "info.circle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(CoupleSetupPalette.secondary)
            Text("• 두 기기에서 서로 다른 Apple 계정으로 로그인해 주세요.\n• 초대 코드를 재생성하면 이전 코드는 사용할 수 없어요.")
                .font(.footnote)
                .foregroundStyle(CoupleSetupPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoupleSetupPalette.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
