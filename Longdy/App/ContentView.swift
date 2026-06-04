import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppViewModel

    var body: some View {
        Group {
            if !appState.isFirebaseConfigured {
                FirebaseSetupView()
            } else if appState.isLoadingSession {
                LoadingView(message: "Longdy를 준비하고 있어요")
            } else if appState.currentUser == nil {
                AuthView()
            } else if appState.currentProfile?.partnerCoupleId == nil {
                CoupleSetupView()
            } else {
                MainTabView()
            }
        }
        .task {
            appState.start()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel.preview)
}
