import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppViewModel

    var body: some View {
        Group {
            if appState.isLoadingSession {
                LoadingView(message: "Longdy를 준비하고 있어요")
            } else if appState.appleSession == nil {
                AuthView()
            } else if appState.currentProfile?.partnerCoupleId == nil {
                CoupleSetupView()
            } else if appState.couple == nil {
                LoadingView(message: "커플 공간을 확인하고 있어요")
            } else if (appState.couple?.memberIds.count ?? 0) < 2 {
                CoupleSetupView()
            } else if appState.isLoadingCoupleData {
                LoadingView(message: "둘의 하루를 불러오고 있어요")
            } else {
                MainTabView()
            }
        }
        .task {
            appState.start()
        }
        .task(id: appState.coupleId) {
            await appState.pollCoupleStatus()
        }
        .alert("기존 초대를 버리고 연결할까요?", isPresented: $appState.showReplaceInviteConfirmation) {
            Button("취소", role: .cancel) {
                appState.cancelPendingShareAcceptance()
            }
            Button("연결하기", role: .destructive) {
                appState.acceptPendingShareReplacingCurrentInvite()
            }
        } message: {
            Text("이미 만든 공유 초대가 있어요. 상대의 초대를 수락하면 기존 초대는 삭제되고 새 커플 공간으로 연결돼요.")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel.preview)
}
