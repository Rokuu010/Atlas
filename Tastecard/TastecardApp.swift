//
//  TastecardApp.swift
//  Tastecard
//
//  App entry + root flow router (§4). One @StateObject AppModel drives the phase.
//

import SwiftUI

@main
struct TastecardApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)   // chrome stays dark; the card supplies its own palette
                .statusBarHidden(false)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            switch model.phase {
            case .greeting:
                GreetingView()
            case .priming:
                PermissionPrimingView()
            case .generating:
                GenerationView()
            case .card:
                if let vm = model.cardViewModel {
                    CardView(vm: vm)
                } else {
                    GreetingView()
                }
            case .warmingUp(let reason, let scanned):
                WarmingUpView(reason: reason, photosScanned: scanned)
            case .permissionDenied:
                PermissionDeniedView()
            case .setupRequired(let message):
                SetupRequiredView(message: message)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.phase)
    }
}
