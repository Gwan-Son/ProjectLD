//
//  LongdyApp.swift
//  Longdy
//
//  Created by 심관혁 on 5/26/26.
//

import SwiftUI
import FirebaseCore

@main
struct LongdyApp: App {
    @StateObject private var appState = AppViewModel()

    init() {
        if FirebaseApp.app() == nil,
           Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
