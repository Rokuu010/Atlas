//
//  PermissionDeniedView.swift
//  Tastecard
//
//  Graceful handling when Photos access is denied/restricted (§4.3, §10 performance &
//  stability). No crash, a clear path to Settings, and the honest privacy reassurance.
//

import SwiftUI
import UIKit

struct PermissionDeniedView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            OnboardingBackground()
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: "lock.slash")
                    .font(.system(size: 42, weight: .light))
                    .foregroundColor(.white)
                Text("Photo access is off")
                    .font(AppFont.display(24, weight: .bold))
                    .foregroundColor(.white)
                Text("Rollcard needs to read your photos on this device to build your card. You can turn this on in Settings — your photos still never leave your device.")
                    .font(AppFont.sans(15))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.72))
                    .padding(.horizontal, 28)
                Spacer()
                VStack(spacing: 14) {
                    CTAButton(title: "Open Settings", systemImage: "gear") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    SecondaryButton(title: "Back") { model.phase = .greeting }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
            }
        }
        .onAppear { model.photoService.refreshAuthorization() }
    }
}
